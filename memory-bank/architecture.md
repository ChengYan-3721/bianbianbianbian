# 架构说明

本文件记录项目**当前**运行期结构：哪些文件/目录存在、各自承担什么职责、模块间如何依赖。每当新增或重构关键文件/目录时同步更新。

- 设计意图（为什么这么做）看 `design-document.md`；
- 阶段路线与验收标准看 `implementation-plan.md`；
- 已完成步骤的时间线看 `progress.md`。

---

## 当前文件一览（Phase 8 · Step 8.3 汇率自动刷新与手动覆盖后）

```
bianbianbianbian/
├─ lib/
│  ├─ main.dart                 应用入口：Riverpod bootstrap（预热 defaultSeedProvider）+ 错误兜底
│  ├─ app/
│  │  ├─ app.dart               BianBianApp 根组件（MaterialApp.router）
│  │  ├─ app_router.dart        顶层 goRouter（/ → HomeShell, /record/new → RecordNewPage, …, /settings/multi-currency → MultiCurrencyPage）
│  │  ├─ app_theme.dart         appTheme + BianBianSemanticColors ThemeExtension
│  │  └─ home_shell.dart        底部 4 Tab 壳页（Step 8.1：我的 Tab 加"多币种"入口）
│  ├─ core/
│  │  ├─ crypto/
│  │  │  └─ bianbian_crypto.dart  BianbianCrypto（PBKDF2 + AES-256-GCM）+ DecryptionFailure
│  │  ├─ network/               [空] Supabase 客户端工厂（双模）
│  │  └─ util/
│  │     └─ currencies.dart     Currency 数据类 + kBuiltInCurrencies (11 种) + kFxRateSnapshot 写死快照（Step 8.1）
│  ├─ data/
│  │  ├─ local/
│  │  │  ├─ app_database.dart         drift AppDatabase（schemaVersion=6；含 v3 重建 category / v4 budget 结转 / v5 信用卡日 / v6 多币种 + fx_rate）
│  │  │  ├─ app_database.g.dart       build_runner 产物
│  │  │  ├─ db_cipher_key_store.dart  本地 DB 加密密钥的生成/持久化
│  │  │  ├─ device_id_store.dart      device_id 加载器（secure ↔ user_pref 双向同步）
│  │  │  ├─ seeder.dart               DefaultSeeder（首次启动默认数据种子化 + Step 8.1 fx_rate 独立判空）
│  │  │  ├─ providers.dart            @Riverpod appDatabase / deviceId / defaultSeed 三个 provider
│  │  │  ├─ providers.g.dart          riverpod_generator 产物
│  │  │  ├─ dao/
│  │  │  │  ├─ ledger_dao.dart              LedgerDao + .g.dart（Step 1.4）
│  │  │  │  ├─ category_dao.dart            CategoryDao + .g.dart（Step 1.4）
│  │  │  │  ├─ account_dao.dart             AccountDao + .g.dart（Step 1.4）
│  │  │  │  ├─ transaction_entry_dao.dart   TransactionEntryDao + .g.dart（Step 1.4）
│  │  │  │  ├─ budget_dao.dart              BudgetDao + .g.dart（Step 1.4）
│  │  │  │  ├─ sync_op_dao.dart             SyncOpDao + .g.dart（Step 2.2，供仓库层写队列）
│  │  │  │  └─ fx_rate_dao.dart             FxRateDao + .g.dart（Step 8.1，工具表 listAll/getByCode/upsert）
│  │  │  └─ tables/
│  │  │     ├─ user_pref_table.dart         §7.1 user_pref 表（Step 8.1 追加 multi_currency_enabled）
│  │  │     ├─ ledger_table.dart            §7.1 ledger 表
│  │  │     ├─ category_table.dart          重构版 category 表（parent_key/is_favorite，全局二级分类）
│  │  │     ├─ account_table.dart           §7.1 account 表（Step 7.3 追加 billing_day / repayment_day）
│  │  │     ├─ transaction_entry_table.dart §7.1 transaction_entry 表（FK→ledger）
│  │  │     ├─ budget_table.dart            §7.1 budget 表
│  │  │     ├─ sync_op_table.dart           §7.1 sync_op 队列表（AUTOINCREMENT id）
│  │  │     └─ fx_rate_table.dart           Step 8.1 工具表（code PK / rate_to_cny REAL / updated_at INTEGER）
│  │  ├─ remote/                [空] Supabase DataSource
│  │  └─ repository/             Step 2.2 已填充：entity_mappers + repo_clock + 5 个仓库
│  │     ├─ repo_clock.dart             RepoClock typedef（仓库层时间注入点）
│  │     ├─ entity_mappers.dart         drift row ↔ domain entity 映射桥接层
│  │     ├─ ledger_repository.dart      LedgerRepository 接口 + LocalLedgerRepository
│  │     ├─ category_repository.dart    CategoryRepository 接口 + LocalCategoryRepository
│  │     ├─ account_repository.dart     AccountRepository 接口 + LocalAccountRepository
│  │     ├─ transaction_repository.dart TransactionRepository 接口 + LocalTransactionRepository
│  │     ├─ budget_repository.dart      BudgetRepository 接口 + LocalBudgetRepository
│  │     ├─ providers.dart              7 个 @Riverpod provider；Step 2.3
│  │     └─ providers.g.dart            riverpod_generator 产物
│  ├─ domain/
│  │  ├─ entity/
│  │  │  ├─ ledger.dart                纯 Dart 不可变实体（Step 2.1）
│  │  │  ├─ category.dart              同上
│  │  │  ├─ account.dart               同上
│  │  │  ├─ transaction_entry.dart     同上（含 _bytesEqual/_bytesHash 深比较）
│  │  │  └─ budget.dart                同上
│  │  └─ usecase/               [空] 跨仓库业务用例
│  └─ features/
│     ├─ record/                Step 3.2 已重构：新建记账页采用一级/二级分类 + 收藏 + 自动收支判定
│     │  ├─ record_home_page.dart       RecordHomePage + 子组件（顶栏/月份/卡片/快捷输入/流水列表/FAB）
│     │  ├─ record_new_page.dart        RecordNewPage + 子组件（一级Tab/收藏/金额/分类/账户/时间/备注/附件/保存）
│     │  ├─ record_providers.dart       RecordMonth Notifier + recordMonthSummary FutureProvider
│     │  ├─ record_providers.g.dart     riverpod_generator 产物
│     │  ├─ record_new_providers.dart   RecordFormData + _parseExpr + RecordForm Notifier（自动判定 income/expense + 本地附件管理）
│     │  ├─ record_new_providers.g.dart riverpod_generator 产物
│     │  └─ widgets/
│     │     └─ number_keyboard.dart     NumberKeyboard（4行自定义键盘：7/8/9/⌫，4/5/6/+，1/2/3/-，CNY/0/./✓或=）
│     ├─ stats/                 Step 5.6 已填充：统计区间选择器 + 折线图 + 分类饼图 + 收支排行榜 + 日历热力图 + 导出 PNG/CSV
│     │  ├─ stats_page.dart            StatsPage（区间选择 + 4 类图表 + 顶栏导出按钮 + RepaintBoundary 包裹图表区）
│     │  ├─ stats_range_providers.dart StatsRangePreset/StatsDateRange/StatsRangeState + 4 类统计聚合 provider
│     │  ├─ stats_range_providers.g.dart riverpod_generator 产物
│     │  └─ stats_export_service.dart  encodeStatsCsv（@visibleForTesting）+ buildExportFileName + StatsExportService（PNG/CSV/Share）
│     ├─ ledger/                Step 4.1 已填充：正式账本列表页
│     │  ├─ ledger_list_page.dart       LedgerListPage（账本卡片列表 + 切换 + 归档折叠区）
│     │  ├─ ledger_list_page.g.dart     riverpod_generator 产物
│     │  ├─ ledger_providers.dart       LedgerTxCounts AsyncNotifier（各账本流水条数）
│     │  └─ ledger_providers.g.dart     riverpod_generator 产物
│     ├─ budget/                Step 6.1 列表/编辑；Step 6.2 进度计算 + 颜色 + 震动
│     │  ├─ budget_progress.dart        BudgetProgress / Level + computeBudgetProgress / computePeriodSpent / budgetPeriodRange / shouldTriggerBudgetVibration
│     │  ├─ budget_providers.dart       activeBudgets / budgetableCategories + kParentKeyLabels + budgetClock + budgetProgressFor + BudgetVibrationSession
│     │  ├─ budget_providers.g.dart     riverpod_generator 产物
│     │  ├─ budget_list_page.dart       BudgetListPage（卡片列表 + 进度条/颜色/震动 + 新建 FAB + 删除二次确认）
│     │  └─ budget_edit_page.dart       BudgetEditPage（周期/分类/金额/结转，冲突 Snackbar）
│     ├─ account/               Step 7.1 列表；Step 7.2 CRUD（新建/编辑/软删）
│     │  ├─ account_balance.dart        AccountBalance + aggregateNetAmountsByAccount / computeAccountBalances / computeTotalAssets 纯函数
│     │  ├─ account_providers.dart      accountsList / accountBalances / totalAssets 三个 @riverpod FutureProvider
│     │  ├─ account_providers.g.dart    riverpod_generator 产物
│     │  ├─ account_list_page.dart      AccountListPage（总资产卡片 + 账户卡片列表 + 信用卡负余额红色 + FAB 新建 + 长按编辑/删除菜单）
│     │  └─ account_edit_page.dart      AccountEditPage（名称/类型/图标/初始余额/币种/计入总资产，新建+编辑双模式）
│     ├─ sync/                  [空] 同步 UI + 状态
│     ├─ trash/                 [空] 垃圾桶
│     ├─ lock/                  [空] 应用锁
│     ├─ import_export/         [空] 导入导出
│     └─ settings/              Step 8.1：多币种开关；Step 8.2：账本默认币种 + 汇率快照 provider
│        ├─ settings_providers.dart      MultiCurrencyEnabled + currentLedgerDefaultCurrency + fxRates + computeFxRate
│        ├─ settings_providers.g.dart    riverpod_generator 产物
│        └─ multi_currency_page.dart     MultiCurrencyPage（开关 SwitchListTile + 内置币种概览 + 汇率管理占位）
├─ android/app/build.gradle.kts Android 构建脚本（core library desugaring + minSdk 23）
├─ test/
│  ├─ core/
│  │  └─ crypto/
│  │     └─ bianbian_crypto_test.dart     PBKDF2 + AES-GCM KAT + 往返 + 篡改检测（11 用例，Step 1.6）
│  ├─ data/
│  │  └─ local/
│  │     ├─ app_database_test.dart           user_pref schema/CHECK 约束（2 用例）
│  │     ├─ business_tables_test.dart        6 张业务表 CRUD + soft-delete + 索引断言（7 用例）
│  │     ├─ dao_test.dart                    5 个 DAO × 4 类方法（5 用例，Step 1.4）
│  │     ├─ device_id_store_test.dart        device_id 加载器的 4 条分支（5 用例，Step 1.5）
│  │     ├─ seeder_test.dart                 默认数据种子化的 3 条路径（3 用例，Step 1.7）
│  │     ├─ db_cipher_key_store_test.dart    密钥生成/持久化（4 用例）
│  │     └─ fx_rate_test.dart                FxRateDao + seeder fx_rate 路径 + 内置币种常量（11 用例，Step 8.1）
│  ├─ data/
│  │  └─ repository/
│  │     ├─ transaction_repository_test.dart TransactionRepository 4 条用例（Step 2.2）
│  │     ├─ account_repository_test.dart     AccountRepository CRUD + getById 兜底（7 用例，Step 7.2）
│  │     └─ budget_repository_test.dart      BudgetRepository 唯一性 + 软删后重建（8 用例，Step 6.1）
│  ├─ domain/
│  │  └─ entity/
│  │     └─ entities_test.dart               5 个实体 roundtrip/copyWith + drift 隔离（17 用例，Step 2.1）
│  ├─ features/
│  │  ├─ record/
│  │  │  ├─ record_new_providers_test.dart   RecordForm Notifier 单元测试（含 Step 3.5 附件序列化、Step 8.2 setCurrency/fxRate 写入断言）
│  │  │  └─ record_new_page_test.dart        RecordNewPage widget 测试（含 Step 3.5 附件 UI、Step 8.2 币种下拉与 fxRate 保存）
│  │  │  └─ record_home_page_format_test.dart formatTxAmountForDetail 纯函数（6 用例，Step 8.2）
│  │  └─ stats/
│  │     ├─ stats_range_providers_test.dart  统计区间/饼图/排行/热力图聚合测试（Step 5.1~5.5）
│  │     └─ stats_export_service_test.dart   CSV 编码 + 文件名规则测试（Step 5.6）
│  ├─ features/budget/
│  │  ├─ budget_progress_test.dart           computeBudgetProgress 边界 + computePeriodSpent + shouldTriggerBudgetVibration（16 用例，Step 6.2）
│  │  └─ budget_vibration_session_test.dart  BudgetVibrationSession Notifier 幂等/独立标记/clear（5 用例，Step 6.2）
│  ├─ features/account/
│  │  └─ account_balance_test.dart           aggregateNetAmountsByAccount + computeAccountBalances + computeTotalAssets 纯函数边界（16 用例，Step 7.1）
│  ├─ features/settings/
│  │  └─ multi_currency_page_test.dart       MultiCurrencyPage 开关行为 + 内置币种行 + 汇率管理 disabled（5 用例，Step 8.1）
│  │  └─ fx_rate_compute_test.dart           computeFxRate 同币种/跨币种/兜底（8 用例，Step 8.2）
│  └─ widget_test.dart          Widget 测试（HomeShell + 首页流水列表 + 已删账户回退 6 用例）
├─ memory-bank/
│  ├─ design-document.md        产品设计（权威来源）
│  ├─ implementation-plan.md    分阶段实施计划
│  ├─ progress.md               执行进度流水
│  └─ architecture.md           本文件
├─ pubspec.yaml                 依赖声明（Step 0.3 集合 − sqlite3_flutter_libs + sqlcipher_flutter_libs ^0.6.5）
└─ analysis_options.yaml        静态分析配置（flutter_lints + custom_lint 插件）
```

说明：`[空]` 表示目录仅含 `.gitkeep` 占位，等待后续 Phase 填充。

## 各文件/目录职责

### `lib/main.dart`
- 启动入口。Step 1.5 把 DB smoke test 从"裸 `AppDatabase()` + `SELECT 1`"改造为"Riverpod bootstrap"；Step 1.7 把预热目标升级为 `defaultSeedProvider`（下游链依次触发 device_id → DB → 种子数据）：
  1. `WidgetsFlutterBinding.ensureInitialized()`——因 `AppDatabase()` / `flutter_secure_storage` 都依赖 platform channel，必须先初始化 binding；
  2. `final container = ProviderContainer()`——独立于 Widget 树创建的 Riverpod 容器；
  3. `await container.read(defaultSeedProvider.future)`——一次性触发连锁：`defaultSeedProvider` → `deviceIdProvider` → `appDatabaseProvider` → `AppDatabase()` 构造 → `LazyDatabase` 打开 `bbb.db` → `PRAGMA key` 注入 → `PRAGMA cipher_version` 断言 → `LocalDeviceIdStore.loadOrCreate()` → `DefaultSeeder.seedIfEmpty()`。任何一环抛错都冒泡到 catch，兜底页显示 stack trace；
  4. 成功 → `runApp(UncontrolledProviderScope(container: container, child: BianBianApp()))`——把 main 里已预热的 container 原样交给 Widget 树，避免 runApp 后 ProviderScope 又开一次 DB。失败 → `container.dispose()` 释放资源、`runApp(ProviderScope(_BootstrapErrorApp(...)))` 渲染红字错误页。
- Step 1.4 之前的 `import 'data/local/app_database.dart'` 已被移除，现在只 import `data/local/providers.dart`——意味着 main.dart **不再直接 new AppDatabase()**，一切走 provider。

### `lib/app/`
应用装配层。Step 0.4 已填充四个文件：

