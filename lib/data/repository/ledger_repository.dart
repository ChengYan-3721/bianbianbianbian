import 'dart:convert';

import '../../domain/entity/ledger.dart';
import '../local/app_database.dart';
import '../local/dao/budget_dao.dart';
import '../local/dao/ledger_dao.dart';
import '../local/dao/sync_op_dao.dart';
import '../local/dao/transaction_entry_dao.dart';
import 'entity_mappers.dart';
import 'repo_clock.dart';

/// 账本仓库——对 UI 层以 [Ledger] 领域实体为契约。
///
/// 所有仓库的共同职责（Step 2.2）：
/// 1. **自动填充 `updated_at` / `device_id`**：caller 传入的这两字段被 repo
///    覆写——业务路径不应让调用方操心"写对时间戳和 deviceId"。**例外**：
///    Phase 10 同步引擎从远端拉取数据回写本地时，需要保留远端 `updated_at` /
///    `device_id`——届时新增 `saveFromRemote` 方法，走另一条不覆写的路径。
/// 2. **软删除**：[softDeleteById] 更新 `updated_at` / `deleted_at` / `device_id`
///    三列，不走 DAO 的 2 列 `softDeleteById`（DAO 层不管 device_id；repo
///    直接写 3 列，保证同步 LWW 的 deviceId tiebreak 与 payload 一致）。
///    同时级联软删除该账本下的所有流水和预算。
/// 3. **写 sync_op 队列**：无论同步开关是否启用，每次写入/软删都入队一条。
///    Phase 10 同步开启后消费这张表；若同步一直关闭，表会长期增长——这是
///    刻意的（保留"稍后启用同步时追溯本地历史"的能力）。
abstract class LedgerRepository {
  Future<Ledger?> getById(String id);
  Future<List<Ledger>> listActive();

  /// 保存或更新。返回"已被 repo 覆写 `updated_at` / `device_id` 的实体快照"。
  Future<Ledger> save(Ledger entity);

  /// 软删除该 id——若行不存在则静默返回，不报错也不入队。
  /// 会级联软删除该账本下的所有流水和预算。
  Future<void> softDeleteById(String id);

  /// 归档/取消归档账本。返回更新后的实体快照。
  Future<Ledger> setArchived(String id, bool archived);
}

class LocalLedgerRepository implements LedgerRepository {
  LocalLedgerRepository({
    required AppDatabase db,
    required String deviceId,
    RepoClock clock = DateTime.now,
  })  : _db = db,
        _dao = db.ledgerDao,
        _txDao = db.transactionEntryDao,
        _budgetDao = db.budgetDao,
        _syncOp = db.syncOpDao,
        _deviceId = deviceId,
        _clock = clock;

  final AppDatabase _db;
  final LedgerDao _dao;
  final TransactionEntryDao _txDao;
  final BudgetDao _budgetDao;
  final SyncOpDao _syncOp;
  final String _deviceId;
  final RepoClock _clock;

  @override
  Future<Ledger?> getById(String id) async {
    final row = await (_db.select(_db.ledgerTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : rowToLedger(row);
  }

  @override
  Future<List<Ledger>> listActive() async {
    final rows = await _dao.listActive();
    return rows.map(rowToLedger).toList(growable: false);
  }

  @override
  Future<Ledger> save(Ledger entity) async {
    final now = _clock();
    final stamped = entity.copyWith(updatedAt: now, deviceId: _deviceId);
    await _db.transaction(() async {
      await _dao.upsert(ledgerToCompanion(stamped));
      await _syncOp.enqueue(
        entity: 'ledger',
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
    final nowMs = now.millisecondsSinceEpoch;
    await _db.transaction(() async {
      final row = await (_db.select(_db.ledgerTable)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (row == null) return;

      // 1. 级联软删除该账本下的所有流水
      await _txDao.softDeleteByLedgerId(
        id,
        deletedAt: nowMs,
        updatedAt: nowMs,
      );
      // 2. 级联软删除该账本下的所有预算
      await _budgetDao.softDeleteByLedgerId(
        id,
        deletedAt: nowMs,
        updatedAt: nowMs,
      );

      // 3. 软删除账本本身
      final updated = rowToLedger(row).copyWith(
        updatedAt: now,
        deletedAt: now,
        deviceId: _deviceId,
      );
      await (_db.update(_db.ledgerTable)..where((t) => t.id.equals(id))).write(
        LedgerTableCompanion(
          updatedAt: Value(nowMs),
          deletedAt: Value(nowMs),
          deviceId: Value(_deviceId),
        ),
      );
      await _syncOp.enqueue(
        entity: 'ledger',
        entityId: id,
        op: 'delete',
        payload: jsonEncode(updated.toJson()),
        enqueuedAt: nowMs,
      );
    });
  }

  @override
  Future<Ledger> setArchived(String id, bool archived) async {
    final now = _clock();
    final nowMs = now.millisecondsSinceEpoch;
    return _db.transaction(() async {
      final row = await (_db.select(_db.ledgerTable)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (row == null) {
        throw ArgumentError('Ledger not found: $id');
      }
      final updated = rowToLedger(row).copyWith(
        archived: archived,
        updatedAt: now,
        deviceId: _deviceId,
      );
      await (_db.update(_db.ledgerTable)..where((t) => t.id.equals(id))).write(
        LedgerTableCompanion(
          archived: Value(archived ? 1 : 0),
          updatedAt: Value(nowMs),
          deviceId: Value(_deviceId),
        ),
      );
      await _syncOp.enqueue(
        entity: 'ledger',
        entityId: id,
        op: 'upsert',
        payload: jsonEncode(updated.toJson()),
        enqueuedAt: nowMs,
      );
      return updated;
    });
  }
}