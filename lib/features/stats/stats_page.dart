import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/app_theme.dart';
import '../../app/home_shell.dart';
import '../../core/l10n/l10n_ext.dart';
import '../../data/repository/providers.dart';
import '../../domain/entity/budget.dart';
import '../budget/budget_progress.dart';
import '../budget/budget_providers.dart';
import '../record/record_providers.dart';
import 'stats_export_service.dart';
import 'stats_range_providers.dart';

class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  final GlobalKey _chartsBoundaryKey = GlobalKey();
  final StatsExportService _exportService = StatsExportService();
  bool _exporting = false;

  Future<void> _onExportPressed() async {
    if (_exporting) return;
    final choice = await showModalBottomSheet<_ExportKind>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: Text(ctx.l10n.statsExportPng),
                onTap: () => Navigator.of(ctx).pop(_ExportKind.png),
              ),
              ListTile(
                leading: const Icon(Icons.table_chart_outlined),
                title: Text(ctx.l10n.statsExportCsv),
                onTap: () => Navigator.of(ctx).pop(_ExportKind.csv),
              ),
            ],
          ),
        );
      },
    );
    if (choice == null) return;
    setState(() => _exporting = true);
    try {
      switch (choice) {
        case _ExportKind.png:
          await _exportPng();
          break;
        case _ExportKind.csv:
          await _exportCsv();
          break;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.statsExportFailed(e.toString()))),
      );
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<void> _exportPng() async {
    final boundary =
        _chartsBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    final l10n = context.l10n;
    if (boundary == null) {
      throw StateError(l10n.statsChartNotMounted);
    }
    final range = ref.read(statsRangeProvider).range;
    final file = await _exportService.exportPng(
      boundary: boundary,
      range: range,
    );
    await _exportService.shareFile(
      file,
      subject: l10n.statsPngTitle,
      text: l10n.statsPngSubtitle(_formatRange(range)),
    );
  }

  Future<void> _exportCsv() async {
    final l10n = context.l10n;
    final range = ref.read(statsRangeProvider).range;
    final ledgerId = await ref.read(currentLedgerIdProvider.future);
    final txRepo = await ref.read(transactionRepositoryProvider.future);
    final catRepo = await ref.read(categoryRepositoryProvider.future);
    final accRepo = await ref.read(accountRepositoryProvider.future);

    final entries = await txRepo.listActiveByLedger(ledgerId);
    final categories = await catRepo.listActiveAll();
    final accounts = await accRepo.listActive();

    final file = await _exportService.exportCsv(
      entries: entries,
      categoryMap: {for (final c in categories) c.id: c},
      accountMap: {for (final a in accounts) a.id: a},
      range: range,
    );
    await _exportService.shareFile(
      file,
      subject: l10n.statsCsvTitle,
      text: l10n.statsCsvSubtitle(_formatRange(range)),
    );
  }

  String _formatRange(StatsDateRange range) {
    final fmt = DateFormat('yyyy-MM-dd');
    return '${fmt.format(range.start)} ~ ${fmt.format(range.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(statsRangeProvider);
    final notifier = ref.read(statsRangeProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const SizedBox(width: 40),
                  Expanded(
                    child: Center(
                      child: Text(
                        context.l10n.statsTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: _exporting
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.ios_share),
                            tooltip: context.l10n.statsExport,
                            onPressed: _onExportPressed,
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _PresetChip(
                    label: context.l10n.statsThisMonth,
                    selected: state.preset == StatsRangePreset.thisMonth,
                    onTap: () => notifier.setPreset(StatsRangePreset.thisMonth),
                  ),
                  const SizedBox(width: 8),
                  _PresetChip(
                    label: context.l10n.statsLastMonth,
                    selected: state.preset == StatsRangePreset.lastMonth,
                    onTap: () => notifier.setPreset(StatsRangePreset.lastMonth),
                  ),
                  const SizedBox(width: 8),
                  _PresetChip(
                    label: context.l10n.statsThisYear,
                    selected: state.preset == StatsRangePreset.thisYear,
                    onTap: () => notifier.setPreset(StatsRangePreset.thisYear),
                  ),
                  const SizedBox(width: 8),
                  _PresetChip(
                    label: context.l10n.statsCustom,
                    selected: state.preset == StatsRangePreset.custom,
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDateRangePicker(
                        context: context,
                        locale: const Locale('zh', 'CN'),
                        firstDate: DateTime(now.year - 10, 1, 1),
                        lastDate: DateTime(now.year + 10, 12, 31),
                        initialDateRange: DateTimeRange(
                          start: state.range.start,
                          end: state.range.end,
                        ),
                        helpText: context.l10n.statsSelectRange,
                        saveText: context.l10n.confirm,
                        cancelText: context.l10n.cancel,
                      );
                      if (picked == null) return;
                      notifier.setCustomRange(picked.start, picked.end);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _RangeBanner(range: state.range),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: RepaintBoundary(
                  key: _chartsBoundaryKey,
                  child: Container(
                    color: Theme.of(context).colorScheme.surface,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        SizedBox(height: 300, child: _CategoryPieCard()),
                        const SizedBox(height: 12),
                        _RankingCard(),
                        const SizedBox(height: 12),
                        const SizedBox(
                          height: 320,
                          child: _HeatmapCard(),
                        ),
                        const SizedBox(height: 12),
                        const SizedBox(
                          height: 320,
                          child: _YearlyLineCard(),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ExportKind { png, csv }

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: colors.primary.withAlpha(80),
      backgroundColor: colors.surfaceContainerHighest.withAlpha(120),
      side: BorderSide(color: colors.primary.withAlpha(120)),
      labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colors.onSurface,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
    );
  }
}

class _RangeBanner extends StatelessWidget {
  const _RangeBanner({required this.range});

  final StatsDateRange range;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy-MM-dd');
    final text = '${fmt.format(range.start)} ~ ${fmt.format(range.end)}';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(110),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.date_range_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPieCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slicesAsync = ref.watch(statsPieSlicesProvider);
    final totalBudgetAsync = ref.watch(totalBudgetProvider);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.statsExpenseCategoryPie,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // 总预算进度环：与预算设置页同源；无总预算时整个区域留空。
                totalBudgetAsync.maybeWhen(
                  data: (budget) => budget == null
                      ? const SizedBox.shrink()
                      : _TotalBudgetRing(budget: budget),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: slicesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    context.l10n.statsChartLoadFailed(e.toString()),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                data: (slices) {
                  if (slices.isEmpty) {
                    return _PieChartEmptyState();
                  }
                  return _PieChartView(slices: slices);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PieChartEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pie_chart_outline, size: 34),
          const SizedBox(height: 8),
          Text(
            context.l10n.statsNoExpenseData,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.statsAddExpenseHint,
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Step 6.3：饼图卡片头部展示的总预算进度环。
///
/// 通过 [budgetProgressForProvider] 与预算设置页同源，保证两页"已花 / 上限"
/// 完全一致；点击跳转 `/budget` 进入预算设置页。
class _TotalBudgetRing extends ConsumerWidget {
  const _TotalBudgetRing({required this.budget});

  final Budget budget;

  static const double _size = 44;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(budgetProgressForProvider(budget));
    final theme = Theme.of(context);
    final semantic = theme.extension<BianBianSemanticColors>()!;

    return Tooltip(
      message: context.l10n.statsViewBudget,
      child: InkWell(
        borderRadius: BorderRadius.circular(_size),
        onTap: () => context.push('/budget'),
        child: SizedBox(
          width: _size,
          height: _size,
          child: progressAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            error: (_, _) => Icon(
              Icons.error_outline,
              size: 20,
              color: semantic.danger,
            ),
            data: (progress) {
              final color = switch (progress.level) {
                BudgetProgressLevel.green => semantic.success,
                BudgetProgressLevel.orange => semantic.warning,
                BudgetProgressLevel.red => semantic.danger,
              };
              final ratioClamped = progress.ratio.clamp(0.0, 1.0);
              final percent = (progress.ratio * 100).toStringAsFixed(0);
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: _size,
                    height: _size,
                    child: CircularProgressIndicator(
                      value: ratioClamped,
                      strokeWidth: 4,
                      backgroundColor: color.withValues(alpha: 0.18),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PieChartView extends StatefulWidget {
  const _PieChartView({required this.slices});

  final List<StatsPieSlice> slices;

  @override
  State<_PieChartView> createState() => _PieChartViewState();
}

class _PieChartViewState extends State<_PieChartView> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        response == null ||
                        response.touchedSection == null) {
                      _touchedIndex = null;
                      return;
                    }
                    _touchedIndex =
                        response.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              sectionsSpace: 2,
              centerSpaceRadius: 32,
              sections: _buildSections(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: _LegendList(slices: widget.slices),
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildSections() {
    final textTheme = Theme.of(context).textTheme;
    final total = widget.slices.fold<double>(0, (s, e) => s + e.amount);

    return widget.slices.asMap().entries.map((entry) {
      final i = entry.key;
      final s = entry.value;
      final isTouched = i == _touchedIndex;
      final radius = isTouched ? 55.0 : 45.0;
      final pct = total > 0 ? (s.amount / total * 100).toStringAsFixed(1) : '0.0';

      return PieChartSectionData(
        color: s.categoryColor,
        value: s.amount,
        title: '$pct%',
        radius: radius,
        titleStyle: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: _contrastColor(s.categoryColor),
        ),
        badgeWidget: isTouched
            ? Text(
                '¥${NumberFormat('#,##0').format(s.amount)}',
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
        badgePositionPercentageOffset: 1.4,
      );
    }).toList(growable: false);
  }

  Color _contrastColor(Color bg) {
    final luminance = bg.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }
}

class _LegendList extends StatelessWidget {
  const _LegendList({required this.slices});

  final List<StatsPieSlice> slices;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final moneyFmt = NumberFormat('#,##0');
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: slices.map((s) {
          // Localize fallback names from aggregation functions
          final displayName = s.categoryId == null
              ? context.l10n.parentKeyOther
          // i18n-exempt: '未分类' matches DB seed data name, not UI display
              : (s.categoryName == '未分类' ? context.l10n.txTypeUncategorized : s.categoryName);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: s.categoryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    displayName,
                    style: textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '¥${moneyFmt.format(s.amount)}',
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _RankingCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankAsync = ref.watch(statsRankItemsProvider);
    final theme = Theme.of(context);
    final moneyFmt = NumberFormat('#,##0.00');

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.statsRanking,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            rankAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  context.l10n.statsRankLoadFailed(e.toString()),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return _RankingEmptyState();
                }
                final top10 = items.take(10).toList(growable: false);
                return _RankingList(
                  items: top10,
                  moneyFmt: moneyFmt,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.leaderboard_outlined, size: 34),
          const SizedBox(height: 8),
          Text(
            context.l10n.statsNoRankData,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.statsAddMoreHint,
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _RankingList extends StatelessWidget {
  const _RankingList({
    required this.items,
    required this.moneyFmt,
  });

  final List<StatsRankItem> items;
  final NumberFormat moneyFmt;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final maxAmount = items.isNotEmpty ? items.first.amount : 1.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0) const SizedBox(height: 2),
          Builder(builder: (context) {
            final item = items[index];
            // Localize fallback names from aggregation functions
            // i18n-exempt: '未分类' matches DB seed data name, not UI display
            final displayName = item.categoryName == '未分类'
                ? context.l10n.txTypeUncategorized
                : (item.categoryId == null ? context.l10n.parentKeyOther : item.categoryName);
            final ratio = maxAmount > 0 ? item.amount / maxAmount : 0.0;
            final prefix = item.isIncome ? '+' : '-';

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    child: Text(
                      '${index + 1}',
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: index < 3
                            ? item.categoryColor
                            : Theme.of(context).colorScheme.onSurface.withAlpha(150),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: item.categoryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    flex: 3,
                    child: Text(
                      displayName,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    flex: 4,
                    child: Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withAlpha(150),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: ratio.clamp(0.0, 1.0),
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: item.categoryColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 120,
                    child: Text(
                      '$prefix¥${moneyFmt.format(item.amount)}',
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: item.isIncome
                            ? Theme.of(context).extension<BianBianSemanticColors>()!.success
                            : Theme.of(context).extension<BianBianSemanticColors>()!.danger,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _HeatmapCard extends ConsumerWidget {
  const _HeatmapCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heatmapAsync = ref.watch(statsHeatmapCellsProvider);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.statsHeatmapTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.statsHeatmapLegend,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: heatmapAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    context.l10n.statsHeatmapLoadFailed(e.toString()),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                data: (cells) {
                  if (cells.isEmpty) {
                    return _HeatmapEmptyState();
                  }
                  return _HeatmapView(
                    cells: cells,
                    onTapDay: (day) {
                      ref.read(recordMonthProvider.notifier).jumpTo(day);
                      ref.read(recordScrollTargetProvider.notifier).state =
                          DateTime(day.year, day.month, day.day);
                      HomeShell.switchToRecordTab();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeatmapEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_month_outlined, size: 34),
          const SizedBox(height: 8),
          Text(
            context.l10n.statsNoHeatmapData,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.statsHeatmapHint,
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _HeatmapView extends StatelessWidget {
  const _HeatmapView({
    required this.cells,
    required this.onTapDay,
  });

  final List<StatsHeatmapCell> cells;
  final ValueChanged<DateTime> onTapDay;

  static const double _cellSize = 22;
  static const double _cellGap = 6;
  static const double _weekGap = 6;
  static const double _weekdayColumnWidth = 20;

  @override
  Widget build(BuildContext context) {
    final weeks = _buildWeeks(cells);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          width: _weekdayColumnWidth,
          child: _WeekdayAxis(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: weeks
                  .map((week) => Padding(
                        padding: const EdgeInsets.only(right: _weekGap),
                        child: Column(
                          children: week
                              .map((cell) => Padding(
                                    padding: const EdgeInsets.only(bottom: _cellGap),
                                    child: _HeatmapCellTile(
                                      cell: cell,
                                      size: _cellSize,
                                      onTap: cell?.amount != null && cell!.amount > 0
                                          ? () => onTapDay(cell.day)
                                          : null,
                                    ),
                                  ))
                              .toList(growable: false),
                        ),
                      ))
                  .toList(growable: false),
            ),
          ),
        ),
      ],
    );
  }

  List<List<StatsHeatmapCell?>> _buildWeeks(List<StatsHeatmapCell> cells) {
    final byDate = {
      for (final cell in cells)
        DateTime(cell.day.year, cell.day.month, cell.day.day): cell,
    };
    final firstDay = cells.first.day;
    final lastDay = cells.last.day;

    final firstWeekStart = _startOfWeekSunday(firstDay);
    final lastWeekEnd = _endOfWeekSaturday(lastDay);

    final weeks = <List<StatsHeatmapCell?>>[];
    for (
      var weekStart = firstWeekStart;
      !weekStart.isAfter(lastWeekEnd);
      weekStart = weekStart.add(const Duration(days: DateTime.daysPerWeek))
    ) {
      final week = <StatsHeatmapCell?>[];
      for (var i = 0; i < DateTime.daysPerWeek; i++) {
        final day = weekStart.add(Duration(days: i));
        week.add(byDate[DateTime(day.year, day.month, day.day)]);
      }
      weeks.add(week);
    }
    return weeks;
  }

  DateTime _startOfWeekSunday(DateTime day) {
    final delta = day.weekday % DateTime.daysPerWeek;
    return DateTime(day.year, day.month, day.day).subtract(Duration(days: delta));
  }

  DateTime _endOfWeekSaturday(DateTime day) {
    final start = _startOfWeekSunday(day);
    return start.add(const Duration(days: DateTime.daysPerWeek - 1));
  }
}

class _WeekdayAxis extends StatelessWidget {
  const _WeekdayAxis();

  static const double _cellSize = 22;
  static const double _cellGap = 6;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final labels = [
      l10n.weekdayShortSun,
      l10n.weekdayShortMon,
      l10n.weekdayShortTue,
      l10n.weekdayShortWed,
      l10n.weekdayShortThu,
      l10n.weekdayShortFri,
      l10n.weekdayShortSat,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: labels
          .map((label) => Padding(
                padding: const EdgeInsets.only(bottom: _cellGap),
                child: SizedBox(
                  width: 20,
                  height: _cellSize,
                  child: Center(
                    child: Text(
                      label,
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ))
          .toList(growable: false),
    );
  }
}

class _HeatmapCellTile extends StatelessWidget {
  const _HeatmapCellTile({
    required this.cell,
    required this.size,
    this.onTap,
  });

  final StatsHeatmapCell? cell;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = Theme.of(context).extension<BianBianSemanticColors>()!.danger;

    if (cell == null) {
      return SizedBox(width: size, height: size);
    }

    final bg = Color.lerp(
          colorScheme.surfaceContainerHighest.withAlpha(110),
          baseColor,
          cell!.intensity.clamp(0.0, 1.0),
        ) ??
        colorScheme.surfaceContainerHighest;

    return Tooltip(
      message:
          '${DateFormat(context.l10n.statsTooltipDateFormat).format(cell!.day)}\n${context.l10n.txTypeExpense}：¥${NumberFormat('#,##0.00').format(cell!.amount)}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: cell!.amount > 0
                    ? baseColor.withAlpha(120)
                    : colorScheme.outlineVariant.withAlpha(120),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _YearlyLineCard extends ConsumerStatefulWidget {
  const _YearlyLineCard();

  @override
  ConsumerState<_YearlyLineCard> createState() => _YearlyLineCardState();
}

class _YearlyLineCardState extends ConsumerState<_YearlyLineCard> {
  bool _showIncome = true;
  bool _showExpense = true;
  bool _showBalance = true;

  void _toggleLine(String type) {
    setState(() {
      switch (type) {
        case 'income':
          if (!_showIncome || (_showExpense || _showBalance)) {
            _showIncome = !_showIncome;
          }
          break;
        case 'expense':
          if (!_showExpense || (_showIncome || _showBalance)) {
            _showExpense = !_showExpense;
          }
          break;
        case 'balance':
          if (!_showBalance || (_showIncome || _showExpense)) {
            _showBalance = !_showBalance;
          }
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final year = ref.watch(statsYearlyYearProvider);
    final pointsAsync = ref.watch(statsYearlyMonthPointsProvider);
    final theme = Theme.of(context);
    final semantic = theme.extension<BianBianSemanticColors>()!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    ref.read(statsYearlyYearProvider.notifier).previousYear();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                Text(
                  '$year',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    ref.read(statsYearlyYearProvider.notifier).nextYear();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const Spacer(),
                _LegendChip(
                  label: '收入',
                  color: semantic.success,
                  selected: _showIncome,
                  onTap: () => _toggleLine('income'),
                ),
                const SizedBox(width: 8),
                _LegendChip(
                  label: '支出',
                  color: semantic.danger,
                  selected: _showExpense,
                  onTap: () => _toggleLine('expense'),
                ),
                const SizedBox(width: 8),
                _LegendChip(
                  label: '结余',
                  color: const Color(0xFFFFA726),
                  selected: _showBalance,
                  onTap: () => _toggleLine('balance'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: pointsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    context.l10n.statsChartLoadFailed(e.toString()),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                data: (points) {
                  return _YearlyLineChartView(
                    points: points,
                    incomeColor: semantic.success,
                    expenseColor: semantic.danger,
                    balanceColor: const Color(0xFFFFA726),
                    showIncome: _showIncome,
                    showExpense: _showExpense,
                    showBalance: _showBalance,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : theme.colorScheme.outline.withAlpha(100),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: selected ? Colors.white : theme.colorScheme.onSurface.withAlpha(150),
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _YearlyLineChartView extends StatelessWidget {
  const _YearlyLineChartView({
    required this.points,
    required this.incomeColor,
    required this.expenseColor,
    required this.balanceColor,
    required this.showIncome,
    required this.showExpense,
    required this.showBalance,
  });

  final List<StatsYearlyMonthPoint> points;
  final Color incomeColor;
  final Color expenseColor;
  final Color balanceColor;
  final bool showIncome;
  final bool showExpense;
  final bool showBalance;

  @override
  Widget build(BuildContext context) {
    final moneyFmt = NumberFormat('#,##0');

    final incomeSpots = <FlSpot>[];
    final expenseSpots = <FlSpot>[];
    final balanceSpots = <FlSpot>[];

    double minY = 0;
    double maxY = 0;

    for (final p in points) {
      final x = (p.month - 1).toDouble();
      if (showIncome) {
        incomeSpots.add(FlSpot(x, p.income));
        if (p.income > maxY) maxY = p.income;
      }
      if (showExpense) {
        expenseSpots.add(FlSpot(x, p.expense));
        if (p.expense > maxY) maxY = p.expense;
      }
      if (showBalance) {
        balanceSpots.add(FlSpot(x, p.balance));
        if (p.balance > maxY) maxY = p.balance;
        if (p.balance < minY) minY = p.balance;
      }
    }

    if (maxY <= 0 && minY >= 0) {
      maxY = 1;
    } else {
      final range = maxY - minY;
      maxY = maxY + range * 0.15;
      minY = minY - range * 0.15;
    }

    final lineBars = <LineChartBarData>[];
    if (showIncome && incomeSpots.isNotEmpty) {
      lineBars.add(LineChartBarData(
        spots: incomeSpots,
        isCurved: true,
        color: incomeColor,
        barWidth: 3,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: incomeColor.withAlpha(50),
        ),
      ));
    }
    if (showExpense && expenseSpots.isNotEmpty) {
      lineBars.add(LineChartBarData(
        spots: expenseSpots,
        isCurved: true,
        color: expenseColor,
        barWidth: 3,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: expenseColor.withAlpha(50),
        ),
      ));
    }
    if (showBalance && balanceSpots.isNotEmpty) {
      lineBars.add(LineChartBarData(
        spots: balanceSpots,
        isCurved: true,
        color: balanceColor,
        barWidth: 3,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: balanceColor.withAlpha(50),
        ),
      ));
    }

    return Padding(
      padding: const EdgeInsets.only(right: 12, top: 10),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: 11,
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            horizontalInterval: (maxY - minY) / 4,
            drawVerticalLine: false,
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  return Text(
                    moneyFmt.format(value),
                    style: Theme.of(context).textTheme.labelSmall,
                    textAlign: TextAlign.right,
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final month = value.toInt() + 1;
                  if (month < 1 || month > 12) return const SizedBox.shrink();
                  return Text(
                    '$month',
                    style: Theme.of(context).textTheme.labelSmall,
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              fitInsideVertically: true,
              fitInsideHorizontally: true,
              getTooltipItems: (spots) {
                return spots.map((spot) {
                  String label = '';
                  Color color = Colors.white;

                  int currentIndex = 0;
                  if (showIncome) {
                    if (spot.barIndex == currentIndex) {
                      label = '收入';
                      color = incomeColor;
                    }
                    currentIndex++;
                  }
                  if (showExpense) {
                    if (spot.barIndex == currentIndex) {
                      label = '支出';
                      color = expenseColor;
                    }
                    currentIndex++;
                  }
                  if (showBalance) {
                    if (spot.barIndex == currentIndex) {
                      label = '结余';
                      color = balanceColor;
                    }
                  }

                  return LineTooltipItem(
                    '$label\n¥${moneyFmt.format(spot.y)}',
                    TextStyle(color: color, fontWeight: FontWeight.bold),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: lineBars,
        ),
      ),
    );
  }
}