- **`app.dart`**：`BianBianApp`（StatelessWidget）。返回 `MaterialApp.router`，注入 `theme: appTheme`、`routerConfig: goRouter`、`title: '边边记账'`、`debugShowCheckedModeBanner: false`。未来 Step 15.1 主题切换时，此处改为 `ConsumerWidget` 并从 provider 读 theme。
- **`app_router.dart`**：顶层 `final GoRouter goRouter`。当前只有一条 `GoRoute('/')` → `HomeShell`；后续各 Phase 在此数组追加路由（`/record/new`、`/ledger`、`/settings/sync` …）。若 Phase 10 同步启动后需要监听登录态重定向，应改为 `@riverpod GoRouter goRouter(Ref ref)`。
- **`app_theme.dart`**：
  - 顶层 `final ThemeData appTheme`：Material 3 light 主题，基于 design-document §10.2 奶油兔色板构造**显式** `ColorScheme`（不使用 `fromSeed`，以确保奶油黄 `#FFE9B0` 保真）。`cardTheme`（圆角 16 / 阴影 `Color(0x148A5A3B)`）与 `bottomNavigationBarTheme`（背景奶油黄 / 选中可可棕）按 §10.5 落地。
  - `BianBianSemanticColors`：`ThemeExtension`，承载抹茶绿 / 蜜橘 / 苹果红三色（对应成功/警告/错误语义）。故意不塞进 `ColorScheme`，避免 Material 组件错把这些当作 `colorScheme.error` 使用。读取方式：`Theme.of(context).extension<BianBianSemanticColors>()!`。
- **`home_shell.dart`**：`HomeShell`（StatefulWidget）。`BottomNavigationBar` 4 Tab：记账 / 统计 / 账本 / 我的。使用**本地 index**（`setState`）管理当前 Tab。各 Tab body：
  - 记账（index=0）：`RecordHomePage`（Step 3.1 接入，ConsumerWidget，独立 Scaffold + FAB）。
  - 统计（index=1）：`StatsPage`（Step 5.1 接入，时间区间选择器 + 区间展示）。
  - 账本（index=2）：`LedgerListPage`（Step 4.1 接入，ConsumerWidget，正式卡片列表 + 点击切换）。
  - 我的（index=3）：`_MeTab`（Step 6.1 接入，文件内私有 StatelessWidget）。当前仅承载"预算"入口（`Icons.savings_outlined` → `context.push('/budget')`）；Phase 17 会扩展为完整设置页（同步 / 主题 / 导入导出 / 应用锁等）。
  - 若未来某 Tab 要求"深链 + 各自独立历史栈"，迁移到 `StatefulShellRoute.indexedStack`。

### `lib/core/`
横切关注点，三个子目录按职责拆分：
- **`crypto/`**（Step 1.6 已填充）：
  - **`bianbian_crypto.dart`**：`BianbianCrypto` 工具类（私有构造，只暴露 static 方法）+ `DecryptionFailure` 异常。三个公开 API：`deriveKey(password, salt, {iterations=100000})` 走 PBKDF2-HMAC-SHA256；`encrypt(plaintext, key)` 走 AES-256-GCM 并返回 `nonce(12) ‖ ciphertext(N) ‖ tag(16)` 连续打包的 `Uint8List`；`decrypt(packed, key)` 反向解包，任何失败（长度不足 / tag 校验失败 / 错误 key）统一抛 `DecryptionFailure`。nonce 由 `AesGcm.newNonce()` 生成（`Random.secure()` 内核）每次都独立，避免同一 key 下重用导致 GCM 泄密。`@visibleForTesting` 的 `encryptWithFixedNonce` 让 KAT 能对照固定 `(K, N, P) → (C, T)` 向量。key 长度严格校验 32 字节，nonce 严格 12 字节，非法输入抛 `ArgumentError`。
  - 消费者（均 Phase 11 起陆续接）：`transaction_entry.note_encrypted` / `attachments_encrypted` 字段级加密（Step 11.2）、附件上传前 `.enc` 临时文件（Step 11.3）、"同步码"对称外壳（Step 11.4）、`.bbbak` 备份包（Step 13.2）、`user_pref.ai_api_key_encrypted` 存取。**与 SQLCipher/`DbCipherKeyStore` 走两条完全独立路径**——本工具加密的是"将来要上云的字段"，SQLCipher 加密的是"本机 DB 文件"。
- **`network/`**：`SupabaseClient` 工厂，支持"官方托管 / 用户自建"双模切换。Step 10.2 填充。
- **`util/`**：无分类的纯函数工具；最先的使用者是 Step 9.1 的 `QuickTextParser`（中文快速记账文本解析）。

### `lib/data/`
数据访问层，按"数据源"分三个子目录：
- **`local/`**：drift 数据库定义与 DAO。Step 1.1（user_pref 表）、Step 1.2（SQLCipher + 密钥）、Step 1.3（其余 6 张业务表 + v1→v2 migration）已落地；Step 1.4（5 个 DAO 分层）已落地；并在 Phase 3 对 `category` 做了 v3 不兼容重构（全局二级分类）。
  - **`app_database.dart`**：`AppDatabase extends _$AppDatabase`，`@DriftDatabase(tables: [UserPrefTable, LedgerTable, CategoryTable, AccountTable, TransactionEntryTable, BudgetTable, SyncOpTable], daos: [LedgerDao, CategoryDao, AccountDao, TransactionEntryDao, BudgetDao])`。生产构造 `AppDatabase()` → `_openEncrypted()`：① 先在主 isolate 跑 `applyWorkaroundToOpenSqlCipherOnOldAndroidVersions()`；② 从 `DbCipherKeyStore().loadOrCreate()` 取 hex 密钥；③ `NativeDatabase.createInBackground(file, isolateSetup: ..., setup: ...)`——`isolateSetup` 在后台 isolate 再跑一次 Android workaround，`setup` 里执行 `PRAGMA key = "x'<hex>'"` 并用 `PRAGMA cipher_version` 断言 SQLCipher 真的加载（未加载即 `StateError`，防止"看似加密实则明文落盘"）。测试构造 `AppDatabase.forTesting(NativeDatabase.memory())` 不变。顶层 `export 'package:drift/drift.dart' show Value;`。DAO 作为 `late final xxxDao = XxxDao(this as AppDatabase)` 字段由 drift_dev 生成在 `app_database.g.dart`——调用方通过 `db.ledgerDao` / `db.categoryDao` / `db.accountDao` / `db.transactionEntryDao` / `db.budgetDao` 访问。
    - **`schemaVersion = 5`（Phase 7 Step 7.3）**：
      - v1：`user_pref`
      - v2：新增 `ledger/category/account/transaction_entry/budget/sync_op` + transaction 索引
      - v3：`category` 改为“全局二级分类”模型（`parent_key` + `is_favorite`，移除 `ledger_id` + `type`）
      - v4：`budget` 追加 `carry_balance` / `last_settled_at`（预算结转）
      - v5：`account` 追加 `billing_day` / `repayment_day`（信用卡专属，1-28，仅展示）
    - **`MigrationStrategy`**：
      - `onCreate`：`m.createAll()` + `_createTransactionIndexes()`
      - `onUpgrade`：`from < 2` 时创建 v2 业务表；`from < 3` 时按产品要求**不兼容旧分类结构**，执行 `deleteTable('category')` 后 `createTable(categoryTable)` 重建；`from < 4` 时给 `budget` `addColumn` 两列；`from < 5` 时给 `account` `addColumn` 两列。
  - **`db_cipher_key_store.dart`**：`DbCipherKeyStore` + `SecureKeyValueStore` 抽象接口 + `FlutterSecureKeyValueStore` 生产实现。`loadOrCreate()`：已有合法 hex（64 字符小写）→ 读回；否则用注入的 `Random`（默认 `Random.secure()`）生成 32 字节，hex 编码写入 `flutter_secure_storage` 条目 `local_db_cipher_key`。密钥以 hex 串保存、以 `PRAGMA key = "x'<hex>'"` 注入，跳过 SQLCipher 自带 PBKDF2。**该密钥仅保护本机 `bbb.db`，与 Phase 11 的用户同步密码派生密钥完全无关**。
  - **`device_id_store.dart`**（Step 1.5）：`LocalDeviceIdStore` + `UuidFactory` 类型别名。`loadOrCreate()` 按「`flutter_secure_storage` → `user_pref.device_id` → 新生成」优先级解析 device_id，并把最终值**同步写回另一侧**（"冗余防丢"）。密钥名 `local_device_id`（静态常量 `storageKey`）独立于 `DbCipherKeyStore.storageKey`——前者可被同步恢复，后者丢失即本机 DB 永久不可读，两者命名空间故意分开。UUID 合法性走宽松正则（8-4-4-4-12 hex、不校验 v4 version/variant 位），允许从老库恢复任意合法 UUID。`_ensureUserPref` **故意不用 `insertOnConflictUpdate`**——user_pref 的 `CHECK(id=1)` 约束在 SQLite UPSERT 的 DO UPDATE 路径会被二次评估并误报失败，改为显式 select-then-insert/update（DAO 层普通表不受此影响，原因是它们没有 id CHECK）。依赖注入点：`SecureKeyValueStore`（生产 `FlutterSecureKeyValueStore`、测试 in-memory）+ `UuidFactory`（默认 `const Uuid().v4()`、测试返回固定字面量）。
  - **`seeder.dart`**（Step 1.7）：`DefaultSeeder` + `SeedClock` / `SeedUuidFactory` 类型别名。`seedIfEmpty()` 在单事务内判断 `ledger` 表是否空——非空整体跳过；空则插入 1 账本（📒 生活）+ 28 分类（18 支出 + 10 收入）+ 5 账户（现金 / 工商银行卡 / 招商信用卡 / 支付宝 / 微信）。默认列表作为 `static const List<(...)> expenseCategories / incomeCategories / defaultAccounts` 暴露给测试与后续 UI（Step 3.2 记账页分类网格直接消费）。颜色走 `palette` 6 色（design-document §10.2 奶油兔色板）的 `i % 6` 循环。**不向 `sync_op` 写条目**——Phase 10 再决定种子数据与首次同步的交互规则，避免两台设备各自种子导致"两套默认数据重复上云"。
  - **`providers.dart`**（Step 1.5/1.7）：三个 `@Riverpod(keepAlive: true)` 顶层函数。
    - `appDatabase(Ref)` 构造 `AppDatabase()` 并在 `ref.onDispose` 里关闭。
    - `deviceId(Ref)` 返回 `Future<String>`，`watch(appDatabaseProvider)` 拿到 DB，再 `LocalDeviceIdStore(db: db).loadOrCreate()`。
    - `defaultSeed(Ref)`（Step 1.7 加）返回 `Future<void>`，`watch(appDatabaseProvider)` + `await watch(deviceIdProvider.future)` 后调 `DefaultSeeder.seedIfEmpty()`。是整条 bootstrap 链最靠前的那个 provider——main.dart 只要 `await container.read(defaultSeedProvider.future)` 即可穿过"DB 打开 → device_id → 种子"三环。
    - `keepAlive: true` 保证在 ProviderContainer 生命周期内只构建一次；main.dart 的 bootstrap 依赖这点：`container.read` 预热后，runApp 交给 `UncontrolledProviderScope`，widget 树再读就是 cache hit。
    - `providers.g.dart` 由 `riverpod_generator` 产出对应的 `appDatabaseProvider` / `deviceIdProvider` / `defaultSeedProvider`。
  - **`tables/user_pref_table.dart`**：§7.1 `user_pref` 表——单行 `CHECK (id = 1)` 约束、`device_id` NOT NULL、其余字段按文档定义 nullability + 默认值。
  - **`tables/ledger_table.dart`**（Step 1.3）：`LedgerTable` + `@DataClassName('LedgerEntry')`。§7.1 账本表，PK `id` (TEXT, uuid)，`name` NOT NULL，`cover_emoji` 可空，`default_currency` 默认 `'CNY'`，`archived` 默认 0，`created_at` / `updated_at` NOT NULL，`deleted_at`, `device_id`。
  - **`tables/category_table.dart`**（Phase 3 重构）：`CategoryTable` + `@DataClassName('CategoryEntry')`。分类改为“固定一级 + 落库二级”的全局模型：
    - 一级分类不落库，仅由 `parent_key` 归属（如 `income/food/shopping/...`）；
    - 二级分类通过 `is_favorite` 标记收藏（全局共享）；
    - 已移除 `ledger_id` 与 `type`，并通过 `parent_key` 约束保证值域合法。
  - **`tables/account_table.dart`**（Step 1.3 / Step 7.3）：`AccountTable` + `@DataClassName('AccountEntry')`。`type` ∈ `cash` / `debit` / `credit` / `third_party` / `other`；`initial_balance` REAL 默认 0（信用卡可为负）；`include_in_total` 默认 1；`currency` 默认 `'CNY'`。账户不绑定账本——全局资源。**Step 7.3** 追加两列 `billing_day INTEGER` / `repayment_day INTEGER`（均 nullable，UI 校验取值 1-28），仅信用卡使用，仅展示用、不生成提醒。
  - **`tables/transaction_entry_table.dart`**（Step 1.3）：`TransactionEntryTable` + `@DataClassName('TransactionEntryRow')`——**刻意不叫 `TransactionEntry`**，让位给 Step 2.1 的领域实体同名。`ledger_id` 声 FK，`amount` / `currency` / `occurred_at` NOT NULL，`fx_rate` 默认 1.0，`note_encrypted` / `attachments_encrypted` 为 BLOB（Phase 11 装密文，Phase 3 先明文/JSON）。两索引 `idx_tx_ledger_time (ledger_id, occurred_at DESC)` 与 `idx_tx_updated (updated_at)` 在 `MigrationStrategy` 里用 `customStatement` 建。
  - **`tables/budget_table.dart`**（Step 1.3）：`BudgetTable` + `@DataClassName('BudgetEntry')`。`period` ∈ `monthly` / `yearly`；`category_id = NULL` 表示"总预算"（该账本该周期的总盘子）；`carry_over` 默认 0（Phase 6 Step 6.4 才真正使用）。
  - **`tables/sync_op_table.dart`**（Step 1.3）：`SyncOpTable` + `@DataClassName('SyncOpEntry')`——本机出站同步队列。`id` 用 `integer().autoIncrement()`（隐式主键，**不**再覆写 `primaryKey`；重复覆写会触发 drift_dev 的 `primary_key_and_auto_increment` 报错）。无 `updated_at` / `deleted_at` / `device_id` 三件套——这是队列而非实体，push 成功就物理删除条目。
  - **`dao/`**（Step 1.4）：5 个业务表 DAO，每个文件均为 `@DriftAccessor(tables: [XxxTable])` + `extends DatabaseAccessor<AppDatabase> with _$XxxDaoMixin`。所有 DAO 只暴露 **4 类方法**（实施计划 Step 1.4 硬性约束）：
    1. **list-active**：未软删记录的查询。`category` 已从“按账本”切为“按一级分类 key”查询（`listActiveByParentKey(parentKey)`）与全量/收藏查询（`listActiveAll` / `listFavorites`）；`transaction_entry` / `budget` 仍按 `ledger_id` 查询；`ledger` / `account` 为全局查询。
    2. **upsert**：`into(table).insertOnConflictUpdate(entry)`——调用方负责填 `updated_at` / `device_id`（Step 2.2 仓库层会统一封装）。
    3. **softDeleteById(id, {deletedAt, updatedAt})**：双写 `deleted_at` + `updated_at`；单凭写 `deleted_at` 不够，同步层按 `updated_at` 拉取增量，不刷 `updated_at` 的软删会被对端当成"没变过"漏掉。
    4. **hardDeleteById(id)**：`delete(table)..where(id = ?)` 物理移除。**方法文档显式注明"仅供垃圾桶定时任务调用"**——业务路径必须走 softDelete 以保留 30 天恢复窗口。接口不会自检 `deleted_at IS NOT NULL`；"仅 GC 可调"靠文档 + 代码评审守护，不做运行时护栏（会让正常 GC 也绕不过）。
    - 排序约定：`listActive()` 按 `updated_at DESC`（最近变动靠前）；`listActiveByLedger` 在 `category` 按 `sort_order ASC`（与记账页网格顺序一致）、`transaction_entry` 按 `occurred_at DESC`（命中 `idx_tx_ledger_time` 索引）、`budget` 不排序（UI 层按 `category_id IS NULL` 优先 + 周期分组自行排）。
    - **未提供 watch 变体**：Step 1.4 只暴露 `Future` API，够支撑 Step 2.2 仓库层做一次性查询；UI 响应式刷新由 Step 2.3 的 Riverpod provider `invalidate` 机制驱动。如果未来某 Tab 需要真正的 drift Stream（例如首页流水列表），可以在 DAO 里增量加 `watchActiveByLedger`，而不是把 `listActive...` 全改成 Stream。
