import 'dart:convert';

import '../../domain/entity/budget.dart';
import '../../domain/usecase/budget_carry_over.dart';
import '../local/app_database.dart';
import '../local/dao/budget_dao.dart';
import '../local/dao/sync_op_dao.dart';
import 'entity_mappers.dart';
import 'repo_clock.dart';

/// 预算唯一性冲突——同一账本、同一周期、同一分类（含 `categoryId == null` 总
/// 预算）下只能存在一个未软删的预算（Step 6.1 验收）。
class BudgetConflictException implements Exception {
  const BudgetConflictException(this.message);
  final String message;
  @override
  String toString() => 'BudgetConflictException: $message';
}

/// 预算仓库——语义与职责同 [LedgerRepository]；类型换成 [Budget]。
abstract class BudgetRepository {
  Future<List<Budget>> listActiveByLedger(String ledgerId);
  Future<Budget?> getById(String id);
  Future<Budget> save(Budget entity);
  Future<void> softDeleteById(String id);

  /// 批量软删除某账本下所有未软删预算（用于账本级联删除）。
  /// 返回受影响行数。
  Future<int> softDeleteByLedgerId(String ledgerId);

  /// **垃圾桶专用**（Phase 12 Step 12.1）。
  Future<List<Budget>> listDeleted();
  Future<void> restoreById(String id);
  Future<int> purgeById(String id);
  Future<int> purgeAllDeleted();
  Future<List<Budget>> listExpired(DateTime cutoff);

  /// Step 6.4：仅持久化"懒结算产物"（`carry_balance` / `last_settled_at`），
  /// **不**走 [save] 的 toggle 检测，也**不**入队 `sync_op`——结算只是派生
  /// 数据维护，对端从流水重算即可，不应在网络上交换。
  Future<void> updateCarrySettlement({
    required String id,
    required double carryBalance,
    required DateTime? lastSettledAt,
  });
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
  Future<Budget?> getById(String id) async {
    final row = await (_db.select(_db.budgetTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return rowToBudget(row);
  }

  @override
  Future<Budget> save(Budget entity) async {
    final now = _clock();
    // Step 6.4：在写库前，根据"已存在的旧预算"决定 carry_balance / last_settled_at
    // 的写值——applyCarryOverToggle 是纯函数，把 toggle 检测做在仓库层让 UI 不用
    // 关心结转 anchor 的语义。
    final prev = await getById(entity.id);
    final adjusted = applyCarryOverToggle(prev: prev, next: entity, now: now);
    final stamped = adjusted.copyWith(updatedAt: now, deviceId: _deviceId);
    await _db.transaction(() async {
      // 唯一性：同账本 + 同周期 + 同分类（含 null 总预算）下不允许重复
      final dup = await _findActiveDuplicate(
        ledgerId: stamped.ledgerId,
        period: stamped.period,
        categoryId: stamped.categoryId,
        excludeId: stamped.id,
      );
      if (dup != null) {
        throw BudgetConflictException(
          stamped.categoryId == null
              ? '该账本的${_periodLabel(stamped.period)}总预算已存在'
              : '该分类的${_periodLabel(stamped.period)}预算已存在',
        );
      }
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

  @override
  Future<void> updateCarrySettlement({
    required String id,
    required double carryBalance,
    required DateTime? lastSettledAt,
  }) async {
    await (_db.update(_db.budgetTable)..where((t) => t.id.equals(id))).write(
      BudgetTableCompanion(
        carryBalance: Value(carryBalance),
        lastSettledAt: Value(lastSettledAt?.millisecondsSinceEpoch),
      ),
    );
  }

  @override
  Future<List<Budget>> listDeleted() async {
    final rows = await _dao.listDeleted();
    return rows.map(rowToBudget).toList(growable: false);
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
    return (_db.delete(_db.budgetTable)
          ..where((t) => t.deletedAt.isNotNull()))
        .go();
  }

  @override
  Future<List<Budget>> listExpired(DateTime cutoff) async {
    final rows = await _dao.listExpired(cutoff.millisecondsSinceEpoch);
    return rows.map(rowToBudget).toList(growable: false);
  }

  Future<BudgetEntry?> _findActiveDuplicate({
    required String ledgerId,
    required String period,
    required String? categoryId,
    required String excludeId,
  }) async {
    final query = _db.select(_db.budgetTable)
      ..where((t) => t.ledgerId.equals(ledgerId))
      ..where((t) => t.period.equals(period))
      ..where((t) => t.deletedAt.isNull())
      ..where((t) => t.id.isNotIn([excludeId]));
    if (categoryId == null) {
      query.where((t) => t.categoryId.isNull());
    } else {
      query.where((t) => t.categoryId.equals(categoryId));
    }
    return query.getSingleOrNull();
  }

  static String _periodLabel(String period) {
    switch (period) {
      case 'monthly':
        return '月';
      case 'yearly':
        return '年';
      default:
        return period;
    }
  }
}
