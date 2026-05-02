import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/repository/providers.dart'
    show currentLedgerIdProvider, transactionRepositoryProvider;
import '../../domain/entity/transaction_entry.dart';

part 'record_providers.g.dart';

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