- **`dao/sync_op_dao.dart`**（Step 2.2）：`SyncOpDao`——`@DriftAccessor(tables: [SyncOpTable])`。两个方法：`enqueue(...)` 返回 AUTOINCREMENT id；`listAll()` 按 `id ASC` 列出所有待同步记录。`op` 取 `'upsert'` / `'delete'`；`entity` 取 `'ledger'` / `'category'` / `'account'` / `'transaction'` / `'budget'`——注意是 `'transaction'` 而非 `'transaction_entry'`，与 design-document §7.1 DDL 注释字面一致。
- **`remote/`**：Supabase 的 DataSource（表映射 + 批量 push/pull）。Step 10.x 填充。
- **`repository/`**（Step 2.2 已填充）：
  - **`repo_clock.dart`**：`typedef RepoClock = DateTime Function()`——仓库层"当前时间"注入点。生产路径默认 `DateTime.now`，测试路径注入固定时间戳。
  - **`entity_mappers.dart`**：drift 行对象 ↔ 领域实体的唯一映射桥接层。5 组 10 个函数（每组 `rowToXxx` + `xxxToCompanion`），完成 `int epochMs ↔ DateTime`、`int? 0/1 ↔ bool`、nullable 默认值应用。**这是 `lib/data/` 与 `lib/domain/` 之间唯一允许的桥接点**——UI 层只能通过抽象接口 import 仓库。
  - **5 个仓库**（一个抽象接口 + 一个 `LocalXxxRepository` 实现）：
    - `ledger_repository.dart`：`listActive()` / `save(Ledger)` / `softDeleteById(id)`
    - `category_repository.dart`：`listActiveByParentKey(parentKey)` / `listFavorites()` / `listActiveAll()` / `save(Category)` / `toggleFavorite(id, isFavorite)` / `softDeleteById(id)`
    - `account_repository.dart`：`listActive()` / `getById(id)` / `save(Account)` / `softDeleteById(id)`。**Step 7.2 新增 `getById`**：**不**过滤 `deleted_at`，软删账户也能查到——这是流水详情显示"（已删账户）"占位的实现路径（参见 `_TxTile.accountName`）。
    - `transaction_repository.dart`：`listActiveByLedger(ledgerId)` / `save(TransactionEntry)` / `softDeleteById(id)`
    - `budget_repository.dart`：`listActiveByLedger(ledgerId)` / `save(Budget)` / `softDeleteById(id)`。**Step 6.1 强化**：`save()` 内额外查 `(ledgerId, period, categoryId)` 是否有未软删的同键预算（`categoryId == null` 与非空分别走 `isNull` / `equals`）；命中即抛 `BudgetConflictException`（同文件公开类，`Exception` 而非 `Error`）。允许"同 id 视为更新"（excludeId 排除自身）；软删后释放唯一性锁，可重建。
  - 所有仓库的 `LocalXxxRepository` 构造参数统一为 `(db, deviceId, {clock})`，内部持有 `AppDatabase` + 对应 DAO + `SyncOpDao`。
  - **共同职责**：
    1. `save`：覆写 `updated_at`（clock）+ `device_id`（构造参数），单事务内 `dao.upsert` + `syncOpDao.enqueue('upsert')`。返回已被 repo 覆写的实体快照。
    2. `softDeleteById`：先查一行判存（不存在静默返回），单事务内直接写 `updated_at` / `deleted_at` / `device_id` 三列 + `syncOpDao.enqueue('delete')`。**不调用 DAO 的 `softDeleteById`**——DAO 只管两列、不含 `device_id`；repo 三列全写以保证同步 LWW tiebreak 一致。
    3. 无论同步开关是否启用，每次写入/软删都入队 sync_op。若同步一直关闭，表会长期增长——这是刻意的，保留"稍后启用同步时追溯本地历史"的能力。
  - **`providers.dart`**（Step 2.3）：7 个 `@Riverpod(keepAlive: true)` provider：
    - `CurrentLedgerId`（`@riverpod` AsyncNotifier，`keepAlive: true`，Step 4.1 升级）：`build()` 先查 `user_pref.current_ledger_id`（校验仍存在且活跃），失败则回退首个活跃账本；`switchTo(newId)` 持久化到 `user_pref` 后 `invalidateSelf()` 触发重建。
    - `ledgerRepository(Ref)` / `categoryRepository(Ref)` / `accountRepository(Ref)` / `transactionRepository(Ref)` / `budgetRepository(Ref)` → `Future<XxxRepository>`：`watch(appDatabaseProvider)` + `await watch(deviceIdProvider.future)`，构造 `LocalXxxRepository`。
    - 所有仓库 provider 返回抽象接口类型（`LedgerRepository` 等），但内部构造的是 `LocalXxxRepository` 具体实现——UI 消费 `AsyncValue<XxxRepository>`，已通过接口隔离。

### `lib/domain/`
- **`entity/`**（Step 2.1 已填充）：5 个纯 Dart 不可变实体，文件名与类名一一对应（`Ledger` / `Category` / `Account` / `TransactionEntry` / `Budget`）。每个实体:
  - 所有字段 `final` + `const` 构造；所有非空字段在构造中是 `required` 或带默认值。
  - `copyWith({...})`——所有参数可空，**null 即不改**；**不支持通过 copyWith 把一个已有值清回 null**（要反软删、清 toAccountId 等场景，Step 12.2 或相关业务步骤再加 `restore()` / `clearXxx()` 方法，或调用方直接构造新实体）。
  - `toJson()` / `fromJson(Map)`：键名统一 snake_case（与设计文档 §7.1 DDL 以及 Phase 10 Supabase 列名一致）；`DateTime` 用 ISO 8601 字符串；`Uint8List?`（仅 `TransactionEntry` 有）用 **base64 字符串**；`bool` / `double` / `int` / `String?` 走原生 JSON 类型。`fromJson` 对可空字段显式 `??` 应用默认值，保证默认值在序列化-反序列化链路上不丢（比如 `defaultCurrency='CNY'`、`fxRate=1.0`、`carryOver=false`）。
  - `==` / `hashCode` 手写。对 `TransactionEntry.noteEncrypted` / `attachmentsEncrypted` 走**深比较**（`_bytesEqual` / `_bytesHash` 位于 `transaction_entry.dart` 底部的 top-level 私有函数）——原因：`Uint8List` 在 Dart 默认是引用相等，`Uint8List.fromList([1,2,3]) == Uint8List.fromList([1,2,3])` 为 `false`，若不深比较，`fromJson(toJson(x)) == x` 的验收会假阴。
  - `toString()` 列出所有字段（bytes 字段仅打印 length），`expect(..., equals(...))` 失败时能直接看出哪个字段不匹配。
  - **类型收紧**相对于 drift 数据类（也即"一一对应"的语义解释）：`archived` / `includeInTotal` / `carryOver` 用 `bool` 而非 `int?`；`defaultCurrency` / `currency` / `fxRate` / `initialBalance` / `sortOrder` 用非空 + 默认值；`created_at` / `updated_at` / `deleted_at` / `occurred_at` / `start_date` 用 `DateTime?`。仓库层（Step 2.2）承担 drift `int epoch ms` ↔ `DateTime` 与 `int?` ↔ `bool` 的桥接。
  - **`TransactionEntry` 的命名**：drift 数据类叫 `TransactionEntryRow`（Step 1.3 备忘有记录），此命名差异是为了让领域层享有纯粹 `TransactionEntry` 这个名字。仓库层同时引入两个类型时可用 `import 'package:.../transaction_entry_table.dart' show TransactionEntryRow;` + `import 'package:.../transaction_entry.dart' show TransactionEntry;` 避免重名冲突。
- **`usecase/`**：预留给需要跨多个仓库协调的业务动作；简单场景可直接在仓库中完成，不强求每个功能都建一个 usecase。

### `lib/features/`
UI + 状态管理的纵向切分，每个子目录对应一块用户可见功能。

- **`budget/`**（Step 6.1 列表/编辑；Step 6.2 进度计算 + 颜色 + 震动）：
  - **`budget_progress.dart`**（Step 6.2 新增）：纯 Dart 工具集，不依赖 Flutter / Riverpod。
    - `BudgetProgressLevel { green, orange, red }`、`BudgetProgress(spent, limit, ratio, level)`。
    - `computeBudgetProgress({spent, limit})`：色档纯函数。`<70%` 绿、`70%~100%`（含两端）橙、`>100%` 红；`limit <= 0` 直接返回 ratio=0 / level=green，避免误震动。
    - `budgetPeriodRange(period, now)`：返回半开区间 `[start, end)`。`monthly` = now 所在自然月，`yearly` = now 所在自然年。Step 6.4 接入结转后会改造为以 `Budget.startDate` 起算。
    - `computePeriodSpent({budget, transactions, now})`：按上述区间过滤 + `type == 'expense'` + `categoryId 匹配（总预算不限）` + `deletedAt == null` 累加金额。
    - `shouldTriggerBudgetVibration({level, alreadyVibrated})`：把"是否触发震动"的决策抽出为纯函数，`HapticFeedback` 留给 UI 调用方，便于单测覆盖"仅首次"语义。
  - **`budget_providers.dart`**：
    - `kParentKeyLabels`：一级分类 key → 中文标签的常量映射（与 `seeder.dart` 的 `categoriesByParent.keys` 同集合，仅是展示层翻译）。
    - `activeBudgets(Ref)`（`@riverpod FutureProvider`）：当前账本的活跃预算列表，客户端排序——先按 `period` 月→年、再按 `categoryId == null` 的总预算优先。依赖 `currentLedgerIdProvider` + `budgetRepositoryProvider`。
    - `budgetableCategories(Ref)`（`@riverpod FutureProvider`）：从 `categoryRepositoryProvider.listActiveAll()` 中过滤掉 `parentKey == 'income'` 的分类——预算只针对支出。依赖 `categoryRepositoryProvider`。
    - `BudgetClock` typedef + `budgetClock(Ref)` provider（`keepAlive`）：默认 `DateTime.now`；测试覆盖以锁定参考时间，避免周期边界 flaky。
    - `budgetProgressFor(Ref, Budget)`（`@riverpod FutureProvider.family`）：拉当前账本流水 → `computePeriodSpent` → `computeBudgetProgress`。Family key = Budget 实体，因此预算金额变更会产生新的 cache entry，旧 entry 由 autoDispose 回收；Riverpod 用 `Budget.hashCode` / `==`，所以实体的 `==` 实现必须包含所有相关字段（已有）。
    - `BudgetVibrationSession`（`@Riverpod(keepAlive: true) class`）：状态为 `Set<String>`（已震动的预算 id 集合）。`hasVibrated(id)` / `markVibrated(id)`（幂等：重复 mark 不重建 state，避免无谓 rebuild）/ `clear(id)`。冷启动后自然清空——这就是"会话级"语义，符合 implementation-plan 的"session 标记"约束。
  - **`budget_list_page.dart`**：`BudgetListPage`（ConsumerWidget）。
    - `Scaffold` + `FloatingActionButton.extended('新建预算')` → `context.push('/budget/edit')`，返回 `true` 时 `invalidate(activeBudgetsProvider)` 刷新。
    - 内嵌 `_BudgetCard`（Step 6.2 升级为 `ConsumerWidget`）：左侧分类 emoji（总预算用 💰）+ 中部"标题（分类名 / 总预算）+ 周期/结转副标题"+ 右侧金额 + 删除按钮；下方追加 `_ProgressSection`（订阅 `budgetProgressForProvider(budget)`）。
    - **`_ProgressSection`**（ConsumerWidget）：渲染彩色 `LinearProgressIndicator`（color 来自 `BianBianSemanticColors`：green=success / orange=warning / red=danger，进度条 value 用 `ratio.clamp(0, 1)` 防止溢出）+ 一行"已花 ¥X / ¥Y · 百分比"。当 `shouldTriggerBudgetVibration(level, alreadyVibrated)` 为真时，**整段** `markVibrated + HapticFeedback.heavyImpact()` 都放进 `WidgetsBinding.addPostFrameCallback`——build 期间修改 provider state 会触发 Riverpod 的 "Tried to modify a provider while the widget tree was building" 断言。回调内再做一次 `hasVibrated` 检查，保证同帧多次 build 注册多个 postFrame 时只执行一次。
    - 空状态：`_EmptyState`（💰 图标 + "还没有预算"+"点右下角加一个吧 🐰"）。
    - 空状态：`_EmptyState`（💰 图标 + "还没有预算"+"点右下角加一个吧 🐰"）。
  - **`budget_edit_page.dart`**：`BudgetEditPage`（ConsumerStatefulWidget，`budgetId` 可选——传入即编辑，否则新建）。
    - `_loadBudget()` 编辑模式下从 `repo.listActiveByLedger` 中按 id 提取（不存在抛 `StateError`）；`_hydrate(...)` 仅在第一次 build 时把字段写入表单 controller / `_period` / `_categoryId` / `_carryOver`，避免 setState 循环覆盖输入。
    - 表单组件：周期 `SegmentedButton<String>('monthly'/'yearly')`、分类 `DropdownButtonFormField<String?>`（首项"总预算（不限分类）"对应 `null`，其余按 `(parentKey 中文 + sortOrder)` 排序）、金额 `TextFormField`（`numberWithOptions(decimal: true)` + 正则限制最多两位小数）、结转 `SwitchListTile`（subtitle 注明"Step 6.4 实装"）。
    - 保存逻辑：新建走 `const Uuid().v4()` + `startDate` 取本月/本年第一天；编辑走"裸构造 Budget"（`copyWith` 不能把 `categoryId` 清回 null，如果用户从分类预算切回总预算会失败）。捕获 `BudgetConflictException` 走 SnackBar；其他异常走通用"保存失败：$e"。
    - 路由 `/budget` / `/budget/edit?id=...` 在 `app_router.dart` 注册。

- **`stats/`**(Step 5.6 已填充)：
  - **`stats_range_providers.dart`**：统计区间状态源 + 统计聚合纯函数/Provider。
    - `StatsRangePreset`：`thisMonth / lastMonth / thisYear / custom`；
    - `StatsDateRange`：`month(...)` / `year(...)` 边界构造 + `normalize(start, end)`（支持起止反序与跨年）；
    - `StatsRangeState`：当前 preset + 生效区间；
    - `StatsRange`（`@Riverpod(keepAlive: true)`）：`build()` 默认本月；`setPreset(...)` 切换本月/上月/本年；`setCustomRange(...)` 写入自定义区间。
    - `StatsLinePoint` + `statsLinePointsProvider`：按日聚合收入/支出折线数据，排除 transfer。
    - `StatsPieSlice` + `aggregatePieSlices(...)` + `statsPieSlicesProvider`：支出分类 Top 6 + 其他饼图聚合。
    - `StatsRankItem` + `aggregateRankItems(...)` + `statsRankItemsProvider`：按分类金额生成收支排行榜，收入/支出各自计算百分比。
    - `StatsHeatmapCell` + `quantileNormalize(...)` + `aggregateHeatmapCells(...)` + `statsHeatmapCellsProvider`：按日聚合支出热力图，并使用 90 分位归一化抑制极端值“冲白”其它日期。
  - **`stats_page.dart`**：`StatsPage`（ConsumerStatefulWidget，Step 5.6 升级）。
    - 顶部 4 个区间入口（本月/上月/本年/自定义）；
    - 自定义区间用 `showDateRangePicker` 选择后写回 `statsRangeProvider`；
    - 页面展示当前生效区间，作为 Step 5.2+ 图表的统一时间过滤来源；
    - 当前卡片布局：收支折线图 / 分类饼图 / 收支排行榜 / 支出日历热力图，整体被 `RepaintBoundary(key: _chartsBoundaryKey)` + `Container(surface)` 包裹（避免截图透明）；
    - 标题行右侧承载 `IconButton(Icons.ios_share)`，点击弹出 `showModalBottomSheet`（PNG / CSV 二选一），导出过程中显示 `CircularProgressIndicator`，错误通过 `ScaffoldMessenger` 提示；
    - 热力图 `_HeatmapCard` 使用“周列 × 星期行”的滚动网格，cell 通过 `Tooltip` 展示“日期 + 支出金额”，颜色由 `BianBianSemanticColors.danger` 与 `surfaceContainerHighest` 插值得到。
  - **`stats_export_service.dart`**（Step 5.6 新建）：
    - `encodeStatsCsv({entries, categoryMap, accountMap, range})`（顶层 `@visibleForTesting` 纯函数）：UTF-8 BOM `\uFEFF` + 中文列头 `日期/类型/金额/币种/分类/账户/转入账户/备注` + RFC 4180 转义 + 按 `occurredAt` 升序 + 区间外丢弃 + 缺失字段空白。
    - `buildExportFileName({prefix, extension, now, range})`（顶层 `@visibleForTesting` 纯函数）：`<prefix>_<startDate>_<endDate>_<timestamp>.<ext>`。
    - `StatsExportService`：`exportCsv(...)` / `exportPng({boundary, range, pixelRatio = 3.0})` / `shareFile(File, {subject, text})` / `writeExportFile(filename, bytes)` / `capturePng(boundary, pixelRatio)`。`<documents>/exports/` 子目录写盘 + `share_plus.Share.shareXFiles` 分享。三个钩子可注入：`documentsDirProvider` / `shareXFiles` / `now`。

