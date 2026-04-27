import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/account_table.dart';

part 'account_dao.g.dart';

/// `account` 表 DAO——仅暴露 Step 1.4 约定的 4 类方法。
///
/// 所有日常查询自动过滤 `deleted_at IS NULL`；物理删除走 [hardDeleteById]，
/// 该接口仅限垃圾桶定时任务（Phase 12 Step 12.3）调用。
///
/// Account 是全局资源不绑定账本——"按 ledgerId 查询未删除"在这里退化为
/// "列出全部未删除账户"，对应 [listActive]。
@DriftAccessor(tables: [AccountTable])
class AccountDao extends DatabaseAccessor<AppDatabase> with _$AccountDaoMixin {
  AccountDao(super.db);

  /// 所有未软删的账户，按 `updated_at` 倒序。
  Future<List<AccountEntry>> listActive() {
    return (select(accountTable)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  /// Upsert by primary key。调用方负责设置 `updated_at` / `device_id`。
  Future<void> upsert(AccountTableCompanion entry) {
    return into(accountTable).insertOnConflictUpdate(entry);
  }

  /// 软删除：写入 `deleted_at` 并刷新 `updated_at`。
  Future<int> softDeleteById(
    String id, {
    required int deletedAt,
    required int updatedAt,
  }) {
    return (update(accountTable)..where((t) => t.id.equals(id))).write(
      AccountTableCompanion(
        deletedAt: Value(deletedAt),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  /// **仅供垃圾桶定时任务调用**（Phase 12 Step 12.3）。物理移除该行；
  /// 业务路径必须走 [softDeleteById]。
  Future<int> hardDeleteById(String id) {
    return (delete(accountTable)..where((t) => t.id.equals(id))).go();
  }
}
