import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import 'month_picker_dialog.dart';
import 'quick_confirm_sheet.dart';
import 'quick_input_providers.dart';
import 'record_new_page.dart';
import 'record_new_providers.dart';
import 'record_providers.dart';
import 'record_tile_actions.dart';

import '../../core/util/currencies.dart';
import '../../core/util/category_icon_packs.dart';
import '../../data/repository/ledger_repository.dart';
import '../../data/repository/providers.dart'
    show
        currentLedgerIdProvider,
        ledgerRepositoryProvider,
        transactionRepositoryProvider;
import '../account/account_providers.dart';
import '../ledger/ledger_list_page.dart';
import '../ledger/ledger_providers.dart';
import '../budget/budget_providers.dart';
import '../settings/settings_providers.dart';
import '../stats/stats_range_providers.dart';
import '../sync/attachment/attachment_providers.dart';
import '../sync/sync_trigger.dart';
import '../../domain/entity/account.dart';
import '../../domain/entity/category.dart';
import '../../domain/entity/ledger.dart';
import '../../domain/entity/transaction_entry.dart';

final _fmt = NumberFormat('#,##0.00');

/// Step 8.2：在 [kBuiltInCurrencies] 中按 code 查 symbol，未命中回退 CNY 的 ¥。
String _symbolFor(String code) {
  for (final c in kBuiltInCurrencies) {
    if (c.code == code) return c.symbol;
  }
  return '¥';
}

/// Step 8.2：流水详情/列表展示金额的字符串。
///
/// - 同币种：`±¥10.00`（直接用 tx.currency 的符号）。
/// - 跨币种：`±USD 10.00（≈ ¥72.00）`——前段是原始币种 + 金额，括号内是
///   按 `tx.fxRate` 折算到账本默认币种的近似值。`fxRate` 在保存时已经把
///   "原币 → 账本默认币种"换算因子算好（[computeFxRate]），所以这里直接
///   `amount * fxRate` 即可，无需再读 fx_rate 表。
///
/// 转账（type == 'transfer'）不带正负号；income +、expense -。
///
/// 此前曾标 `@visibleForTesting`，Step 3.6 续作（搜索结果点击复用详情底部
/// 表单）将 `_RecordDetailSheet` 拆到 `record_tile_actions.dart` 后，需要
/// 在 lib/ 内跨文件调用，故移除该注解。
String formatTxAmountForDetail(TransactionEntry tx, String ledgerCurrency) {
  final isExpense = tx.type == 'expense';
  final isTransfer = tx.type == 'transfer';
  final sign = isTransfer ? '' : (isExpense ? '-' : '+');
  final amount = _fmt.format(tx.amount);
  if (tx.currency == ledgerCurrency) {
    return '$sign${_symbolFor(tx.currency)}$amount';
  }
  final converted = _fmt.format(tx.amount * tx.fxRate);
  return '$sign${tx.currency} $amount（≈ ${_symbolFor(ledgerCurrency)}$converted）';
}

/// 记账首页骨架（Phase 3 Step 3.1）。
///
/// 结构（自上而下）：
/// - 顶栏：账本名 + emoji（只读）+ 月份切换（← →）+ 搜索图标（占位）
/// - 数据卡片：本月收入 / 支出 / 结余
/// - 快捷输入条：单行输入 + "✨ 识别"（占位）
/// - 流水列表：按日期倒序分组，空时显示引导文字
/// - FAB：`+` → 跳转新建记账页（Step 3.2）
///
/// Phase 3 Step 3.2 落地新建页后 FAB 会接入路由；Step 3.3 做详情/编辑/删
/// 除；Step 3.5 做图片附件。
class RecordHomePage extends ConsumerWidget {
  const RecordHomePage({super.key});

