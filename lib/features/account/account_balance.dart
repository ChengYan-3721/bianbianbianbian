import '../../domain/entity/account.dart';
import '../../domain/entity/transaction_entry.dart';

/// 单个账户在某条时间线上的当前余额。
///
/// 字段语义：
/// - [netAmount]：流水净额（参与计算的全部 income/expense/transfer 给该账户
///   带来的净增减）。
/// - [currentBalance] = [netAmount]。账户不再保存余额字段，当前余额完全由
///   未删除流水计算得出。
class AccountBalance {
  const AccountBalance({required this.accountId, required this.netAmount});

  final String accountId;
  final double netAmount;

  double get currentBalance => netAmount;

  @override
  bool operator ==(Object other) =>
      other is AccountBalance &&
      other.accountId == accountId &&
      other.netAmount == netAmount;

  @override
  int get hashCode => Object.hash(accountId, netAmount);

  @override
  String toString() =>
      'AccountBalance(accountId: $accountId, '
      'netAmount: $netAmount, currentBalance: $currentBalance)';
}

/// 给定一组流水，按账户聚合净流入金额。
///
/// 规则（与 design-document §5.6 + §7.1 transaction_entry 一致）：
/// - `type == 'expense'`：从 `accountId` 扣除 `amount`。
/// - `type == 'income'`：向 `accountId` 增加 `amount`。
/// - `type == 'transfer'`：从 `accountId` 扣除 `amount`，向 `toAccountId`
///   增加 `amount`。
/// - 已软删流水（`deletedAt != null`）会被过滤掉——调用方传入的列表通常已经
///   是 `listActiveByLedger` 的结果，但保留过滤防御未来可能直接传 raw row。
/// - `accountId` / `toAccountId` 为 null 的流水（例如还没绑定账户的旧数据）
///   会被静默忽略——不计入任何账户净额。
Map<String, double> aggregateNetAmountsByAccount(
  Iterable<TransactionEntry> transactions,
) {
  final result = <String, double>{};
  for (final tx in transactions) {
    if (tx.deletedAt != null) continue;
    switch (tx.type) {
      case 'expense':
        final id = tx.accountId;
        if (id == null) continue;
        result[id] = (result[id] ?? 0) - tx.amount;
      case 'income':
        final id = tx.accountId;
        if (id == null) continue;
        result[id] = (result[id] ?? 0) + tx.amount;
      case 'transfer':
        final from = tx.accountId;
        final to = tx.toAccountId;
        if (from != null && from.isNotEmpty) {
          result[from] = (result[from] ?? 0) - tx.amount;
        }
        if (to != null && to.isNotEmpty) {
          result[to] = (result[to] ?? 0) + tx.amount;
        }
      default:
        // 未来若引入新 type（如 'refund'），保持向前兼容：默认忽略。
        break;
    }
  }
  return result;
}

/// 给定账户清单 + 流水清单，产出每个账户的 [AccountBalance]。
///
/// 顺序与 [accounts] 一致（不重排序）。即便某账户没有任何流水，也会出现在
/// 结果里（[netAmount] = 0），这样 UI 渲染时不会"消失"。
List<AccountBalance> computeAccountBalances({
  required Iterable<Account> accounts,
  required Iterable<TransactionEntry> transactions,
}) {
  final nets = aggregateNetAmountsByAccount(transactions);
  return [
    for (final acc in accounts)
      AccountBalance(accountId: acc.id, netAmount: nets[acc.id] ?? 0),
  ];
}

/// 计算"总资产"——只把 [Account.includeInTotal] = true 的账户当前余额相加。
///
/// 实施计划 Step 7.1 验收：切换 `includeInTotal` 时数值跟随变化；信用卡账户
/// 当前余额可为负（计入即为减项）。
double computeTotalAssets({
  required Iterable<Account> accounts,
  required Iterable<TransactionEntry> transactions,
}) {
  final nets = aggregateNetAmountsByAccount(transactions);
  var total = 0.0;
  for (final acc in accounts) {
    if (!acc.includeInTotal) continue;
    total += nets[acc.id] ?? 0;
  }
  return total;
}

