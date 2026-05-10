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

  /// Step 8.1：多币种全局开关。0 = 关闭（默认；记账页币种字段隐藏），
  /// 1 = 开启（记账页可选币种、统计页按账本默认币种换算展示）。
  IntColumn get multiCurrencyEnabled => integer()
      .named('multi_currency_enabled')
      .nullable()
      .withDefault(const Constant(0))();

  IntColumn get lastSyncAt =>
      integer().nullable().named('last_sync_at')();

  /// Step 8.3：上次汇率自动刷新时间（epoch ms）。null = 从未刷新。
  /// 用于"每日最多一次"节流，[FxRateRefreshService.refreshIfDue] 据此判断。
  IntColumn get lastFxRefreshAt =>
      integer().nullable().named('last_fx_refresh_at')();

  /// 历史遗留列（自 Step 4.2 user_pref 表初次落库即存在，但直到 Step 9.3
  /// 才被消费）：用户在"我的 → 快速输入 → AI 增强"页配置的 LLM endpoint URL。
  TextColumn get aiApiEndpoint =>
      text().nullable().named('ai_api_endpoint')();

  /// 历史遗留列（同上）：API key 的存放位置。
  ///
  /// **当前实现（Step 9.3）**：UTF-8 编码后的 raw bytes（即"未加密"），整个 DB 由
  /// SQLCipher 加密保护，故 at-rest 安全已由 DB 级别覆盖；列名带 `_encrypted`
  /// 是为 Phase 11 [BianbianCrypto] 字段级加密预留的——届时会用同步密码派生
  /// 出的 key 重写读写路径，本列名保持不变。
  BlobColumn get aiApiKeyEncrypted =>
      blob().nullable().named('ai_api_key_encrypted')();

  /// Step 9.3：AI 增强使用的模型名（如 `'gpt-4o-mini'` / `'qwen-turbo'`）。
  /// 用户在配置页填写；为空时 [AiInputSettings.hasMinimalConfig] = false。
  TextColumn get aiApiModel =>
      text().nullable().named('ai_api_model')();

  /// Step 9.3：AI 增强使用的 prompt 模板（含 `{NOW}` / `{TEXT}` / `{CATEGORIES}`
  /// 占位符）。为空时使用 [kDefaultAiInputPromptTemplate] 兜底。
  TextColumn get aiApiPromptTemplate =>
      text().nullable().named('ai_api_prompt_template')();

  /// Step 9.3：AI 增强全局开关。0/null = 关闭（默认；确认卡片不显示 AI 增强按钮），
  /// 1 = 开启（且只有 endpoint + key + model 三件齐全才会真正显示按钮）。
  IntColumn get aiInputEnabled => integer()
      .named('ai_input_enabled')
      .nullable()
      .withDefault(const Constant(0))();

  /// Step 15.2：字号档位。'small' / 'standard'(默认) / 'large'。
  TextColumn get fontSize =>
      text().nullable().named('font_size').withDefault(const Constant('standard'))();

  /// Step 15.3：分类图标包。'sticker'(默认/手绘贴纸) / 'flat'(扁平简约)。
  TextColumn get iconPack =>
      text().nullable().named('icon_pack').withDefault(const Constant('sticker'))();

  @override
  Set<Column> get primaryKey => {id};
}
