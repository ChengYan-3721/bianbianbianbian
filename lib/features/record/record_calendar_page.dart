import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/app_theme.dart';
import '../../core/l10n/l10n_ext.dart';
import '../../core/util/category_icon_packs.dart';
import '../../core/util/currencies.dart';
import '../../core/util/svg_or_emoji_icon.dart';
import '../../data/repository/providers.dart'
    show currentLedgerIdProvider, transactionRepositoryProvider;
import '../../domain/entity/account.dart';
import '../../domain/entity/budget.dart';
import '../../domain/entity/category.dart';
import '../../domain/entity/transaction_entry.dart';
import '../account/account_providers.dart';
import '../budget/budget_providers.dart';
import '../settings/settings_providers.dart';
import 'month_picker_dialog.dart';
import 'record_new_page.dart';
import 'record_new_providers.dart';
import 'record_providers.dart';
import 'record_tile_actions.dart';

final _moneyFmt = NumberFormat('#,##0.00');

final recordCalendarMonthProvider = FutureProvider.autoDispose
    .family<RecordCalendarMonthData, DateTime>((ref, month) async {
      final monthKey = _monthKey(month);
      final ledgerId = await ref.watch(currentLedgerIdProvider.future);
      final txRepo = await ref.watch(transactionRepositoryProvider.future);
      final currencyCode = await ref.watch(
        currentLedgerDefaultCurrencyProvider.future,
      );
      final budgets = await ref.watch(activeBudgetsProvider.future);
      final txs = await txRepo.listActiveByLedger(ledgerId);

      final monthTxs = txs.where((tx) {
        final t = tx.occurredAt;
        return t.year == monthKey.year && t.month == monthKey.month;
      }).toList()..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

      final dailyBudget = _resolveDailyBudget(budgets, monthKey);
      final mutable = <DateTime, _CalendarDayAccumulator>{};
      for (final tx in monthTxs) {
        final date = _dayKey(tx.occurredAt);
        final acc = mutable.putIfAbsent(date, _CalendarDayAccumulator.new);
        acc.transactions.add(tx);
        final converted = tx.amount * tx.fxRate;
        if (tx.type == 'income') {
          acc.income += converted;
        } else if (tx.type == 'expense') {
          acc.expense += converted;
        }
      }

      final days = <DateTime, CalendarDaySummary>{};
      for (final entry in mutable.entries) {
        final value = entry.value;
        final overBudget =
            dailyBudget != null && value.expense > dailyBudget + 0.005;
        days[entry.key] = CalendarDaySummary(
          date: entry.key,
          income: value.income,
          expense: value.expense,
          transactions: List.unmodifiable(value.transactions),
          hasBudget: dailyBudget != null,
          isOverBudget: overBudget,
        );
      }

      return RecordCalendarMonthData(
        month: monthKey,
        currencyCode: currencyCode,
        dailyBudget: dailyBudget,
        days: Map.unmodifiable(days),
      );
    });

class RecordCalendarMonthData {
  const RecordCalendarMonthData({
    required this.month,
    required this.currencyCode,
    required this.days,
    this.dailyBudget,
  });

  final DateTime month;
  final String currencyCode;
  final double? dailyBudget;
  final Map<DateTime, CalendarDaySummary> days;

  CalendarDaySummary summaryFor(DateTime day) {
    final key = _dayKey(day);
    return days[key] ??
        CalendarDaySummary(
          date: key,
          income: 0,
          expense: 0,
          transactions: const <TransactionEntry>[],
          hasBudget: dailyBudget != null,
          isOverBudget: false,
        );
  }
}

class CalendarDaySummary {
  const CalendarDaySummary({
    required this.date,
    required this.income,
    required this.expense,
    required this.transactions,
    required this.hasBudget,
    required this.isOverBudget,
  });

  final DateTime date;
  final double income;
  final double expense;
  final List<TransactionEntry> transactions;
  final bool hasBudget;
  final bool isOverBudget;

  bool get hasTransactions => transactions.isNotEmpty;
}

class _CalendarDayAccumulator {
  double income = 0;
  double expense = 0;
  final transactions = <TransactionEntry>[];
}

class RecordCalendarPage extends ConsumerStatefulWidget {
  const RecordCalendarPage({super.key});

  @override
  ConsumerState<RecordCalendarPage> createState() => _RecordCalendarPageState();
}