- **`record/`**（Step 3.1 已填充，Step 3.2 已完成分类模型重构）：
  - **`record_providers.dart`**：
    - `RecordMonth`（`@riverpod` Notifier）：当前导航月份（`DateTime`），`build()` 返回当月，`previous()` / `next()` 切换月份。Phase 5 可扩展为自定义区间。
    - `recordMonthSummary(Ref)`（`@riverpod FutureProvider`）：依赖 `recordMonthProvider` + `currentLedgerIdProvider` + `transactionRepositoryProvider`。取当前账本全量活跃流水 → 客户端按月份过滤 → 按 `occurredAt` 倒序 → 汇总收入/支出 → 按天分组为 `List<DailyTransactions>` → 产出 `RecordMonthSummary`。
    - 数据类 `DailyTransactions` / `RecordMonthSummary`：不依赖 flutter/riverpod 的纯 Dart 类型。
  - **`record_home_page.dart`**：`RecordHomePage`（ConsumerWidget）→ 内层 `Scaffold`（自有 FAB）。5 个子区域：
    1. `_TopBar`：`currentLedgerIdProvider` + `ledgerRepositoryProvider` → 显示账本 `📒 名称 ▾` + 搜索占位
    2. `_MonthBar`：左右箭头 + `{year}年{month}月` → `ref.read(recordMonthProvider.notifier).previous()/next()`
    3. `_DataCards`：3 个 `_CardChip`（收入/支出/结余），财务三色
    4. `_QuickInputBar`：单行输入 + `✨ 识别` 占位
    5. `_TransactionList`：`summary.when()` 三态（loading/error/data），无数据时"开始记第一笔吧 🐰"空状态，有数据时按天分组列表
  - FAB `+` → Step 3.2 已接线到 `/record/new`（`context.go('/record/new')`）。
  - **`record_new_providers.dart`**（Step 3.2 新增并重构）：
    - `RecordFormData`：表单数据类（`selectedParentKey` / expression / amount / categoryId / accountId / occurredAt / note），`canSave => amount != null && amount! > 0 && categoryId != null`。
    - `_parseExpr(String expr)`：递归下降求值器，从右向左找 `+`/`-` 分割点，仅支持浮点加减。不完整表达式返回 null。
    - `RecordForm`（`@riverpod` Notifier）：管理表单状态。`onKeyTap` 处理键盘按键；`setParentKey` 切换一级分类；Step 3.5 新增本地附件状态管理（最多 3 张、相册/拍照、删除、沙盒落盘）；`save()` 按 `selectedParentKey` 自动推导流水类型（`income` 或 `expense`）并保存，同时把附件路径列表编码到 `attachmentsEncrypted`（明文 JSON bytes），随后 `invalidate(recordMonthSummaryProvider)`。
  - **`record_new_page.dart`**（Step 3.2 新增并重构；Step 3.5 增量）：`RecordNewPage`（ConsumerWidget），`Column(Expanded(SingleChildScrollView), NumberKeyboard)` 布局。子组件：`_ParentTabs`（底部单字一级分类，含 `☆` 收藏）/ `_AmountDisplay` / `_CategoryGrid`（按一级或收藏过滤）/ `_AccountSelector` / `_LedgerLabel` / `_TimeAndNote` / `_SaveButton`。已移除顶部收入/支出/转账 tab，且不再提供“再记一笔”开关。Step 3.5 在备注弹层新增本地附件区（相册/拍照入口、缩略图预览、删除、`x/3` 上限提示）。
  - **`widgets/number_keyboard.dart`**（Step 3.2 新增，2026-04-26 调整）：`NumberKeyboard`，4 行布局（`7 8 9 ⌫` / `4 5 6 +` / `1 2 3 -` / `CNY 0 . ✓/=`），移除 `C` 与括号键；右下动作键按 `showEquals` 动态显示 `=` 或 `✓`，并受 `canAction` 控制可点击态。

### `test/data/local/app_database_test.dart`
- Step 1.1 落地的 2 个用例：① 空库插入 `user_pref(id=1, deviceId=...)` 并完整读回（校验所有字段默认值）；② 显式 `id: Value(2)` 被 CHECK 约束拒绝。
- 测试走 `AppDatabase.forTesting(NativeDatabase.memory())`，**不**走 SQLCipher——仅验 schema 行为。SQLCipher 的真实加密效果只能在设备级验证（见 progress.md Step 1.2 验证节）。

### `test/data/local/business_tables_test.dart`
- Step 1.3 落地的 7 个用例（6 张业务表 + 1 个索引存在性）：
  1. `ledger` · insert → update(`updated_at`) → soft-delete(`deleted_at`)；校验默认值 `defaultCurrency='CNY'` / `archived=0`。
  2. `category` · 同上；先插父 ledger 演练真实路径（FK 未强制，但当作最佳实践）。
  3. `account` · 同上；校验 `initialBalance=-1200.0`（信用卡欠款为负）、`includeInTotal=1`、`currency='CNY'`。
  4. `transaction_entry` · 同上；校验 `fxRate=1.0` 默认值、tags 明文、`noteEncrypted` 为 null（Phase 11 才写密文）。
  5. `idx_tx_ledger_time` / `idx_tx_updated` 两索引存在性——直接查 `sqlite_master WHERE type='index' AND tbl_name='transaction_entry'`。
  6. `budget` · 同上；`categoryId=null` 表示总预算。
  7. `sync_op` · 队列语义：insert（断言 AUTOINCREMENT `id == 1`）→ tried++ + `lastError` 写入 → 物理 delete。
- 都走 `NativeDatabase.memory()`；用常量 `insertTs / updateTs / deleteTs` 固定时间戳，避免 flaky。

### `test/data/local/dao_test.dart`
- Step 1.4 落地的 5 个用例（每个 DAO 一组，组内按 4 类方法顺序跑一条完整流程）：
  1. `LedgerDao` · upsert×2（含二次 upsert 覆写同 id 触发更新路径）→ `listActive` 按 updated_at DESC → softDelete ledger-1 → `listActive` 剩 ledger-2 → 直查 `select(ledgerTable)` 确认软删行仍物理存在且 `deleted_at`/`updated_at` 均已写 → `hardDeleteById` 返回 1 → 原始表查不到（这就是验收要求"soft-delete 后普通查询查不到，但硬删除接口能看到"的落地）。
  2. `CategoryDao` · 在 ledger-1 下插两条 + ledger-2 下一条（跨账本噪声），`listActiveByLedger('ledger-1')` 断言按 `sort_order` 升序且不含 ledger-2 的噪声，然后跑 soft/hardDelete。
  3. `AccountDao` · 同 LedgerDao 模式（account 无 ledgerId）。
  4. `TransactionEntryDao` · 两条不同 occurred_at 的 tx，断言 `listActiveByLedger` 按 `occurred_at DESC`（命中 `idx_tx_ledger_time`），softDelete 一条后 list 排除，hardDelete 命中软删行。
  5. `BudgetDao` · 三条（ledger-1 总预算 + ledger-1 餐饮分类预算 + ledger-2 年度总预算），断言 `listActiveByLedger('ledger-1')` 仅返回前两条且包含 categoryId=null 的总预算，soft/hardDelete 流程同上。
- 共享 `seedLedger(id)` 辅助函数插父 ledger（category/transaction 需要）。都走 `NativeDatabase.memory()`；`hardDeleteById` 的返回值 = 物理删除行数，测试里都断言为 1（精确命中软删后的残留）。

### `test/core/crypto/bianbian_crypto_test.dart`
- Step 1.6 落地的 11 个用例：
  - **deriveKey（3）**：① RFC 7914 §11 的 PBKDF2-HMAC-SHA256(`passwd`,`salt`,c=1,64B) 向量（取前 32 字节 = `55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc`）；② 默认 iterations=100000 产出 32 字节长度校验；③ 确定性（同输入同输出）+ 不同 salt 产出不同密钥。
  - **AES-GCM KAT（1）**：NIST SP 800-38D Test Case 13（zero key / zero nonce / 16 字节零明文），对照固定 `cea7403d4d606b6e074ec5d3baf39d18 ‖ d0d1c8a799996bf0265b98b5d48ab919` —— 通过 `@visibleForTesting` 的 `encryptWithFixedNonce` 注入 nonce，然后断言打包 bytes 精确相等；同步反向验 decrypt 得回 16 字节零明文。
  - **encrypt/decrypt 往返（2）**：含非 ASCII 的 UTF-8 字符串（中文 + emoji 🐰）往返不丢失字节；同明文二次 encrypt 产出不同 bytes（fresh nonce）但都能解回。
  - **失败场景（4）**：错误密钥 → `DecryptionFailure`；密文段某字节翻转 → `DecryptionFailure`（GCM tag 认证生效）；tag 段某字节翻转 → 同；packed 短于 `12+16=28` 字节 → 同。
  - **参数校验（1）**：非 32 字节 key 抛 `ArgumentError`。
- 辅助函数：`_hex(String)` 把 hex 字符串转 `Uint8List`；`_countingBytes(32)` 产出 `[0,1,2,...,31]` 作为合法非零测试 key。

### `test/data/local/device_id_store_test.dart`
- Step 1.5 落地的 5 个用例，对应 `LocalDeviceIdStore.loadOrCreate()` 的四条分支 + 一条脏数据覆盖：
  1. **全新安装**：secure + user_pref 均空 → 注入的 `uuidFactory` 被调 **1 次**（断言 `callCount == 1`），最终值同时写回两侧。
  2. **冷启动**：secure 预置合法 UUID → 两次调 `loadOrCreate` 返回同值，`uuidFactory` 注入为 `() => fail(...)` 以确保**绝不会被调用**；user_pref 在第一次调用时被顺手补写。
  3. **iOS 重装**：secure 留存 + user_pref 空 → 返回 secure 值 + 补写 user_pref；`uuidFactory` 也配成 fail。
  4. **恢复分支**：手动 `await db.into(userPrefTable).insert(UserPrefTableCompanion.insert(deviceId: _fixedUuidB))` 预置 user_pref，secure 空 → 返回 pref 值并回写 secure。
  5. **脏数据**：secure 存 `'not-a-uuid'` → 视为缺失，回落到生成新 UUID 并覆盖原脏值。
- 自带 `_InMemoryStore` 实现 `SecureKeyValueStore`（不复用 `db_cipher_key_store_test` 的同名类是为了避免跨文件测试耦合）；两个固定 UUID 字面量 `_fixedUuidA` / `_fixedUuidB` 用于跨用例复用。`setUp` 用 `AppDatabase.forTesting(NativeDatabase.memory())` 保证每个用例独立 DB。

### `test/data/local/db_cipher_key_store_test.dart`
- Step 1.2 落地的 4 个用例：① 首次调用生成 64 字符小写 hex 并持久化；② 第二次调用返回同一密钥；③ 底层已存在非法值时覆写；④ 两个独立 `DbCipherKeyStore` 实例（用 `Random.secure()`）产出不同密钥。
- 通过注入内存实现的 `SecureKeyValueStore` 测试，免去 platform channel mock；`Random(seed)` 让 CI 上输出可重现。

### `test/data/local/seeder_test.dart`
- Step 1.7 落地的 3 个用例：
  1. **空库路径**：单次 `seedIfEmpty()` 后断言 1 ledger（含 emoji `📒`、`default_currency='CNY'`、`archived=0`、`device_id='device-a'`、时间戳 = 注入的 `fixedInstant`）+ 28 categories（18 `expense` + 10 `income`，各自按 `sort_order` 升序首个是「餐饮」/「工资」；末个都叫「其他」且颜色按 `i%6` 循环）+ 5 accounts（5 种预期 type、`includeInTotal=1`、`currency='CNY'`、`initialBalance=0.0`）。
  2. **幂等**：连续两次调用（第二次 `counterStart=1000` 确保不会意外重复生成同 UUID），对比前后两次 `ledger/category/account` 的 id 集合应完全相等——证明第二次整体跳过。
  3. **预置账本跳过**：手动插入一个 `'工作'` 账本，然后 `seedIfEmpty()` → 仍只剩那一个账本、分类与账户表保持空，确认 seeder 不越权"补齐"任何数据。
- 辅助 `makeSeeder({counterStart})` 封装确定性 `clock`（固定 `fixedInstant = 1714000000000`）+ 确定性 UUID 工厂（`uuid-0001`, `uuid-0002`, ... 递增）——让"第一个 UUID 属于 ledger"之类的断言可以精确到 id 字符串。

### `test/domain/entity/entities_test.dart`
- Step 2.1 落地的 17 个用例（每个实体 3-4 条 + 1 条依赖隔离）：
  - **Ledger / Category / Account / Budget**：各 3 条——全字段 roundtrip、部分可空字段为 null 的 roundtrip（同时验证默认值落地：`defaultCurrency='CNY'`、`sortOrder=0`、`initialBalance=0`、`carryOver=false` 等）、`copyWith` 改一字段其它不动。
  - **TransactionEntry**：4 条——前两条同上，加上 `Uint8List` 深等断言（`identical` 是 `false` 但 `==` 是 `true`，证明 `_bytesEqual` 生效）+ 一条反面用例（换一组 bytes 后必须 `!=`，防止 `_bytesEqual` 被改成 trivially true 时无人察觉）。
  - **domain 依赖隔离**：1 条——递归扫 `lib/domain/**.dart`，只检查 `import ` / `export ` 开头的行，禁止出现 `'package:drift/` 或 `"package:drift/`。注释 / 字符串里的 `package:drift/` 字面量不会误伤。
- 所有测试用固定时间戳（`DateTime.utc(2026, 4, 21, ...)`）构造实体，不依赖 `DateTime.now()`，CI 可重复。

### `test/data/repository/transaction_repository_test.dart`
- Step 2.2 落地的 4 个用例（以 TransactionEntry 为代表验证所有仓库的共同契约）：
  1. **create → sync_op 入队**：构造一个 `TransactionEntry`（`updatedAt` 与 `deviceId` 故意写错误值），`repo.save()` 后断言——返回实体的 `updatedAt` 已被覆写为固定时间戳 `1714000000000`（注入 clock）、`deviceId` 被覆写为 `'device-test'`（注入参数）；`syncOpDao.listAll()` 有 1 条 upsert，payload JSON 里 `amount=42.5`、`device_id='device-test'`。
  2. **update → sync_op 再入队**：同 id 第二次 `save`（改 `amount 100→200`），断言 sync_op 共 2 条 upsert，第 2 条 payload 含 `amount=200`。
  3. **softDeleteById → sync_op 入队 delete**：先 save 后 softDelete，断言 `listActiveByLedger` 返回空、sync_op 共 2 条（1 upsert + 1 delete）、delete payload 含 `deleted_at` 非空 + `device_id='device-test'`。
  4. **返回实体是纯 Dart 类型**：`isA<TransactionEntry>()` + `runtimeType.toString() == 'TransactionEntry'`——不含 drift 专属 ref/getter。
- 共享 `setUp` → `NativeDatabase.memory()` + 种子一条 `ledger-1`（TransactionEntry 需要父 ledger，FK 虽未强制但保持最佳实践）。`RepoClock` 注入固定 `1714000000000`。
- 其余 4 个仓库（Ledger/Category/Account/Budget）的实现形式完全一致、复用同一套 `entity_mappers.dart` 映射函数——仅以 TransactionEntry 为代表做覆盖，避免 5×3=15 条高重复用例。

### `test/widget_test.dart`
- HomeShell 骨架测试，共 5 用例（Step 3.1 / Step 6.1 配合）：
  1. HomeShell renders all 4 bottom-nav tabs（Tab 名在 nav bar 各出现一次）。
  2. BottomNavigationBar background is cream yellow `#FFE9B0`。
  3. Tapping "统计" tab switches body text（body + nav bar 各一处"统计"）。
  4. 记账 Tab 通过 provider 显示当前账本名称：注入 `_FakeLedgerRepository` 返回"测试账本"，验证 `find.text('测试账本')` + Key 断言。
  5. 有 mock 数据时流水列表按天分组：注入两条 4 月流水，断言月份 header / 金额 / 数据卡片。
- 所有测试通过 `ProviderScope(overrides: _standardOverrides())` 注入。Step 6.1 新增 `_FixedRecordMonth` Notifier 并 override `recordMonthProvider` 为 `DateTime(2026, 4)`——此前用例 4 / 5 硬编码 "2026年4月" / "4月25日"，跨月（如 2026-05-01 之后）跑会因 `RecordMonth.build()` 读 `DateTime.now()` 而 flaky；固定后测试与真实日期解耦。
- `_FakeLedgerRepository` 实现 `LedgerRepository` 接口：`getById` 返回固定 Ledger、`listActive` 返回单元素列表，其余操作走 `fail()`。
- `_FakeTransactionRepository` 实现 `TransactionRepository` 接口：`listActiveByLedger` 返回构造时传入的固定列表，其余走 `fail()`。

