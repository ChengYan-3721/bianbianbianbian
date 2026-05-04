import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository/providers.dart';
import '../../domain/entity/account.dart';
import '../../domain/entity/budget.dart';
import '../../domain/entity/category.dart';
import '../../domain/entity/ledger.dart';
import '../../domain/entity/transaction_entry.dart';

/// Phase 12 垃圾桶保留窗口。超出该窗口的软删项由 Step 12.3 启动清理任务硬删。
const Duration kTrashRetention = Duration(days: 30);

/// 剩余天数（向上取整，最少 0）——UI 列表用这个值显示"剩余 X 天"徽标，
/// 同时 ≤0 的项目不再展示（implementation-plan §12.1 验收）。
int trashDaysLeft({
  required DateTime deletedAt,
  required DateTime now,
  Duration retention = kTrashRetention,
}) {
  final cutoff = deletedAt.add(retention);
  final remainingMs = cutoff.millisecondsSinceEpoch - now.millisecondsSinceEpoch;
  if (remainingMs <= 0) return 0;
  // 向上取整：剩 12 小时仍显示"1 天"。
  final days = (remainingMs / Duration.millisecondsPerDay).ceil();
  return days;
}

/// 4 类垃圾桶 provider——返回 `deleted_at != null` 的全部实体（不做剩余天数过滤，
/// UI 层根据 [trashDaysLeft] 决定显隐）。
final trashedTransactionsProvider =
    FutureProvider.autoDispose<List<TransactionEntry>>((ref) async {
  final repo = await ref.watch(transactionRepositoryProvider.future);
  return repo.listDeleted();
});

final trashedCategoriesProvider =
    FutureProvider.autoDispose<List<Category>>((ref) async {
  final repo = await ref.watch(categoryRepositoryProvider.future);
  return repo.listDeleted();
});

final trashedAccountsProvider =
    FutureProvider.autoDispose<List<Account>>((ref) async {
  final repo = await ref.watch(accountRepositoryProvider.future);
  return repo.listDeleted();
});

final trashedLedgersProvider =
    FutureProvider.autoDispose<List<Ledger>>((ref) async {
  final repo = await ref.watch(ledgerRepositoryProvider.future);
  return repo.listDeleted();
});

/// 已软删预算——Phase 12 Step 12.1 暂不在 UI 露出（4 个 Tab 不含预算），
/// 但保留 provider 供未来扩展或定时清理服务使用。
final trashedBudgetsProvider =
    FutureProvider.autoDispose<List<Budget>>((ref) async {
  final repo = await ref.watch(budgetRepositoryProvider.future);
  return repo.listDeleted();
});

/// 一次性 invalidate 全部垃圾桶 provider——恢复/清空操作完成后调用，让
/// UI 4 个 Tab 同时刷新（账本恢复会级联恢复流水/预算，影响多 Tab）。
/// 由 [TrashPage] 直接调用：把 invalidate 集中在一处，调用方持有 [WidgetRef] 即可。
void invalidateTrashFromWidgetRef(WidgetRef ref) {
  ref.invalidate(trashedTransactionsProvider);
  ref.invalidate(trashedCategoriesProvider);
  ref.invalidate(trashedAccountsProvider);
  ref.invalidate(trashedLedgersProvider);
  ref.invalidate(trashedBudgetsProvider);
}
