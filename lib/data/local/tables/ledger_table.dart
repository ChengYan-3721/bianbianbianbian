import 'package:drift/drift.dart';

/// 对应 design-document §7.1 的 `ledger` 表——账本。
///
/// 同步三件套：`updated_at` / `deleted_at` / `device_id`——所有实体表共用。
/// 软删除：`deleted_at IS NULL` 视为存活；硬删仅由垃圾桶定时任务执行（Phase 12）。
@DataClassName('LedgerEntry')
class LedgerTable extends Table {
  @override
  String get tableName => 'ledger';

  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get coverEmoji => text().nullable().named('cover_emoji')();

  TextColumn get defaultCurrency => text()
      .named('default_currency')
      .nullable()
      .withDefault(const Constant('CNY'))();

  IntColumn get archived =>
      integer().nullable().withDefault(const Constant(0))();

  IntColumn get createdAt => integer().named('created_at')();

  IntColumn get updatedAt => integer().named('updated_at')();

  IntColumn get deletedAt => integer().nullable().named('deleted_at')();

  TextColumn get deviceId => text().named('device_id')();

  @override
  Set<Column> get primaryKey => {id};
}