### `test/data/repository/budget_repository_test.dart`
- Step 6.1 落地的 8 个用例覆盖唯一性约束的所有边界：
  1. 同账本 + 同周期 + 同分类（categoryId 非空）二次保存抛 `BudgetConflictException`。
  2. 同账本 + 同周期 + `categoryId == null`（总预算）二次保存抛冲突——`isNull` 路径单独覆盖。
  3. 同账本同周期不同分类可共存。
  4. 总预算与分类预算同账本同周期可共存（一个 categoryId=null + 一个 categoryId 非空）。
  5. 同分类不同周期（monthly / yearly）可共存。
  6. 不同账本同周期同分类可共存。
  7. 同 id 二次保存视为更新，`excludeId` 排除自身——不报冲突，金额从 1000 变 2000。
  8. 软删除已存在预算后释放唯一性锁，允许重建（验证 `_findActiveDuplicate` 走 `deletedAt.isNull()` 过滤）。
- 共享 setUp：`AppDatabase.forTesting(NativeDatabase.memory())` + 种子 `ledger-1` / `ledger-2`。`RepoClock` 注入固定 `1714000000000`。

### `pubspec.yaml`
- 运行依赖（Step 0.3 集合经 Step 1.2 调整后）：
  - 路由：`go_router ^17.2.1`
  - 状态：`flutter_riverpod ^2.6.1`、`riverpod_annotation ^2.6.1`
  - 本地 DB：`drift '>=2.22.0 <2.28.2'`、`sqlcipher_flutter_libs ^0.6.5`（实际解析到 0.6.8）、`path_provider ^2.1.5`、`path ^1.9.1`
    - **Step 1.2 变更**：移除 `sqlite3_flutter_libs`；`sqlcipher_flutter_libs` 从 `^0.7.0+eol`（EOL 空壳，仅适配 sqlite3 3.x）回退到 `^0.6.5`（与 `sqlite3 2.x` 匹配并提供 `applyWorkaroundToOpenSqlCipherOnOldAndroidVersions` 工具）。两者并存会在 Android 上同时链入普通 sqlite3 与 SQLCipher，行为未定义，drift 文档明确告警。
  - 远端：`supabase_flutter ^2.12.4`
  - 偏好/密钥：`shared_preferences ^2.5.5`、`flutter_secure_storage ^10.0.0`
  - 加密：`cryptography ^2.9.0`
  - 图表/SVG：`fl_chart ^1.2.0`、`flutter_svg ^2.2.4`
  - 平台能力：`local_auth ^3.0.1`、`flutter_local_notifications ^21.0.0`
  - 国际化/工具：`intl ^0.20.2`、`uuid ^4.5.3`、`flutter_localizations`（sdk）、`cupertino_icons ^1.0.8`
  - 分享：`share_plus ^10.1.4`（Step 5.6 新增，用于统计页导出 PNG/CSV 后唤起系统 Share Sheet）
- dev 依赖：`flutter_test`（sdk）、`flutter_lints ^6.0.0`、`build_runner ^2.4.13`、`drift_dev '>=2.22.0 <2.28.2'`、`riverpod_generator ^2.6.3`、`custom_lint ^0.7.4`、`riverpod_lint ^2.6.3`。
- 版本整体略落后于 pub.dev 最新（如 `flutter_riverpod` 锁 2.x），是为了彼此 API 兼容；若要升级需作为独立一步。

### `analysis_options.yaml`
- 继承 `package:flutter_lints/flutter.yaml`。
- 已追加 `analyzer.plugins: [custom_lint]`，使 `riverpod_lint` 规则在 `dart run custom_lint` 与 IDE 中生效（`flutter analyze` 不受此块影响，二者互补）。

### `android/app/build.gradle.kts`
- 应用 Gradle 脚本。`flutter_local_notifications` 依赖 Java 8+ 的时间 API，因此：
  - `compileOptions.isCoreLibraryDesugaringEnabled = true`
  - `dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") }`
- 若升级 `flutter_local_notifications` 或其他 plugin 要求更高的 desugar 版本，这里是唯一改动点。
- `defaultConfig.minSdk = 23`（Step 1.2 确认值）——`flutter_secure_storage ^10.0.0` 使用 AndroidX `EncryptedSharedPreferences`，要求 API 23+。注意不再跟随 `flutter.minSdkVersion`，升级 Flutter 不会倒退此值。

## 依赖分层（Step 2.2 后已部分实现）

```
features/*  →  domain/entity/*  →  data/repository/（抽象接口） →  data/local/repository/（LocalXxxRepository）
                                     ↑                                          │
                                     └── 抽象接口与实现均在同一文件                    ├─ dao/（drift DAO）
                                                                                  ├─ entity_mappers.dart
                                                                                  └─ sync_op_dao.dart
```

- UI 仅通过 Riverpod Provider 获取 Repository，**不直接持有** drift / supabase 对象。
- `domain/entity` 禁止 import `package:drift/*`（Step 2.1 有依赖检查测试）。
- `data/repository/entity_mappers.dart` 是 `lib/data/` 与 `lib/domain/` 之间唯一桥接点。

## 本机约定

- Dart SDK：`^3.11.5`（pubspec.yaml 锁定）。
- Shell：本机虽为 Windows，但 Claude Code 使用 bash —— 脚本与命令统一 POSIX 风格（`/` 作分隔符、`/dev/null` 作空设备），禁止 `NUL` / 反斜杠路径。


## Phase 3 · Step 3.3 增量说明（2026-04-26）

- `lib/features/record/record_home_page.dart`：
  - 首页流水项点击进入只读详情底部页（新增 `_RecordDetailSheet`），不再直接进入编辑。
  - 详情页动作标准化为：编辑 / 复制 / 删除（`_DetailAction`）。
  - 编辑与复制均复用 `RecordNewPage` + `recordFormProvider.notifier.preloadFromEntry(...)`：
    - 编辑：`asEdit: true`（保留原 id，覆盖保存）
    - 复制：`asEdit: false`（新建语义，不覆盖原记录）
  - 首页支持 `Dismissible` 左滑删除，并在确认后执行 `TransactionRepository.softDeleteById`，随后 `invalidate(recordMonthSummaryProvider)` 刷新列表。
  - FAB 新建前先重置 `recordFormProvider`，防止编辑态脏状态污染新建流程。

- `test/data/repository/transaction_repository_test.dart`：
  - update 用例新增对 `updated_at` 递增断言与 upsert payload 中 `updated_at/device_id` 断言；
  - soft delete 用例新增“库内物理行仍存在且 `deleted_at` 非空”断言，明确软删除语义。

- 本次仅为 Step 3.3 增量，未引入 Step 3.4（转账）字段与流程改造。

## Phase 3 · Step 3.5 增量说明（2026-04-26）

- `lib/features/record/record_new_providers.dart`：
  - `RecordFormData` 增加 `attachmentPaths: List<String>`，用于承载当前表单的本地附件路径集合。
  - `RecordForm` 增加附件操作 API：
    - `pickAndAttachFromGallery()` / `pickAndAttachFromCamera()`；
    - `removeAttachmentAt(index)`；
    - `canAddAttachment`（上限 3 张）。
  - 文件持久化策略：选择图片后复制到应用文档目录 `attachments/<tx_id>/...`，避免依赖系统临时路径。
  - 序列化策略：附件路径数组 `List<String>` 以 UTF-8 JSON 编码写入 `TransactionEntry.attachmentsEncrypted`（当前阶段为明文 JSON bytes）。
  - 反序列化策略：`preloadFromEntry(...)` 从 `attachmentsEncrypted` 解码恢复 `attachmentPaths`，保证编辑/复制时可回显已有附件。
- `lib/features/record/record_new_page.dart`：
  - 备注弹层新增附件 UI（缩略图、删除、相册/拍照入口、数量提示 `x/3`）。
  - `_NotePillButton` 由 `StatelessWidget` 调整为 `ConsumerWidget`，直接感知附件状态变化。
- `test/features/record/record_new_providers_test.dart`：
  - 增加 Step 3.5 断言：保存时 `attachmentPaths` 会编码进 `attachmentsEncrypted`，并可按 JSON 数组还原。

## Phase 4 · Step 4.1 增量说明（2026-04-26）

- `lib/data/repository/providers.dart`：
  - `currentLedgerId` 从 `Future<String>` 升级为 `AsyncNotifier`（`CurrentLedgerId`）。
  - `build()` 先查 `user_pref.current_ledger_id`，验证目标账本仍存在且活跃 → 是则返回；否则取第一个活跃账本并写回 `user_pref`。
  - 新增 `switchTo(newId)` 供 UI 切换：持久化 → `invalidateSelf()` → `build()` 重跑读到新值。

- `lib/data/local/dao/transaction_entry_dao.dart`：
  - 新增 `countActiveByLedger(ledgerId)`：`SELECT COUNT(*) WHERE ledger_id=? AND deleted_at IS NULL`，供账本列表展示流水总数。

- `lib/features/ledger/ledger_providers.dart`（新建）：
  - `LedgerTxCounts`（AsyncNotifier）：遍历活跃账本调 `countActiveByLedger`，产出 `Map<String, int>`。
  - `invalidate()` 供外部（切换账本 / 写流水后）触发全量重建。

- `lib/features/ledger/ledger_list_page.dart`（新建）：
  - `LedgerListPage`（ConsumerWidget）：`watch(currentLedgerIdProvider)` + `watch(ledgerRepositoryProvider)` + `watch(ledgerTxCountsProvider)` 三态渲染。
  - `ledgerGroupsProvider`（FutureProvider）：按 `archived` 字段分组。
  - `_LedgerCard`：封面 emoji + 名称 + 流水计数；当前账本奶油黄底色 + ✓ 高亮；归档卡片置灰 + archive 图标。
  - 切换后自动刷新 `ledgerTxCountsProvider`。

- `lib/app/home_shell.dart`：
  - 移除 `_LedgerPreviewBody` 及其 ConsumerStatefulWidget（Step 1.7 临时预览退役）。
  - index=2 分支改为 `const LedgerListPage()`。
  - 清理 `flutter_riverpod` / `app_database` / `local/providers` 三行无用 import。

- 测试更新：
  - 新增 `_TestCurrentLedgerId extends CurrentLedgerId`（覆盖 `build()` 返回固定 id），用于 `AsyncNotifierProvider` override。
  - 三处测试文件（widget_test / record_new_providers_test / record_new_page_test）的 override 同步升级。

## Phase 4 · Step 4.2 增量说明（2026-04-27）

- `lib/data/local/dao/transaction_entry_dao.dart`：
  - 新增 `softDeleteByLedgerId(ledgerId, {deletedAt, updatedAt})`——批量软删除某账本下所有未软删流水，返回受影响行数。

- `lib/data/local/dao/budget_dao.dart`：
  - 新增 `softDeleteByLedgerId(ledgerId, {deletedAt, updatedAt})`——批量软删除某账本下所有未软删预算，返回受影响行数。

- `lib/data/repository/transaction_repository.dart`：
  - 接口新增 `softDeleteByLedgerId(String ledgerId)`。
  - `LocalTransactionRepository` 实现：先查出所有将被软删的流水 → 调 DAO 批量写 → 逐条入队 sync_op delete。

- `lib/data/repository/budget_repository.dart`：
  - 接口新增 `softDeleteByLedgerId(String ledgerId)`。
  - `LocalBudgetRepository` 实现同上模式。

- `lib/data/repository/ledger_repository.dart`（重写）：
  - 接口新增 `setArchived(String id, bool archived)`——归档/取消归档，返回更新后的实体快照。
  - `LocalLedgerRepository` 新增持有 `TransactionEntryDao` / `BudgetDao`。
  - `softDeleteById` 改为级联：先调 `_txDao.softDeleteByLedgerId` → 再调 `_budgetDao.softDeleteByLedgerId` → 最后软删账本自身。全部在同一事务内完成。
  - `setArchived` 实现：查行 → 覆写 `archived`/`updated_at`/`device_id` → 入队 sync_op upsert。

- `lib/features/ledger/ledger_edit_page.dart`（新建）：
  - `LedgerEditPage`（ConsumerStatefulWidget）——支持新建/编辑双模式。
  - 表单含名称、封面 Emoji、默认币种下拉（CNY/USD/EUR/JPY/KRW/GBP/HKD）；编辑模式额外显示归档开关。
  - 保存时新建走 `const Uuid().v4()` 生成 id，编辑走 `copyWith` 更新；保存后 invalidate 相关 provider。

- `lib/app/app_router.dart`：
  - 新增路由 `/ledger/edit`（可选 query 参数 `id` 进入编辑模式）。

- `lib/features/ledger/ledger_list_page.dart`（重写）：
  - `LedgerListPage` 改为返回 `Scaffold`，新增 `FloatingActionButton.extended`（"新建账本"）→ 跳转 `/ledger/edit`。
  - `_LedgerCard` 新增 `onLongPress` 回调。
  - 活跃账本长按弹出底部菜单：编辑 / 归档（或取消归档） / 删除。当前账本删除按钮置灰并提示"请先切换到其他账本"。
  - 归档账本长按弹出底部菜单：取消归档 / 删除。
  - 删除前弹出二次确认对话框，确认后调 `repo.softDeleteById`（级联删除流水+预算），删除后若为当前账本则 invalidate `currentLedgerIdProvider` 触发重新选择。

- 测试更新：
  - `test/widget_test.dart`：`_FakeLedgerRepository` 补 `setArchived`；`_FakeTransactionRepository` 补 `softDeleteByLedgerId`。
  - `test/features/record/record_new_page_test.dart`：`_FakeLedgerRepository` 补 `setArchived`；`_FakeTransactionRepository` 补 `softDeleteByLedgerId`。
  - `test/features/record/record_new_providers_test.dart`：`_FakeTransactionRepository` 补 `softDeleteByLedgerId`。

## Phase 5 · Step 5.1 增量说明（2026-04-28）

- `lib/features/stats/stats_range_providers.dart`（新建）：
  - 新增 `StatsRangePreset`：`thisMonth / lastMonth / thisYear / custom`。
  - 新增 `StatsDateRange`：封装统计时间区间，提供 `month(...)` / `year(...)` 构造与 `normalize(start, end)`（支持起止反序与跨年边界归一）。
  - 新增 `StatsRangeState`：承载当前区间模式与生效区间。
  - 新增 `StatsRange`（`@Riverpod(keepAlive: true)` Notifier）：
    - `build()` 默认本月；
    - `setPreset(...)` 切换本月/上月/本年；
    - `setCustomRange(...)` 写入自定义时间区间。
- `lib/features/stats/stats_page.dart`（新建）：
  - 新增 `StatsPage`（`ConsumerWidget`）作为统计 Tab 页面。
  - 顶部接入 4 个区间入口（本月/上月/本年/自定义）。
  - 自定义区间通过 `showDateRangePicker` 选择并写回 `statsRangeProvider`。
  - 增加当前生效区间展示条，为 Step 5.2+ 图表组件提供统一时间过滤来源。
- `lib/app/home_shell.dart`：
  - 统计 Tab（index=1）从占位 `_PlaceholderTab(label: '统计')` 替换为 `const StatsPage()`。
- 测试更新：
  - `test/features/stats/stats_range_providers_test.dart`（新建）：
## Phase 5 · Step 5.3 增量说明（2026-04-28）

- `lib/features/stats/stats_range_providers.dart`：
  - 新增 `StatsPieSlice` 数据类：承载饼图单个切片的展示信息（`categoryId`/`categoryName`/`categoryColor`/`amount`/`percentage`），其中 `categoryId` 在"其他"切片中为 null。
  - 新增 `aggregatePieSlices(List<TransactionEntry>, Map<String, Category>, DateTime, DateTime)` 纯函数：从流水列表中筛选支出类型、时间范围内的记录，按 `categoryId` 聚合金额，降序取 Top 6，其余归入"其他"切片。`Category.color` 为 hex 时解析为 `Color`，否则按索引从 `_piePalette` 6 色轮取色。
  - 新增 `statsPieSlices`（`@Riverpod(keepAlive: true)` FutureProvider）：组合 `statsRangeProvider` + `currentLedgerIdProvider` + `transactionRepositoryProvider` + `categoryRepositoryProvider`，产出 `List<StatsPieSlice>`。
  - 修复 `package:flutter/foundation.dart` 导入冲突：改为 `show visibleForTesting`，避免与 `domain/entity/category.dart` 的 `Category` 类型歧义。
  - 新增 `_piePalette`（6 色奶油兔调色板常量）与 `_parseHexColor`（`#RRGGBB` → `Color` 解析器）。

