import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/transaction_entry_table.dart';

part 'transaction_entry_dao.g.dart';

/// `transaction_entry` 表 DAO——仅暴露 Step 1.4 约定的 4 类方法。
///
/// 所有日常查询自动过滤 `deleted_at IS NULL`；物理删除走 [hardDeleteById]，
/// 该接口仅限垃圾桶定时任务（Phase 12 Step 12.3）调用。
@DriftAccessor(tables: [TransactionEntryTable])
class TransactionEntryDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionEntryDaoMixin {
  TransactionEntryDao(super.db);

  /// 某账本下所有未软删流水，按 `occurred_at` 倒序——命中 `idx_tx_ledger_time`
  /// 索引（`ledger_id, occurred_at DESC`）。
  Future<List<TransactionEntryRow>> listActiveByLedger(String ledgerId) {
    return (select(transactionEntryTable)
          ..where((t) => t.ledgerId.equals(ledgerId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]))
        .get();
  }

  /// Upsert by primary key。调用方负责设置 `updated_at` / `device_id`。
  Future<void> upsert(TransactionEntryTableCompanion entry) {
    return into(transactionEntryTable).insertOnConflictUpdate(entry);
  }

  /// 软删除:写入 `deleted_at` 并刷新 `updated_at`。
  Future<int> softDeleteById(
    String id, {
    required int deletedAt,
    required int updatedAt,
  }) {
    return (update(transactionEntryTable)..where((t) => t.id.equals(id)))
        .write(
      TransactionEntryTableCompanion(
        deletedAt: Value(deletedAt),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  /// **垃圾桶专用**（Phase 12 Step 12.1）。所有已软删的流水（全账本），
  /// 按 `deleted_at` 倒序——最近删的靠前。
  Future<List<TransactionEntryRow>> listDeleted() {
    return (select(transactionEntryTable)
          ..where((t) => t.deletedAt.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]))
        .get();
  }

  /// **垃圾桶定时清理专用**（Phase 12 Step 12.3）。所有 `deleted_at <= cutoff`
  /// 的软删行——比 [listDeleted] 多了"超期"过滤，供 GC 任务批量识别。
  Future<List<TransactionEntryRow>> listExpired(int cutoffMs) {
    return (select(transactionEntryTable)
          ..where((t) => t.deletedAt.isNotNull() & t.deletedAt.isSmallerOrEqualValue(cutoffMs)))
        .get();
  }

  /// 某账本下未软删流水的条数，供账本列表展示"流水总数"。
  Future<int> countActiveByLedger(String ledgerId) async {
    final query = selectOnly(transactionEntryTable)
      ..addColumns([transactionEntryTable.id.count()])
      ..where(
        transactionEntryTable.ledgerId.equals(ledgerId) &
            transactionEntryTable.deletedAt.isNull(),
      );
    final row = await query.getSingle();
    return row.read(transactionEntryTable.id.count()) ?? 0;
  }

  /// 批量软删除某账本下所有未软删流水（用于账本级联删除）。
  /// 返回受影响行数。
  Future<int> softDeleteByLedgerId(
    String ledgerId, {
    required int deletedAt,
    required int updatedAt,
  }) {
    return (update(transactionEntryTable)
          ..where(
            (t) => t.ledgerId.equals(ledgerId) & t.deletedAt.isNull(),
          ))
        .write(
      TransactionEntryTableCompanion(
        deletedAt: Value(deletedAt),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  /// **仅供垃圾桶定时任务调用**（Phase 12 Step 12.3）。物理移除该行；
  /// 业务路径必须走 [softDeleteById]。Step 3.5 的本地附件文件由垃圾桶清理
  /// 任务在调用本方法前一步负责删除。
  Future<int> hardDeleteById(String id) {
    return (delete(transactionEntryTable)..where((t) => t.id.equals(id))).go();
  }

  /// **垃圾桶恢复专用**（Phase 12 Step 12.2）。把软删行清回活跃态——
  /// 写 `deleted_at = null` 并刷新 `updated_at`。返回受影响行数（正常 1 / 不存在 0）。
  Future<int> restoreById(String id, {required int updatedAt}) {
    return (update(transactionEntryTable)..where((t) => t.id.equals(id)))
        .write(
      TransactionEntryTableCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(updatedAt),
      ),
    );
  }
}
