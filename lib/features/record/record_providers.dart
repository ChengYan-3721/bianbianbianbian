import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repository/providers.dart'
    show
        categoryRepositoryProvider,
        currentLedgerIdProvider,
        transactionRepositoryProvider;
import '../../domain/entity/category.dart';
import '../../domain/entity/transaction_entry.dart';

part 'record_providers.g.dart';

/// 当前活跃二级分类列表（与 [_TxTile] / 详情卡片共享）。
///
/// 引入动机（修复 2026-05-02 bug）：原 `_TxTile` 直接 `FutureBuilder<List<Category>>`
/// 包裹 `categoryRepositoryProvider.listActiveAll()`，每次 build 都会生成一个新
/// Future——`recordMonthSummaryProvider` 失效并导致 `_TxTile` 重建那一帧，
/// FutureBuilder 的 `snapshot.data` 被重置为 `null`，于是当帧分类列表为空 →
/// 全部流水回退到 "💸/💰 + 未分类" 占位，下一帧 Future 完成后又恢复正常。
///
/// 用 Riverpod `FutureProvider` 替代后，`ref.watch(categoriesListProvider).valueOrNull`
/// 在重建期间继续返回上一帧的列表（Riverpod 缓存语义），不再有"瞬间未分类"
/// 闪烁。识别路径下的 QuickConfirm 卡片高度比 FAB sheet 矮，闪烁在视觉上
/// 更明显，所以 bug 仅在该路径被用户察觉，但 FAB 路径其实也存在同样的
/// 重建瞬间——本修复一并消除。
///
/// 故意手写而非 `@riverpod` 注解：避免 codegen 二次跑 build_runner。分类增删
/// 改的 UI 流目前仅 `category_manage_page.toggleFavorite` 一处（不影响图标/名称
/// 显示），future 若加分类编辑请在那里 `ref.invalidate(categoriesListProvider)`。
final categoriesListProvider = FutureProvider<List<Category>>((ref) async {
  final repo = await ref.watch(categoryRepositoryProvider.future);
  return repo.listActiveAll();
});

/// 记账首页当前选择的月份（年月，day 固定为 1）。
///
/// Phase 3 Step 3.1 以月为单位导航；后续可拆分为自定义区间。
@riverpod
class RecordMonth extends _$RecordMonth {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void previous() {
    state = DateTime(state.year, state.month - 1);
  }

  void next() {
    state = DateTime(state.year, state.month + 1);
  }

  void jumpTo(DateTime day) {
    state = DateTime(day.year, day.month);
  }
}

/// 记账列表期望滚动到的目标日期。
///
/// 一次性信号：消费方读取后应立即清空，避免下次月份切换被误触发。
/// 由统计页热力图点击设置，由 [RecordHomePage] 在新月份数据就绪后消费。
final recordScrollTargetProvider = StateProvider<DateTime?>((ref) => null);

/// 按日期倒序分组的流水列表。
class DailyTransactions {
  const DailyTransactions({required this.date, required this.transactions});
  final DateTime date;
  final List<TransactionEntry> transactions;
}

/// 月度汇总数据——收入 / 支出 / 结余 + 按日期分组的流水列表。
class RecordMonthSummary {
  const RecordMonthSummary({
    required this.month,
    required this.income,
    required this.expense,
    required this.dailyGroups,
    this.balance = 0,
  });

  final DateTime month;
  final double income;
  final double expense;
  final double balance;
  final List<DailyTransactions> dailyGroups;
}

/// 当前账本当月的汇总数据。
///
/// 依赖 [recordMonthProvider] → 自动响应月份切换；依赖
/// [currentLedgerIdProvider] + [transactionRepositoryProvider] 取流水。
@riverpod
Future<RecordMonthSummary> recordMonthSummary(Ref ref) async {
  final month = ref.watch(recordMonthProvider);
  final ledgerId = await ref.watch(currentLedgerIdProvider.future);
  final repo = await ref.watch(transactionRepositoryProvider.future);
  final txs = await repo.listActiveByLedger(ledgerId);

  // 客户端按月份过滤——当前阶段流水量极小，不做 SQL 层面 month 过滤。
  final monthTxs = txs.where((tx) {
    final o = tx.occurredAt;
    return o.year == month.year && o.month == month.month;
  }).toList();

  // 按 occurredAt 倒序
  monthTxs.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

  double income = 0;
  double expense = 0;
  for (final tx in monthTxs) {
    // Step 8.2：跨币种流水按 fxRate 折算到账本默认币种再求和。
    // fxRate 在保存时已计算（同币种 = 1.0），因此这里乘法对 V1 单币种用户
    // 是无变化路径；多币种开启后才真正起作用。
    final converted = tx.amount * tx.fxRate;
    if (tx.type == 'income') {
      income += converted;
    } else if (tx.type == 'expense') {
      expense += converted;
    }
  }

  // 按日期分组（天级别）
  final groups = <DateTime, List<TransactionEntry>>{};
  for (final tx in monthTxs) {
    final date = DateTime(tx.occurredAt.year, tx.occurredAt.month, tx.occurredAt.day);
    groups.putIfAbsent(date, () => []).add(tx);
  }

  final dailyGroups = groups.entries
      .map((e) => DailyTransactions(date: e.key, transactions: e.value))
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  return RecordMonthSummary(
    month: month,
    income: income,
    expense: expense,
    dailyGroups: dailyGroups,
    balance: income - expense,
  );
}

// ---- Step 16.2：未记账天数提醒 ----

/// 当前账本距最近一笔未软删流水的天数；无流水时返回 null。
///
/// UI 消费本 provider 判断是否展示"未记账天数"轻提示卡片。
@Riverpod(keepAlive: true)
Future<int?> daysSinceLastTransaction(Ref ref) async {
  final ledgerId = await ref.watch(currentLedgerIdProvider.future);
  final repo = await ref.watch(transactionRepositoryProvider.future);
  final latest = await repo.latestOccurredAtByLedger(ledgerId);
  if (latest == null) return null;
  final now = DateTime.now();
  final lastDate = DateTime(latest.year, latest.month, latest.day);
  final today = DateTime(now.year, now.month, now.day);
  return today.difference(lastDate).inDays;
}

/// 当天是否已展示过未记账天数轻提示。
///
/// 持久化到 SharedPreferences（key: `idle_reminder_last_date`），
/// 值为 'yyyy-MM-dd' 格式。跨重启后同一天不会重复提醒。
@Riverpod(keepAlive: true)
class IdleReminderShownDate extends _$IdleReminderShownDate {
  static const _prefKey = 'idle_reminder_last_date';

  @override
  Future<String?> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey);
  }

  /// 标记今天已展示过轻提示。
  Future<void> markToday() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, today);
    state = AsyncValue.data(today);
  }
}
