import 'dart:convert';

import '../../domain/entity/account.dart';
import '../local/app_database.dart';
import '../local/dao/account_dao.dart';
import '../local/dao/sync_op_dao.dart';
import 'entity_mappers.dart';
import 'repo_clock.dart';

/// 账户仓库——语义与职责同 [LedgerRepository]；类型换成 [Account]。
///
/// Account 是全局资源不绑定账本，API 是 [listActive]——与 LedgerDao 的退化
/// 方法名一致。
abstract class AccountRepository {
  Future<List<Account>> listActive();
  Future<Account> save(Account entity);
  Future<void> softDeleteById(String id);
}

class LocalAccountRepository implements AccountRepository {
  LocalAccountRepository({
    required AppDatabase db,
    required String deviceId,
    RepoClock clock = DateTime.now,
  })  : _db = db,
        _dao = db.accountDao,
        _syncOp = db.syncOpDao,
        _deviceId = deviceId,
        _clock = clock;

  final AppDatabase _db;
  final AccountDao _dao;
  final SyncOpDao _syncOp;
  final String _deviceId;
  final RepoClock _clock;

  @override
  Future<List<Account>> listActive() async {
    final rows = await _dao.listActive();
    return rows.map(rowToAccount).toList(growable: false);
  }

  @override
  Future<Account> save(Account entity) async {
    final now = _clock();
    final stamped = entity.copyWith(updatedAt: now, deviceId: _deviceId);
    await _db.transaction(() async {
      await _dao.upsert(accountToCompanion(stamped));
      await _syncOp.enqueue(
        entity: 'account',
        entityId: stamped.id,
        op: 'upsert',
        payload: jsonEncode(stamped.toJson()),
        enqueuedAt: now.millisecondsSinceEpoch,
      );
    });
    return stamped;
  }

  @override
  Future<void> softDeleteById(String id) async {
    final now = _clock();
    await _db.transaction(() async {
      final row = await (_db.select(_db.accountTable)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (row == null) return;
      final updated = rowToAccount(row).copyWith(
        updatedAt: now,
        deletedAt: now,
        deviceId: _deviceId,
      );
      await (_db.update(_db.accountTable)..where((t) => t.id.equals(id)))
          .write(
        AccountTableCompanion(
          updatedAt: Value(now.millisecondsSinceEpoch),
          deletedAt: Value(now.millisecondsSinceEpoch),
          deviceId: Value(_deviceId),
        ),
      );
      await _syncOp.enqueue(
        entity: 'account',
        entityId: id,
        op: 'delete',
        payload: jsonEncode(updated.toJson()),
        enqueuedAt: now.millisecondsSinceEpoch,
      );
    });
  }
}