  static const List<String> _weekdays = [
    '周一', '周二', '周三', '周四', '周五', '周六', '周日',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(recordMonthSummaryProvider);
    final currentId = ref.watch(currentLedgerIdProvider).valueOrNull;
    final repo = ref.watch(ledgerRepositoryProvider).valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(currentId: currentId, repo: repo),
            _MonthBar(ref: ref),
            _DataCards(summary: summary),
            const _IdleReminderCard(),
            const _QuickInputBar(),
            Expanded(child: _TransactionList(summary: summary)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'record_home_fab',
        onPressed: () {
          ref.read(recordFormProvider.notifier).reset();
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (sheetContext) => FractionallySizedBox(
              heightFactor: 0.58,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: Material(
                  color: Theme.of(sheetContext).colorScheme.surface,
                  child: const _RecordBottomSheetPage(),
                ),
              ),
            ),
          );
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.add, size: 32),
      ),
    );
  }
}

// ---- 顶栏：账本名 + emoji + 搜索占位 ----

class _TopBar extends ConsumerWidget {
  const _TopBar({this.currentId, this.repo});

  final String? currentId;
  final LedgerRepository? repo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = currentId;
    final r = repo;
    final ledgersAsync = ref.watch(ledgerGroupsProvider);
    if (id == null || r == null) {
      return const SizedBox(height: 48);
    }
    return FutureBuilder<Ledger?>(
      future: r.getById(id),
      builder: (context, snapshot) {
        final ledger = snapshot.data;
        final emoji = ledger?.coverEmoji ?? '📒';
        final name = ledger?.name ?? '账本';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              PopupMenuButton<Ledger>(
                tooltip: '切换账本',
                position: PopupMenuPosition.under,
                offset: const Offset(0, 6),
                onSelected: (selected) async {
                  if (selected.id == id) return;
                  await ref.read(currentLedgerIdProvider.notifier).switchTo(selected.id);
                  ref.invalidate(recordMonthSummaryProvider);
                  ref.invalidate(ledgerTxCountsProvider);
                  ref.invalidate(statsLinePointsProvider);
                  ref.invalidate(statsPieSlicesProvider);
                  ref.invalidate(statsRankItemsProvider);
                  ref.invalidate(statsHeatmapCellsProvider);
                  ref.invalidate(activeBudgetsProvider);
                  ref.invalidate(budgetProgressForProvider);
                },
                itemBuilder: (_) {
                  final active = ledgersAsync.valueOrNull?.active ?? const <Ledger>[];
                  return [
                    for (final l in active)
                      PopupMenuItem<Ledger>(
                        value: l,
                        child: Row(
                          children: [
                            Text(l.coverEmoji ?? '📒', style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(l.name)),
                            if (l.id == id) const Icon(Icons.check_circle, size: 18),
                          ],
                        ),
                      ),
                  ];
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  child: Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 6),
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 20),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              const _SyncStatusBadge(),
              IconButton(
                icon: const Icon(Icons.swap_horiz, size: 22),
                onPressed: () {
                  ref.read(recordFormProvider.notifier).reset();
                  ref.read(recordFormProvider.notifier).setTransferMode(true);
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (sheetContext) => FractionallySizedBox(
                      heightFactor: 0.58,
                      child: ClipRRect(
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(20)),
                        child: Material(
                          color: Theme.of(sheetContext).colorScheme.surface,
                          child: const _RecordTransferBottomSheetPage(),
                        ),
                      ),
                    ),
                  );
                },
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.search, size: 22),
                onPressed: () {
                  // Step 3.6：跳转搜索页 `/record/search`。
                  context.push('/record/search');
                },
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        );
      },
    );
  }

}

// ---- 同步状态徽标（Step 10.7）----

