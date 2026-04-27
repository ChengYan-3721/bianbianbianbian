import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/category_table.dart';

part 'category_dao.g.dart';

/// `category` 表 DAO（重构版：全局二级分类 + 收藏）。
///
/// 所有日常查询自动过滤 `deleted_at IS NULL`；物理删除走 [hardDeleteById]，
/// 该接口仅限垃圾桶定时任务（Phase 12 Step 12.3）调用。
@DriftAccessor(tables: [CategoryTable])
class CategoryDao extends DatabaseAccessor<AppDatabase>
    with _$CategoryDaoMixin {
  CategoryDao(super.db);

  /// 某一级分类下所有未软删二级分类，按 `sort_order` 升序。
  Future<List<CategoryEntry>> listActiveByParentKey(String parentKey) {
    return (select(categoryTable)
          ..where(
            (t) => t.parentKey.equals(parentKey) & t.deletedAt.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  /// 全部未软删分类（用于管理页等场景）。
  Future<List<CategoryEntry>> listActiveAll() {
    return (select(categoryTable)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.asc(t.parentKey),
            (t) => OrderingTerm.asc(t.sortOrder),
          ]))
        .get();
  }

  /// 收藏分类（全局），按 `sort_order` 升序。
  Future<List<CategoryEntry>> listFavorites() {
    return (select(categoryTable)
          ..where((t) => t.isFavorite.equals(1) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  /// Upsert by primary key。调用方负责设置 `updated_at` / `device_id`。
  Future<void> upsert(CategoryTableCompanion entry) {
    return into(categoryTable).insertOnConflictUpdate(entry);
  }

  /// 更新收藏状态并刷新 `updated_at`。
  Future<int> updateFavoriteById(
    String id, {
    required bool isFavorite,
    required int updatedAt,
  }) {
    return (update(categoryTable)..where((t) => t.id.equals(id))).write(
      CategoryTableCompanion(
        isFavorite: Value(isFavorite ? 1 : 0),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  /// 软删除：写入 `deleted_at` 并刷新 `updated_at`。
  Future<int> softDeleteById(
    String id, {
    required int deletedAt,
    required int updatedAt,
  }) {
    return (update(categoryTable)..where((t) => t.id.equals(id))).write(
      CategoryTableCompanion(
        deletedAt: Value(deletedAt),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  /// 批量软删除某账本下所有分类（用于账本级联删除）。
  Future<int> softDeleteByLedgerId(
    String ledgerId, {
    required int deletedAt,
    required int updatedAt,
  }) async {
    // category 表已无 ledger_id 列，此方法不再需要。保留空实现或移除。
    // 因为分类已全局化，不再按账本隔离，所以不需要此方法。
    return 0;
  }

  /// **仅供垃圾桶定时任务调用**（Phase 12 Step 12.3）。物理移除该行；
  /// 业务路径必须走 [softDeleteById]。
  Future<int> hardDeleteById(String id) {
    return (delete(categoryTable)..where((t) => t.id.equals(id))).go();
  }
}
