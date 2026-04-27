import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/sync_op_table.dart';

part 'sync_op_dao.g.dart';

/// `sync_op` 队列表 DAO——仓库层（Step 2.2）写入、同步引擎（Phase 10 Step 10.4）消费。
///
/// Step 1.4 把这张表刻意排除在 5 个业务表 DAO 之外——它不是实体表、不走"4 类方法"
/// 模式。Step 2.2 仓库层需要 `enqueue` API 写待同步记录，因此补这个 DAO。
///
/// `[op]` 取 `'upsert'` | `'delete'`；`[entity]` 取 `'ledger'` | `'category'` |
/// `'account'` | `'transaction'` | `'budget'`（**注意**最后一个是 `'transaction'` 而
/// 非 `'transaction_entry'`——与 design-document §7.1 DDL 注释字面一致）。
/// `[payload]` 为 `jsonEncode(entity.toJson())` 产出的 JSON 字符串。
@DriftAccessor(tables: [SyncOpTable])
class SyncOpDao extends DatabaseAccessor<AppDatabase> with _$SyncOpDaoMixin {
  SyncOpDao(super.db);

  /// 入队一条待同步记录。返回 AUTOINCREMENT 产出的 `id`。
  Future<int> enqueue({
    required String entity,
    required String entityId,
    required String op,
    required String payload,
    required int enqueuedAt,
  }) {
    return into(syncOpTable).insert(
      SyncOpTableCompanion.insert(
        entity: entity,
        entityId: entityId,
        op: op,
        payload: payload,
        enqueuedAt: enqueuedAt,
      ),
    );
  }

  /// 按入队顺序列出所有待同步记录。Phase 10 同步引擎拉取；Step 2.2 测试用于断言队列快照。
  Future<List<SyncOpEntry>> listAll() {
    return (select(syncOpTable)..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
  }
}
