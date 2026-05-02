import '../../domain/entity/account.dart';
import '../../domain/entity/transaction_entry.dart';

/// 单个账户在某条时间线上的当前余额。
///
/// 字段语义：
/// - [initialBalance]：账户的初始余额（来自 [Account.initialBalance]）。
/// - [netAmount]：流水净额（参与计算的全部 income/expense/transfer 给该账户
///   带来的净增减）。
/// - [currentBalance] = [initialBalance] + [netAmount]——展示给用户的"当前
///   余额"，信用卡欠款时为负数。
class AccountBalance {
  const AccountBalance({
    required this.accountId,
    required this.initialBalance,
    required this.netAmount,
  });

  final String accountId;
  final double initialBalance;
  final double netAmount;

  double get currentBalance => initialBalance + netAmount;

  @override
  bool operator ==(Object other) =>
      other is AccountBalance &&
      other.accountId == accountId &&
      other.initialBalance == initialBalance &&
      other.netAmount == netAmount;

  @override
  int get hashCode => Object.hash(accountId, initialBalance, netAmount);

  @override
  String toString() => 'AccountBalance(accountId: $accountId, '
      'initialBalance: $initialBalance, netAmount: $netAmount, '
      'currentBalance: $currentBalance)';
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
      AccountBalance(
        accountId: acc.id,
        initialBalance: acc.initialBalance,
        netAmount: nets[acc.id] ?? 0,
      ),
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
    total += acc.initialBalance + (nets[acc.id] ?? 0);
  }
  return total;
}