/// 顶栏同步状态小图标 + 上次同步时间（小字）。
///
/// 仅当 [SyncTriggerState.isConfigured] 为真时渲染——本地模式下隐藏，避免
/// 用户被一个永远不变的灰圆点干扰。点击跳转「我的 → 云服务」页。
class _SyncStatusBadge extends ConsumerWidget {
  const _SyncStatusBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncTriggerProvider);
    if (!state.isConfigured) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    Widget icon;
    Color tint;
    String tooltip;
    if (state.isRunning) {
      icon = SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(colors.tertiary),
        ),
      );
      tint = colors.tertiary;
      tooltip = '同步中…';
    } else if (state.lastError != null) {
      icon = Icon(Icons.cloud_off_outlined, size: 18, color: colors.error);
      tint = colors.error;
      tooltip = '同步失败：${state.lastError}';
    } else if (state.lastSyncedAt != null) {
      icon = Icon(Icons.cloud_done_outlined, size: 18, color: colors.tertiary);
      tint = colors.tertiary;
      tooltip = '上次同步：${_formatRelative(state.lastSyncedAt!)}';
    } else {
      icon = Icon(Icons.cloud_outlined,
          size: 18, color: colors.onSurface.withAlpha(140));
      tint = colors.onSurface.withAlpha(140);
      tooltip = '尚未同步';
    }

    final ts = state.lastSyncedAt;
    final tsLabel = ts == null ? null : _formatRelative(ts);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push('/sync'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              if (tsLabel != null && !state.isRunning) ...[
                const SizedBox(width: 4),
                Text(
                  tsLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: tint,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatRelative(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return DateFormat('MM-dd HH:mm').format(t);
  }
}

// ---- 月份切换条 ----

class _MonthBar extends StatelessWidget {
  const _MonthBar({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(recordMonthProvider);
    final monthLabel = '${month.year}年${month.month}月';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 24),
            onPressed: () =>
                ref.read(recordMonthProvider.notifier).previous(),
            visualDensity: VisualDensity.compact,
          ),
          // Step 3.7：点击月份文字弹出年-月选择器，可快速跳转到任意年月。
          InkWell(
            key: const Key('record_month_label'),
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              final picked = await showMonthPicker(
                context: context,
                initialMonth: month,
              );
              if (picked != null) {
                ref.read(recordMonthProvider.notifier).jumpTo(picked);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                monthLabel,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 24),
            onPressed: () =>
                ref.read(recordMonthProvider.notifier).next(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ---- 数据卡片 ----

class _DataCards extends ConsumerWidget {
  const _DataCards({required this.summary});

  final AsyncValue<RecordMonthSummary> summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = summary.valueOrNull;
    // Step 8.2：卡片汇总以账本默认币种为单位（recordMonthSummary 已按 fxRate
    // 折算）；这里只取 symbol 与之保持一致。
    final ledgerCurrency =
        ref.watch(currentLedgerDefaultCurrencyProvider).valueOrNull ?? 'CNY';
    final symbol = _symbolFor(ledgerCurrency);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          _CardChip(
            label: '收入',
            amount: data?.income,
            colorKey: 'income',
            symbol: symbol,
          ),
          const SizedBox(height: 6),
          _CardChip(
            label: '支出',
            amount: data?.expense,
            colorKey: 'expense',
            symbol: symbol,
          ),
          const SizedBox(height: 6),
          _CardChip(
            label: '结余',
            amount: data?.balance,
            colorKey: 'balance',
            symbol: symbol,
          ),
        ],
      ),
    );
  }
}

class _CardChip extends StatelessWidget {
  const _CardChip({
    required this.label,
    this.amount,
    required this.colorKey,
    this.symbol = '¥',
  });

  final String label;
  final double? amount;
  final String colorKey;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Color chipColor;
    switch (colorKey) {
      case 'income':
        chipColor = const Color(0xFFA8D8B9); // 抹茶绿
        break;
      case 'expense':
        chipColor = const Color(0xFFE76F51); // 苹果红
        break;
      case 'balance':
      default:
        chipColor = colors.tertiary; // 可可棕，与 onSurface 同色系，对比度足够
    }

    final display = amount != null
        ? '$symbol${_fmt.format(amount!)}'
        : '$symbol--.--';

    return Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: chipColor.withAlpha(48),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: chipColor.withAlpha(80), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text(display, style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: chipColor,
                  ),
            ),
          ],
        ),
      );
  }
}

// ---- 快捷输入条 ----