class _RecordCalendarPageState extends ConsumerState<RecordCalendarPage> {
  late DateTime _visibleMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final monthKey = _monthKey(_visibleMonth);
    final data = ref.watch(recordCalendarMonthProvider(monthKey));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: context.l10n.close,
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: _CalendarMonthSwitcher(
          month: monthKey,
          onPrevious: () => _moveMonth(-1),
          onNext: () => _moveMonth(1),
          onPick: _pickMonth,
        ),
        actions: [
          IconButton(
            tooltip: context.l10n.recordNewTitle,
            icon: const Icon(Icons.add, size: 28),
            onPressed: _openNewRecordSheet,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: data.when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(context.l10n.loadFailedWithError(e.toString())),
          ),
          data: (monthData) {
            final selectedSummary = monthData.summaryFor(_selectedDate);
            return Column(
              children: [
                _CalendarCard(
                  data: monthData,
                  selectedDate: _selectedDate,
                  onSelected: (day) => setState(() => _selectedDate = day),
                ),
                Expanded(
                  child: _SelectedDayPanel(
                    summary: selectedSummary,
                    monthKey: monthKey,
                    currencyCode: monthData.currencyCode,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickMonth() async {
    final picked = await showMonthPicker(
      context: context,
      initialMonth: _visibleMonth,
    );
    if (picked != null && mounted) {
      _setVisibleMonth(picked);
    }
  }

  void _moveMonth(int delta) {
    _setVisibleMonth(DateTime(_visibleMonth.year, _visibleMonth.month + delta));
  }

  void _setVisibleMonth(DateTime value) {
    final nextMonth = _monthKey(value);
    final day = math.min(_selectedDate.day, _daysInMonth(nextMonth));
    setState(() {
      _visibleMonth = nextMonth;
      _selectedDate = DateTime(nextMonth.year, nextMonth.month, day);
    });
  }

  Future<void> _openNewRecordSheet() async {
    final selected = _selectedDate;
    final now = DateTime.now();
    final initialDate = DateTime(
      selected.year,
      selected.month,
      selected.day,
      now.hour,
      now.minute,
    );
    ref.read(recordFormProvider.notifier).reset();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.58,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Material(
            color: Theme.of(sheetContext).colorScheme.surface,
            child: SafeArea(
              top: false,
              child: RecordNewPage(initialOccurredAt: initialDate),
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    ref.invalidate(recordCalendarMonthProvider(_monthKey(_visibleMonth)));
  }
}

class _CalendarMonthSwitcher extends StatelessWidget {
  const _CalendarMonthSwitcher({
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('yyyy.MM').format(month);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: context.l10n.a11yRecordHomePrevMonth,
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrevious,
          visualDensity: VisualDensity.compact,
        ),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPick,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        IconButton(
          tooltip: context.l10n.a11yRecordHomeNextMonth,
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.data,
    required this.selectedDate,
    required this.onSelected,
  });

  final RecordCalendarMonthData data;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final first = DateTime(data.month.year, data.month.month);
    final leadingEmpty = first.weekday % DateTime.sunday;
    final dayCount = _daysInMonth(data.month);
    final cellCount = ((leadingEmpty + dayCount + 6) ~/ 7) * 7;
    final weekdayLabels = MaterialLocalizations.of(context).narrowWeekdays;

    return Card(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                for (final label in weekdayLabels)
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: colors.onSurface.withAlpha(120)),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cellCount,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.76,
              ),
              itemBuilder: (context, index) {
                final dayNumber = index - leadingEmpty + 1;
                if (dayNumber < 1 || dayNumber > dayCount) {
                  return const SizedBox.shrink();
                }
                final day = DateTime(
                  data.month.year,
                  data.month.month,
                  dayNumber,
                );
                return _CalendarDayCell(
                  summary: data.summaryFor(day),
                  currencyCode: data.currencyCode,
                  selected: _sameDay(day, selectedDate),
                  today: _sameDay(day, DateTime.now()),
                  onTap: () => onSelected(day),
                );
              },
            ),
            const SizedBox(height: 10),
            _CalendarLegend(hasBudget: data.dailyBudget != null),
          ],
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.summary,
    required this.currencyCode,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final CalendarDaySummary summary;
  final String currencyCode;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  static const _blue = Color(0xFF6F93E6);
  static const _selectedYellow = Color(0xFFFFC857);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final semantic = theme.extension<BianBianSemanticColors>();
    final red = semantic?.danger ?? colors.error;
    final hasFill = selected || summary.hasTransactions;
    final fill = selected
        ? _selectedYellow
        : summary.hasTransactions
        ? (summary.isOverBudget ? red : _blue)
        : Colors.transparent;
    final foreground = hasFill ? Colors.white : colors.onSurface;
    final border = today && !selected
        ? Border.all(color: colors.primary.withAlpha(140), width: 1.2)
        : null;

    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(4),
              border: border,
            ),
            child: Column(
              mainAxisAlignment: summary.hasTransactions
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Text(
                  summary.date.day.toString().padLeft(2, '0'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: foreground,
                  ),
                ),
                if (summary.hasTransactions) ...[
                  const SizedBox(height: 3),
                  _TinyAmountLine(
                    text:
                        '+${_symbolFor(currencyCode)}${_compactMoney(summary.income)}',
                    color: foreground,
                  ),
                  _TinyAmountLine(
                    text:
                        '-${_symbolFor(currencyCode)}${_compactMoney(summary.expense)}',
                    color: foreground,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TinyAmountLine extends StatelessWidget {
  const _TinyAmountLine({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 12,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color.withAlpha(230),
          ),
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend({required this.hasBudget});

  final bool hasBudget;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<BianBianSemanticColors>();
    final red = semantic?.danger ?? colors.error;
    return Row(
      children: [
        const _LegendDot(color: _CalendarDayCell._blue),
        const SizedBox(width: 5),
        Text(
          hasBudget
              ? context.l10n.recordCalendarUnderBudget
              : context.l10n.recordCalendarHasRecords,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.onSurface.withAlpha(140),
          ),
        ),
        const SizedBox(width: 16),
        _LegendDot(color: red),
        const SizedBox(width: 5),
        Text(
          context.l10n.recordCalendarOverBudget,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.onSurface.withAlpha(140),
          ),
        ),
        const Spacer(),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.push('/budget'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(
              context.l10n.recordCalendarSetBudget,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: _CalendarDayCell._selectedYellow,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _SelectedDayPanel extends ConsumerWidget {
  const _SelectedDayPanel({
    required this.summary,
    required this.monthKey,
    required this.currencyCode,
  });

  final CalendarDaySummary summary;
  final DateTime monthKey;
  final String currencyCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!summary.hasTransactions) {
      return _EmptySelectedDay(date: summary.date);
    }

    final symbol = _symbolFor(currencyCode);
    return Card(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('yyyy.MM.dd').format(summary.date),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${context.l10n.txTypeExpense}: $symbol${_moneyFmt.format(summary.expense)}  |  '
                      '${context.l10n.txTypeIncome}: $symbol${_moneyFmt.format(summary.income)}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha(150),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              itemCount: summary.transactions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, index) => _CalendarTxTile(
                tx: summary.transactions[index],
                monthKey: monthKey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySelectedDay extends StatelessWidget {
  const _EmptySelectedDay({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 72,
            color: colors.onSurface.withAlpha(80),
          ),
          const SizedBox(height: 14),
          Text(
            context.l10n.recordCalendarEmptyDay,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.onSurface.withAlpha(120),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarTxTile extends ConsumerWidget {
  const _CalendarTxTile({required this.tx, required this.monthKey});

  final TransactionEntry tx;
  final DateTime monthKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories =
        ref.watch(categoriesListProvider).valueOrNull ?? const <Category>[];
    final accounts =
        ref.watch(accountsListProvider).valueOrNull ?? const <Account>[];
    final iconPack = ref.watch(currentIconPackProvider);

    Category? matched;
    if (tx.categoryId != null) {
      for (final c in categories) {
        if (c.id == tx.categoryId) {
          matched = c;
          break;
        }
      }
    }

    final isTransfer = tx.type == 'transfer';
    final isExpense = tx.type == 'expense';
    final semantic = Theme.of(context).extension<BianBianSemanticColors>();
    final amountColor = isTransfer
        ? Theme.of(context).colorScheme.primary
        : isExpense
        ? (semantic?.danger ?? Theme.of(context).colorScheme.error)
        : (semantic?.success ?? const Color(0xFFA8D8B9));
    final iconText = isTransfer
        ? '🔁'
        : matched != null
        ? resolveCategoryIcon(
            matched.icon,
            matched.parentKey,
            matched.name,
            iconPack,
          )
        : (isExpense ? '💸' : '💰');
    final iconSvg = isTransfer ? null : matched?.iconSvg;
    final nameText = isTransfer
        ? context.l10n.txTypeTransfer
        : (matched?.name ?? context.l10n.txTypeUncategorized);
    final noteText = tx.tags?.trim();
    final titleText = noteText == null || noteText.isEmpty
        ? nameText
        : '$nameText · $noteText';

    String accountName(String? id) {
      if (id == null || id.isEmpty) return context.l10n.recordNewWallet;
      for (final a in accounts) {
        if (a.id == id) return a.name;
      }
      return context.l10n.deletedAccount;
    }

    final subtitle = isTransfer
        ? '${accountName(tx.accountId)} → ${accountName(tx.toAccountId)}'
        : DateFormat('HH:mm').format(tx.occurredAt);
    final sign = isTransfer ? '' : (isExpense ? '-' : '+');

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        await openRecordTileActions(
          context: context,
          ref: ref,
          tx: tx,
          category: matched,
          accountName: accountName(tx.accountId),
          toAccountName: isTransfer ? accountName(tx.toAccountId) : null,
          parentKey: inferParentKeyForTx(matched, tx),
        );
        ref.invalidate(recordCalendarMonthProvider(monthKey));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: amountColor.withAlpha(36),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: SvgOrEmojiIcon(
                svgString: iconSvg,
                emoji: iconText,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(145),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$sign${_symbolFor(tx.currency)}${_moneyFmt.format(tx.amount)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

DateTime _monthKey(DateTime date) => DateTime(date.year, date.month);

DateTime _dayKey(DateTime date) => DateTime(date.year, date.month, date.day);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

int _daysInMonth(DateTime month) =>
    DateTime(month.year, month.month + 1, 0).day;

double? _resolveDailyBudget(List<Budget> budgets, DateTime month) {
  double? limit;
  String? period;

  double effectiveAmount(Budget b) =>
      b.amount + (b.carryOver ? b.carryBalance : 0);

  Budget? totalMonthly;
  Budget? totalYearly;
  double monthlyCategorySum = 0;
  double yearlyCategorySum = 0;

  for (final b in budgets) {
    if (b.categoryId == null && b.period == 'monthly') {
      totalMonthly ??= b;
    } else if (b.categoryId == null && b.period == 'yearly') {
      totalYearly ??= b;
    } else if (b.categoryId != null && b.period == 'monthly') {
      monthlyCategorySum += effectiveAmount(b);
    } else if (b.categoryId != null && b.period == 'yearly') {
      yearlyCategorySum += effectiveAmount(b);
    }
  }

  if (totalMonthly != null) {
    limit = effectiveAmount(totalMonthly);
    period = 'monthly';
  } else if (monthlyCategorySum > 0) {
    limit = monthlyCategorySum;
    period = 'monthly';
  } else if (totalYearly != null) {
    limit = effectiveAmount(totalYearly);
    period = 'yearly';
  } else if (yearlyCategorySum > 0) {
    limit = yearlyCategorySum;
    period = 'yearly';
  }

  if (limit == null || limit <= 0 || period == null) return null;
  if (period == 'monthly') return limit / _daysInMonth(month);
  final yearStart = DateTime(month.year);
  final nextYearStart = DateTime(month.year + 1);
  return limit / nextYearStart.difference(yearStart).inDays;
}

String _symbolFor(String code) {
  for (final c in kBuiltInCurrencies) {
    if (c.code == code) return c.symbol;
  }
  return '¥';
}

String _compactMoney(double value) {
  final abs = value.abs();
  if (abs >= 1000) {
    return abs.toStringAsFixed(0);
  }
  if (abs == abs.roundToDouble()) {
    return abs.toStringAsFixed(0);
  }
  return _trimZero(abs.toStringAsFixed(2));
}

String _trimZero(String value) {
  var result = value;
  while (result.contains('.') && result.endsWith('0')) {
    result = result.substring(0, result.length - 1);
  }
  if (result.endsWith('.')) {
    result = result.substring(0, result.length - 1);
  }
  return result;
}
