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

  /// **垃圾桶专用**（Phase 12 Step 12.1）。所有已软删流水（全账本），按
  /// `deletedAt` 倒序——最近删的靠前。
  Future<List<TransactionEntry>> listDeleted();

  /// **垃圾桶恢复**（Phase 12 Step 12.2）。`deleted_at = null` + 刷新
  /// `updated_at`；不存在则静默返回。**不**入队 `sync_op`——快照模型下
  /// 同步走整体覆盖（`scheduleDebounced` 由调用方触发）。
  Future<void> restoreById(String id);

  /// **垃圾桶永久删除**（Phase 12 Step 12.2）。仅硬删 DB 行，**不**清理附件
  /// 文件——附件目录由 `TrashCleaner` 在调用本方法**之前**负责删除。
  /// 返回硬删行数（0 = 该 id 不存在或已被清理）。
  Future<int> purgeById(String id);

  /// **垃圾桶一键清空**（Phase 12 Step 12.2）。硬删全部 `deleted_at` 非空的
  /// 流水。同样**不**清附件——调用方负责。返回硬删行数。
  Future<int> purgeAllDeleted();

  /// **垃圾桶定时清理**（Phase 12 Step 12.3）。返回 `deleted_at <= cutoff`
  /// 的全部软删流水（仅查询，不删除）——调用方据此先清附件、再调 [purgeById]。
  Future<List<TransactionEntry>> listExpired(DateTime cutoff);

  /// Step 16.2：某账本下最近一笔未软删流水的 `occurredAt`，无流水返回 null。
  Future<DateTime?> latestOccurredAtByLedger(String ledgerId);
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

  @override
  Future<List<TransactionEntry>> listDeleted() async {
    final rows = await _dao.listDeleted();
    return rows.map(rowToTransactionEntry).toList(growable: false);
  }

  @override
  Future<void> restoreById(String id) async {
    final now = _clock();
    final nowMs = now.millisecondsSinceEpoch;
    await _db.transaction(() async {
      final row = await (_db.select(_db.transactionEntryTable)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (row == null) return;
      await _dao.restoreById(id, updatedAt: nowMs);
      // 同步路径：快照模型整体覆盖，无需 sync_op；触发由调用方负责。
    });
  }

  @override
  Future<int> purgeById(String id) {
    return _dao.hardDeleteById(id);
  }

  @override
  Future<int> purgeAllDeleted() async {
    return (_db.delete(_db.transactionEntryTable)
          ..where((t) => t.deletedAt.isNotNull()))
        .go();
  }

  @override
  Future<List<TransactionEntry>> listExpired(DateTime cutoff) async {
    final rows = await _dao.listExpired(cutoff.millisecondsSinceEpoch);
    return rows.map(rowToTransactionEntry).toList(growable: false);
  }

  @override
  Future<DateTime?> latestOccurredAtByLedger(String ledgerId) async {
    final ms = await _dao.latestOccurredAtByLedger(ledgerId);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
}