/// Step 9.2：首页顶部快捷输入条。
///
/// 用户在 TextField 输入中文短句后回车 / 点 "✨ 识别" 按钮，调用
/// [quickTextParserProvider] 做本地解析，弹出 [QuickConfirmCard] 作为
/// "确认卡片"——含可编辑的金额 / 分类 / 时间 / 备注。卡片内确认即落库
/// 一条流水；置信度 < [quickConfidenceThreshold] 时卡片顶部高亮"请核对"。
///
/// 输入框为空 / 全空白时点识别会以 SnackBar 提示，不弹卡片；保存成功后
/// 输入框自动清空，便于连续多条快速记账。
class _QuickInputBar extends ConsumerStatefulWidget {
  const _QuickInputBar();

  @override
  ConsumerState<_QuickInputBar> createState() => _QuickInputBarState();
}

class _QuickInputBarState extends ConsumerState<_QuickInputBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _busy = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (!mounted) return;
    if (_focused != _focusNode.hasFocus) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_busy) return;
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先输入一段话再点识别')),
      );
      return;
    }
    // 弹卡片前主动收起键盘——避免确认卡片打开时键盘还从首页 TextField 提起。
    _focusNode.unfocus();
    setState(() => _busy = true);
    final parser = ref.read(quickTextParserProvider);
    final parsed = parser.parse(text);
    final saved = await showQuickConfirmSheet(
      context: context,
      parsed: parsed,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved) {
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // 焦点驱动外层圆角矩形的边框颜色 / 宽度——避免 InputDecoration 自带的内
    // 层高亮与外层不齐导致的"小一圈"视觉。同时 AnimatedContainer 提供 150ms
    // 过渡。
    final borderColor = _focused
        ? colors.primary
        : colors.primary.withAlpha(120);
    final borderWidth = _focused ? 1.5 : 1.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: borderWidth),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('quick_input_field'),
                      controller: _controller,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.send,
                      // 点 TextField 外的任何区域都收起键盘 / 取消焦点。Flutter
                      // 默认不会自动这么做——必须显式 unfocus 主焦点节点，否
                      // 则用户得切 Tab 才能让键盘消失。
                      onTapOutside: (_) {
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      // 显式把所有 *Border 全部置 none，避免 M3 默认 focused 态
                      // 在内层叠加一个比外框小的圆角矩形（用户报告的"高亮比
                      // 外框小"现象）。
                      decoration: const InputDecoration(
                        hintText: '写点什么，我来帮你记 🐰',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        filled: false,
                        isDense: true,
                        isCollapsed: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: Theme.of(context).textTheme.bodyMedium,
                      onSubmitted: (_) => _handleSubmit(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            key: const Key('quick_input_recognize_button'),
            onPressed: _busy ? null : _handleSubmit,
            icon: const Text('✨', style: TextStyle(fontSize: 14)),
            label: const Text('识别'),
            style: TextButton.styleFrom(
              foregroundColor: colors.tertiary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- 流水列表 ----

class _TransactionList extends ConsumerStatefulWidget {
  const _TransactionList({required this.summary});

  final AsyncValue<RecordMonthSummary> summary;

  @override
  ConsumerState<_TransactionList> createState() => _TransactionListState();
}

class _TransactionListState extends ConsumerState<_TransactionList> {
  final ScrollController _scrollController = ScrollController();
  final Map<DateTime, GlobalKey> _dayKeys = {};

  /// 已在本地左滑确认删除、但 `recordMonthSummaryProvider` 还未刷新出新
  /// 数据的流水 ID 集合。两个互相协作的目的：
  ///
  /// 1. **绕开 Dismissible 的 framework 断言**：Flutter `Dismissible` 在
  ///    `_resizeAnimation.status == completed` 后再被父级 rebuild 命中
  ///    `update → build`，会抛 *"A dismissed Dismissible widget is still
  ///    part of the tree"*。结合 `skipLoadingOnReload: true`，老数据会在
  ///    重载窗口里继续渲染，如果不主动从渲染列表里剔除该流水，
  ///    Dismissible 就会被 `updateChild` 命中并触发断言。
  /// 2. **消除「闪现」**：把"已折叠的 Dismissible 还活在树里"换成
  ///    "干脆不渲染该流水"，配合 `skipLoadingOnReload: true` 不让 loading
  ///    分支抢一次 spinner，整个左滑删除路径就只剩 Dismissible 自带的
  ///    收起动画，无菊花、无重新挂载。
  ///
  /// 时序要求：[_TxTile] 的 `onDismissed` **必须先同步调用**
  /// `markLocallyDeleted` 再 `await` 后续 DB 写入——这样 setState 在 frame
  /// 的 build 阶段之前就把 `_TransactionListState` 标脏，build 时父级把该
  /// 流水从孩子列表里剔除，Dismissible Element 被 unmount 而不是 update，
  /// 不会进到带断言的 build。
  ///
  /// 数据刷新落地后（流水从 `data.dailyGroups` 里消失），build 阶段会把对应
  /// ID 从集合里清理掉——所以从垃圾桶恢复的流水不会被错误地继续过滤。
  final Set<String> _locallyDeleted = {};

  void _markLocallyDeleted(String txId) {
    if (!mounted) return;
    if (_locallyDeleted.contains(txId)) return;
    setState(() => _locallyDeleted.add(txId));
  }

  String _dayLabel(DateTime date) {
    final weekdays = RecordHomePage._weekdays;
    final wd = weekdays[date.weekday - 1];
    return '${date.month}月${date.day}日 $wd';
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _consumeScrollTarget(List<DailyTransactions> groups) {
    final target = ref.read(recordScrollTargetProvider);
    if (target == null) return;
    final normalizedTarget =
        DateTime(target.year, target.month, target.day);
    if (!groups.any((g) => g.date == normalizedTarget)) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _dayKeys[normalizedTarget];
      final ctx = key?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignment: 0.05,
        );
      }
      // 一次性消费，避免下次重建被误触发
      ref.read(recordScrollTargetProvider.notifier).state = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;

    // 配合 `_locallyDeleted` + 下面的 _dayKeys 稳定化，左滑删除路径的
    // 渲染时序为：onDismissed 同步把 tx.id 加入 `_locallyDeleted` →
    // 当帧 build 阶段 `_TransactionListState` 重建 → 流水被过滤掉 →
    // Dismissible Element 被 unmount（避免 "still part of the tree" 断言）。
    //
    // `skipLoadingOnReload: true` —— 软删后我们 invalidate
    // `recordMonthSummaryProvider`，默认 `when` 会切到 loading 分支用
    // `CircularProgressIndicator` 替换整个列表，下一帧再回到 data 分支，
    // 用户视觉上感知为「消失 → 闪现 → 再消失」（中间那次菊花）。
    // 开启 skipLoadingOnReload 后，重载期间继续以上一帧 data 渲染，
    // 配合 `_locallyDeleted` 把已删流水保持在过滤态，整个动画只剩
    // Dismissible 收起动画本身，无闪烁、无菊花。
    return summary.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败：$e')),
      data: (data) {
        // 1) 收集当前 data 里的 active id，把已经从 data 中消失的 id
        //    （= 后端刷新落地）从 `_locallyDeleted` 里清掉。这样
        //    "用户从垃圾桶恢复某条流水"时，新一次 data 不会被旧的过滤
        //    集误伤。
        final activeIds = <String>{};
        for (final g in data.dailyGroups) {
          for (final tx in g.transactions) {
            activeIds.add(tx.id);
          }
        }
        _locallyDeleted.removeWhere((id) => !activeIds.contains(id));

        // 2) 过滤出实际渲染用的分组——把还在 `_locallyDeleted` 里的流水
        //    剔除（重载窗口期内 data 仍包含它们）。整组被清空时连组一起
        //    丢掉，避免出现"只剩日期标题"的孤儿。
        final visibleGroups = <DailyTransactions>[];
        for (final g in data.dailyGroups) {
          if (_locallyDeleted.isEmpty) {
            visibleGroups.add(g);
            continue;
          }
          final kept = g.transactions
              .where((tx) => !_locallyDeleted.contains(tx.id))
              .toList(growable: false);
          if (kept.isNotEmpty) {
            visibleGroups.add(
              DailyTransactions(date: g.date, transactions: kept),
            );
          }
        }

        if (visibleGroups.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => _onPullToRefresh(context),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.coffee_outlined,
                            size: 64,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withAlpha(128)),
                        const SizedBox(height: 12),
                        Text(
                          '开始记第一笔吧 🐰',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withAlpha(160),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // 3) 维护日期 → GlobalKey 映射：保留已有日期的 key，仅为新增日期
        //    分配新 key、移除已消失日期的 key。
        //
        //    不能 `clear()` 后整体重建——每次 `data:` 分支重建都会产生
        //    全新的 GlobalKey 实例，导致 `Container(key: _dayKeys[date])`
        //    的 Element 被销毁重建，连带其子树的 `_TxTile` 也被重新挂载。
        //    虽然过滤集已经把已删流水从渲染列表里剔除，但稳定 key 仍是
        //    良好实践，避免无关的状态丢失（比如 _TxTile 内部 ConsumerState
        //    缓存）。
        final activeDates = visibleGroups.map((g) => g.date).toSet();
        _dayKeys.removeWhere((date, _) => !activeDates.contains(date));
        for (final g in visibleGroups) {
          _dayKeys.putIfAbsent(
            g.date,
            () => GlobalKey(debugLabel: 'tx_day_${g.date}'),
          );
        }
        _consumeScrollTarget(visibleGroups);

        return RefreshIndicator(
          onRefresh: () => _onPullToRefresh(context),
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final group in visibleGroups)
                  Container(
                    key: _dayKeys[group.date],
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 4),
                          child: Text(
                            _dayLabel(group.date),
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withAlpha(160),
                                ),
                          ),
                        ),
                        for (final tx in group.transactions)
                          _TxTile(
                            key: ValueKey('tx_tile_${tx.id}'),
                            tx: tx,
                            onLocalDismiss: () => _markLocallyDeleted(tx.id),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Step 10.7：下拉刷新 = 强制触发一次同步，并把结果落到 SnackBar。
  /// 未配置云服务时静默退出（不打扰本地模式用户）。
  Future<void> _onPullToRefresh(BuildContext context) async {
    final result = await ref.read(syncTriggerProvider.notifier).trigger();
    if (!context.mounted) return;
    switch (result.outcome) {
      case SyncTriggerOutcome.success:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已同步')),
        );
      case SyncTriggerOutcome.networkUnavailable:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('网络不可用')),
        );
      case SyncTriggerOutcome.failure:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步失败：${result.message ?? ''}')),
        );
      case SyncTriggerOutcome.skipped:
        // 前一次还在跑——静默
        break;
      case SyncTriggerOutcome.notConfigured:
        // 本地模式——静默
        break;
    }
  }
}

class _TxTile extends ConsumerStatefulWidget {
  const _TxTile({
    super.key,
    required this.tx,
    this.onLocalDismiss,
  });

  final TransactionEntry tx;

  /// 左滑确认删除的同步回调——必须由父级在当帧 setState 把对应 tx
  /// 从渲染列表里剔除，否则 Dismissible 在 `_resizeAnimation` 完成后被
  /// 父级 rebuild 命中 update→build 会触发 framework 断言
  /// *"A dismissed Dismissible widget is still part of the tree"*。
  /// 详见 [_TransactionListState._locallyDeleted]。
  ///
  /// 详情页删除路径不走 Dismissible，所以这个回调可空。
  final VoidCallback? onLocalDismiss;

  @override
  ConsumerState<_TxTile> createState() => _TxTileState();
}

class _TxTileState extends ConsumerState<_TxTile> {
  String _inferParentKey(Category? category, TransactionEntry tx) {
    if (category != null) return category.parentKey;
    if (tx.type == 'income') return 'income';
    return 'other';
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.tx;
    final isTransfer = tx.type == 'transfer';
    final isExpense = tx.type == 'expense';
    final sign = isTransfer ? '' : (isExpense ? '-' : '+');
    final amountColor = isTransfer
        ? const Color(0xFF6C8CC8)
        : (isExpense ? const Color(0xFFE76F51) : const Color(0xFFA8D8B9));
    // Step 7.2 修复：watch `accountsListProvider`（而非 `accountRepositoryProvider`
    // + FutureBuilder）。后者拿到的是仓库实例本身，删除账户后实例不变 → tile
    // 不会 rebuild → 显示陈旧的账户名。前者在 `_confirmDelete` / `_save` 后已
    // 被 invalidate → 触发整族 watcher 重建 → 流水副标题与详情底部页立即拿到
    // 最新账户列表，软删账户立即显示"（已删账户）"。
    final accounts =
        ref.watch(accountsListProvider).valueOrNull ?? const <Account>[];
    // 2026-05-02 修复：分类列表改为 watch `categoriesListProvider` 而非
    // 仓库实例 + FutureBuilder。原模式每次 build 都生成新 Future，
    // `recordMonthSummaryProvider` 失效那一帧 `snapshot.data == null` →
    // 全部流水瞬间回退到"💸/💰 + 未分类"占位（用户识别路径下尤其明显，
    // 因为 QuickConfirm 卡片矮，没遮住首页）。Riverpod watch 在重建期间
    // 保留上一帧值 → 闪烁消除。
    final categories =
        ref.watch(categoriesListProvider).valueOrNull ?? const <Category>[];
    // Step 15.3：当前图标包——流水列表图标解析。
    final iconPack = ref.watch(currentIconPackProvider);
    Category? matched;
    final id = tx.categoryId;
    if (id != null) {
      for (final c in categories) {
        if (c.id == id) {
          matched = c;
          break;
        }
      }
    }

    final iconText = isTransfer
        ? '🔁'
        : (matched != null
            ? resolveCategoryIcon(
                matched.icon, matched.parentKey, matched.name, iconPack)
            : (tx.type == 'expense' ? '💸' : (tx.type == 'income' ? '💰' : '🔁')));
    final nameText = isTransfer ? '转账' : (matched?.name ?? '未分类');
    final parentKey = _inferParentKey(matched, tx);

    String accountName(String? id) {
      if (id == null || id.isEmpty) return '账户';
      for (final a in accounts) {
        if (a.id == id) return a.name;
      }
      // Step 7.2：账户已被软删（不在 listActive 结果里），但流水的
      // accountId 仍指向它——展示"（已删账户）"占位，避免 UI 误把
      // 缺失账户当作"未填写"。
      return '（已删账户）';
    }

    final transferSubTitle = isTransfer
        ? '${accountName(tx.accountId)} → ${accountName(tx.toAccountId)}'
        : null;

    return Dismissible(
          key: Key('tx_${tx.id}'),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) async {
            return _confirmDelete(context);
          },
          onDismissed: (_) async {
            // 第一步必须同步执行：把 tx.id 标记为本地已删，触发父级
            // setState 在当帧 build 阶段把该流水从渲染列表里剔除——
            // Dismissible Element 因此被 unmount 而非 update，避开
            // framework 断言 *"A dismissed Dismissible widget is still
            // part of the tree"*。
            //
            // 此前曾尝试 `addPostFrameCallback` 延后 invalidate，
            // 或仅靠 `skipLoadingOnReload: true` 保留旧数据——前者根本
            // 没解决"父级仍在渲染该 Dismissible"的问题，后者直接触发了
            // 上面那条断言。把同步剔除提到所有 await 之前，配合
            // `_locallyDeleted` 过滤集才是稳妥写法。
            widget.onLocalDismiss?.call();

            if (!context.mounted) return;
            final messenger = ScaffoldMessenger.of(context);
            final txRepo = await ref.read(transactionRepositoryProvider.future);
            await txRepo.softDeleteById(tx.id);
            // Step 11.4：软删后清 cache 子目录（fire-and-forget）。
            unawaited(() async {
              try {
                final pruner =
                    await ref.read(attachmentCachePrunerProvider.future);
                await pruner.removeForTransaction(tx.id);
              } catch (_) {/* 静默——cache 残留不影响业务 */}
            }());
            if (!context.mounted) return;
            // 触发 provider 失效；新数据落地后 build 阶段会把 tx.id
            // 从 `_locallyDeleted` 里清理掉。配合
            // `skipLoadingOnReload: true`，重载窗口里继续渲染旧 data
            // 但 tx 已被过滤，不会 spinner 抢一帧。
            ref.invalidate(recordMonthSummaryProvider);
            ref.invalidate(statsLinePointsProvider);
            ref.invalidate(statsPieSlicesProvider);
            ref.invalidate(statsRankItemsProvider);
            ref.invalidate(statsHeatmapCellsProvider);
            ref.invalidate(budgetProgressForProvider);
            messenger.showSnackBar(
              const SnackBar(content: Text('已删除')),
            );
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFE76F51).withAlpha(36),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.delete_outline),
          ),
          child: InkWell(
            onTap: () async {
              await openRecordTileActions(
                context: context,
                ref: ref,
                tx: tx,
                category: matched,
                accountName: accountName(tx.accountId),
                toAccountName: tx.type == 'transfer'
                    ? accountName(tx.toAccountId)
                    : null,
                parentKey: parentKey,
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: amountColor.withAlpha(36),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      iconText,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nameText,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (transferSubTitle != null)
                          Text(
                            transferSubTitle,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withAlpha(150),
                                ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '$sign${_symbolFor(tx.currency)}${_fmt.format(tx.amount)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: amountColor,
                        ),
                  ),
                ],
              ),
            ),
          ),
        );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('删除这条记录？'),
            content: const Text('删除后可在后续垃圾桶中恢复。'),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(ctx).colorScheme.onSurface,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(ctx).colorScheme.onSurface,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    return ok;
  }
}

