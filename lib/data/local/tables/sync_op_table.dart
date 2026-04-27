import 'package:drift/drift.dart';

/// 对应 design-document §7.1 的 `sync_op` 表——同步队列（本机出站变更）。
///
/// 每次仓库层写入实体都会 enqueue 一条记录：`entity` 指明目标表（`ledger` /
/// `category` / `account` / `transaction` / `budget`），`op` 取值 `upsert` |
/// `delete`，`payload` 是该实体的 JSON 快照。同步引擎 push 成功后删掉对应行。
///
/// 队列表本身**不是实体表**——没有 `updated_at` / `deleted_at` / `device_id`
/// 三件套，因为它只是本机待办，不需要与云端双向同步。
///
/// `id INTEGER PRIMARY KEY AUTOINCREMENT`——drift 里用 `.autoIncrement()`
/// 一次性声明自增 + 主键，不需要另外覆写 [primaryKey]。
@DataClassName('SyncOpEntry')
class SyncOpTable extends Table {
  @override
  String get tableName => 'sync_op';

  IntColumn get id => integer().autoIncrement()();

  TextColumn get entity => text()();

  TextColumn get entityId => text().named('entity_id')();

  TextColumn get op => text()();

  TextColumn get payload => text()();

  IntColumn get enqueuedAt => integer().named('enqueued_at')();

  IntColumn get tried =>
      integer().nullable().withDefault(const Constant(0))();

  TextColumn get lastError => text().nullable().named('last_error')();
}
