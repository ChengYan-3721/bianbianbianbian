import 'dart:convert';

import '../../domain/entity/transaction_entry.dart';
import '../local/app_database.dart';
import '../local/dao/sync_op_dao.dart';
import '../local/dao/transaction_entry_dao.dart';
import 'entity_mappers.dart';
import 'repo_clock.dart';

/// 流水（交易条目）仓库——语义与职责同 [LedgerRepository]；类型换成 [TransactionEntry]。
///
/// **sync_op `entity` 字段值为 `'transaction'`**，而非表名 `'transaction_entry'`——
/// 与 design-document §7.1 `sync_op` 注释（`entity TEXT ... -- ledger | category |
/// account | transaction | budget`）字面一致。Phase 10 同步引擎据此字符串路由到
/// 对应的 Supabase 表名。
abstract class TransactionRepository {
  Future<List<TransactionEntry>> listActiveByLedger(String ledgerId);
  Future<TransactionEntry> save(TransactionEntry entity);
  Future<void> softDeleteById(String id);

  /// 批量软删除某账本下所有未软删流水（用于账本级联删除）。
  /// 返回受影响行数。
  Future<int> softDeleteByLedgerId(String ledgerId);
}

class LocalTransactionRepository implements TransactionRepository {
  LocalTransactionRepository({
    required AppDatabase db,
    required String deviceId,
    RepoClock clock = DateTime.now,
  })  : _db = db,
        _dao = db.transactionEntryDao,
        _syncOp = db.syncOpDao,
        _deviceId = deviceId,
        _clock = clock;

  final AppDatabase _db;
  final TransactionEntryDao _dao;
  final SyncOpDao _syncOp;
  final String _deviceId;
  final RepoClock _clock;

  @override
  Future<List<TransactionEntry>> listActiveByLedger(String ledgerId) async {
    final rows = await _dao.listActiveByLedger(ledgerId);
    return rows.map(rowToTransactionEntry).toList(growable: false);
  }

  @override
  Future<TransactionEntry> save(TransactionEntry entity) async {
    if (entity.type == 'transfer') {
      final from = entity.accountId;
      final to = entity.toAccountId;
      if (from == null || from.isEmpty || to == null || to.isEmpty || from == to) {
        throw ArgumentError('transfer requires different non-empty accountId/toAccountId');
      }
    }

    final now = _clock();
    final stamped = entity.copyWith(updatedAt: now, deviceId: _deviceId);
    await _db.transaction(() async {
      await _dao.upsert(transactionEntryToCompanion(stamped));
      await _syncOp.enqueue(
        entity: 'transaction',
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
      final row = await (_db.select(_db.transactionEntryTable)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (row == null) return;
      final updated = rowToTransactionEntry(row).copyWith(
        updatedAt: now,
        deletedAt: now,
        deviceId: _deviceId,
      );
      await (_db.update(_db.transactionEntryTable)
            ..where((t) => t.id.equals(id)))
          .write(
        TransactionEntryTableCompanion(
          updatedAt: Value(now.millisecondsSinceEpoch),
          deletedAt: Value(now.millisecondsSinceEpoch),
          deviceId: Value(_deviceId),
        ),
      );
      await _syncOp.enqueue(
        entity: 'transaction',
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
      final rows = await (_db.select(_db.transactionEntryTable)
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
        final updated = rowToTransactionEntry(row).copyWith(
          updatedAt: now,
          deletedAt: now,
          deviceId: _deviceId,
        );
        await _syncOp.enqueue(
          entity: 'transaction',
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
