import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/local/app_database.dart';
import '../../data/local/providers.dart';
import '../../data/repository/providers.dart';
import '../../domain/entity/account.dart';
import '../../domain/entity/transaction_entry.dart';
import 'account_balance.dart';

part 'account_providers.g.dart';

/// 用户在 `user_pref.account_order` 中保存的账户排序（JSON 数组字符串）。
///
/// - null：使用默认排序（余额倒序）
/// - 非空：用户手动拖动后的 ID 顺序
@riverpod
Future<List<String>?> accountOrder(Ref ref) async {
  final db = ref.watch(appDatabaseProvider);
  final pref = await (db.select(db.userPrefTable)
        ..where((t) => t.id.equals(1)))
      .getSingleOrNull();
  final raw = pref?.accountOrder;
  if (raw == null || raw.isEmpty) return null;
  final list = (jsonDecode(raw) as List).cast<String>();
  return list;
}

/// 当前账本视角下的账户清单，按用户自定义排序（`user_pref.account_order`）
/// 或默认余额倒序排列。Step 7.1 列表页直接消费。
///
/// 当 `account_order` 为 null（默认）时，独立计算余额用于排序，
/// 不依赖 [accountBalancesProvider] 以避免循环依赖。
@riverpod
Future<List<Account>> accountsList(Ref ref) async {
  final repo = await ref.watch(accountRepositoryProvider.future);
  final accounts = await repo.listActive();

  final orderIds = await ref.watch(accountOrderProvider.future);
  if (orderIds == null || orderIds.isEmpty) {
    // 默认：按余额倒序——独立计算余额，避免与 accountBalancesProvider 循环
    final ledgerId = await ref.watch(currentLedgerIdProvider.future);
    final txRepo = await ref.watch(transactionRepositoryProvider.future);
    final txs = await txRepo.listActiveByLedger(ledgerId);
    final nets = aggregateNetAmountsByAccount(txs);
    final sorted = [...accounts]..sort((a, b) {
        final netA = nets[a.id];
        final netB = nets[b.id];
        final ba = netA != null ? netA.converted : 0.0;
        final bb = netB != null ? netB.converted : 0.0;
        return bb.compareTo(ba);
      });
    return sorted;
  }

  // 用户自定义排序：排好序的在前，不在列表中的新账户追加到末尾
  final indexed = {for (var i = 0; i < orderIds.length; i++) orderIds[i]: i};
  final inOrder = <Account>[];
  final remaining = <Account>[];
  for (final acc in accounts) {
    final idx = indexed[acc.id];
    if (idx != null) {
      inOrder.add(acc);
    } else {
      remaining.add(acc);
    }
  }
  inOrder.sort((a, b) => (indexed[a.id] ?? 0).compareTo(indexed[b.id] ?? 0));
  return [...inOrder, ...remaining];
}

/// 当前账本视角下的所有账户余额（含未发生流水的账户）。
///
/// design-document §5.1.4 明确"统计页、预算、资产均在'当前账本'维度内聚合"
/// ——故仅取当前账本流水参与净额。账户本身是全局资源（跨账本共享），但本期
/// 余额展示走"账本维度"。
@riverpod
Future<List<AccountBalance>> accountBalances(Ref ref) async {
  final accounts = await ref.watch(accountsListProvider.future);
  final ledgerId = await ref.watch(currentLedgerIdProvider.future);
  final txRepo = await ref.watch(transactionRepositoryProvider.future);
  final txs = await txRepo.listActiveByLedger(ledgerId);
  return computeAccountBalances(accounts: accounts, transactions: txs);
}

/// 当前账本视角下的总资产——所有 [Account.includeInTotal] = true 的账户当前
/// 余额求和。Step 7.1 资产页顶部卡片消费。
@riverpod
Future<double> totalAssets(Ref ref) async {
  final accounts = await ref.watch(accountsListProvider.future);
  final ledgerId = await ref.watch(currentLedgerIdProvider.future);
  final txRepo = await ref.watch(transactionRepositoryProvider.future);
  final txs = await txRepo.listActiveByLedger(ledgerId);
  return computeTotalAssets(accounts: accounts, transactions: txs);
}

/// 当前账本视角下「资产 / 负债」二分——按 `includeInTotal` 账户当前余额的
/// 正负拆分（详见 [computeAssetsAndLiabilities]）。资产页顶部卡片在新版三值
/// 布局（资产 + 净资产 + 负债）下消费本结果。
///
/// 手写 provider 而非走 `@riverpod` 代码生成，避免新增产物时跑 build_runner。
final accountAssetLiabilityProvider =
    AutoDisposeFutureProvider<({double assets, double liabilities})>((ref) async {
  final accounts = await ref.watch(accountsListProvider.future);
  final ledgerId = await ref.watch(currentLedgerIdProvider.future);
  final txRepo = await ref.watch(transactionRepositoryProvider.future);
  final txs = await txRepo.listActiveByLedger(ledgerId);
  return computeAssetsAndLiabilities(accounts: accounts, transactions: txs);
});

/// 当前账本视角下未软删的全部流水——账户详情页用本 provider 拉数后再按账户、
/// 年份在本地聚合。手写 provider 同样避免触发 build_runner。
final currentLedgerTransactionsProvider =
    AutoDisposeFutureProvider<List<TransactionEntry>>((ref) async {
  final ledgerId = await ref.watch(currentLedgerIdProvider.future);
  final txRepo = await ref.watch(transactionRepositoryProvider.future);
  return txRepo.listActiveByLedger(ledgerId);
});

/// 将用户手动拖动排列后的账户 ID 顺序写入 `user_pref.account_order`，
/// 并 invalidate 相关 provider 让列表即时刷新。
Future<void> saveAccountOrder(WidgetRef ref, List<String> accountIds) async {
  final db = ref.read(appDatabaseProvider);
  await (db.update(db.userPrefTable)..where((t) => t.id.equals(1))).write(
    UserPrefTableCompanion(
      accountOrder: Value(jsonEncode(accountIds)),
    ),
  );
  ref.invalidate(accountOrderProvider);
  ref.invalidate(accountsListProvider);
  ref.invalidate(accountBalancesProvider);
  ref.invalidate(totalAssetsProvider);
  ref.invalidate(accountAssetLiabilityProvider);
}

/// 清除 `user_pref.account_order`，恢复为默认余额倒序排序。
Future<void> resetAccountOrder(WidgetRef ref) async {
  final db = ref.read(appDatabaseProvider);
  await (db.update(db.userPrefTable)..where((t) => t.id.equals(1))).write(
    const UserPrefTableCompanion(
      accountOrder: Value(null),
    ),
  );
  ref.invalidate(accountOrderProvider);
  ref.invalidate(accountsListProvider);
  ref.invalidate(accountBalancesProvider);
  ref.invalidate(totalAssetsProvider);
  ref.invalidate(accountAssetLiabilityProvider);
}
