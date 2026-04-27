import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../local/app_database.dart';
import '../local/providers.dart';
import 'account_repository.dart';
import 'budget_repository.dart';
import 'category_repository.dart';
import 'ledger_repository.dart';
import 'transaction_repository.dart';

part 'providers.g.dart';

/// 当前选中账本的 id。
///
/// Phase 4 Step 4.1 升级为 [AsyncNotifier]：支持 [switchTo] 切换并持久化到
/// [user_pref.current_ledger_id]。build 先查 user_pref → 存在且 ledger 仍活跃
/// 则返回；否则回退到第一个活跃账本（覆盖写入 user_pref 供下次 build 命中）。
@Riverpod(keepAlive: true)
class CurrentLedgerId extends _$CurrentLedgerId {
  @override
  Future<String> build() async {
    await ref.watch(defaultSeedProvider.future);
    final db = ref.watch(appDatabaseProvider);

    final pref = await (db.select(db.userPrefTable)
          ..where((t) => t.id.equals(1)))
        .getSingle();
    if (pref.currentLedgerId != null) {
      // 校验该账本仍存在且活跃
      final row = await (db.select(db.ledgerTable)
            ..where((t) => t.id.equals(pref.currentLedgerId!)))
          .getSingleOrNull();
      if (row != null && row.deletedAt == null) {
        return pref.currentLedgerId!;
      }
    }

    // 回退：取第一个活跃账本
    final ledgers = await db.ledgerDao.listActive();
    final id = ledgers.first.id;
    // 写入 user_pref 供后续 build 命中
    await (db.update(db.userPrefTable)..where((t) => t.id.equals(1))).write(
      UserPrefTableCompanion(currentLedgerId: Value(id)),
    );
    return id;
  }

  /// 切换到指定账本：持久化到 [user_pref.current_ledger_id] 后触发重建。
  Future<void> switchTo(String newId) async {
    final db = ref.read(appDatabaseProvider);
    await (db.update(db.userPrefTable)..where((t) => t.id.equals(1))).write(
      UserPrefTableCompanion(currentLedgerId: Value(newId)),
    );
    ref.invalidateSelf();
  }
}

@Riverpod(keepAlive: true)
Future<LedgerRepository> ledgerRepository(Ref ref) async {
  final db = ref.watch(appDatabaseProvider);
  final devId = await ref.watch(deviceIdProvider.future);
  return LocalLedgerRepository(db: db, deviceId: devId);
}

@Riverpod(keepAlive: true)
Future<CategoryRepository> categoryRepository(Ref ref) async {
  final db = ref.watch(appDatabaseProvider);
  final devId = await ref.watch(deviceIdProvider.future);
  return LocalCategoryRepository(db: db, deviceId: devId);
}

@Riverpod(keepAlive: true)
Future<AccountRepository> accountRepository(Ref ref) async {
  final db = ref.watch(appDatabaseProvider);
  final devId = await ref.watch(deviceIdProvider.future);
  return LocalAccountRepository(db: db, deviceId: devId);
}

@Riverpod(keepAlive: true)
Future<TransactionRepository> transactionRepository(Ref ref) async {
  final db = ref.watch(appDatabaseProvider);
  final devId = await ref.watch(deviceIdProvider.future);
  return LocalTransactionRepository(db: db, deviceId: devId);
}

@Riverpod(keepAlive: true)
Future<BudgetRepository> budgetRepository(Ref ref) async {
  final db = ref.watch(appDatabaseProvider);
  final devId = await ref.watch(deviceIdProvider.future);
  return LocalBudgetRepository(db: db, deviceId: devId);
}
