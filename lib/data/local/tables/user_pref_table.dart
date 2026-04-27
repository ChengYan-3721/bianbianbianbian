import 'package:drift/drift.dart';

/// 对应 design-document §7.1 的 `user_pref` 表——应用级偏好单行表。
///
/// 通过 `CHECK (id = 1)` 约束保证永远只有一行；Dart 代码需始终以 id=1 读/写。
/// `device_id` 在 Step 1.5 由 app 启动初始化生成并写入本表 + `flutter_secure_storage`。
@DataClassName('UserPrefEntry')
class UserPrefTable extends Table {
  @override
  String get tableName => 'user_pref';

  // CHECK 用 CustomExpression 写死 SQL 片段，避免 `id.equals(...)` 触发
  // Dart 分析器的 recursive_getters 警告（drift 常见权衡）。
  IntColumn get id => integer()
      .withDefault(const Constant(1))
      .check(const CustomExpression<bool>('id = 1'))();

  TextColumn get deviceId => text().named('device_id')();

  TextColumn get currentLedgerId =>
      text().nullable().named('current_ledger_id')();

  TextColumn get defaultCurrency => text()
      .named('default_currency')
      .nullable()
      .withDefault(const Constant('CNY'))();

  TextColumn get theme =>
      text().nullable().withDefault(const Constant('cream_bunny'))();

  IntColumn get lockEnabled => integer()
      .named('lock_enabled')
      .nullable()
      .withDefault(const Constant(0))();

  IntColumn get syncEnabled => integer()
      .named('sync_enabled')
      .nullable()
      .withDefault(const Constant(0))();

  IntColumn get lastSyncAt =>
      integer().nullable().named('last_sync_at')();

  TextColumn get aiApiEndpoint =>
      text().nullable().named('ai_api_endpoint')();

  BlobColumn get aiApiKeyEncrypted =>
      blob().nullable().named('ai_api_key_encrypted')();

  @override
  Set<Column> get primaryKey => {id};
}
