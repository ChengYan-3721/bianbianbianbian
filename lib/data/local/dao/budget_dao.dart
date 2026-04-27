import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/budget_table.dart';

part 'budget_dao.g.dart';

/// `budget` 表 DAO——仅暴露 Step 1.4 约定的 4 类方法。
///
/// 所有日常查询自动过滤 `deleted_at IS NULL`；物理删除走 [hardDeleteById]，
/// 该接口仅限垃圾桶定时任务（Phase 12 Step 12.3）调用。
@DriftAccessor(tables: [BudgetTable])
class BudgetDao extends DatabaseAccessor<AppDatabase> with _$BudgetDaoMixin {
  BudgetDao(super.db);

  /// 某账本下所有未软删预算（总预算 + 各分类预算混合）。返回顺序不保证——
  /// UI 侧按 `category_id IS NULL` 优先 + 周期聚合自行排序。
  Future<List<BudgetEntry>> listActiveByLedger(String ledgerId) {
    return (select(budgetTable)
          ..where((t) => t.ledgerId.equals(ledgerId) & t.deletedAt.isNull()))
        .get();
  }

  /// Upsert by primary key。调用方负责设置 `updated_at` / `device_id`。
  Future<void> upsert(BudgetTableCompanion entry) {
    return into(budgetTable).insertOnConflictUpdate(entry);
  }

  /// 软删除：写入 `deleted_at` 并刷新 `updated_at`。
  Future<int> softDeleteById(
    String id, {
    required int deletedAt,
    required int updatedAt,
  }) {
    return (update(budgetTable)..where((t) => t.id.equals(id))).write(
      BudgetTableCompanion(
        deletedAt: Value(deletedAt),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  /// 批量软删除某账本下所有未软删预算（用于账本级联删除）。
  /// 返回受影响行数。
  Future<int> softDeleteByLedgerId(
    String ledgerId, {
    required int deletedAt,
    required int updatedAt,
  }) {
    return (update(budgetTable)
          ..where(
            (t) => t.ledgerId.equals(ledgerId) & t.deletedAt.isNull(),
          ))
        .write(
      BudgetTableCompanion(
        deletedAt: Value(deletedAt),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  /// **仅供垃圾桶定时任务调用**（Phase 12 Step 12.3）。物理移除该行；
  /// 业务路径必须走 [softDeleteById]。
  Future<int> hardDeleteById(String id) {
    return (delete(budgetTable)..where((t) => t.id.equals(id))).go();
  }
}
