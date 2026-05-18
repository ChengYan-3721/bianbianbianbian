import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/repository/providers.dart';
import '../../domain/entity/account.dart';
import '../../domain/entity/transaction_entry.dart';
import 'account_balance.dart';

part 'account_providers.g.dart';

/// 当前账本视角下的账户清单（按 [accountRepository.listActive] 顺序，
/// 即 `updated_at` 倒序）。Step 7.1 列表页直接消费。
@riverpod
Future<List<Account>> accountsList(Ref ref) async {
  final repo = await ref.watch(accountRepositoryProvider.future);
  return repo.listActive();
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
