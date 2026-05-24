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

  /// Step 16.1：每日记账提醒开关。0/null = 关闭（默认），1 = 开启。
  IntColumn get reminderEnabled => integer()
      .named('reminder_enabled')
      .nullable()
      .withDefault(const Constant(0))();

  /// Step 16.1：每日记账提醒时间，格式 'HH:mm'（如 '20:00'）。
  /// null = 从未设置（默认）；开启提醒时 UI 应要求用户先选时间。
  TextColumn get reminderTime =>
      text().nullable().named('reminder_time')();

  /// Step 17（云同步 V2）：增量同步的逐表 pull 游标。
  ///
  /// 值为 JSON 字符串，shape: `{"ledger": 1700000000000, "category": ...}`
  /// 其中 value 是 epoch ms。下次 pull 时 `where updated_at > cursor`，
  /// 命中行 merge 后把 cursor 推进到本批最大 `updated_at`。
  ///
  /// 用 JSON 而非每表一列：5 张表未来还可能扩，避免每次新表都加列 + 迁移；
  /// drift 不直接支持 JSON 列类型，存 TEXT，业务层 jsonDecode / jsonEncode。
  ///
  /// null = 从未 pull 过（首次 pull 即全量）。
  TextColumn get lastPulledAtJson =>
      text().nullable().named('last_pulled_at_json')();

  /// 账户排序：用户手动拖动排列后的账户 ID 顺序，JSON 数组字符串如
  /// `'["id1","id2","id3"]'`。null = 按余额倒序（默认）。
  /// 排在数组里但实际已删的 ID 会在 provider 层被过滤掉；数组里没有的新账户
  /// 追加到末尾。
  TextColumn get accountOrder =>
      text().nullable().named('account_order')();

  @override
  Set<Column> get primaryKey => {id};
}