- `lib/features/stats/stats_page.dart`：
  - `StatsPage` 统计卡片区重构为 `SingleChildScrollView` + `Column` 双卡片布局（折线图卡片 + 饼图卡片）。
  - 新增 `_CategoryPieCard`（ConsumerWidget）：订阅 `statsPieSlicesProvider`，loading/error/data 三态渲染；数据为空时显示 `_PieChartEmptyState`（"暂无支出数据"）。
  - 新增 `_PieChartView`（StatefulWidget）：`fl_chart` `PieChart`，支持触摸反馈（`_touchedIndex` 状态驱动选中切片放大 + 显示金额 badge），颜色直接使用 `StatsPieSlice.categoryColor`，切片标题文字颜色按背景亮度自动选择黑白。右侧搭配 `_LegendList`（圆点 + 分类名，`SingleChildScrollView` 兜底）。
  - 新增 `_PieChartEmptyState`：与 `_LineChartEmptyState` 风格一致的占位组件。

- `test/features/stats/stats_range_providers_test.dart`：
  - 新增 `makeTx` / `makeCat` 本地辅助构造器。
  - 新增 7 条 `aggregatePieSlices` 用例：空数据、排除 income/transfer、4 分类百分比和 = 100%、>6 分类 Top 6 + 其他、排除超时、使用分类自身颜色、无颜色回退调色板。

- `test/widget_test.dart`：
  - `_standardOverrides()` 新增 `statsLinePointsProvider` / `statsPieSlicesProvider` override（空列表），避免统计页 provider 未 mock 导致 widget 测试 `pumpAndSettle` 超时。

## Phase 5 · Step 5.4 增量说明（2026-04-29）

- `lib/features/stats/stats_range_providers.dart`：
  - 新增 `StatsRankItem` 数据类：承载排行榜单行展示信息（`categoryId`/`categoryName`/`categoryColor`/`amount`/`percentage`/`isIncome`），其中 `categoryId` 在"未分类"场景中可能为 null。
  - 新增 `_CategoryAgg` 内部聚合辅助类（`double amount = 0`）。
  - 新增 `aggregateRankItems(List<TransactionEntry>, Map<String, Category>, DateTime, DateTime)` 纯函数：从流水列表中排除 transfer、按时间区间过滤、按 `type|categoryId` 复合键聚合金额，分别计算收入/支出各自的总和，产出按金额降序排列的 `List<StatsRankItem>`。百分比按各自类型（收入/支出）的总和计算。
  - 新增 `statsRankItems`（`@Riverpod(keepAlive: true)` FutureProvider）：组合 `statsRangeProvider` + `currentLedgerIdProvider` + `transactionRepositoryProvider` + `categoryRepositoryProvider`，产出 `List<StatsRankItem>`。

- `lib/features/stats/stats_page.dart`：
  - `StatsPage` 统计卡片区新增排行榜卡片：`SizedBox(height: 360, child: _RankingCard())`。
  - 新增 `_RankingCard`（ConsumerWidget）：订阅 `statsRankItemsProvider`，loading/error/data 三态渲染；数据为空时显示 `_RankingEmptyState`（"暂无排行数据"）。
  - 新增 `_RankingList`（StatelessWidget）：`ListView.separated` 渲染排行榜。每行含排名序号（前 3 名用分类颜色高亮）、分类颜色圆点、分类名称、占比进度条（`FractionallySizedBox` 按 `amount/maxAmount` 比例填充）、金额（收入绿色 `+` 前缀、支出红色 `-` 前缀，颜色来自 `BianBianSemanticColors`）。
  - 新增 `_RankingEmptyState`：与 `_LineChartEmptyState` / `_PieChartEmptyState` 风格一致的占位组件。

- `test/features/stats/stats_range_providers_test.dart`：
  - 新增 8 条 `aggregateRankItems` 用例：空数据、排除 transfer、同分类聚合、百分比计算、排除超时、使用分类颜色、回退调色板、混合收支正确分组与百分比。

- `test/widget_test.dart`：
  - `_standardOverrides()` 及第二个测试用例的 override 列表均新增 `statsRankItemsProvider.overrideWith((ref) async => [])`。

## Phase 5 · Step 5.6 增量说明（2026-04-29）

- `pubspec.yaml`：新增依赖 `share_plus: ^10.1.4`（实际解析到 10.1.4）。10.x 而非最新 13.x 是为了与现有 SDK / 依赖约束保持兼容；同时引入间接依赖 `share_plus_platform_interface 5.0.2` 与 `cross_file`（提供 `XFile`）。

- `lib/features/stats/stats_export_service.dart`（新建）：
  - `encodeStatsCsv({entries, categoryMap, accountMap, range})`（顶层 `@visibleForTesting` 纯函数）：UTF-8 BOM `\uFEFF` + 中文列头 `日期/类型/金额/币种/分类/账户/转入账户/备注` + RFC 4180 转义（值含 `,` / `"` / `\n` / `\r` 整体加引号、内部 `"` 转义为 `""`）+ 按 `occurredAt` 升序 + 区间外行丢弃 + categoryId/accountId 缺失时空字段。日期格式 `yyyy-MM-dd HH:mm`，金额 `0.00`，类型映射中文（`收入/支出/转账`）。
  - `buildExportFileName({prefix, extension, now, range})`（顶层 `@visibleForTesting` 纯函数）：产出 `<prefix>_<startDate>_<endDate>_<timestamp>.<ext>`，时间戳格式 `yyyyMMdd_HHmmss`、区间格式 `yyyyMMdd`，避免 Windows 文件名非法字符。
  - `StatsExportService` 类：注入 `documentsDirProvider`（默认 `getApplicationDocumentsDirectory`）/ `shareXFiles`（默认 `Share.shareXFiles`）/ `now`（默认 `DateTime.now`）三个钩子；公开 API：
    - `writeExportFile(filename, bytes)`：在 `<documents>/exports/` 子目录下写文件，自动创建目录，`flush: true` 保证落盘后再返回 `File`。
    - `exportCsv(...)` / `exportPng({boundary, range, pixelRatio = 3.0})`：组合 encode + 文件名 + 写盘。
    - `capturePng(boundary, pixelRatio)`：`RenderRepaintBoundary.toImage(pixelRatio: 3.0)` 默认值满足验收"PNG 分辨率 ≥ 2x"；`image.dispose()` 在 finally 内确保 ImageBuffer 释放。
    - `shareFile(File, {subject, text})`：薄封装 `share_plus.Share.shareXFiles([XFile(file.path)], ...)`。

- `lib/features/stats/stats_page.dart`：
  - `StatsPage` 由 `ConsumerWidget` 升级为 `ConsumerStatefulWidget`，持有 `_chartsBoundaryKey: GlobalKey` + `_exportService: StatsExportService` + `_exporting: bool`。
  - 标题行重构为 `Row` 三段式：左占位 40px / 居中 `Text('统计分析')` / 右侧 40px 区域承载 `IconButton(Icons.ios_share, tooltip: '导出')`；导出中显示 `CircularProgressIndicator(strokeWidth: 2)`。
  - 点击导出按钮 → `showModalBottomSheet<_ExportKind>` 选 PNG / CSV → `_exportPng()` 或 `_exportCsv()`；任意失败由 `try/catch` 通过 `ScaffoldMessenger` 提示「导出失败：$e」并在 finally 中复位 `_exporting`。
  - PNG 路径：`_chartsBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?` → service.exportPng → service.shareFile。
  - CSV 路径：`ref.read` 拉取 `currentLedgerIdProvider.future` / `transactionRepositoryProvider.future` / `categoryRepositoryProvider.future` / `accountRepositoryProvider.future`，组装 `categoryMap` / `accountMap` 后调用 service.exportCsv → service.shareFile。
  - 图表区被 `RepaintBoundary(key: _chartsBoundaryKey, child: Container(color: surface, ...))` 包裹（`Container` 给 PNG 截图填充背景，避免透明区显示为黑/白色）。
  - 顺手清理 Step 5.5 留下的预存 warning：`_HeatmapCard` 删除未消费的 `super.key` 形参。

- `test/features/stats/stats_export_service_test.dart`（新建）：8 条用例——
  - `encodeStatsCsv` × 6：UTF-8 BOM + 中文列头 / 行排序 + 字段格式 / transfer 行 toAccount 解析 / RFC 4180 转义（`,` / `"` / `\n`）/ 区间过滤 / 缺失映射时空字段。
  - `buildExportFileName` × 2：含起止 + 时间戳 / 扩展名参数生效。
  - 自带迷你 `LineSplitter`（识别 `\n` / `\r\n`）以避免外部 `dart:convert` import 噪声。

- 验证摘要：`flutter analyze` → No issues found；`flutter test` → 126/126 通过（118 前 + 8 新）；`dart run custom_lint` → 3 条预存 INFO（`record_new_providers.dart`），与本步无关。

## Phase 6 · Step 6.1 增量说明（2026-05-01）

- `lib/data/repository/budget_repository.dart`：
  - 新增 `BudgetConflictException`（`Exception`，含 `message`），用于业务可恢复的"重复预算"冲突。
  - `LocalBudgetRepository.save()` 在事务内、`dao.upsert` 之前先调 `_findActiveDuplicate(...)`：按 `(ledgerId, period, categoryId)` 查未软删行（`categoryId == null` 走 `t.categoryId.isNull()`，否则 `t.categoryId.equals(...)`）；通过 `t.id.isNotIn([excludeId])` 排除自身，使"同 id 二次保存"仍是合法更新。
  - 静态助手 `_periodLabel(period)` 把 `'monthly'` / `'yearly'` 映射为中文"月" / "年"，仅用于异常 message 的拼接，不外泄到 UI 文案。

- `lib/features/budget/budget_providers.dart`（新建）：
  - `kParentKeyLabels`：常量映射，键集与 `seeder.dart::categoriesByParent.keys` 同步。
  - `activeBudgets(Ref)`：从 `budgetRepositoryProvider` 拉当前账本未软删预算，客户端排序"先 monthly 后 yearly、再 categoryId=null 优先"，UI 不再二次排序。
  - `budgetableCategories(Ref)`：从 `categoryRepositoryProvider.listActiveAll()` 过滤掉 `parentKey == 'income'`——预算覆盖支出场景。

- `lib/features/budget/budget_list_page.dart`（新建）：
  - `BudgetListPage`（ConsumerWidget）：`Scaffold` + 列表 + `FloatingActionButton.extended`。卡片点击进入编辑、按钮触发删除二次确认（`AlertDialog`）。删除走 `repo.softDeleteById` → `invalidate(activeBudgetsProvider)` + Snackbar。
  - 私有 `_BudgetCard`：左 emoji（来自分类 icon，总预算用 💰 兜底）+ 中部双行（标题/副标题"周期 · 结转标记"）+ 右金额（`NumberFormat('#,##0.00')`）+ 删除 `IconButton`。
  - 私有 `_EmptyState`：💰 图标 + "还没有预算" + "点右下角加一个吧 🐰"。

- `lib/features/budget/budget_edit_page.dart`（新建）：
  - `BudgetEditPage`（ConsumerStatefulWidget，`budgetId` 可选）。`_loadBudget()` 在 `FutureBuilder` 内异步取 budget；`_hydrate(...)` 守 `_initialized` flag 仅首次 build 写入字段，避免重渲染时覆盖用户编辑。
  - 字段：周期 `SegmentedButton<String>(monthly/yearly)`、分类 `DropdownButtonFormField<String?>`（首项 null = 总预算 + 其余按"中文 parentKey + sortOrder"排序）、金额 `TextFormField`（`numberWithOptions(decimal:true)` + `FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))`）、结转 `SwitchListTile`。
  - 保存逻辑：编辑模式直接 `Budget(...)` 裸构造（不走 copyWith——`copyWith` 不能把 `categoryId` 清回 null，否则用户从分类预算切回总预算会失败）。新建走 `Uuid().v4()` + `startDate` 取本月/本年第一天。捕获 `BudgetConflictException` → SnackBar 友好提示；捕获其他异常 → "保存失败：$e"。`_saving` 状态守按钮，避免双击。

- `lib/app/app_router.dart`：新增两条路由 `/budget`（`BudgetListPage`）、`/budget/edit`（`BudgetEditPage` + `?id=...`）。

- `lib/app/home_shell.dart`：
  - 移除占位 `_PlaceholderTab`；`_pages[3]` 改为 `_MeTab`。
  - 新增 `_MeTab` 私有 StatelessWidget：`Scaffold` + `AppBar('我的')` + `ListView`，目前唯一一项 `ListTile('预算')` → `context.push('/budget')`。Phase 17 会扩展为完整设置/同步/锁等入口。
  - 新增 import `package:go_router/go_router.dart`（`_MeTab` 内 `context.push` 用）。

- `test/data/repository/budget_repository_test.dart`（新建）：8 用例覆盖 `(ledgerId, period, categoryId)` 唯一性的全部边界（详见对应 test 文件章节）。

- `test/widget_test.dart`：新增 `_FixedRecordMonth extends RecordMonth` 并在 `_standardOverrides()` + 测试 5 的 inline overrides 中各加一行 `recordMonthProvider.overrideWith(() => _FixedRecordMonth(DateTime(2026, 4)))`——把 widget 测试的"当前月"锁死，避免随真实日期跨月而 flaky（曾在 2026-05-01 触发）。

- 验证摘要：`flutter analyze` → No issues found；`flutter test` → 134/134 通过（126 前 + 8 新 budget repo 用例）；含 widget_test 时间敏感修复后 5/5 通过。

## Phase 6 · Step 6.2 增量说明（2026-05-01）

- `lib/features/budget/budget_progress.dart`（新建）：纯 Dart 工具集（不依赖 Flutter / Riverpod / drift），承载色档、周期边界、消费聚合、震动决策四件事。详细内容见上文 `lib/features/budget/` 节。色档边界严格按 implementation-plan：`<70%` 绿、`70%`/`100%` 归橙、`>100%` 红。

- `lib/features/budget/budget_providers.dart`：
  - 新增 `BudgetClock` typedef + `budgetClock(Ref)` provider（默认 `DateTime.now`）——测试可 override 锁定参考时间。
  - 新增 `budgetProgressFor(Ref, Budget)`（family FutureProvider）：拉当前账本流水 → `computePeriodSpent` → `computeBudgetProgress`。
  - 新增 `BudgetVibrationSession` Notifier（`keepAlive`）：状态为 `Set<String>`，`hasVibrated` / `markVibrated`（幂等）/ `clear`。冷启动后清空，符合"会话级"语义。

- `lib/features/budget/budget_list_page.dart`：
  - `_BudgetCard` 升级为 `ConsumerWidget`；卡片 body 从单 `Row` 改为 `Column`，下方追加 `_ProgressSection`。
  - `_ProgressSection`（ConsumerWidget）：彩色 `LinearProgressIndicator` + "已花 ¥X / ¥Y · N%" 文案。颜色取自 `BianBianSemanticColors`（success/warning/danger）。`ratio.clamp(0, 1)` 给进度条 value，避免 >100% 溢出动画。
  - 震动逻辑：`shouldTriggerBudgetVibration(level, hasVibrated)` 为真时，**整段** `markVibrated + HapticFeedback.heavyImpact()` 都放进 `WidgetsBinding.addPostFrameCallback`——build 期间修改 provider state 会被 Riverpod 拒绝。回调内再做一次 `hasVibrated` 检查，确保同帧多次 build 注册多个 postFrame 时只执行一次。
  - import 新增 `package:flutter/services.dart`（HapticFeedback）+ `app/app_theme.dart`（BianBianSemanticColors）+ `budget_progress.dart`。

- `test/features/budget/budget_progress_test.dart`（新建，16 用例）：
  - `computeBudgetProgress`：< 70%、= 70%、85%、= 100%、100.01%、limit ≤ 0、spent = 0 共 7 条边界。
  - `budgetPeriodRange`：monthly/yearly/12 月跨年 3 条。
  - `computePeriodSpent`：总预算累加 / 分类预算过滤 / yearly 全年范围 3 条。
  - `shouldTriggerBudgetVibration`：green/orange 不触发、red 首次触发、red 已触发不再触发 3 条。

- `test/features/budget/budget_vibration_session_test.dart`（新建，5 用例）：
  - 初始 state 空；`markVibrated` → `hasVibrated` true；同 id 重复 mark 不重建 state（`identical` 断言）；多 id 独立标记；`clear` 移除指定 id。

- 验证摘要：`flutter analyze` → No issues found；`flutter test` → 155/155 通过（134 前 + 16 budget_progress + 5 vibration_session）；`dart run custom_lint` → 仍是 3 条预存 INFO（`record_new_providers.dart`），与本步无关。

