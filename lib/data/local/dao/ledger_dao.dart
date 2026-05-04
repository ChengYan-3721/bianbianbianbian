import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/ledger_table.dart';

part 'ledger_dao.g.dart';

/// `ledger` 表 DAO——仅暴露 Step 1.4 约定的 4 类方法。
///
/// 所有日常查询自动过滤 `deleted_at IS NULL`；物理删除走 [hardDeleteById]，
/// 该接口仅限垃圾桶定时任务（Phase 12 Step 12.3）调用。
///
/// Ledger 表不挂在任何父实体下——"按 ledgerId 查询未删除"在这里退化为
/// "列出全部未删除账本"，对应 [listActive]。
@DriftAccessor(tables: [LedgerTable])
class LedgerDao extends DatabaseAccessor<AppDatabase> with _$LedgerDaoMixin {
  LedgerDao(super.db);

  /// 所有未软删的账本，按 `updated_at` 倒序（最近变动的最靠前）。
  Future<List<LedgerEntry>> listActive() {
    return (select(ledgerTable)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  /// **垃圾桶专用**（Phase 12 Step 12.1）。所有已软删的账本，按 `deleted_at`
  /// 倒序——最近删的靠前。
  Future<List<LedgerEntry>> listDeleted() {
    return (select(ledgerTable)
          ..where((t) => t.deletedAt.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]))
        .get();
  }

  /// **垃圾桶定时清理专用**（Phase 12 Step 12.3）。`deleted_at <= cutoff` 的全部软删行。
  Future<List<LedgerEntry>> listExpired(int cutoffMs) {
    return (select(ledgerTable)
          ..where((t) => t.deletedAt.isNotNull() & t.deletedAt.isSmallerOrEqualValue(cutoffMs)))
        .get();
  }

  /// Upsert by primary key。调用方负责设置 `updated_at` / `device_id`
  /// （仓库层 Step 2.2 会统一封装这两个字段的自动填充）。
  Future<void> upsert(LedgerTableCompanion entry) {
    return into(ledgerTable).insertOnConflictUpdate(entry);
  }

  /// 软删除：写入 `deleted_at` 并刷新 `updated_at`——[listActive] 立即过滤掉此行。
  /// 物理行仍保留，等待垃圾桶倒计时到期后由 [hardDeleteById] 清除。
  Future<int> softDeleteById(
    String id, {
    required int deletedAt,
    required int updatedAt,
  }) {
    return (update(ledgerTable)..where((t) => t.id.equals(id))).write(
      LedgerTableCompanion(
        deletedAt: Value(deletedAt),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  /// **仅供垃圾桶定时任务调用**（Phase 12 Step 12.3）。物理移除该行；
  /// 业务路径必须走 [softDeleteById]，否则记录会绕过 30 天恢复窗口。
  Future<int> hardDeleteById(String id) {
    return (delete(ledgerTable)..where((t) => t.id.equals(id))).go();
  }

  /// **垃圾桶恢复专用**（Phase 12 Step 12.2）。注意账本恢复仅复活账本本身——
  /// 该账本下流水/预算的级联恢复由仓库层调用方按需触发。
  Future<int> restoreById(String id, {required int updatedAt}) {
    return (update(ledgerTable)..where((t) => t.id.equals(id))).write(
      LedgerTableCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(updatedAt),
      ),
    );
  }
}