class _RecordBottomSheetPage extends ConsumerWidget {
  const _RecordBottomSheetPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SafeArea(
      top: false,
      child: RecordNewPage(),
    );
  }
}

class _RecordTransferBottomSheetPage extends ConsumerWidget {
  const _RecordTransferBottomSheetPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SafeArea(
      top: false,
      child: RecordNewPage(isTransfer: true),
    );
  }
}

// ---- Step 16.2：未记账天数轻提示卡片 ----

/// 当距最近一笔流水 ≥ 2 天且当天未提醒过时，在首页数据卡片下方展示一条
/// 轻提示（不是通知）。用户可关闭；关闭后同一天不再弹出。
class _IdleReminderCard extends ConsumerStatefulWidget {
  const _IdleReminderCard();

  @override
  ConsumerState<_IdleReminderCard> createState() => _IdleReminderCardState();
}

class _IdleReminderCardState extends ConsumerState<_IdleReminderCard> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final daysAsync = ref.watch(daysSinceLastTransactionProvider);
    final days = daysAsync.valueOrNull;
    // days == null 表示无流水数据（新用户），不提醒
    if (days == null || days < 2) return const SizedBox.shrink();

    // 当天是否已提醒过
    final shownDate = ref.watch(idleReminderShownDateProvider).valueOrNull;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (shownDate == today) return const SizedBox.shrink();

    // 首次渲染时标记已展示，防止同一天重复弹出
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(idleReminderShownDateProvider.notifier).markToday();
    });

    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF4A261).withAlpha(36),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF4A261).withAlpha(80)),
        ),
        child: Row(
          children: [
            const Text('🍯', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '已经 $days 天没记账了，快来记一笔吧 🐻',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withAlpha(200),
                    ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: colors.onSurface.withAlpha(120)),
              onPressed: () => setState(() => _dismissed = true),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
      ),
    );
  }
}