## Phase 7 · Step 7.2 增量说明（2026-05-01）

- `lib/data/repository/account_repository.dart`：
  - 接口新增 `Future<Account?> getById(String id)`——**不**过滤 `deleted_at`。
  - `LocalAccountRepository.getById`：`select(accountTable)..where(id == id)..getSingleOrNull()` → `rowToAccount`；调用方按 `account.deletedAt != null` 自行决定如何渲染。这是流水详情显示"（已删账户）"占位的实现路径——`listActive` 不能给出软删账户，但流水的 `accountId` 仍指向历史 id，必须能拿到历史名 / 软删标记。

- `lib/features/account/account_edit_page.dart`（新建）：`AccountEditPage`（`ConsumerStatefulWidget`，`accountId` 可选）。字段：名称（`TextFormField`，必填校验）、类型（下拉，`cash` / `debit` / `credit` / `third_party` / `other`）、图标 emoji（`TextFormField`，可空）、初始余额（`TextFormField` + `numberWithOptions(decimal: true, signed: true)` + 正则 `^-?\d*\.?\d{0,2}` 限两位小数 + 可负号）、默认币种（下拉同账本编辑页 7 种）、计入总资产（`SwitchListTile`）。`initState` 启动 `_loadFuture`；`_hydrate(acc)` 守 `_initialized` flag 仅首次写入字段。`_save()` 编辑模式走 `existing.copyWith(...)` 路径（避免裸构造遗漏字段）；新建模式走 `Account(id: const Uuid().v4(), ..., deviceId: '')` 让 repo 覆写 deviceId/updatedAt。保存成功后 `ref.invalidate(accountsListProvider)` / `accountBalancesProvider` / `totalAssetsProvider` 三连击，再 `Navigator.pop(true)`。`_saving` 守按钮防双击。

- `lib/features/account/account_list_page.dart`：
  - 新增 `FloatingActionButton.extended('新建账户')` → `context.push<bool>('/accounts/edit')`，返回 `true` 触发 3 个 provider invalidate。
  - `_AccountCard` 接收 `onTap` / `onLongPress` 回调；`InkWell` 包裹卡片内容，点击进入 `/accounts/edit?id=<acc.id>`。
  - 长按弹出 `showModalBottomSheet`：编辑（同 onTap）+ 删除（红色，触发 `_confirmDelete`）。
  - `_confirmDelete(...)`：`AlertDialog` 二次确认 → `repo.softDeleteById(account.id)` → 3 个 provider invalidate + Snackbar `「{name}」已删除`；删除按钮置 `foregroundColor: Colors.red`。`hero_tag: 'account_list_fab'` 与账本列表的 FAB 区分，避免 Hero 冲突。

- `lib/app/app_router.dart`：新增 `GoRoute('/accounts/edit')`，可选 query `id` 进入编辑模式；与 `/accounts` 路由列表平行。

- `lib/features/record/record_home_page.dart::_TxTile` 的 `accountName(id)` 回退逻辑修订：
  - id == null / 空字符串 → `'账户'`（保持旧版"未填写账户"语义）。
  - id != null 且不在 `accountRepo?.listActive()` 结果中 → `'（已删账户）'`（**新增**——Step 7.2 验收）。
  - 这是"懒查询"实现：不去查 `getById`（每条流水 + 每次 build 都查会爆查询），而是利用 `listActive` 一次性查出全部活跃账户后做内存查找。`getById` 由仓库测试覆盖，UI 不消费——但若未来产品要求"已删账户保留原名 + 加`（已删）`后缀"，则改为消费 `getById` 即可（每个 `_TxTile` 内 `FutureBuilder<Account?>`）。
  - 转账流水副标题 `'A → B'` 与详情底部页 `_RecordDetailSheet` 的"钱包" / "转出" / "转入" KV 行均经此 `accountName` 函数，故同一处修改即生效。

- `test/data/repository/account_repository_test.dart`（新建，7 用例）：
  - `save → 写入并入队 sync_op upsert`（覆写 device_id/updated_at + payload 断言）。
  - `getById 命中活跃账户`（基础正向）。
  - `getById 不存在的 id 返回 null`。
  - `softDeleteById → listActive 不可见，但 getById 仍能查到（含 deletedAt）`（Step 7.2 兜底关键）。
  - `softDeleteById 不存在的 id 静默跳过（不入队）`。
  - `save (update) 同 id 二次保存视为更新`（步进 clock + 单行 + 2 条 upsert）。
  - `返回实体是纯 Dart 类型（不含 drift 专属类型）`。

- `test/widget_test.dart`：
  - 新增 `_FakeAccountRepository`（`listActive` / `getById` / `save fail` / `softDeleteById fail`）。
  - 新增第 6 条用例 `删除账户后转账流水显示"（已删账户）"占位`：注入 1 条 transfer 流水 + 空账户列表 → 验证副标题 `（已删账户） → （已删账户）` + 金额 `¥200.00` 渲染（不崩溃）。

- `test/features/record/record_new_page_test.dart`：`_FakeAccountRepository` 补 `getById`（按 id 内存匹配）以保持 implements 接口完整。

- 验证摘要：`flutter analyze` → No issues found；`flutter test` → 200/200 通过（192 前 + 7 account repo + 1 widget = 200）。

## Phase 7 · Step 7.2 刷新补丁（2026-05-01）

- **现象**：删除账户后流水副标题不更新；切换账本再切回才刷新。
- **根因**：`_TxTile` watch 的是 `accountRepositoryProvider`（仓库实例从不变），`accountsListProvider` 被 invalidate 不会让 tile 重建。
- **修复点**：`lib/features/record/record_home_page.dart::_TxTile.build()`——把 `ref.watch(accountRepositoryProvider).valueOrNull` + 内层 `FutureBuilder<List<Account>>` 替换为 `ref.watch(accountsListProvider).valueOrNull ?? const <Account>[]`。同时 import 调整为 `features/account/account_providers.dart::accountsListProvider`，原 `data/repository/providers.dart` 的 `accountRepositoryProvider` 从 import 列表里移除（不再使用）。
- **回归测试**：`test/widget_test.dart` 新增 `删除账户后流水副标题立即刷新（无需切换账本）` 用例——`_FakeAccountRepository.accounts` 改为可变；`ProviderContainer.invalidate(accountsListProvider)` 模拟删除事件；pumpAndSettle 后断言副标题从原账户名变为"（已删账户）"。
- **同款风险**：`categoryRepositoryProvider` 在 `_TxTile` 内同样以仓库实例 + FutureBuilder 模式使用。若未来用户报告"删/改分类后流水图标/名未刷新"，应按同模式切换为某个 `categoriesListProvider`。本次刻意不顺手改，保持补丁聚焦。
- 验证摘要：`flutter analyze` → No issues found；`flutter test` → 201/201 通过（200 前 + 1 新刷新回归）。

## Phase 7 · Step 7.3 增量说明（2026-05-02）

数据层 / 实体层：
- `lib/data/local/tables/account_table.dart`：`AccountTable` 追加两列——`billing_day INTEGER`（nullable）、`repayment_day INTEGER`（nullable）。命名按 design-document §7.1 风格保持下划线，drift Companion getter 自动转 camelCase。两列对所有账户都允许 null，UI 层按 `type == 'credit'` 决定是否显示 / 是否写入。
- `lib/data/local/app_database.dart`：`schemaVersion` 从 v4 升 v5；`onUpgrade` 新增 `if (from < 5)` 分支，调 `m.addColumn(accountTable, accountTable.billingDay)` + `m.addColumn(accountTable, accountTable.repaymentDay)`。schema 版本注释同步追加 v5 行。
- `lib/domain/entity/account.dart`：实体加 `int? billingDay` / `int? repaymentDay`；`copyWith` / `toJson` / `fromJson` / `==` / `hashCode` / `toString` 全部同步。`fromJson` 用 `(json['billing_day'] as num?)?.toInt()` 兜底——保持向旧 JSON 备份的兼容（旧备份缺这两个 key 时按 null 解析）。Step 2.1 实体约定不变：`copyWith` 不能把 `T?` 清回 null；要清 `billingDay` / `repaymentDay` 必须裸构造（账户编辑页保存路径已切换为裸构造）。
- `lib/data/repository/entity_mappers.dart`：`rowToAccount` / `accountToCompanion` 两侧都补两个字段映射，与其他 nullable 字段同模式（drift 端 `int?` ↔ 实体端 `int?` 直接透传）。

UI 层：
- `lib/features/account/account_edit_page.dart`：
  - 新增 `_billingDayController` / `_repaymentDayController` 两个 controller + 对应 dispose；`_hydrate(acc)` 编辑模式回填两字段。
  - `build()` 内当 `_type == 'credit'` 时条件渲染一行双 `TextFormField`（`Row + Expanded`），输入限制：`TextInputType.number` + `FilteringTextInputFormatter.digitsOnly` + `LengthLimitingTextInputFormatter(2)`；`validator` 共用 `_validateDay` 私有方法（空字符串放行；非空时要求 `1 ≤ n ≤ 28`，否则提示"请输入 1-28 的整数"）。两字段各挂 `Key('billing_day_field')` / `Key('repayment_day_field')`。
  - 类型 dropdown 的 `onChanged` 在切到非 credit 时同步 `setState` 清空两个 controller，避免视觉残留。
  - `_save()` 编辑分支改为**裸构造 `Account(...)`**（不走 copyWith）——这是为了支持"由非空 → null"的清空场景。`billingDay` / `repaymentDay` 仅当 `_type == 'credit'` 时取 controller 值，其它类型一律落 null。新建分支沿用裸构造（本来就是）。
- `lib/features/account/account_list_page.dart`：
  - `_AccountCard` 新增静态方法 `_creditDayLine(billingDay, repaymentDay)`：根据填写情况组合 `'账单日 X 号 · 还款日 Y 号'`；任一字段缺失时仅显示已填字段；两者都缺失返回 null。
  - `build()` 中当 `account.type == 'credit' && creditInfo != null` 时，在卡片中部 Column 第二行（类型 + 不计入总资产 suffix）下方再渲染一行 `Text(creditInfo)`，挂 `Key('credit_info_<accountId>')` 便于测试断言。

测试：
- `test/domain/entity/entities_test.dart::Account` 组：原 `full` 加 `billingDay: 5` / `repaymentDay: 22`，覆盖含信用卡日的全字段 roundtrip；`minimal`（cash 账户）的预期断言新增"两字段为 null"；`copyWith` 用例新增"不动信用卡日"断言；新增第 4 条"信用卡日仅存其一也能 roundtrip"用例（仅填 `billingDay`）。
- `test/data/repository/account_repository_test.dart`：`makeAccount` 工厂加 `billingDay` / `repaymentDay` 可选参数；新增 2 条 Step 7.3 用例——① 信用卡日持久化并可读回（同时验 sync_op payload 含两个 key）；② 非信用卡保存时两字段为 null（即使被传入也按 UI 规范落 null，但仓库本身不强制）。

验证摘要：`dart run build_runner build --delete-conflicting-outputs` → 147 outputs；`flutter analyze` → No issues found；`flutter test` → 204/204 通过（201 前 + 1 entities + 2 account_repository = 204）；`dart run custom_lint` → 仍是 3 条预存 INFO（与 record_new_providers.dart 相关），与本步无关。


## Phase 8 · Step 8.1 增量说明（2026-05-02）

数据层 / Schema：
- `lib/data/local/tables/user_pref_table.dart`：新增 `multi_currency_enabled INTEGER NULLABLE DEFAULT 0` 列。命名按 design-document §7.1 风格保持下划线，drift Companion getter 自动转 camelCase。`0` / `null` 视为关闭，`1` 视为开启——与生产默认一致。
- `lib/data/local/tables/fx_rate_table.dart`（新建）：`FxRateTable` + `@DataClassName('FxRateEntry')`。**工具表**（与 `sync_op` 同性质，不是同步实体）——只有 `code` (TEXT PK) / `rate_to_cny` (REAL NOT NULL) / `updated_at` (INTEGER NOT NULL) 三列，无 `deleted_at` / `device_id` / sync_op 入队。设计 §5.7 的"汇率快照"职责。
- `lib/data/local/app_database.dart`：`schemaVersion` 从 v5 升 v6；注册 `FxRateTable` + `FxRateDao`；`onUpgrade` 新增 `if (from < 6)` 分支：`m.addColumn(userPrefTable, userPrefTable.multiCurrencyEnabled)` + `m.createTable(fxRateTable)`。**故意不**在 onUpgrade 写入 fx_rate 快照——把"种子化"职责留给 `seeder.dart` 的独立判空，与 ledger 路径解耦。
- `lib/data/local/dao/fx_rate_dao.dart`（新建）：`FxRateDao` 暴露 3 个方法——`listAll()` (按 code 升序) / `getByCode(code)` / `upsert(companion)`。不走 Step 1.4 的"业务表 4 方法"模式；不需要 softDelete / hardDelete。

常量层：
- `lib/core/util/currencies.dart`（新建，原目录 `[空]` 退役）：`Currency` 数据类（`code` / `symbol` / `name`）+ 顶层 `kBuiltInCurrencies` (11 种：CNY / USD / EUR / JPY / KRW / HKD / TWD / GBP / SGD / CAD / AUD) + 顶层 `kFxRateSnapshot: Map<String, double>`（写死的初始汇率快照，以 CNY 为基准；CNY 自身 = 1.0）。两个常量集对外暴露但**不可在运行期 mutate**——Step 8.3 联网刷新走的是"覆盖 fx_rate 表行"，不动这两个 const。

种子化：
- `lib/data/local/seeder.dart::seedIfEmpty()` 重构为**两段独立判空**：
  - 第一段（旧 ledger 路径）：`ledger` 表为空 → 插入账本 + 分类 + 账户。
  - 第二段（Step 8.1 新增）：`fx_rate` 表为空 → 按 [kFxRateSnapshot] 批量插入 11 行（updated_at = `_clock()` ms）。
  两段都在同一个 `_db.transaction` 内，任一失败整体回滚。这种解耦让 v5 → v6 升级路径下的"既有用户首次冷启 v6"能仅补齐 fx_rate（不重建 ledger）；同样让"用户已手动覆盖某币种汇率"的场景下 seeder 不会回写覆盖（fx_rate 整体非空 → 整段跳过；逐 code 增量补齐留给 Step 8.3 的联网刷新）。

UI 层 / 设置入口：
- `lib/features/settings/settings_providers.dart`（新建）：`@Riverpod(keepAlive: true) class MultiCurrencyEnabled extends _$MultiCurrencyEnabled`。`build()` 读 `user_pref.multi_currency_enabled` → bool；`set(bool enabled)` 写 user_pref + `invalidateSelf()`。与 Step 4.1 的 `CurrentLedgerId` AsyncNotifier 同模式，是后续 settings 模块的"单字段开关"基底。
- `lib/features/settings/multi_currency_page.dart`（新建）：`MultiCurrencyPage` ConsumerWidget。`SwitchListTile`（挂 `Key('multi_currency_switch')`）+ "内置币种" ListTile（展示 `kBuiltInCurrencies.map(code).join(' · ')`）+ "汇率管理"占位 ListTile（disabled，文案"Step 8.3 接入联网刷新与手动覆盖"）。
- `lib/app/app_router.dart`：新增 `GoRoute('/settings/multi-currency')` → `MultiCurrencyPage`。
- `lib/app/home_shell.dart`：`_MeTab` 在"资产"项之后追加"多币种"项（`Icons.public` → `context.push('/settings/multi-currency')`）。

记账页接线：
- `lib/features/record/widgets/number_keyboard.dart`：`NumberKeyboard` 加 `bool showCurrencyKey = true` 参数；构建左下角 'CURRENCY' 位时用 `key == 'CURRENCY' && !showCurrencyKey ? const SizedBox(height: 65) : _KeyButton(...)` 决定渲染。**保持 4×4 网格布局**——只是把币种按钮替换成等高空 SizedBox，不让其它键变形或换位。点击事件在该位为空时也不响应。
- `lib/features/record/record_new_page.dart`：`_RecordNewPageState.build` 内 `ref.watch(multiCurrencyEnabledProvider).valueOrNull ?? false`，把结果作为 `NumberKeyboard.showCurrencyKey` 透传。loading/error 期间默认按"关闭"显示——避免短暂闪现币种键的不一致体验。

