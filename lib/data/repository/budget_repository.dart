import 'dart:convert';

import '../../domain/entity/budget.dart';
import '../local/app_database.dart';
import '../local/dao/budget_dao.dart';
import '../local/dao/sync_op_dao.dart';
import 'entity_mappers.dart';
import 'repo_clock.dart';

/// 预算仓库——语义与职责同 [LedgerRepository]；类型换成 [Budget]。
abstract class BudgetRepository {
  Future<List<Budget>> listActiveByLedger(String ledgerId);
  Future<Budget> save(Budget entity);
  Future<void> softDeleteById(String id);

  /// 批量软删除某账本下所有未软删预算（用于账本级联删除）。
  /// 返回受影响行数。
  Future<int> softDeleteByLedgerId(String ledgerId);
}

class LocalBudgetRepository implements BudgetRepository {
  LocalBudgetRepository({
    required AppDatabase db,
    required String deviceId,
    RepoClock clock = DateTime.now,
  })  : _db = db,
        _dao = db.budgetDao,
        _syncOp = db.syncOpDao,
        _deviceId = deviceId,
        _clock = clock;

  final AppDatabase _db;
  final BudgetDao _dao;
  final SyncOpDao _syncOp;
  final String _deviceId;
  final RepoClock _clock;

  @override
  Future<List<Budget>> listActiveByLedger(String ledgerId) async {
    final rows = await _dao.listActiveByLedger(ledgerId);
    return rows.map(rowToBudget).toList(growable: false);
  }

  @override
  Future<Budget> save(Budget entity) async {
    final now = _clock();
    final stamped = entity.copyWith(updatedAt: now, deviceId: _deviceId);
    await _db.transaction(() async {
      await _dao.upsert(budgetToCompanion(stamped));
      await _syncOp.enqueue(
        entity: 'budget',
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
      final row = await (_db.select(_db.budgetTable)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (row == null) return;
      final updated = rowToBudget(row).copyWith(
        updatedAt: now,
        deletedAt: now,
        deviceId: _deviceId,
      );
      await (_db.update(_db.budgetTable)..where((t) => t.id.equals(id))).write(
        BudgetTableCompanion(
          updatedAt: Value(now.millisecondsSinceEpoch),
          deletedAt: Value(now.millisecondsSinceEpoch),
          deviceId: Value(_deviceId),
        ),
      );
      await _syncOp.enqueue(
        entity: 'budget',
        entityId: id,
        op: 'delete',
        payload: jsonEncode(updated.toJson()),
        enqueuedAt: now.millisecondsSinceEpoch,
      );
    });
  }

  @override
  Future<int> softDeleteByLedgerId(String ledgerId) async {
    final now = _clock();
    final nowMs = now.millisecondsSinceEpoch;
    return _db.transaction(() async {
      final rows = await (_db.select(_db.budgetTable)
            ..where((t) => t.ledgerId.equals(ledgerId))
            ..where((t) => t.deletedAt.isNull()))
          .get();
      if (rows.isEmpty) return 0;

      final count = await _dao.softDeleteByLedgerId(
        ledgerId,
        deletedAt: nowMs,
        updatedAt: nowMs,
      );

      for (final row in rows) {
        final updated = rowToBudget(row).copyWith(
          updatedAt: now,
          deletedAt: now,
          deviceId: _deviceId,
        );
        await _syncOp.enqueue(
          entity: 'budget',
          entityId: row.id,
          op: 'delete',
          payload: jsonEncode(updated.toJson()),
          enqueuedAt: nowMs,
        );
      }
      return count;
    });
  }
}
