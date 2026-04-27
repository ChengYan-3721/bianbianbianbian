# 架构说明

本文件记录项目**当前**运行期结构：哪些文件/目录存在、各自承担什么职责、模块间如何依赖。每当新增或重构关键文件/目录时同步更新。

- 设计意图（为什么这么做）看 `design-document.md`；
- 阶段路线与验收标准看 `implementation-plan.md`；
- 已完成步骤的时间线看 `progress.md`。

---

## 当前文件一览（Phase 4 · Step 4.1 账本列表后）

```
bianbianbianbian/
├─ lib/
│  ├─ main.dart                 应用入口：Riverpod bootstrap（预热 defaultSeedProvider）+ 错误兜底
│  ├─ app/
│  │  ├─ app.dart               BianBianApp 根组件（MaterialApp.router）
│  │  ├─ app_router.dart        顶层 goRouter（/ → HomeShell, /record/new → RecordNewPage）
│  │  ├─ app_theme.dart         appTheme + BianBianSemanticColors ThemeExtension
│  │  └─ home_shell.dart        底部 4 Tab 骨架页（Step 4.1：记账=RecordHomePage / 账本=LedgerListPage）
│  ├─ core/
│  │  ├─ crypto/
│  │  │  └─ bianbian_crypto.dart  BianbianCrypto（PBKDF2 + AES-256-GCM）+ DecryptionFailure
│  │  ├─ network/               [空] Supabase 客户端工厂（双模）
│  │  └─ util/                  [空] 通用工具（如 QuickTextParser）
│  ├─ data/
│  │  ├─ local/
│  │  │  ├─ app_database.dart         drift AppDatabase（schemaVersion=3；v2->v3 重建 category）
│  │  │  ├─ app_database.g.dart       build_runner 产物
│  │  │  ├─ db_cipher_key_store.dart  本地 DB 加密密钥的生成/持久化
│  │  │  ├─ device_id_store.dart      device_id 加载器（secure ↔ user_pref 双向同步）
│  │  │  ├─ seeder.dart               DefaultSeeder（首次启动默认数据种子化）
│  │  │  ├─ providers.dart            @Riverpod appDatabase / deviceId / defaultSeed 三个 provider
│  │  │  ├─ providers.g.dart          riverpod_generator 产物
│  │  │  ├─ dao/
│  │  │  │  ├─ ledger_dao.dart              LedgerDao + .g.dart（Step 1.4）
│  │  │  │  ├─ category_dao.dart            CategoryDao + .g.dart（Step 1.4）
│  │  │  │  ├─ account_dao.dart             AccountDao + .g.dart（Step 1.4）
│  │  │  │  ├─ transaction_entry_dao.dart   TransactionEntryDao + .g.dart（Step 1.4）
│  │  │  │  ├─ budget_dao.dart              BudgetDao + .g.dart（Step 1.4）
│  │  │  │  └─ sync_op_dao.dart             SyncOpDao + .g.dart（Step 2.2，供仓库层写队列）
│  │  │  └─ tables/
│  │  │     ├─ user_pref_table.dart         §7.1 user_pref 表定义
│  │  │     ├─ ledger_table.dart            §7.1 ledger 表
│  │  │     ├─ category_table.dart          重构版 category 表（parent_key/is_favorite，全局二级分类）
│  │  │     ├─ account_table.dart           §7.1 account 表
│  │  │     ├─ transaction_entry_table.dart §7.1 transaction_entry 表（FK→ledger）
│  │  │     ├─ budget_table.dart            §7.1 budget 表
│  │  │     └─ sync_op_table.dart           §7.1 sync_op 队列表（AUTOINCREMENT id）
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
│     ├─ stats/                 [空] 统计
│     ├─ ledger/                Step 4.1 已填充：正式账本列表页
│     │  ├─ ledger_list_page.dart       LedgerListPage（账本卡片列表 + 切换 + 归档折叠区）
│     │  ├─ ledger_list_page.g.dart     riverpod_generator 产物
│     │  ├─ ledger_providers.dart       LedgerTxCounts AsyncNotifier（各账本流水条数）
│     │  └─ ledger_providers.g.dart     riverpod_generator 产物
│     ├─ budget/                [空] 预算
│     ├─ account/               [空] 资产账户
│     ├─ sync/                  [空] 同步 UI + 状态
│     ├─ trash/                 [空] 垃圾桶
│     ├─ lock/                  [空] 应用锁
│     ├─ import_export/         [空] 导入导出
│     └─ settings/              [空] 设置
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
│  │     └─ db_cipher_key_store_test.dart    密钥生成/持久化（4 用例）
│  ├─ data/
│  │  └─ repository/
│  │     └─ transaction_repository_test.dart TransactionRepository 4 条用例（Step 2.2）
│  ├─ domain/
│  │  └─ entity/
│  │     └─ entities_test.dart               5 个实体 roundtrip/copyWith + drift 隔离（17 用例，Step 2.1）
│  ├─ features/
│  │  └─ record/
│  │     ├─ record_new_providers_test.dart  RecordForm Notifier 单元测试（含 Step 3.5 附件序列化断言）
│  │     └─ record_new_page_test.dart        RecordNewPage widget 测试（含 Step 3.5 附件 UI 回归）
│  └─ widget_test.dart          Widget 测试（HomeShell + 首页流水列表覆盖 5 用例）
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
  - 统计（index=1）：占位大标题；Phase 5 填充。
  - 账本（index=2）：`LedgerListPage`（Step 4.1 接入，ConsumerWidget，正式卡片列表 + 点击切换）。
  - 我的（index=3）：占位大标题；Phase 17 填充。
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
    - **`schemaVersion = 3`（Phase 3 分类重构）**：
      - v1：`user_pref`
      - v2：新增 `ledger/category/account/transaction_entry/budget/sync_op` + transaction 索引
      - v3：`category` 改为“全局二级分类”模型（`parent_key` + `is_favorite`，移除 `ledger_id` + `type`）
    - **`MigrationStrategy`**：
      - `onCreate`：`m.createAll()` + `_createTransactionIndexes()`
      - `onUpgrade`：`from < 2` 时创建 v2 业务表；`from < 3` 时按产品要求**不兼容旧分类结构**，执行 `deleteTable('category')` 后 `createTable(categoryTable)` 重建。
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
  - **`tables/account_table.dart`**（Step 1.3）：`AccountTable` + `@DataClassName('AccountEntry')`。`type` ∈ `cash` / `debit` / `credit` / `third_party` / `other`；`initial_balance` REAL 默认 0（信用卡可为负）；`include_in_total` 默认 1；`currency` 默认 `'CNY'`。账户不绑定账本——全局资源。
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
    - `account_repository.dart`：`listActive()` / `save(Account)` / `softDeleteById(id)`
    - `transaction_repository.dart`：`listActiveByLedger(ledgerId)` / `save(TransactionEntry)` / `softDeleteById(id)`
    - `budget_repository.dart`：`listActiveByLedger(ledgerId)` / `save(Budget)` / `softDeleteById(id)`
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
- HomeShell 骨架测试，共 4 用例（Step 2.3 重写）：
  1. HomeShell renders all 4 bottom-nav tabs（Tab 名在 nav bar 各出现一次）。
  2. BottomNavigationBar background is cream yellow `#FFE9B0`。
  3. Tapping "统计" tab switches body text（body + nav bar 各一处"统计"）。
  4. 记账 Tab 通过 provider 显示当前账本名称：注入 `_FakeLedgerRepository` 返回"测试账本"，验证 `find.text('测试账本')` + Key 断言。
- 所有测试通过 `ProviderScope(overrides: _standardOverrides())` 注入 `currentLedgerIdProvider`（固定字符串） + `ledgerRepositoryProvider`（`_FakeLedgerRepository` 实例），避免 `_RecordTabBody` 中的 `CircularProgressIndicator` 导致 `pumpAndSettle` 超时。
- `_FakeLedgerRepository` 实现 `LedgerRepository` 接口：`getById` 返回固定 Ledger、`listActive` 返回单元素列表、`save`/`softDeleteById` 走 `fail()`。

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
- 当前边界：
  - 已完成 Step 3.5；
  - Step 4.1 已于 2026-04-26 完成，账本列表正式上线。

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

- 当前边界：
  - 已完成 Step 4.1；
  - 按任务约束，在用户验证前不开始 Step 4.2。

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

- 当前边界：
  - 已完成 Step 4.2；
  - 按任务约束，在用户验证前不开始 Step 4.3。