测试：
- `test/data/local/fx_rate_test.dart`（新建，11 用例）：
  1. `FxRateDao` × 3：`upsert + listAll` 升序 / `upsert` 同 code 二次更新 / `getByCode` 命中与未命中。
  2. `DefaultSeeder` fx_rate 路径 × 4：空库 → 写入 [kFxRateSnapshot] 全集 / CNY = 1.0 且 11 种内置币种全覆盖 / 已有 fx_rate 不被覆盖（独立判空）/ ledger 已存在但 fx_rate 为空 → 仅种子化 fx_rate（验证 v5→v6 升级路径）。
  3. 内置币种常量 × 4：codes 顺序锁定 / [kFxRateSnapshot].keys 与 [kBuiltInCurrencies] 同集 / CNY 自身 = 1.0 / 每种币种有非空 symbol+中文 name。
- `test/features/settings/multi_currency_page_test.dart`（新建，5 用例）：覆盖 SwitchListTile 在 initial=false / 切换后 true / initial=true 三种状态；内置币种行展示三个 code 抽样；汇率管理行 disabled。`_TestMultiCurrencyEnabled` fake notifier 走"override `build` + override `set` 直接 `state = AsyncValue.data(...)`"模式，避免 dependencies on real DB。
- `test/features/record/record_new_page_test.dart`：
  - `_baseOverrides` 加 `bool multiCurrencyEnabled = false` 参数 + `_TestMultiCurrencyEnabled` 类，默认与生产一致（false）。
  - 原"数字键盘完整渲染"用例改为传 `multiCurrencyEnabled: true`（含 'CNY' 键断言）。
  - 新增 2 条 Step 8.1 验收用例：① 开关关闭时 'CNY' 不可见、其它键仍渲染保持布局；② 开关开启时 'CNY' 可见。

验证摘要：`dart run build_runner build --delete-conflicting-outputs` → 155 outputs；`flutter analyze` → No issues found；`flutter test` → 222/222 通过（204 前 + 11 fx_rate + 5 multi_currency_page + 2 record_new_page Step 8.1 = 222）；`dart run custom_lint` → 仍是 3 条预存 INFO（与 record_new_providers.dart 相关），与本步无关。


## Phase 8 · Step 8.2 增量说明（2026-05-02）

Provider 与纯函数：
- `lib/features/settings/settings_providers.dart`：新增 `currentLedgerDefaultCurrencyProvider`（依赖 `currentLedgerIdProvider` + `ledgerRepositoryProvider`，账本切换 / 编辑后自动重算；读取失败兜底 `'CNY'`）+ `fxRatesProvider`（dump `fx_rate` 表为 `Map<String, double>`，code → rate_to_cny；后续 Step 8.3 联网刷新或用户手动覆写后会 invalidate）+ 顶层纯函数 `computeFxRate(from, to, ratesToCny)`（`from == to → 1.0` / 任一码缺失或 `toRate == 0` 兜底 1.0 / 否则 `from/to`）。本文件因新增 `Ref` 类型 import 加上 `package:flutter_riverpod/flutter_riverpod.dart`。

记账表单：
- `lib/features/record/record_new_providers.dart`：保留 `toggleCurrency()`（不再被 UI 调用，Step 8.3 之后再决定移除）；新增 `setCurrency(String code)` 与 `initDefaultCurrency()`（async，把 `state.currency` 设为账本默认币种；当 `state.currency != 'CNY'` 时跳过，避免覆盖已选/已 preload 的值）。`save()` 在保存前 `ref.read currentLedgerDefaultCurrencyProvider + fxRatesProvider`，调 `computeFxRate` 算出"原币 → 账本默认币种"的换算因子写入 `tx.fxRate`，与 `currency` 一同持久化。
- `lib/features/record/record_new_page.dart`：`initState` 内 `addPostFrameCallback` 触发 `initDefaultCurrency()`（fire-and-forget，与 `initDefaultAccount()` 同模式）。`_AmountDisplay` 改为按 `kBuiltInCurrencies` 查 `symbol`（移除硬编码 `¥` / `$`）。`NumberKeyboard.onCurrencyTap` 由 toggle 改为打开 `_CurrencyPicker` 底部抽屉——抽屉新增同文件，`ListView.builder` 渲染 11 内置币种、当前选中尾部 ✓、点击 `Navigator.pop(context, code)` 把 ISO 码回传，外层 `setCurrency(picked)`。

记账首页 / 流水：
- `lib/features/record/record_home_page.dart`：新增顶层 `_symbolFor(String code)` 私有 helper 与顶层 `@visibleForTesting` 函数 `formatTxAmountForDetail(tx, ledgerCurrency)`——同币种 → `±¥10.00`；跨币种 → `±USD 10.00（≈ ¥72.00）`（`amount * fxRate` 即折合，无需读 fx_rate 表）。`_TxTile` 显示金额改用 `_symbolFor(tx.currency)`（保留原币展示）。`_DataCards` 升级为 `ConsumerWidget`，watch `currentLedgerDefaultCurrencyProvider` 拿账本默认币种 symbol 传给 `_CardChip`，使顶部卡片在 USD 账本下显示 `$X.XX`。`_RecordDetailSheet` 升级为 `ConsumerWidget`，watch 同 provider 后调 `formatTxAmountForDetail(tx, ledgerCurrency)`，并把容器挂上 `Key('detail_amount')`。

统计聚合：
- `lib/features/record/record_providers.dart`：`recordMonthSummary` 收入/支出累加从 `tx.amount` 改为 `tx.amount * tx.fxRate`，与"卡片显示账本默认币种 symbol"一致。
- `lib/features/stats/stats_range_providers.dart`：`aggregatePieSlices` / `aggregateRankItems` / `aggregateHeatmapCells` / `statsLinePoints` 内的所有 `tx.amount` 求和改为 `tx.amount * tx.fxRate`。同币种流水 `fxRate = 1.0`，因此 V1 单币种用户行为完全不变；多币种开启后才真正起作用。
- `lib/features/budget/budget_progress.dart`：`computePeriodSpent` 与 `_spentBetween` 同样改为 `tx.amount * tx.fxRate`——预算金额本身是账本默认币种，两侧单位一致。
- **未触动** `lib/features/account/account_balance.dart`——账户余额按原币累加（每个账户有自己的 currency），跨币种总资产换算超出 Step 8.2 范围（V1 简化：跨币种转账留空，单账户内币种应与 account.currency 一致）。

测试：
- `test/features/settings/fx_rate_compute_test.dart`（新建，8 用例）：`computeFxRate` 同币种 / USD↔CNY / USD↔EUR / USD 10×7.2=72 验收 / 源缺失 / 目标缺失 / 除零保护。
- `test/features/stats/stats_range_providers_test.dart`：新增 3 用例覆盖 pie / rank / heatmap 在 USD 10、fxRate 7.2 下计入 72 CNY；现有用例 `fxRate` 默认 1.0 → 行为不变。
- `test/features/record/record_new_providers_test.dart`：新增 `_FakeLedgerRepository` + `_testLedger` + `currentLedgerDefaultCurrencyProvider` / `fxRatesProvider` / `ledgerRepositoryProvider` overrides；新增 6 个 Step 8.2 用例（setCurrency / initDefaultCurrency 默认 / initDefaultCurrency 不覆盖非 CNY / save 跨币种 USD 10 写入 fxRate=7.2 / save 同币种 fxRate=1.0 / save 跨币种到 USD 账本 fxRate=1/7.2）。
- `test/features/record/record_new_page_test.dart`：`_baseOverrides` 加 `currentLedgerDefaultCurrencyProvider` + `fxRatesProvider` 注入；新增 2 个 Step 8.2 widget 用例（点 CNY 键打开下拉 + 选 USD 后金额前缀变 `$` / 保存 USD 10 → fxRate=7.2、折合 72 CNY）。
- `test/features/record/record_home_page_format_test.dart`（新建，6 用例）：`formatTxAmountForDetail` 同币种 / USD 10×7.2 → "-USD 10.00（≈ ¥72.00）" / 收入用 `+` / 转账无符号 / CNY → USD 账本 / JPY 1500 千分位逗号。

验证摘要：`dart run build_runner build --delete-conflicting-outputs` → 70 outputs；`flutter analyze` → No issues found；`flutter test` → 247/247 通过（222 前 + 25 Step 8.2 = 247）；`dart run custom_lint` → 仍是 3 条预存 INFO（`record_new_providers.dart`），与本步无关。


## Phase 8 · Step 8.3 增量说明（2026-05-02）

数据层 / Schema：
- `lib/data/local/tables/fx_rate_table.dart`：新增 `is_manual INTEGER NOT NULL DEFAULT 0` 列。`1` = 用户在"我的 → 多币种 → 汇率管理"手动覆盖；`0` = 由种子化 / 自动刷新写入。CNY 永远保持 `is_manual=0` 且服务层过滤掉 CNY，避免覆写基准。
- `lib/data/local/tables/user_pref_table.dart`：新增 `last_fx_refresh_at INTEGER`（nullable）。每日刷新节流锚点；NULL = 从未刷新。
- `lib/data/local/app_database.dart`：`schemaVersion` 从 v6 升 v7；`onUpgrade` 新增 `if (from < 7)` 分支：`m.addColumn(fxRateTable, fxRateTable.isManual)` + `m.addColumn(userPrefTable, userPrefTable.lastFxRefreshAt)`。Schema 版本注释同步追加 v7 行。
- `lib/data/local/dao/fx_rate_dao.dart`：在原有 `listAll` / `getByCode` / `upsert` 之外新增 3 个方法。
  - `setAutoRate({code, rateToCny, updatedAt})`：自动刷新写入。先 `getByCode`：不存在 → insert（`is_manual=0`）；存在且 `is_manual=0` → update；存在且 `is_manual=1` → 跳过。返回写入行数（0 表示被手动行跳过）。
  - `setManualRate({code, rateToCny, updatedAt})`：用户手动覆盖。`insertOnConflictUpdate` 写入并把 `is_manual=1`。
  - `clearManualFlag(code)`：把 `is_manual` 置回 0；汇率本身不动，等下次自动刷新覆盖（短暂保留旧值，避免出现"无值"中间态）。

服务层：
- `lib/features/settings/fx_rate_refresh_service.dart`（新建）：`FxRateRefreshService` 三公开 API。
  - `refreshIfDue({force=false})`：受 `user_pref.last_fx_refresh_at` 节流（默认 24h）。`force=true`（"立即刷新"按钮）绕过节流。fetcher 抛异常 / 返回空 Map / 返回非有限数 / 返回 0 或负数都被防御性跳过——任何失败都返回 false 且**不**推进 `last_fx_refresh_at`，保证下次启动还能重试。CNY 在写入前过滤掉。
  - `setManualRate(code, rate)`：参数校验（非 CNY、正有限数）后调 DAO 写入 `is_manual=1`；包装异常为 `ArgumentError`。
  - `resetToAuto(code)`：调 DAO `clearManualFlag`。
  - `defaultFxRateFetcher`（顶层）：默认 fetcher 走 `https://open.er-api.com/v6/latest/CNY`（免费、无 API key、ECB+Fed 数据源）。返回 `1 CNY = X target`，需要倒数得到 `rate_to_cny[code] = 1 / X`。仅对 [kBuiltInCurrencies] 中的非 CNY 币种返回结果；任何字段缺失或非法都跳过该币种（不抛异常，整体仍可成功）。
  - `FxRateFetcher` typedef：`Future<Map<code, rate_to_cny>> Function()`。测试可注入伪造 fetcher 验证 throttle / failure / manual-skip 行为而不依赖网络。

Provider 层：
- `lib/features/settings/settings_providers.dart`：
  - 新增 `fxRateRowsProvider`（`@Riverpod(keepAlive: true)`）：dump `fx_rate` 全字段行（含 `is_manual` / `updated_at`），供"汇率管理"列表渲染。与 `fxRatesProvider` 区分——后者只暴露 `code → rate`（供换算），本 provider 暴露视图所需全字段。
  - 新增 `fxRateRefreshServiceProvider`（`@Riverpod(keepAlive: true)`）：返回 `FxRateRefreshService(db: ref.watch(appDatabaseProvider))`，生产 fetcher 默认走 `defaultFxRateFetcher`。
- `lib/main.dart`：bootstrap `await defaultSeedProvider.future` 之后追加 fire-and-forget `container.read(fxRateRefreshServiceProvider).refreshIfDue()`。成功后 invalidate `fxRatesProvider` / `fxRateRowsProvider`；catchError 静默吞掉，不影响首帧。`unawaited(...)` 显式标注 fire-and-forget。

UI 层：
- `lib/features/settings/multi_currency_page.dart`（重写，从 ConsumerWidget 升级为 ConsumerStatefulWidget）：
  - 顶部 AppBar 右侧 `IconButton(Icons.refresh, key: 'fx_refresh_now')`：刷新中显示 `CircularProgressIndicator`，点击触发 `service.refreshIfDue(force: true)`，成功 → "汇率已更新"，失败 → "联网失败，使用现有快照"。
  - 三段：① 多币种 SwitchListTile（与 Step 8.1 一致）；② 内置币种概览（与 Step 8.1 一致）；③ "汇率管理"标题 + 11 行 `_FxRateTile`（每行渲染 code + 中文名 + 汇率 + 4 位小数 + 更新时间 + 手动/自动徽章；CNY 行显示"基准"徽章 + disabled）。
  - 入页 `addPostFrameCallback` fire-and-forget `service.refreshIfDue()`（节流，不 force）；成功后 invalidate 行列表。
  - 点击非 CNY 行 → `_ManualRateDialog`（StatefulWidget）：TextField 数字输入（默认 `numberWithOptions(decimal: true)`）+ 校验（正有限数）+ "保存"按钮。手动行额外显示"重置为自动"按钮 + 提示文案。返回 `_ManualResult(rate?, reset)` 由父组件分发到 `service.setManualRate` / `service.resetToAuto`。
  - 视图模型 `FxRateRow.fromEntry(FxRateEntry)`：把 drift 行解耦成 UI 用结构（`isManual: bool`），便于 widget 测试 + 服务层 fake。

测试：
- `test/features/settings/fx_rate_refresh_service_test.dart`（新建，15 用例）：
  - 节流 × 4：从未刷新即触发 / < 24h 跳过 / >= 24h 重发 / `force=true` 绕过节流。
  - 失败静默 × 3：fetcher 抛异常 → 不更新 fx_rate 也不推进 `last_fx_refresh_at` / 返回空 Map / 返回非有限/非正数（NaN / 负数 / 0）跳过该币种但其他正常币种仍写入。
  - 手动覆盖与重置 × 5：手动行不被自动刷新覆盖 / `resetToAuto` 后下次刷新可覆盖 / CNY 在 fetcher 返回时被服务层过滤掉永远保持 1.0 / `setManualRate` 拒绝 CNY / 拒绝非正数 / 写入新行（fx_rate 表中不存在的 code 也能被手动覆盖）。
- `test/data/local/fx_rate_test.dart`：在原 11 用例基础上补 6 个 Step 8.3 DAO 用例（默认 is_manual=0 / `setAutoRate` 在新行插入 / `setAutoRate` 跳过手动行 / `setManualRate` 写入并标 1 / `clearManualFlag` 清标记保留 rate / `clearManualFlag` 对不存在 code 返回 0），原"upsert + listAll"用例补 `is_manual` 默认值断言。
- `test/features/settings/multi_currency_page_test.dart`（重写）：注入 `_FakeRefreshService`（实现 `FxRateRefreshService` 接口的内存 fake，记录 `refreshCalls` / `refreshForceCalls` 并在 `setManualRate` / `resetToAuto` 调用时同步更新内存 rows），覆盖 11 用例：原开关 3 用例 + 内置币种行 + Step 8.3 新 7 用例（汇率列表渲染 / CNY 行禁用 + "基准"徽章 / 点击 USD 行 → 输入 → setManualRate / 点击 EUR（手动行）→ "重置为自动" / 点击 CNY 行无反应 / AppBar 立即刷新成功提示 / 立即刷新失败降级提示 / 入页 fire-and-forget refreshIfDue）。

验证摘要：`dart run build_runner build --delete-conflicting-outputs` → 38 outputs；`flutter analyze` → No issues found；`flutter test` → 270/270 通过（247 前 + 15 fx_rate_refresh_service + 6 fx_rate_dao Step 8.3 + 7 multi_currency_page Step 8.3 - 5 multi_currency_page 老用例移除/合并 = 270）；`dart run custom_lint` → 6 条 INFO（3 条预存 `record_new_providers.dart` + 3 条新 `multi_currency_page_test.dart` 关于 `scoped_providers_should_specify_dependencies`，仅测试 override 风格，不影响生产）。

依赖：`pubspec.yaml` 新增 `http: ^1.2.0`（`open.er-api.com` GET 请求）。在此之前 `http` 已是 `supabase_flutter` 的间接依赖；显式声明以满足 `depend_on_referenced_packages`。