/// 资产/负债二分：按 `includeInTotal` 账户当前余额的正负拆分。
///
/// - `assets`：Σ max(0, currentBalance)——仅取正余额。
/// - `liabilities`：Σ |min(0, currentBalance)|——欠款绝对值之和。
///
/// 性质：`assets - liabilities == computeTotalAssets(...)`（净资产即总资产）。
/// 资产页顶部卡片在「余额按正负拆分」口径下消费本结果。
({double assets, double liabilities}) computeAssetsAndLiabilities({
  required Iterable<Account> accounts,
  required Iterable<TransactionEntry> transactions,
}) {
  final nets = aggregateNetAmountsByAccount(transactions);
  var assets = 0.0;
  var liabilities = 0.0;
  for (final acc in accounts) {
    if (!acc.includeInTotal) continue;
    final balance = nets[acc.id] ?? 0;
    if (balance >= 0) {
      assets += balance;
    } else {
      liabilities += -balance;
    }
  }
  return (assets: assets, liabilities: liabilities);
}

/// 账户详情页的"年份×月份"聚合结果。
class AccountYearDetail {
  const AccountYearDetail({
    required this.year,
    required this.yearInflow,
    required this.yearOutflow,
    required this.months,
  });

  final int year;
  final double yearInflow;
  final double yearOutflow;

  /// 长度恒为 12，索引 0..11 对应 1..12 月（缺月仍占位，inflow/outflow=0、
  /// transactions=[]）。UI 据此渲染 12 张月份卡片。
  final List<AccountMonthGroup> months;
}

/// 月度分组：流入/流出 + 该月该账户的全部流水（已按 `occurredAt` 倒序）。
class AccountMonthGroup {
  const AccountMonthGroup({
    required this.month,
    required this.inflow,
    required this.outflow,
    required this.transactions,
  });

  final int month; // 1..12
  final double inflow;
  final double outflow;
  final List<TransactionEntry> transactions;
}

/// 给定流水清单，过滤出与 [accountId] 相关、发生于 [year] 的活跃流水，
/// 按月份聚合流入/流出与明细列表。
///
/// 流入 / 流出口径（与资产/详情页顶部一致，含转账）：
/// - 流入：`type == 'income' && accountId == X` ∪
///   `type == 'transfer' && toAccountId == X`
/// - 流出：`type == 'expense' && accountId == X` ∪
///   `type == 'transfer' && accountId == X`
///
/// 已软删 (`deletedAt != null`) 的流水被忽略。
AccountYearDetail computeAccountYearDetail({
  required String accountId,
  required int year,
  required Iterable<TransactionEntry> transactions,
}) {
  final inflowsByMonth = List<double>.filled(12, 0);
  final outflowsByMonth = List<double>.filled(12, 0);
  final txsByMonth = List<List<TransactionEntry>>.generate(12, (_) => []);

  for (final tx in transactions) {
    if (tx.deletedAt != null) continue;
    if (tx.occurredAt.year != year) continue;

    final isInflowHere =
        (tx.type == 'income' && tx.accountId == accountId) ||
        (tx.type == 'transfer' && tx.toAccountId == accountId);
    final isOutflowHere =
        (tx.type == 'expense' && tx.accountId == accountId) ||
        (tx.type == 'transfer' && tx.accountId == accountId);
    if (!isInflowHere && !isOutflowHere) continue;

    final idx = tx.occurredAt.month - 1;
    if (isInflowHere) inflowsByMonth[idx] += tx.amount;
    if (isOutflowHere) outflowsByMonth[idx] += tx.amount;
    txsByMonth[idx].add(tx);
  }

  for (final list in txsByMonth) {
    list.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  }

  final months = [
    for (var m = 1; m <= 12; m++)
      AccountMonthGroup(
        month: m,
        inflow: inflowsByMonth[m - 1],
        outflow: outflowsByMonth[m - 1],
        transactions: List.unmodifiable(txsByMonth[m - 1]),
      ),
  ];

  var yearInflow = 0.0;
  var yearOutflow = 0.0;
  for (final mg in months) {
    yearInflow += mg.inflow;
    yearOutflow += mg.outflow;
  }

  return AccountYearDetail(
    year: year,
    yearInflow: yearInflow,
    yearOutflow: yearOutflow,
    months: months,
  );
}
