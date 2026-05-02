import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/repository/providers.dart';
import '../../domain/entity/account.dart';
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
