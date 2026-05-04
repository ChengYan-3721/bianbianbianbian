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

  /// 根据 id 查询单个账户——**不**过滤 `deleted_at`，软删账户也能查到。
  ///
  /// Step 7.2：流水详情页要在账户被软删后仍能显示"（已删账户）"占位标签，
  /// 但不会让 UI 试图复用已删账户名称——调用方拿到 [Account] 后应根据
  /// `deletedAt != null` 决定显示原名还是占位。当前 V1 阶段调用方
  /// （`_TxTile.accountName`）选择"找不到/已删一律显示占位"。
  Future<Account?> getById(String id);

  Future<Account> save(Account entity);
  Future<void> softDeleteById(String id);

  /// **垃圾桶专用**（Phase 12 Step 12.1）。
  Future<List<Account>> listDeleted();
  Future<void> restoreById(String id);
  Future<int> purgeById(String id);
  Future<int> purgeAllDeleted();
  Future<List<Account>> listExpired(DateTime cutoff);
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
  Future<Account?> getById(String id) async {
    final row = await (_db.select(_db.accountTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return rowToAccount(row);
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

  @override
  Future<List<Account>> listDeleted() async {
    final rows = await _dao.listDeleted();
    return rows.map(rowToAccount).toList(growable: false);
  }

  @override
  Future<void> restoreById(String id) async {
    final now = _clock();
    await _dao.restoreById(id, updatedAt: now.millisecondsSinceEpoch);
  }

  @override
  Future<int> purgeById(String id) {
    return _dao.hardDeleteById(id);
  }

  @override
  Future<int> purgeAllDeleted() {
    return (_db.delete(_db.accountTable)
          ..where((t) => t.deletedAt.isNotNull()))
        .go();
  }

  @override
  Future<List<Account>> listExpired(DateTime cutoff) async {
    final rows = await _dao.listExpired(cutoff.millisecondsSinceEpoch);
    return rows.map(rowToAccount).toList(growable: false);
  }
}
