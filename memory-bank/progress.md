# 开发进度

按实施计划 `implementation-plan.md` 的步骤顺序推进，每完成一步在此追加一条记录（含改动要点、验证结果、给后续开发者的备忘）。

---

## Phase 0 · 项目基线

### ✅ Step 0.1 清理脚手架（2026-04-19）

**改动**
- `lib/main.dart`：删除 Flutter 默认计数器 Demo（`MyApp` / `MyHomePage` / `_counter` 相关全部移除）。根组件改名为 `BianBianApp`，返回最小 `MaterialApp`；`home` 为 `Scaffold`，AppBar 标题"边边记账"，body 为 `SizedBox.shrink()`。
- `test/widget_test.dart`：移除计数器递增断言，改为 `expect(find.text('边边记账'), findsOneWidget)` 验证 AppBar 文字。

**验证**:`flutter analyze` 零错误零警告；`flutter test` 通过；`flutter run` 首页 AppBar 显示"边边记账"。用户本机手工验证通过。

**给后续开发者的备忘**
- 此刻 `MaterialApp` 没有 `ProviderScope`、没有路由、没有主题——这三件分别由 Step 0.3（基础依赖 + Riverpod 包裹）和 Step 0.4（路由骨架 + 奶油兔主题）接入。
- `BianBianApp.home` 仅是占位壳。Step 0.4 会把 `home` 替换为 `HomeShell`（4 Tab 底部栏），届时 `widget_test.dart` 需要相应扩展（至少断言 4 个 Tab 文字渲染）。

### ✅ Step 0.2 目录骨架（2026-04-19）

**改动**
- 在 `lib/` 下新建 19 个空目录，每个目录内放一个 `.gitkeep` 占位文件，目录结构与 `design-document.md` §8.3 完全一致：
  - `app/`
  - `core/crypto/`、`core/network/`、`core/util/`
  - `data/local/`、`data/remote/`、`data/repository/`
  - `domain/entity/`、`domain/usecase/`
  - `features/record/`、`features/stats/`、`features/ledger/`、`features/budget/`、`features/account/`、`features/sync/`、`features/trash/`、`features/lock/`、`features/import_export/`、`features/settings/`

**验证**：目录结构比对通过；`flutter analyze` 仍零错误。用户本机手工验证通过。

**给后续开发者的备忘**
- 本项目目前**不是** git 仓库（见 `CLAUDE.md`），`.gitkeep` 仅作占位；将来 `git init` 后这些空目录才真正能被追踪。
- 当一个目录下放入首个真实文件时，可以删除该目录的 `.gitkeep`。
- 每个目录的未来职责见 `architecture.md` 的"各文件/目录职责"节。

### ✅ Step 0.3 基础依赖接入（2026-04-19）

**改动**
- `pubspec.yaml` `dependencies` 新增（按实施计划 §Step 0.3 清单）：`go_router ^17.2.1`、`flutter_riverpod ^2.6.1`、`riverpod_annotation ^2.6.1`、`drift '>=2.22.0 <2.28.2'`、`sqlite3_flutter_libs ^0.6.0+eol`、`sqlcipher_flutter_libs ^0.7.0+eol`、`path_provider ^2.1.5`、`path ^1.9.1`、`supabase_flutter ^2.12.4`、`shared_preferences ^2.5.5`、`flutter_secure_storage ^10.0.0`、`cryptography ^2.9.0`、`fl_chart ^1.2.0`、`flutter_svg ^2.2.4`、`local_auth ^3.0.1`、`flutter_local_notifications ^21.0.0`、`intl ^0.20.2`、`uuid ^4.5.3`、`flutter_localizations`（sdk）。
- `pubspec.yaml` `dev_dependencies` 新增：`build_runner ^2.4.13`、`drift_dev '>=2.22.0 <2.28.2'`、`riverpod_generator ^2.6.3`、`custom_lint ^0.7.4`、`riverpod_lint ^2.6.3`。
- `analysis_options.yaml`：在 `include` 下方新增 `analyzer.plugins: [custom_lint]` 块，让 IDE/CLI 能加载 `riverpod_lint` 规则。
- `android/app/build.gradle.kts`：为满足 `flutter_local_notifications` 的要求，在 `compileOptions` 中启用 `isCoreLibraryDesugaringEnabled = true`，并新增 `dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") }` 块。

**验证**
- `flutter pub get` 成功解析（伴随"27 包有更新但被约束锁定"的 info 提示，属正常）。
- `flutter analyze` 零错误零警告。
- `flutter test` 通过（原 AppBar 标题断言仍绿）。
- `dart run custom_lint` 报 1 条 INFO `missing_provider_scope`——这是 riverpod_lint 提示 `runApp` 还未被 `ProviderScope` 包裹；该包裹动作归属 Step 0.4，本步刻意不动 `main.dart`。
- 用户本机 `flutter run` 成功启动（Android 端构建需要上文的 desugaring 配置）。

**给后续开发者的备忘**
- 暂未运行 `dart run build_runner build`：目前项目里还没有需要 code-gen 的源文件（drift DAO、riverpod `@riverpod` 注解等要到 Phase 1 / Phase 2 才会出现）。首次真正需要时再跑。
- `flutter_secure_storage ^10.0.0` 的 Android 端要求 minSdk ≥ 23；当前 `minSdk = flutter.minSdkVersion`（通常为 21）。Step 0.4 或之后若触发冲突，需在 `android/app/build.gradle.kts` 手动把 `minSdk = 23`。
- `flutter_local_notifications ^21.0.0` 已经靠 desugaring 过构建；若未来升级到 22+，需留意是否要求更高 desugar_jdk_libs 版本。
- iOS / macOS 侧尚未配置（`flutter_local_notifications`、`local_auth` 等会要求 Info.plist 权限描述字符串）。首个在 iOS 真机上跑的 Phase 需要补齐。
- 依赖版本整体略落后于 pub.dev 最新（例如 `flutter_riverpod` 锁在 2.x，最新 3.x）——这是为了彼此 API 兼容的合理权衡；如需整体升级，应作为专门一步执行并逐个验证迁移。

### ✅ Step 0.4 路由与主题骨架（2026-04-19）

**改动**
- `lib/app/app_theme.dart`（新建）：暴露 `appTheme`。基于设计文档 §10.2 奶油兔色板构造显式 `ColorScheme`（primary=奶油黄 `#FFE9B0`、tertiary=可可棕 `#8A5A3B`、secondary=樱花粉 `#FFB7C5`、surface=米白 `#FFF9EF`、error=苹果红 `#E76F51`）。按 §10.5 配置 `cardTheme`（圆角 16 / 阴影 `Color(0x148A5A3B)` 即 rgba(138,90,59,.08)）、`bottomNavigationBarTheme`（背景奶油黄、选中可可棕）。抹茶绿 / 蜜橘 / 苹果红三个语义色放入 `BianBianSemanticColors`（一个 `ThemeExtension`），避免污染 M3 ColorScheme，后续 stats/budget 通过 `Theme.of(context).extension<BianBianSemanticColors>()!` 读取。
- `lib/app/app_router.dart`（新建）：顶层 `final GoRouter goRouter`，`initialLocation = '/'`，当前只一条 `GoRoute('/')` → `HomeShell`。
- `lib/app/home_shell.dart`（新建）：`HomeShell` StatefulWidget。`BottomNavigationBar` 的 4 Tab 写在一个 `const List<_HomeTab>` 中（记账 `Icons.edit_note`、统计 `Icons.pie_chart_outline`、账本 `Icons.menu_book_outlined`、我的 `Icons.person_outline`）；body 仅居中显示当前 Tab 的 label 占位。
- `lib/app/app.dart`（新建）：`BianBianApp` 改用 `MaterialApp.router`，注入 `theme: appTheme` 与 `routerConfig: goRouter`，`debugShowCheckedModeBanner: false`。
- `lib/main.dart`：精简为 `runApp(const ProviderScope(child: BianBianApp()));`——把旧的根组件实现迁出到 `lib/app/app.dart` 之后，main.dart 只剩 Riverpod 作用域包裹。
- `lib/app/.gitkeep`：删除（该目录已有真实文件）。
- `test/widget_test.dart`：改为 3 条用例：① HomeShell 渲染 4 个 Tab 文字；② `BottomNavigationBar.backgroundColor`（或主题回退）等于 `#FFE9B0`；③ 点击"统计"后 body 切换为"统计"。

**验证**
- `flutter analyze` 零错误零警告。
- `flutter test` 3/3 通过。
- `dart run custom_lint` 零 issue（上一步的 `missing_provider_scope` INFO 随 `ProviderScope` 接入消失）。
- 用户本机 `flutter run`：4 Tab 可切换、底栏奶油黄、视觉符合奶油兔风格。手工验证通过。

**给后续开发者的备忘**
- `goRouter` 目前是**顶层 final**，非 Riverpod Provider。Phase 10 开启同步后若路由需要监听登录态/会话，应改为 `@riverpod` provider 并在 `MaterialApp.router` 里用 `ref.watch(goRouterProvider)`；改造时注意所有现有 `context.go` 调用的导入保持不变。
- `HomeShell` 用的是**有状态本地 index** 而非嵌套路由（`StatefulShellRoute`）。只要 4 Tab 间不需要独立路径历史就够用；一旦 Phase 3 要求"记账 Tab 内部能深链到 `/record/new`"且"切 Tab 不丢失各自历史"，再迁移到 `StatefulShellRoute.indexedStack`。
- 主题已就位但**尚未接主题切换**（Step 15.1 的任务）。届时把 `appTheme` 改为由 `user_pref.theme` 驱动的 `Provider<ThemeData>`，`BianBianApp` 改用 `ConsumerWidget` 消费。
- 每个 Tab 的 body 目前仍是占位字符串。各 Phase 上线自己 Tab 的真实页面时，替换 `home_shell.dart` 中 `_HomeShellState.build` 的 `body` 分支即可——建议届时把 body 抽成 `IndexedStack`（保留各 Tab 内部滚动位置）。
- 当前测试依赖 `pumpAndSettle`，适用于静态 UI；Phase 3 起 FAB / Lottie 微动效可能导致其等待超时，届时需用 `pump(duration)` 手动步进。

---

## Phase 1 · 本地数据层

### ✅ Step 1.1 drift 数据库初始化（2026-04-20）

**改动**
- `lib/data/local/tables/user_pref_table.dart`（新建）：`UserPrefTable extends Table`，`tableName = 'user_pref'`，`@DataClassName('UserPrefEntry')`。字段严格照 design-document §7.1：`id`（PK，默认 1，带 CHECK 约束）、`device_id`（NOT NULL）、`current_ledger_id`、`default_currency`（默认 `'CNY'`）、`theme`（默认 `'cream_bunny'`）、`lock_enabled`（默认 0）、`sync_enabled`（默认 0）、`last_sync_at`、`ai_api_endpoint`、`ai_api_key_encrypted`（BLOB）均为 nullable——与 §7.1 SQL 的 nullability 一一对应。
- `lib/data/local/app_database.dart`（新建）：`AppDatabase extends _$AppDatabase`，`@DriftDatabase(tables: [UserPrefTable])`，`schemaVersion = 1`。生产构造 `AppDatabase()` → `_openConnection()` 返回 `LazyDatabase`，内部经 `path_provider.getApplicationDocumentsDirectory()` 取 `<docs>/bbb.db`，再 `NativeDatabase.createInBackground(file)`；测试构造 `AppDatabase.forTesting(super.executor)` 用于注入 `NativeDatabase.memory()`。顶层 `export 'package:drift/drift.dart' show Value;` 让调用方只 import 本文件也能用 `Value(...)`。
- `lib/data/local/app_database.g.dart`（build_runner 生成）。
- `lib/data/local/.gitkeep` 删除（目录已有真实文件）。
- `test/data/local/app_database_test.dart`（新建）：2 条用例——① 空库 `AppDatabase.forTesting(NativeDatabase.memory())` 上只传 `deviceId` 插入，读回后全字段断言（id=1、defaultCurrency='CNY'、theme='cream_bunny'、lock/syncEnabled=0、其余 nullable 字段为 null）；② 显式 `id: Value(2)` 插入应被 SQLite CHECK 约束抛错。

**验证**
- `dart run build_runner build --delete-conflicting-outputs` 成功（drift_dev 与 riverpod_generator 各自产出 0 错）。
- `flutter analyze` → No issues found。
- `flutter test` → 5/5 通过（2 新 + 3 原 widget 回归）。
- `dart run custom_lint` → No issues found。
- 用户本机 `flutter run` 启动不崩溃；目前 `main.dart` 完全不触达 `AppDatabase`，故行为与 Step 0.4 等价。手工验证通过。

**给后续开发者的备忘**
- `id` 列的 `CHECK (id = 1)` 用 `CustomExpression<bool>('id = 1')` 写，没用惯用的 `id.equals(1)`。原因：后者会让 Dart 分析器报 `recursive_getters` info（getter 内引用自身），虽为 info 不阻塞但本项目此前一直维持"零 issue"基线。未来若某列需要引用其他列（例如 `category.type.isIn([...])` 这类真·跨列 check），`CustomExpression` 就不适用了，届时可以改成 `id.isIn(...)` / `id.equals(...)` 并把 `// ignore: recursive_getters` 加在该 getter 上。
- 打开方式故意**仍是普通 `NativeDatabase`**（走 `sqlite3_flutter_libs`）而非 SQLCipher——这是 Step 1.1 的范围。Step 1.2 将：① 改成 `NativeDatabase.opened(sqlite3.open(path))` 或直接用 `sqlcipher_flutter_libs` 提供的打开器；② 注入 `PRAGMA key = ?` 密钥（来自 `flutter_secure_storage`）。**届时要同步把 `pubspec.yaml` 里的 `sqlite3_flutter_libs` 依赖移除**，否则 Android 会同时绑定标准 sqlite3 与 SQLCipher 的 `.so`，行为由 Gradle 编译顺序决定，极易踩坑（drift 文档明确警告）。
- 迁移策略（`MigrationStrategy`）**尚未接入**。Step 1.3 加 6 张业务表时会把 `schemaVersion` 从 1 升到 2，届时需在 AppDatabase 里 override `migration` 并处理 v1→v2 的 ADD TABLE。现在留空（drift 默认 `onCreate` 跑所有 CREATE TABLE）。
- `@DataClassName('UserPrefEntry')` 刻意起名为 `UserPrefEntry` 而非 `UserPref`，是给 Step 2.1 的领域实体 `UserPref`（若将来真要做这个实体）预留命名空间。当前 §7.1 表 → drift 数据类 `UserPrefEntry`，若 Step 2.1 做 `UserPref` 纯 Dart 实体，双方不冲突。
- `LazyDatabase` 保证 `getApplicationDocumentsDirectory()` 只在**首次真实查询**时被调用，而不是 `AppDatabase()` 构造时——这让 provider 布线（Step 2.3/1.5）可以安全地在 `ProviderScope` 内随处 new，不触发平台调用。
- 目前没有接 Riverpod provider（Step 1.5 会为 `device_id` 出一个，Step 2.3 统一为仓库布线）。UI 暂不应直接 `new AppDatabase()`——留给后续 provider 封装。

### ✅ Step 1.2 接入 SQLCipher（2026-04-20）

**改动**
- `pubspec.yaml`：
  - 移除 `sqlite3_flutter_libs`（Step 1.1 备忘指出必须移除，否则 Android 侧同时链入普通 sqlite3 与 SQLCipher 的 `.so`，drift 文档明确告警）。
  - `sqlcipher_flutter_libs` 从 `^0.7.0+eol`（EOL 空壳，只适配 sqlite3 3.x）降级为 `^0.6.5`（实际解析到 0.6.8）——本项目 drift 约束 `>=2.22.0 <2.28.2` 锁定 `sqlite3 2.9.x`，必须用 0.6.x 才能拿到真正的 SQLCipher 原生库 + `applyWorkaroundToOpenSqlCipherOnOldAndroidVersions()` 工具。Step 0.3 选 `^0.7.0+eol` 是当时的误判。
- `android/app/build.gradle.kts`：`defaultConfig.minSdk` 从 `flutter.minSdkVersion` 改为写死 `23`——`flutter_secure_storage ^10.0.0` 使用 `EncryptedSharedPreferences` 要求 API 23+（Step 0.3 备忘已标注此待办）。
- `lib/data/local/db_cipher_key_store.dart`（新建）：`DbCipherKeyStore` + `SecureKeyValueStore` 抽象接口 + `FlutterSecureKeyValueStore` 生产实现。`loadOrCreate()`：合法 64 字符小写 hex 存在 → 直接返回；否则 `Random.secure()` 生成 32 字节，hex 化后写入 `flutter_secure_storage` 条目 `local_db_cipher_key` 并返回。`Random` 与 `SecureKeyValueStore` 均可注入，便于测试。有意不暴露 `delete` / `containsKey`，避免业务路径误删密钥。
- `lib/data/local/app_database.dart`：`_openConnection()` 重命名为 `_openEncrypted()`：① 主 isolate 跑 `applyWorkaroundToOpenSqlCipherOnOldAndroidVersions()`；② 取 `DbCipherKeyStore().loadOrCreate()` 得 hex；③ `NativeDatabase.createInBackground` 注入 `isolateSetup`（后台 isolate 再跑一次 workaround）与 `setup`：`PRAGMA key = "x'<hex>'"` + `PRAGMA cipher_version` 断言（空结果集 → `StateError`，强制在启动早期而非写入后才暴露"未挂上 SQLCipher"问题）。`AppDatabase.forTesting(super.executor)` 构造完全不动，单元测试继续用 `NativeDatabase.memory()`。
- `test/data/local/db_cipher_key_store_test.dart`（新建）：4 条用例——① 首次调用生成 64 字符小写 hex 并写回底层 store；② 第二次调用返回同一值（持久化读回）；③ 底层存在非法值时覆写为新密钥；④ 两个独立实例用 `Random.secure()` 产出不同密钥（熵 sanity check）。通过注入内存实现的 `SecureKeyValueStore` 免去 platform channel mock。

**验证**
- `flutter pub get` → 成功解析，`sqlcipher_flutter_libs` 落在 0.6.8、移除 `sqlite3_flutter_libs`。有一条 "Building with plugins requires symlink support. Please enable Developer Mode" 的提示——Windows 专属，不影响 CI/测试，发真机构建前用户需要打开开发者模式。
- `dart run build_runner build --delete-conflicting-outputs` → 24 outputs，0 error。
- `flutter analyze` → No issues found。
- `flutter test` → 9/9 通过（原 2 + 原 3 widget + 新增 4 DbCipherKeyStore）。
- `dart run custom_lint` → No issues found。
- 用户本机 `flutter run` 待手工验证：首次启动能生成 DB、二次启动复用、DB 文件用普通 sqlite 打不开（见"设备级验证项"）。

**设备级验证项（由用户手工完成，测试框架覆盖不到）**
1. 首次冷启动后检查 `<documents>/bbb.db` 存在；用普通 `sqlite3 bbb.db` CLI 打开应报错 `file is not a database`（或读不出表）——这是 SQLCipher 已生效的标志。
2. 第二次冷启动直接读取既有 DB 不报 `StateError`——说明 `flutter_secure_storage` 里的 `local_db_cipher_key` 被正确读回并用于解密。
3. 卸载后重装，应是全新空库（`flutter_secure_storage` 在 Android/iOS 的卸载行为差异由系统保证，无需额外处理）。
4. Android 上 `adb logcat` 不应出现 `libsqlite3` 与 `libsqlcipher` 共存警告。

**给后续开发者的备忘**
- 单元测试走 `NativeDatabase.memory()`（普通 sqlite3），**不**复现 SQLCipher 加密——这是刻意选择：pure-dart 测试环境没法可靠地链到 SQLCipher native lib，且 schema 行为不受加密层影响。若未来新增"加密场景专属"的行为（比如密钥轮换），需要写 `integration_test/` 级别的设备测试。
- `PRAGMA key = "x'<hex>'"` 里的 `<hex>` 是 64 字符小写 hex；若写错长度 SQLCipher 不会立即报错，而是在第一次读写时抛 `SqliteException(26, 'file is not a database')`。Step 1.2 的 `PRAGMA cipher_version` 断言**不能**替代这一失败——它只验库装载，不验密钥正确。若以后调整密钥格式，务必在 `setup` 回调末尾再 `SELECT count(*) FROM sqlite_master` 之类做一次真实 I/O，确保解密通过。
- `DbCipherKeyStore` 生成的密钥**只保护本机 DB**。Phase 11 要做的"字段级加密"会派生另一把密钥（来自用户的同步密码 + salt，PBKDF2），两者命名空间不同、生命周期不同、不要混用；具体：① 本地 DB 密钥丢失 = 本机数据丢失（但云端未加密副本可恢复）；② 同步密码派生密钥丢失 = 云端敏感字段永久不可读（设计如此）。
- `createInBackground` 的 `setup` 回调是闭包——它捕获的 `cipherKeyHex` 会被序列化并送往后台 isolate。Dart 3.x 支持闭包跨 isolate 传递，前提是捕获的所有值都是 sendable（`String` 是）。若将来要捕获非 sendable 对象（比如活动的 `SendPort`、或 `Random.secure()` 实例），必须改用 top-level 函数或 static method。
- `NativeDatabase.createInBackground` 在后台 isolate 打开 DB——这避免了 UI 卡顿，代价是每次 SQL 查询都多一次 isolate 跳转。对记账这种低 QPS 场景完全值得。若 Phase 5 的统计聚合出现响应慢，先看 index 再考虑改 `NativeDatabase.opened`。
- 当前 Android `minSdk = 23` 写死。Flutter 官方偶尔会提升默认 `minSdkVersion`，但本项目 **不再**跟随——任何未来的 Flutter 版本升级都不会倒退此值。Step 0.3 记录的 `flutter_local_notifications` 的 desugar 设置与此独立，不冲突。
- `pubspec.yaml` 的 `sqlcipher_flutter_libs: ^0.6.5` 选 caret 是**刻意**保持对 0.6.x 的上限，不让 pub 自动升到 0.7.x（那是 sqlite3 3.x 才用的 EOL 空壳）。将来整体升级 drift 到 2.28+（迁到 sqlite3 3.x）时，需要一并把这里改成 `sqlcipher_flutter_libs` 的新建议版本（届时 API 改为在 `sqlite3` 包内 `OpenDynamicLibrary.withSqlCipher`）。
- Windows 下 `flutter pub get` 提示 "Developer Mode" ——这是 Flutter 3.x 在 Windows 上对 plugin symlink 的要求。仅影响 `flutter run`/`flutter build windows`，不影响 `flutter test`/`flutter analyze`。用户只要不在 Windows 上 run 应用，可以忽略。


### ✅ Step 1.3 核心业务表建表（2026-04-21）

**改动**
- `lib/data/local/tables/ledger_table.dart`（新建）：`LedgerTable` + `@DataClassName('LedgerEntry')`，字段严格照 §7.1——`id` (TEXT PK)、`name` (NOT NULL)、`cover_emoji`、`default_currency` 默认 `'CNY'`、`archived` 默认 0、`created_at` / `updated_at` (NOT NULL)、`deleted_at`、`device_id` (NOT NULL)。
- `lib/data/local/tables/category_table.dart`（新建）：`CategoryTable` + `@DataClassName('CategoryEntry')`。`ledger_id` 用 `.references(LedgerTable, #id)()` 声明外键；`type` / `sort_order` / 同步三件套全按 §7.1。
- `lib/data/local/tables/account_table.dart`（新建）：`AccountTable` + `@DataClassName('AccountEntry')`。`initial_balance` REAL 默认 0，`include_in_total` 默认 1，`currency` 默认 `'CNY'`。
- `lib/data/local/tables/transaction_entry_table.dart`（新建）：`TransactionEntryTable` + `@DataClassName('TransactionEntryRow')`——**刻意不叫 `TransactionEntry`**，留给 Step 2.1 的领域实体同名。`ledger_id` 声 FK 到 `ledger(id)`；`amount` / `currency` / `occurred_at` NOT NULL；`fx_rate` 默认 1.0；`note_encrypted` / `attachments_encrypted` 为 BLOB nullable（Phase 11 接字段级加密后装密文）。
- `lib/data/local/tables/budget_table.dart`（新建）：`BudgetTable` + `@DataClassName('BudgetEntry')`。`category_id` nullable 表示"总预算"；`carry_over` 默认 0（Step 6.4 真正使用）。
- `lib/data/local/tables/sync_op_table.dart`（新建）：`SyncOpTable` + `@DataClassName('SyncOpEntry')`。`id` 走 `integer().autoIncrement()`（drift 里 autoIncrement 隐式即主键，**不**再覆写 `primaryKey`——否则 drift_dev 报 `primary_key_and_auto_increment`）。无同步三件套（这是本机出站队列，不双向同步）。
- `lib/data/local/app_database.dart`（修改）：① `@DriftDatabase(tables: [...])` 列表加入 6 张新表；② `schemaVersion` 从 1 升到 2；③ 覆写 `MigrationStrategy`，`onCreate` 走 `m.createAll()` + `_createTransactionIndexes()`；`onUpgrade` 处理 `from < 2` 分支，逐表 `m.createTable(...)` + 两个 customStatement 建索引。索引走手写 SQL 而非 `@TableIndex` 注解，为的是保留 §7.1 里的 `DESC` 排序方向（drift 的 annotation 不支持 `DESC`）。
- `lib/data/local/app_database.g.dart`（build_runner 重生成）：新增 6 个 `$XxxTable` 生成类与 `late final xxxTable = ...` 7 个 getter。
- `lib/main.dart`（修改）：`catch` 分支里的 `runApp(_BootstrapErrorApp(...))` 外套 `ProviderScope`。此前 custom_lint 没扫到 catch 分支，本步新增业务表测试过程中 `dart run custom_lint` 才报出 `missing_provider_scope` INFO；修正后保持"所有 runApp 都在 ProviderScope 下"的基线。Step 1.2 的 progress.md 记录的"custom_lint → No issues found"实际遗漏此条，视为本步一并清掉。
- `test/data/local/business_tables_test.dart`（新建）：7 条用例——① ledger / category / account / transaction_entry / budget 各跑一次 insert → update(`updated_at` 自增) → soft-delete(写 `deleted_at`)；② `idx_tx_ledger_time` / `idx_tx_updated` 两索引存在性（查 `sqlite_master`）；③ sync_op 走队列语义 insert (AUTOINCREMENT 断言 id=1) → tried++ → 物理 delete。

**验证**
- `dart run build_runner build --delete-conflicting-outputs` 成功，写出 20 个 outputs，0 error。
- `flutter analyze` → No issues found。
- `flutter test` → 16/16 通过（2 user_pref + 7 business_tables + 4 db_cipher_key_store + 3 widget）。
- `dart run custom_lint` → No issues found（修复 `missing_provider_scope` 后）。
- 用户本机 `flutter run` 待手工验证：新装应用 DB 首次创建应走 onCreate 路径（v2 空库含全部表 + 索引）；若在 Step 1.1 / 1.2 已装过旧 v1 DB（仅 user_pref）再覆盖安装，drift 应走 onUpgrade v1→v2 路径追加 6 张表——**不**清空 user_pref 原有数据。

**给后续开发者的备忘**
- **FK 约束目前**未**强制**。`category.ledger_id` / `transaction_entry.ledger_id` 虽在 drift 里声明 `.references(...)`，但 SQLite 默认 `PRAGMA foreign_keys = OFF`，drift 也没替我们打开。测试中"先插 ledger 再插 category"是真实路径演练，不是强制要求。若 Phase 4 多账本软删要做到"删账本自动级联软删分类/流水"，那套级联要在仓库层实现，不要指望 SQLite FK；若未来真想开 FK 强制，需在 `_openEncrypted()` 的 `setup` 回调里加 `rawDb.execute('PRAGMA foreign_keys = ON')`，并同步在 `AppDatabase.forTesting` 构造后也打开（否则测试与生产行为不一致）。
- **索引用 `CREATE INDEX IF NOT EXISTS`** 是防御性的——正常 migration 流程不会重复建，但万一未来某次升级路径（比如 v2→v3 → rollback → 再 v2→v3）让 onCreate/onUpgrade 重入时不炸。§7.1 原文是 `CREATE INDEX ...`（不带 IF NOT EXISTS），drift 生成侧的 `createAll()` 也不带；只有我们手写的 `customStatement` 带。差异不改变最终 schema 内容。
- **`TransactionEntryRow` 命名决策**：drift 数据类刻意不叫 `TransactionEntry`，是为 Step 2.1 的 `domain/entity/TransactionEntry`（实施计划明确要求的实体名）让位。后续仓库层会这样桥接：`TransactionEntryRow` (drift) ↔ `TransactionEntry` (domain)；同名冲突会在仓库/usecase 文件里通过 import prefix 或 typedef 解决，目前无须提前处理。
- **Schema v2 的 migration 是"只加不改"**——没有任何列的 alter、index drop、数据转换。若未来出现真正需要迁移数据的版本（比如 Step 6.4 的 `budget.carry_balance`、Step 11 的 `user_pref.enc_salt`），必须在 `onUpgrade` 里一次性把 DDL + 数据搬运写明，并补一条对应的迁移测试（用 drift 的 `SchemaVerifier` + 历史 snapshot，或手写 `customStatement` 验证）。
- **`autoIncrement` 与 `primaryKey` 互斥**。`SyncOpTable` 的 id 用 `integer().autoIncrement()` 后若再覆写 `Set<Column> get primaryKey => {id}`，drift_dev 会报 `primary_key_and_auto_increment` 错；这是写 SyncOpTable 时调试一次才发现的，记录在此避免后续有人画蛇添足。
- **测试里用 `const LedgerTableCompanion(...)`**（裸类构造，不是 `.insert`）是给**更新**用的——只传需要写的列，其余保持现状。`.insert` 构造要求非空必填列都给值，适合新增场景。两者都返回同一个 Companion 类型，drift 的 `.write()` 会忽略未指定列。
- **索引方向（DESC vs ASC）对 SQLite 性能**的影响多数情况下可忽略——查询优化器能反向扫索引；但为了与 §7.1 DDL 字节一致，我们仍手写 `DESC`。若以后改用 `@TableIndex` 注解，ASC 索引也足够撑起 Phase 5 统计聚合的性能。
- **sync_op 的 `id` 从 1 起**——SQLite AUTOINCREMENT 遵从 `sqlite_sequence` 机制，即使前面行被全部删除（push 成功清队列），新 id 也继续往上加（1,2,3,...）。测试里断言 `id == 1` 是基于空库假设；若哪天这成为并发测试的 flaky 点，改成 `expect(id, greaterThan(0))`。


### ✅ Step 1.4 DAO 分层（2026-04-21）

**改动**
- `lib/data/local/dao/`（新目录）：5 张业务表各建一个 DAO 文件。每个 DAO：`@DriftAccessor(tables: [XxxTable])` + `extends DatabaseAccessor<AppDatabase> with _$XxxDaoMixin`，只暴露实施计划 Step 1.4 约定的**4 类方法**：
  - `listActive...` — `category` / `transaction_entry` / `budget` 叫 `listActiveByLedger(String ledgerId)`，按"ledger_id = ? AND deleted_at IS NULL"过滤；`ledger` / `account` 没有父 ledger 字段（account 是全局资源、ledger 自身就是聚合根），改为 `listActive()` 只过滤 `deleted_at IS NULL`。排序：`listActive()` 按 `updated_at DESC`；`category` 按 `sort_order ASC`；`transaction_entry` 按 `occurred_at DESC`（命中 `idx_tx_ledger_time` 索引）；`budget` 不排序（UI 自行分组）。
  - `upsert(XxxTableCompanion)` — `insertOnConflictUpdate`，不主动设置 `updated_at` / `device_id`（仓库层 Step 2.2 会统一填）。
  - `softDeleteById(String id, {required int deletedAt, required int updatedAt})` — 双写 `deleted_at` + `updated_at`；只写 `deleted_at` 的软删会在同步层按"updated_at > last_sync_at"拉取增量时被对端漏掉，这是设计必要。
  - `hardDeleteById(String id)` — 物理 delete by id。每个 DAO 的 dartdoc 显式写"**仅供垃圾桶定时任务调用**（Phase 12 Step 12.3）"；接口不做"`deleted_at IS NOT NULL`"的运行时自检（否则正常 GC 反被护栏挡住），"仅 GC 可调"靠文档 + 评审守护。
- `lib/data/local/app_database.dart`：`@DriftDatabase(...)` 新增 `daos: [LedgerDao, CategoryDao, AccountDao, TransactionEntryDao, BudgetDao]`；顶部追加对应 5 个 import。drift_dev 在 `app_database.g.dart` 生成 `late final LedgerDao ledgerDao = LedgerDao(this as AppDatabase)` 等 5 个访问器，调用方一律通过 `db.ledgerDao` / `db.categoryDao` / `db.accountDao` / `db.transactionEntryDao` / `db.budgetDao` 访问。
- `test/data/local/dao_test.dart`（新建）：5 条用例（每个 DAO 一组）。每组跑同一个完整流程：插入 2-3 条（含跨账本噪声覆盖 listByLedger 过滤逻辑）→ 二次 `upsert` 同 id 触发更新路径 → `listActive...` 断言排序 + 存活集合 → `softDeleteById` → 直查 `select(table)` 确认物理行仍在且 `deleted_at`/`updated_at` 都已写 → `listActive...` 已排除 → `hardDeleteById` 返回 1 → 原始表 select 确认物理不存在。这一连串断言同时覆盖验收要求的"soft-delete 后普通查询查不到"**和**"硬删除接口能看到（即 hardDelete 能精确命中软删后的残留行）"。

**验证**
- `dart run build_runner build --delete-conflicting-outputs` 成功，5 个新 `dao/*.g.dart` + `app_database.g.dart` 重新生成。
- `flutter analyze` → No issues found。
- `flutter test` → 21/21 通过（前 16 + 新增 5 DAO 用例）。
- `dart run custom_lint` → No issues found。
- 用户本机 `flutter run` 待手工验证：DAO 只是新 API 层，不改 schema；Step 1.3 已有的 DB 文件应照常打开、行为不变。

**给后续开发者的备忘**
- **LedgerDao / AccountDao 的"退化命名"**：实施计划原文说"按 ledgerId 查询未删除"——但 `ledger` 自身就是聚合根、`account` 是不绑账本的全局资源，两者根本拿不到父 ledgerId。方法名改叫 `listActive()` 而非强行塞一个无意义的 `ledgerId` 参数。Step 2.2 的 `LedgerRepository` / `AccountRepository` 在 API 层也要维持这一不对称——不要为了"对称"在仓库接口里捏一个 `ledgerId` 参数让实现忽略它。
- **未写 watch 变体**：Step 1.4 只给 `Future` API，原因是 Step 2.3 打算用 Riverpod provider 的 `invalidate` 驱动 UI 刷新（一次性查询 + 重跑），不走 drift Stream。若 Phase 3 的首页流水列表验收发现"保存后首页不更新"的 invalidate 覆盖盲区，再把 `transaction_entry_dao` 单独加一个 `watchActiveByLedger` 即可，不用全套改 Stream。
- **`softDeleteById` 强制同时写 `updated_at`**：签名上 `deletedAt` 和 `updatedAt` 都是 `required` 命名参数——这是防御式设计。如果仓库层忘了刷 `updated_at`，同步层 pull 拉增量按 `updated_at > last_sync_at` 过滤时会漏掉这条软删，对端永远看不到"这条被删了"。两个参数通常传同一个时间戳。
- **`hardDeleteById` 不做 `deleted_at IS NOT NULL` 自检**：曾考虑过加护栏防止误调；但垃圾桶定时任务（Phase 12 Step 12.3）本身就是"扫 `deleted_at < now-30天` 再硬删"，护栏反而让其绕不过去。调用方由 dartdoc 警示 + 代码评审守护；如果未来仍想加运行时护栏，可以改成 `hardDeleteExpired(int olderThan)` 这种"只删早于某时间戳的软删行"的窄接口，不要在 `hardDeleteById` 上加条件。
- **`upsert` 不填 `updated_at` / `device_id`**：DAO 故意只是薄封装，`insertOnConflictUpdate` 接受完整 Companion；如果 DAO 私自在这里填 `updated_at = now`，仓库层就没办法做"同步拉下来时按远端 `updated_at` 回写本地"这种场景（那时 `updated_at` 是远端值，不能被覆盖）。统一由 Step 2.2 的仓库层根据"是本地发起 vs 同步拉取"两种路径决定是否刷 `updated_at`。
- **生成的 DAO 访问器名是 camelCase of class name**：`LedgerDao → ledgerDao`、`TransactionEntryDao → transactionEntryDao`。不是自定义、也没有 `@JsonKey` 之类的覆写入口——要想改名只能改类名。


### ✅ Step 1.5 设备 ID 初始化（2026-04-21）

**改动**
- `lib/data/local/device_id_store.dart`（新建）：`LocalDeviceIdStore` 服务类 + `UuidFactory` 类型别名。`loadOrCreate()` 按「`flutter_secure_storage`（key=`local_device_id`）→ `user_pref.device_id` → 新生成」优先级解析 device_id；命中任一源即把最终值**同步写回另一侧**（实施计划所谓"冗余防丢"）。UUID 合法性走宽松正则（8-4-4-4-12 hex，不校验 v4 version/variant 位），以容忍从老库 / 老版本恢复的任意合法 UUID。生产路径默认 `uuidFactory = () => const Uuid().v4()`；测试注入返回固定字面量以获得确定性输出。
- `lib/data/local/providers.dart`（新建）：两个 `@Riverpod(keepAlive: true)` 顶层函数——`appDatabase(Ref)` 构造 `AppDatabase()` 并在 `ref.onDispose` 里关闭连接；`deviceId(Ref)` 返回 `Future<String>`，`watch(appDatabaseProvider)` 后调 `LocalDeviceIdStore(db: db).loadOrCreate()`。`providers.g.dart` 由 `riverpod_generator` 产出 `appDatabaseProvider` / `deviceIdProvider`。
- `lib/main.dart`（改造）：移除直接 `AppDatabase()` + `SELECT 1` smoke test；改为 `final container = ProviderContainer()` + `await container.read(deviceIdProvider.future)` 触发连锁（DB 打开 → SQLCipher 断言 → device_id 初始化/恢复）；成功路径 runApp 用 `UncontrolledProviderScope(container: container, child: BianBianApp())` 把预热过的 container 交给 Widget 树，失败路径 `container.dispose()` 释放资源再走 `_BootstrapErrorApp`。import 从 `data/local/app_database.dart` 换成 `data/local/providers.dart`——main 不再直接 new AppDatabase。
- `test/data/local/device_id_store_test.dart`（新建）：5 个用例覆盖 `loadOrCreate()` 的 4 条分支 + 1 条脏数据覆盖路径（详见架构文档 `test/data/local/device_id_store_test.dart` 节）。本地 `_InMemoryStore` 实现 `SecureKeyValueStore`（未复用 `db_cipher_key_store_test.dart` 的同名类，避免跨文件测试耦合）；固定 UUID 字面量 `_fixedUuidA` / `_fixedUuidB`。注入 `uuidFactory: () => fail(...)` 验证"已命中 secure / pref 时 UUID 生成器绝不被调用"。
- `lib/data/local/app_database.g.dart` + `lib/data/local/providers.g.dart`：`dart run build_runner build --delete-conflicting-outputs` 重新生成（12 outputs）。

**验证**
- `dart run build_runner build --delete-conflicting-outputs` → 12 outputs，0 error。
- `flutter analyze` → No issues found（一次清理：`device_id_store.dart` 初版误 import 了 `package:drift/drift.dart` 和 `tables/user_pref_table.dart`，均通过 `app_database.dart` 的 re-export 传递可用，去掉两条 unused import 即绿）。
- `flutter test` → 26/26 通过（前 21 + 新增 5 device_id 用例）。
- `dart run custom_lint` → No issues found。
- 用户本机 `flutter run` 待手工验证三件：① 首次启动 → `user_pref.device_id` 非空；② 冷启动 → 同一值；③ 清除应用数据 → 重新生成新值（Android 清数据会把 `flutter_secure_storage` 条目也抹掉；iOS 卸载仍保留 Keychain 项）。

**给后续开发者的备忘**
- **`insertOnConflictUpdate` 与 `CHECK(id=1)` 不兼容**——这是本步最吃亏的坑。user_pref 的 `id INTEGER NOT NULL DEFAULT 1 CHECK(id = 1)` 在初次 INSERT 时工作正常；但 `INSERT ... ON CONFLICT(id) DO UPDATE SET device_id = ?` 的第二次调用会抛 `SqliteException(275): CHECK constraint failed: id = 1`，哪怕 UPDATE 子句完全没碰 id 列。SQLite 在 UPSERT 的 DO UPDATE 路径会重新评估 CHECK 约束，推测与其内部用"虚拟 INSERT + 回退到 UPDATE"的实现有关。**解法**：`_ensureUserPref` 改成显式 `select(userPrefTable where id=1).getSingleOrNull()` → 非空走 `update`、为空走 `insert`。DAO 层的其它表（ledger/category/account/...）没有 id CHECK，`insertOnConflictUpdate` 继续正常工作；只有 user_pref 这张单行表受影响。**别把这个规避当成全局约定**——正常表继续用 upsert，user_pref 这种带 CHECK 的表单独处理。
- **`UncontrolledProviderScope` vs `ProviderScope` 二选一**：成功路径用前者（把 main 里预热的 container 带到 Widget 树，provider 状态复用）；失败路径用后者（错误兜底页不关心 provider 状态，重新建一个干净 scope）。混用时要注意：**不要**在失败路径给两个 scope 共享同一个 container——`_BootstrapErrorApp` 不消费任何 provider，但保留 `ProviderScope` 是为了守住"所有 runApp 在 ProviderScope 下"的 riverpod_lint 基线。
- **`device_id` 的两条存储位置语义**：`flutter_secure_storage` 为主，`user_pref.device_id` 为备。iOS Keychain 在重装后保留、Android 卸载时清除——这天然决定了两种平台的"换新设备流程"差异，但 Step 1.5 的 `loadOrCreate` 做到"任一侧生还都能恢复"，让这个差异对 device_id 本身透明。**但加密密钥（`DbCipherKeyStore.storageKey = local_db_cipher_key`）不做这种备份**——后者丢了就是本机 DB 永久不可读，必须靠同步恢复；前者只是"身份识别"，丢失顶多让同一物理设备被误判成"新设备"，可容忍。两套命名空间故意分开。
- **`UuidFactory` 作为注入点，而非 `Uuid` 实例**：原本想直接注入 `Uuid`，但 `uuid` 包的 `Uuid.v4()` 在构造时已经吃了随机源，没有"传 seed 得到确定性序列"的干净接口。改成 `typedef UuidFactory = String Function()` 让测试注入 `() => '<固定字面量>'` 一步到位，生产默认 `() => const Uuid().v4()`。未来若要做"每条流水生成 uuid"的业务，可以同样走这个 factory 走注入路径。
- **Riverpod `Ref` 的 import**：`@Riverpod` 生成的 provider 在 `appDatabase(Ref ref)` 签名里，`Ref` 直接 import 自 `package:flutter_riverpod/flutter_riverpod.dart`——不要改成生成器提供的 `AppDatabaseRef` 别名（虽然也能用，但增加一层命名负担，且会让文件里的几个 provider 之间风格不一致）。`keepAlive: true` 在本项目 bootstrap 模型下是必需的：main 预热后 Widget 树若重新构建，要的是 cache hit 而不是重开 DB。
- **bootstrap 链条**：`container.read(deviceIdProvider.future)` → `deviceIdProvider` → `appDatabaseProvider`（构造 AppDatabase）→ LazyDatabase 首次真实查询（`select(userPrefTable)`）→ SQLCipher `PRAGMA key` + `PRAGMA cipher_version` 断言 → 读 user_pref / 写 user_pref / 写 secure。这条链任何一环抛错都会冒泡到 main 的 catch。**不要再在 main 里加"额外的显式 smoke test"**——provider 链本身就是 smoke test 的载体，重复会让失败定位模糊。
- **测试不覆盖 SQLCipher 加密层**：`device_id_store_test.dart` 走 `AppDatabase.forTesting(NativeDatabase.memory())`——这与 Step 1.1/1.2/1.3/1.4 的所有单元测试一致。SQLCipher 真实加密效果仅能通过设备级验证（参见 Step 1.2 的"设备级验证项"清单）。


### ✅ Step 1.6 加密工具封装（2026-04-21）

**改动**
- `lib/core/crypto/bianbian_crypto.dart`（新建）：`BianbianCrypto` 工具类（私有构造，仅 static 方法）+ `DecryptionFailure` 异常。三个公开 API：
  - `deriveKey(String password, Uint8List salt, {int iterations = 100000})` → `Future<Uint8List>`（32 字节）。内部 `Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: ..., bits: 256).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt)`。`defaultPbkdf2Iterations = 100000` 作为 public 常量也暴露了——Phase 11 Step 11.1 会复用。
  - `encrypt(Uint8List plaintext, Uint8List key)` → `Future<Uint8List>`。内部 `_aesGcm.newNonce()` 生成 12 字节 nonce，`_aesGcm.encrypt(plaintext, secretKey: SecretKey(key), nonce: nonce)` 产出 `SecretBox(cipherText, mac)`。打包顺序 `nonce ‖ cipherText ‖ mac.bytes`（12 + N + 16 字节）用 `Uint8List.setRange` 连续写入；这份自包含格式让 decrypt 不需要外部元数据。
  - `decrypt(Uint8List packed, Uint8List key)` → `Future<Uint8List>`。长度不足 28 字节直接抛 `DecryptionFailure('packed too short')`；否则切片 `(nonce, ciphertext, tag)` 喂 `_aesGcm.decrypt`；catch `SecretBoxAuthenticationError` 统一包成 `DecryptionFailure('authentication failed', cause)`——上层只关心"不可信"，不关心底层细节。
  - `@visibleForTesting encryptWithFixedNonce(plaintext, key, nonce)` → 让 KAT 能对照固定向量。生产路径绝不会调它（nonce 在 GCM 里重用 = 灾难性泄密）。
  - 参数校验：key 必须 32 字节 / nonce 必须 12 字节，否则抛 `ArgumentError`——fail-fast 好过让 SecretBox 给出模糊错误。
- `lib/core/crypto/.gitkeep`（删除）：该目录已有真实文件。
- `test/core/crypto/bianbian_crypto_test.dart`（新建）：10 个用例（详见架构文档该节）。两条 KAT 分别锁死 PBKDF2（RFC 7914 §11 向量）与 AES-GCM（NIST SP 800-38D Test Case 13）；其余覆盖往返、错误密钥、篡改密文/篡改 tag、packed 过短、参数校验。

**验证**
- `flutter analyze` → No issues found。
- `flutter test` → 37/37 通过（前 26 + 新增 10 crypto 用例 + 1 额外的 deriveKey 确定性/salt 区分用例，合计 11 crypto）。
- `dart run custom_lint` → No issues found。
- 用户本机 `flutter run` 行为无变化——本步仅新增独立模块，没有任何代码消费它（Phase 11/13 才会接入）。

**给后续开发者的备忘**
- **GCM nonce 的 12 字节约束**：`AesGcm.with256bits()` 默认 nonce = 12 字节（96 bit，NIST 推荐值）。`encryptWithFixedNonce` 的 nonce 参数**必须**精确 12 字节，否则 `ArgumentError`。Phase 11 Step 11.4 同步码生成时若想用"消息计数器 + 设备 id 派生"做 nonce，需要先压缩/扩展到 12 字节——**千万别缩到 8 字节图方便**，那会降到 CAN-GCM 语义，不是我们测过的路径。
- **AES-GCM 的 `plaintext + 16` 计算**：密文长度 = 明文长度；tag 是独立 16 字节。所以 `packed.length == plaintext.length + 12 + 16`——Phase 11 Step 11.2 在 drift `BlobColumn` 写入前可以用这个公式算容量。SQLite BLOB 上限 1 GB 默认，实际受制于单条 `note`（设计上不鼓励过长），不用特别考虑分块。
- **PBKDF2 iterations 默认 100000**：OWASP 2023 推荐"至少 600,000"（SHA256），但边边记账本地派生场景（用户输入密码 → 立即派生）可接受的交互延迟更短，10 万在 iPhone 12 上 ~60ms、Android 中端 ~150ms——体验可接受、强度足够（离线暴力破解一个真实用户密码依然需要显著算力）。**若未来升迁到更高 iterations，必须保存 `user_pref.enc_kdf_iterations` 列**，否则老密文（用 10 万派生的 key 加密）无法再被解开。本步不加这列——Phase 11 Step 11.1 再新增，保持一次变更一个关注点。
- **`DecryptionFailure` 刻意不继承 `Error` 而实现 `Exception`**：它代表"数据不可信"这种可预期分支（比如用户同步密码输错、云端返回了被篡改的 blob），业务层需要 catch 并友好提示，不是程序员错误。`Error` 类约定是"不应该 catch"的语义。
- **不处理密钥长度不足**：`AesGcm.with256bits()` 强制要求 32 字节 key；如果调用方给 16 字节（AES-128）的 key，底层会抛 `ArgumentError`。我们在 `encrypt`/`decrypt` 进门就先校验 key 长度并抛同类错误，错误信息更明确（"AES-256 key must be 32 bytes"）。Phase 11 Step 11.1 派生密钥时应确保派生到 32 字节。
- **`SecretKey.extractBytes()` 是 Future**：`cryptography` 2.x 为了支持硬件密钥存储（Keychain / Android Keystore 后端）把 key 提取设计成异步。本步每次 `encrypt`/`decrypt` 内部 `SecretKey(key)` → 隐式的 `extractBytes` 等是可忽略的开销（内存 key 立即返回）；但未来若把某些密钥改成硬件后端，这里的 await 就是必需的。
- **KAT 向量的权威来源**：PBKDF2 向量来自 RFC 7914 §11（scrypt RFC 里顺带给的 PBKDF2-HMAC-SHA256 参考），AES-GCM 向量来自 NIST SP 800-38D 的官方测试集（key=全零 / IV=全零 / PT=16 字节全零这组是"Test Case 13"）。**任何调整密文格式（例如换 nonce 前置为后置）的改动都会让 KAT 失败**——这就是 KAT 的目的：格式一旦被消费端依赖，就不能轻易改。真要改格式需要走 schema 迁移流程（旧密文解不开时报错提示导出/重加密）。
- **不在本步写附件/文件流加密**：Step 11.3 的附件加密走"先落临时 `.enc` 再上传"模式，实现上可能用分块流而非一次性 `encrypt(Uint8List)`——届时可以在 `BianbianCrypto` 再加 `encryptStream`/`decryptStream`，不必动现有字节 API。本步有意只覆盖"一次性字段级加密"这一最小子集。


### ✅ Step 1.7 种子数据（2026-04-21）

**改动**
- `lib/data/local/seeder.dart`（新建）：`DefaultSeeder` 类 + `SeedClock` / `SeedUuidFactory` 两个 typedef 注入点。`seedIfEmpty()` 在 `_db.transaction` 原子块内先 `select(ledgerTable)..limit(1)` 判空——非空整体跳过；空则依次 `_insertLedger` / `_insertCategories`（先 18 `expense` 再 10 `income`）/ `_insertAccounts`。所有行共用同一个 `nowMs = clock().millisecondsSinceEpoch` 作为 `created_at` / `updated_at`，`deviceId` 来自注入参数。默认清单作为 `static const List<(...)>` 暴露给后续消费：
  - `expenseCategories`（18 条）：餐饮/交通/购物/服饰/娱乐/住房/水电/通讯/医疗/学习/运动/旅行/美容/宠物/礼物/零食/烟酒/其他。
  - `incomeCategories`（10 条）：工资/奖金/兼职/投资/理财/报销/红包/退款/礼金/其他。
  - `defaultAccounts`（5 条）：现金(`cash`)/工商银行卡(`debit`)/招商信用卡(`credit`)/支付宝(`third_party`)/微信(`third_party`)。
  - `palette`（6 色）：奶油兔色板（design-document §10.2 的奶油黄/樱花粉/可可棕/抹茶绿/蜜橘/苹果红），分类/账户按 `index % 6` 循环取色。
- `lib/data/local/providers.dart`：新增第三个 `@Riverpod(keepAlive: true) defaultSeed(Ref ref)`——内部 `watch(appDatabaseProvider)` + `await watch(deviceIdProvider.future)` 后调 `DefaultSeeder.seedIfEmpty()`。`riverpod_generator` 产出 `defaultSeedProvider`（`FutureProvider<void>`）。
- `lib/main.dart`：bootstrap 预热目标从 `deviceIdProvider.future` 上升为 `defaultSeedProvider.future`——这是整条依赖链的最下游，一次 `await` 跑完"DB 打开 → SQLCipher 断言 → device_id 初始化 → 默认数据种子化（或跳过）"四环。注释相应改写。
- `test/data/local/seeder_test.dart`（新建）：3 用例。① 空库 → 1 ledger + 28 category + 5 account，所有字段精确断言（含 `sort_order` 递增、`palette[i%6]` 循环取色、`created_at`/`updated_at` = 固定注入时间戳 `1714000000000`）；② 幂等（连续两次 `seedIfEmpty()` 后对比三张表的 id 集合完全相等）；③ 预置一个用户自建的 `工作` 账本 → seeder 整体跳过，不补齐分类/账户。辅助 `makeSeeder({counterStart})` 封装确定性 `clock` + 递增 UUID（`uuid-0001`, `uuid-0002`, ...），让断言可精确到 id 字符串。

**验证**
- `dart run build_runner build --delete-conflicting-outputs` → 16 outputs（主要是 `providers.g.dart` 重生）。
- `flutter analyze` → No issues found（初版有 3 条 unused import + 1 条 `no_leading_underscores_for_local_identifiers`，已清理：`seeder.dart` 删掉 `tables/*.dart` 的三行 import——Companion 类通过 `app_database.dart` 的 part 传递可用；测试中本地辅助函数 `_seeder` 改名 `makeSeeder`）。
- `flutter test` → 40/40 通过（37 前 + 3 新）。
- `dart run custom_lint` → No issues found。
- 用户本机 `flutter run` 待手工验证：① 首次冷启动后账本 Tab 预期显示 1 个账本「📒 生活」，记账页分类网格显示 18 支出 + 10 收入；② 二次冷启动不重复插入（DB 中 `ledger` 只有 1 行，没有 `生活(2)` 这类重名重复）。

**给后续开发者的备忘**
- **单事务下的幂等**：`seedIfEmpty` 用 `_db.transaction` 包整块"判空 → 批量插入"，是为了避免两台 isolate（或两个 provider 容器）在极短时间内各跑一次判空，都看到空然后都插入——drift 的 transaction 在 SQLite 层用隐式 BEGIN IMMEDIATE 拿写锁，第二条会等第一条提交后再进入事务，这时 `select(ledger)` 已经能看到第一条插入，走非空分支整体跳过。**绝不能**把 `seedIfEmpty` 拆成"先 `.get()` 再后续 insert"这样非事务的两段，会踩并发双插。
- **不进 `sync_op` 队列**：有意为之。若两台设备各自种子再都开同步，会生成"两套默认账本 / 分类"——它们 id 不同，sync 层不会合并、只会并列。Phase 10 启用同步时需要专门设计一层"种子数据与云端数据的合并规则"（比如：开启同步前先 push 本地种子，拉取时按"name+type+deviceId<=本机"规则去重）。届时可能得重写这里的语义，当前版本刻意只负责本机首启兜底、不预判 Phase 10 的约束。
- **分类颜色用 `i % 6` 循环**：第 7 个支出分类和第 1 个支出分类同色（奶油黄）；18 个支出分类里会产生 3 轮色。视觉上 UI 再通过"图标差异 + 名称"区分，完全不会让用户困惑。如果 Phase 15 想改成"按主题独立配色"，需要把颜色从种子常量里移出，改由分类 UI 在渲染时按主题动态上色——届时 `color` 列可能降为"旧主题冗余"甚至弃用。
- **`默认账户 initialBalance = 0`**：包括信用卡账户也默认 0 而不是负值。用户真用时自己填入实际欠款额（业务测试里 -1200 是作为反面示例，说明「信用卡可以是负的」）。别在种子里塞"猜的"数字。
- **`namedConstructor + (positional, record)` 语法**：`expenseCategories` / `incomeCategories` / `defaultAccounts` 用 Dart 3 的位置记录 `(String, String)` / `(String, String, String)` 作为清单元素类型。好处是比 `const Map<String, Map<String, String>>` 更紧凑、比自定义类更轻量；代价是解包用 `for (final (name, emoji) in expenseCategories) { ... }` 模式匹配语法，需要 Dart 3.0+（项目 SDK 是 3.11.5，没问题）。
- **Companion.insert 必填字段**：`LedgerTableCompanion.insert` 要求 `id / name / createdAt / updatedAt / deviceId` 五个非 null 必填，其他（`coverEmoji` / `defaultCurrency` / `archived` / `deletedAt`）走 `Value` 可选。`CategoryTableCompanion.insert` 必填 `id / ledgerId / name / type / updatedAt / deviceId`。`AccountTableCompanion.insert` 必填 `id / name / type / updatedAt / deviceId`。**如果后续某张表新增 NOT NULL 列（无 default 的），必须先在 `expenseCategories` 等常量里补默认，再跑 build_runner 让 Companion 签名变化，然后 `flutter analyze` 会直接报编译错误**——这也是有意的防御机制，别绕过。
- **`defaultSeedProvider` 不带参数**：很诱人加一个"boolean seeded"返回值让 UI 层读；但本 provider 只是 bootstrap 的副作用 gate，成功即成功，无需告诉调用方"是跑了还是跳过"。需要这种粒度时，应该在 Phase 4 的账本 feature 里单独加一个"是否只剩种子数据"的查询，而不是在 bootstrap provider 上叠概念。
- **widget_test 不会触发种子**：`test/widget_test.dart` 直接构造 `ProviderScope(child: BianBianApp())`，树内任何 widget 都不 `watch(defaultSeedProvider)`——所以种子逻辑在 widget 测试里不运行，widget 测试继续不碰 `AppDatabase` / `flutter_secure_storage`。若 Phase 3 起记账 Tab 真的要从 provider 拿账本数据，需要同时调整 widget_test 布线（用 `overrides` 注入假仓库），否则测试会尝试开真实 DB 然后失败。

### ✅ Step 1.7 临时预览（2026-04-21，非实施计划步骤）

**改动**
- `lib/app/home_shell.dart`：账本 Tab（index=2）body 替换为 `_LedgerPreviewBody`（`ConsumerStatefulWidget`）。`initState` 时 `ref.read(appDatabaseProvider)` 取 DB、`ledgerDao.listActive()` 拿 Future 并缓存；`FutureBuilder` + `ListView.separated` 渲染账本列表（封面 emoji + 名称 + `币种 · 创建时间` 副标题）；顶部有斜体提示「（Step 1.7 种子预览 · Phase 4 Step 4.1 会重写）」。Phase 4 Step 4.1 落地真正的账本列表 UI 时删除本 widget。
- 其他 Tab（记账/统计/我的）body 保持 Step 0.4 占位大标题不变。

**验证**
- `flutter analyze` → No issues。一次 `unnecessary_underscores` info 触发后改用 Dart 3.7 的双通配参数 `(_, _)`。
- `flutter test` → 40/40 通过（widget_test 不触碰 index=2，所以不会实例化 `_LedgerPreviewBody`，也不会打开真实 DB）。
- `dart run custom_lint` → No issues。
- 用户本机 `flutter run` 首次启动：账本 Tab 可见「📒 生活」卡片 + 预览提示，证明 Step 1.7 种子真的落到 DB。

**给后续开发者的备忘**
- 本改动是为了给 Step 1.7 提供肉眼可见的验收——严格来说不在实施计划里，属于"让数据层单测之外再多一条可见性通道"。一旦进入 Phase 4 Step 4.1，整个 `_LedgerPreviewBody` 连同 `_body(index)` 的 `if (index == 2)` 分支会被账本 feature 的正式 widget 替换；此时 `home_shell.dart` 对 `appDatabaseProvider` 的 import 也会随分支消失一起清理。
- **widget_test 不会触发这段**：widget_test 只验 index=0 / 1 的 Tab，不 tap 账本；加上条件分支渲染（不是 IndexedStack 预渲染全部 body），`_LedgerPreviewBody.initState` 永远不会在测试里被调用 → `AppDatabase()` 不会开真实 DB → 测试环境不需要 platform channel mock。**如果未来把 body 改成 `IndexedStack`**（为了各 Tab 保留滚动位置），需要同步给 widget_test 注入 `appDatabaseProvider.overrideWith(...)` 返回 `AppDatabase.forTesting(NativeDatabase.memory())`，否则 widget_test 会挂。


### ✅ Step 2.1 领域实体（2026-04-22）

**改动**
- `lib/domain/entity/`（原 `.gitkeep` 删除）新建 5 个纯 Dart 不可变实体，一文件一类：
  - `ledger.dart` → `Ledger`（9 字段）。
  - `category.dart` → `Category`（10 字段）。
  - `account.dart` → `Account`（11 字段，**无 `ledgerId`**——账户是全局资源）。
  - `transaction_entry.dart` → `TransactionEntry`（17 字段；drift 数据类 `TransactionEntryRow` 刻意让名，见 Step 1.3 备忘）。文件末尾有两个 top-level 私有函数 `_bytesEqual` / `_bytesHash`，供 `==` / `hashCode` 做 `Uint8List?` 深比较——`Uint8List` 在 Dart 默认引用相等，不深比会让 `fromJson(toJson(x)) == x` 验收假阴。
  - `budget.dart` → `Budget`（10 字段，`categoryId == null` 表示"总预算"）。
- **统一语义**：每个实体都手写 `copyWith` / `toJson` / `fromJson` / `==` / `hashCode` / `toString`。
  - `copyWith`：所有参数 `T?`，null 表示不改；**不支持通过 copyWith 把字段清成 null**（见架构文档 `lib/domain/entity/` 节）。
  - `toJson`：键名走 **snake_case**（与设计文档 §7.1 DDL + 未来 Supabase 列名一致）。`DateTime` → ISO 8601 字符串；`Uint8List?` → **base64 字符串**；`bool` / `double` / `int` / `String?` → 原生 JSON。
  - `fromJson`：对带默认值的字段显式 `??` 兜底——保证默认值在 JSON roundtrip 上不丢（`defaultCurrency ?? 'CNY'`、`fxRate ?? 1.0`、`carryOver ?? false` 等）。
  - `toString`：列出所有字段（bytes 字段只打印 length），测试失败时能一眼看到哪个字段不符。
- **类型收紧**（相对 drift 数据类）：`archived` / `includeInTotal` / `carryOver` 用 `bool` 而非 `int?`；`defaultCurrency` / `currency` / `fxRate` / `initialBalance` / `sortOrder` 用非空 + 默认值；所有时间戳列从 drift 的 `int`（epoch ms）升级为 `DateTime` / `DateTime?`。仓库层（Step 2.2）承担 drift ↔ 实体的桥接。
- `test/domain/entity/entities_test.dart`（新建）：17 用例——每实体 3 条（全字段 roundtrip / 可空字段 null roundtrip / copyWith），TransactionEntry 多一条 bytes 反面用例（换 bytes 后必须 `!=`）；最后一条扫描 `lib/domain/**.dart` 所有 `import` / `export` 行，禁止出现 `package:drift/`——实施计划 Step 2.1 的硬约束。

**验证**
- `flutter analyze` → No issues found。
- `flutter test` → 57/57 通过（40 前 + 17 新）。
- `dart run custom_lint` → No issues found。
- 用户本机 `flutter run` 行为无变化——本步只新增领域类型定义，无任何代码现在消费它们（Step 2.2 仓库层接入）。

**给后续开发者的备忘**
- **`Uint8List` 深等是容易踩的坑**：Dart 的 `Uint8List` 没有重写 `==` / `hashCode`，两个内容相同的 byte 数组比较是 `false`。任何含 `Uint8List` 字段的类，如果要做值相等（JSON roundtrip / `expect(a, equals(b))`），必须手动深比，否则测试会误报。本步的 `_bytesEqual` / `_bytesHash` 是针对 `TransactionEntry` 写的私有 helper；若 Phase 11 再在别处（比如附件元数据类）出现 Uint8List 字段，同款 helper 需要再写一次或抽到 `domain/entity/_bytes.dart`（但当前只有一处，没必要提前抽）。
- **`copyWith` 不支持清回 null 的原因**：所有参数用 `T?` 是主流 Dart 约定，好处是简单、自然；代价是 `entry.copyWith(deletedAt: null)` 等同于"不改 deletedAt"。若严格需要"清回 null"，业务路径有两条——① 直接 `TransactionEntry(id: x.id, ..., deletedAt: null, ...)` 重新构造；② 在需要的实体上加专门方法比如 `restored()` 清 deletedAt。Step 12.2（垃圾桶恢复）真正需要时再加，别提前泛化。
- **JSON 为什么用 snake_case**：与 Phase 10 Supabase 列名一致（PostgREST 默认按列名返回），仓库层少做一步 key 翻译。代价是本地测试里读 JSON 时要想着 `ledger_id` 而非 `ledgerId`。**别改 camelCase**，不然 Phase 10 会到处要写 `.replaceAll` 或 `@JsonKey(name: ...)` 样板代码。
- **`DateTime` 在 JSON 里用 ISO 8601 而非 epoch ms**：ISO 8601 是可读的（人看日志友好），Supabase 也默认返回 ISO。代价是每次解析都走 `DateTime.parse`（有 locale 回退逻辑，慢于 `fromMillisecondsSinceEpoch`）；记账场景每秒至多几条实体转换，不是热点。
- **`fromJson` 对默认字段 `??` 兜底很关键**：如果 JSON 是由老版本 App 产出、字段还不存在（比如未来 `Budget.carryOver` 这列被引入前的旧备份），`json['carry_over']` 是 `null`，`?? false` 让新版本仍能解析。Phase 13 Step 13.3（导入本 App 格式）会真正踩到这条路径；没有这个 `??` 就得去加 JSON 版本号字段。
- **`fromJson` 的强转用 `as`**：形如 `json['id'] as String` 对错类型会 ClassCastError。目前没有 try/catch，因为 JSON 来源永远是自家 `toJson` 产出；如果 Phase 13 要导入第三方 JSON 且无法保证结构，应在**导入层**做 schema 校验后再进 `fromJson`，不要把 defensive parsing 写进实体本身。
- **`TransactionEntry` 与 `TransactionEntryRow` 并存**：drift 数据类 `TransactionEntryRow` 在 `data/local/app_database.g.dart` 生成；领域实体 `TransactionEntry` 在 `domain/entity/transaction_entry.dart`。仓库实现（Step 2.2）要同时 import 两个；若出现类型歧义，用 `import '...' show TransactionEntryRow;` 显式收窄，或用 prefix `as drift`。**别为了回避这个命名冲突把领域实体改名为 `Transaction`**——`Transaction` 在 drift 本身是一个 SQL 事务概念的类，反而更糟。
- **依赖隔离扫描**：本步的 drift-isolation 测试走 `dart:io` 直接读文件、grep 字面量。用 `dart analyze` 的 custom lint 规则其实更专业，但那是一整坨 `custom_lint` 插件工程；用文件扫描 4 行代码搞定，性价比更高。若 Phase 以后要对更多层（如 `lib/features/` 不得依赖 `lib/data/remote/`）加类似约束，可以把扫描逻辑抽成辅助函数。


### ✅ Step 2.2 仓库接口与实现（2026-04-25）

**改动**
- `lib/data/local/dao/sync_op_dao.dart`（新建）：`SyncOpDao` — `@DriftAccessor(tables: [SyncOpTable])` + `extends DatabaseAccessor<AppDatabase> with _$SyncOpDaoMixin`。两个方法：`enqueue({entity, entityId, op, payload, enqueuedAt})` 返回 AUTOINCREMENT id；`listAll()` 按 id ASC 列出所有待同步记录。这是 Step 1.4 刻意遗漏的 DAO——sync_op 不是实体表、不走"4 类方法"模式。`op` 取 `'upsert'` / `'delete'`；`entity` 取 `'ledger'` / `'category'` / `'account'` / `'transaction'` / `'budget'`（`transaction` 而非 `transaction_entry`，与 §7.1 DDL 注释一致）。
- `lib/data/local/app_database.dart`：`@DriftDatabase(...)` 的 `daos:` 列表新增 `SyncOpDao`。drift_dev 在 `app_database.g.dart` 生成 `late final SyncOpDao syncOpDao` 访问器。
- `lib/data/repository/`（目录 `.gitkeep` 删除）：7 个新建文件，分三层职责：
  - **注入点**：`repo_clock.dart` — `typedef RepoClock = DateTime Function()`，仓库层"当前时间"注入点。
  - **桥接层**：`entity_mappers.dart` — drift 行对象 ↔ 领域实体的唯一映射函数集。`LedgerEntry → Ledger` / `Ledger → LedgerTableCompanion` 等 5 组 10 个函数。`int epochMs ↔ DateTime`、`int? 0/1 ↔ bool`、nullable 默认值应用（`'CNY'` / `1.0` / `0` / `true` / `false`）都在此层完成。
  - **5 个仓库**：每个实体对应一个抽象接口 + `LocalXxxRepository` 实现。共同职责：
    1. `save(entity)` → 覆写 `updated_at`（注入 clock）+ `device_id`（注入参数），单事务内 `dao.upsert` + `syncOpDao.enqueue('upsert')`。
    2. `softDeleteById(id)` → 先查一行判存（不存在静默返回），单事务内更新 `updated_at` / `deleted_at` / `device_id` 三列 + `syncOpDao.enqueue('delete')`，payload 含完整 `toJson()` 快照（含 `deleted_at`）。
    3. 仓库**不直接调用 DAO 的 `softDeleteById`**——DAO 只管 `updated_at` + `deleted_at` 两列，缺少 `device_id`；仓库直接写三列使 sync op 的 LWW tiebreak 与 payload 一致。
  - 具体文件：`ledger_repository.dart` / `category_repository.dart` / `account_repository.dart` / `transaction_repository.dart` / `budget_repository.dart`。Ledger / Account 的 list 方法退化为 `listActive()`（无需 ledgerId 参数），与 DAO 层的不对称一致。
- `test/data/repository/transaction_repository_test.dart`（新建）：4 条用例——① create → sync_op 入队 upsert（断言 `device_id` / `updated_at` 被 repo 覆写）；② update（同 id 再 save）→ sync_op 再入队一条 upsert、payload 含新金额；③ softDeleteById → listActive 查不到、sync_op 有 1 upsert + 1 delete、delete payload 含 `deleted_at`；④ 返回实体是纯 Dart `TransactionEntry`（`isA<TransactionEntry>()` + `runtimeType.toString() == 'TransactionEntry'`），不含 drift 专属类型。

**验证**
- `dart run build_runner build --delete-conflicting-outputs` → 成功（`sync_op_dao.g.dart` 新生成，`app_database.g.dart` 重生成含 `syncOpDao` 访问器）。
- `flutter analyze` → No issues found。
- `flutter test` → 61/61 通过（57 前 + 4 新 repository 用例）。
- `dart run custom_lint` → No issues found。
- 用户本机 `flutter run` 行为无变化——本步仅新增仓库层类型与测试，无 UI 变更。

**给后续开发者的备忘**
- **仓库层是唯一允许 import 两侧的地方**：`entity_mappers.dart` 同时 import `domain/entity/*.dart` 和 `data/local/app_database.dart`——这是 `lib/data/` 与 `lib/domain/` 之间唯一合法的桥接点。UI 层（`lib/features/`）只能通过抽象接口 import 仓库，不能直接 import drift 或 repository 实现。
- **`softDeleteById` 返回 `void` 不返回值**：不存在就静默跳过——调用方不需要区分"不存在"和"已删"，两者效果等价。如果需要检查是否真的删了什么（Phase 12 垃圾桶恢复），应在调用方先用 `listActive` 查存在性。
- **payload 是 `entity.toJson()` 的 JSON 字符串**：包含 `updated_at` 之前 write 过，Phase 10 同步引擎推送到 Supabase 时会用这个 JSON 作为 upsert 的 body。如果未来 `toJson()` 增加了不应该同步到云端的字段（如 `noteEncrypted` 的明文中间表示），需要在仓库层做一次字段剪裁。当前字段集与 Supabase 列一一对应，暂不需要。
- **sync_op 的 `entity` 值 'transaction' 而非 'transaction_entry'**：设计文档 §7.1 DDL 注释写的是 `ledger | category | account | transaction | budget`（无 `_entry` 后缀）。Phase 10 Step 10.1 Supabase 建表时表名可以叫 `transaction_entry`，但 sync_op.entity 仍用 `'transaction'`；同步引擎做路由时需要做一次映射（例如一个 switch 或 map：`'transaction' → Supabase 'transaction_entry' 表`）。
- **仓库层目前是"本地唯一"实现**：抽象接口 `XxxRepository` 是为了 Phase 10 之后可能的 `SyncedXxxRepository`（组合 local + remote）预留扩展点。目前所有实现都是 `LocalXxxRepository`，Step 2.3 的 provider 直接绑定到 `LocalXxxRepository` 实例而非抽象接口——等到真正需要同步层仓库组合时再改为 `Provider<XxxRepository>`。
- **5 个仓库实现高度相似**——这是刻意的，不抽基类。原因：① 每个仓库的 DAO 签名不同（`listActive` vs `listActiveByLedger`），共性只在 save/softDelete 的模板骨架；② 抽基类需要泛型 DAO / mapper / table，类型体操比重复 5 行代码更复杂；③ Phase 10 引入 remote 后，实现差异会进一步拉大。到那时如果共性仍稳定，再抽也不迟。


### ✅ Step 2.3 Riverpod Provider 布线（2026-04-25）

**改动**
- `lib/data/repository/providers.dart`（新建）：7 个 `@Riverpod(keepAlive: true)` provider：
  - `currentLedgerId(Ref)` → `Future<String>`：依赖 `defaultSeedProvider`（确保种子已落地）→ `appDatabaseProvider` → `db.ledgerDao.listActive()` 取第一个活跃账本的 id。Phase 4 账本切换器上线后需升级为 `Notifier`（mutable），当前仅做默认值。
  - `ledgerRepository(Ref)` / `categoryRepository(Ref)` / `accountRepository(Ref)` / `transactionRepository(Ref)` / `budgetRepository(Ref)` → `Future<XxxRepository>`：`watch(appDatabaseProvider)` + `await watch(deviceIdProvider.future)`，构造对应的 `LocalXxxRepository` 实例。
- `lib/data/repository/providers.g.dart`：`dart run build_runner build` 产出 7 个对应的 `FutureProvider` getter（`currentLedgerIdProvider` / `ledgerRepositoryProvider` / ...）。
- `lib/data/repository/ledger_repository.dart`：接口新增 `getById(String id)` 方法；`LocalLedgerRepository` 实现加 `getById`（`select.where(id)` → `getSingleOrNull()` → null 或 `rowToLedger`）。这是 Step 2.3 UI 读取当前账本名称所必需的操作——保存时返回实体但不方便 UI 先存再读，getById 是合理补充。
- `lib/app/home_shell.dart`：记账 Tab（index=0）body 替换为 `_RecordTabBody`（`ConsumerWidget`）。内部 `watch(currentLedgerIdProvider)` + `watch(ledgerRepositoryProvider)`，`FutureBuilder` 调 `repo.getById(currentId)`，显示 `coverEmoji` + `name` + 预览提示。body 文本给 `name` 挂 `Key('current_ledger_name')` 便于测试断言。导入新增 `data/repository/providers.dart`（show 两个 provider）+ `domain/entity/ledger.dart`。
- `test/widget_test.dart`：完整重写——4 条用例（前 3 条复刻 Step 0.4 原有覆盖，新增 1 条 Step 2.3 专用）：
  1. **HomeShell renders all 4 bottom-nav tabs**（pumpAndSettle + `findsOneWidget` 断言 4 个 Tab 名均在 nav bar 各一次）。
  2. **BottomNavigationBar background is cream yellow**（背景色 `#FFE9B0` 断言）。
  3. **Tapping "统计" tab switches body text**（切换后 `findsWidgets` 验证 body + nav bar 各一处）。
  4. **记账 Tab 通过 provider 显示当前账本名称**（新增）：注入假仓库返回"测试账本"，验证 `find.text('测试账本')` + `find.text('📒')` + Key 断言。
  - 所有测试统一走 `_standardOverrides()`：`currentLedgerIdProvider.overrideWith` → 固定字符串 `'test-ledger-id'`；`ledgerRepositoryProvider.overrideWith` → `_FakeLedgerRepository`（实现 `LedgerRepository` 接口，只复写 `getById` 返回固定 Ledger 实体、`listActive` 返回单元素列表，`save`/`softDeleteById` 走 `fail()`）。这是实施计划"用 `ProviderContainer.test` 覆盖 provider"的落地模式。
  - `_FakeLedgerRepository` + `_testLedger()` + `_standardOverrides()` 作为测试辅助在文件内私有，不暴露给其他测试。
- `lib/data/repository/.gitkeep`：删除（目录已有真实文件）。

**验证**
- `dart run build_runner build --delete-conflicting-outputs` → 18 outputs，0 error（`providers.g.dart` 新生成 7 个 provider getter + `app_database.g.dart` 重生成含 `syncOpDao`）。
- `flutter analyze` → No issues found。
- `flutter test` → 62/62 通过（61 前 + 1 新 widget 用例）。原有 3 条 widget 测试因 `_RecordTabBody` 中的 `CircularProgressIndicator` 导致 `pumpAndSettle` 超时——重写中已通过 provider override 消除。
- `dart run custom_lint` → No issues found。
- 用户本机 `flutter run` → 记账 Tab 应显示当前账本 emoji + 名称（📒 生活）+ 预览提示。另 3 个 Tab 行为不变。

**给后续开发者的备忘**
- **`_RecordTabBody` 是临时的**——Phase 3 Step 3.1 首页骨架会用完整的 `RecordHomePage`（顶栏 + 数据卡片 + 快捷输入条 + 流水列表 + FAB）完全替换。届时删除 `_RecordTabBody` 和它在 `_body()` 中的 index=0 分支，`home_shell.dart` 中 `currentLedgerIdProvider` / `ledgerRepositoryProvider` 的 import 也应随之清理（改由 `features/record/` 内部引用）。
- **`currentLedgerIdProvider` 是只读 `Future<String>`**——Phase 4 Step 4.1 账本切换时需升级为 `Notifier`（`@riverpod class CurrentLedgerId extends _$CurrentLedgerId`），使 UI 可 `ref.read(currentLedgerIdProvider.notifier).setLedger(newId)`。升级时 `build()` 方法的初始值逻辑（读第一个活跃账本）保持不变，只加 `setLedger` 方法 + `user_pref.current_ledger_id` 持久化。
- **仓库 provider 绑定了 `LocalXxxRepository` 具体类型**——不是 `Provider<XxxRepository>`。Phase 10 引入 remote 后，需要改这几行 provider 为返回"组合 local + remote 的新实现类"，或者把提供商泛化为 `XxxRepository` 接口类型并在 provider 内部做实现选择。**届时改 provider 函数体即可，不影响消费方**（消费方 `ref.watch(xxxRepositoryProvider)` 拿到的类型是 `AsyncValue<XxxRepository>`，其中 `XxxRepository` 是抽象接口——这就是在这里绑具体实现不绑接口的原因：调用方已经通过接口消费，实现可随时换）。
- **`_FakeLedgerRepository` 只在 widget_test 内定义**——如果 Phase 3 起其他 feature 的 widget 测试也需要假仓库，可以考虑抽到 `test/fakes/` 目录共享复用。当前只有 1 个 fake 类型、4 条 widget 测试，不值得过早抽。
- **widget_test 现在依赖 `uuid` 包**（`_testLedger()` 用 `const Uuid().v4()` 生成 id）——`uuid` 已在 `pubspec.yaml` dependencies 中（Step 0.3），不是新增依赖。
- **widget 测试的 provider override 模式**：对 `FutureProvider<T>` 用 `provider.overrideWith((ref) async => value)`，对同步 `Provider<T>` 用 `provider.overrideWith((ref) => value)`。这是 Riverpod 2.x 的 `ProviderScope.override` 约定——比老版本的 `.overrideWithValue(value)` 更显式，且支持依赖参数。
- **`LedgerRepository.getById` 是 Step 2.3 新增的方法**——不是 Step 2.2 设计遗漏。其余 4 个仓库（Category/Account/Budget/Transaction）目前不需要 `getById`，因为尚无 UI 消费；Phase 3 起各 Tab 真正需要时再加，届时保持与 LedgerRepository 一致的签名模式（`Future<T?> getById(String id)`）。


---

## Phase 3 · 记账主流程

### ✅ Step 3.1 首页骨架（2026-04-25）

**改动**
- `lib/features/record/record_providers.dart`（新建）：3 个类型定义 + 2 个 provider：
  - `@riverpod class RecordMonth extends _$RecordMonth`（Notifier）：`build()` 返回当月 `DateTime(now.year, now.month)`，`previous()` / `next()` 允许月份导航。Phase 5 自定义区间后可扩展为起止日期。
  - `@riverpod Future<RecordMonthSummary> recordMonthSummary(Ref)`：依赖 `recordMonthProvider` + `currentLedgerIdProvider` + `transactionRepositoryProvider`，取当前账本全部活跃流水、客户端按月份过滤、按 `occurredAt` 倒序排列、分收入/支出汇总、再按天分组为 `DailyTransactions` 列表。
  - 数据类 `DailyTransactions` / `RecordMonthSummary`（plain Dart，不依赖 flutter/riverpod）。
- `lib/features/record/record_providers.g.dart`：build_runner 产物（`recordMonthProvider` + `recordMonthSummaryProvider`）。
- `lib/features/record/record_home_page.dart`（新建）：`RecordHomePage`（ConsumerWidget）——全页 `Scaffold`（含自有 FAB），自上而下 5 个区域：
  1. **`_TopBar`**（StatelessWidget）：`currentLedgerIdProvider` + `ledgerRepositoryProvider` → `FutureBuilder<Ledger?>` → 显示 `coverEmoji` + `name` + 下拉箭头（占位）+ 搜索图标（占位）。
  2. **`_MonthBar`**（StatelessWidget）：`ref.watch(recordMonthProvider)` → 左右箭头 + `{year}年{month}月` 标签。`previous()` / `next()` 通过 `ref.read(recordMonthProvider.notifier)` 驱动。
  3. **`_DataCards`**（StatelessWidget）：`summary.valueOrNull` → 3 个 `_CardChip`（收入/支出/结余），分别用抹茶绿 `#A8D8B9` / 苹果红 `#E76F51` / 奶油黄上色，空数据显示 `¥--.--`。
  4. **`_QuickInputBar`**（StatelessWidget）：单行 `TextField`（hint "写点什么，我来帮你记 🐰"）+ `✨ 识别` 按钮，均为占位（onSubmitted / onPressed 留空，Step 3.2 接线）。
  5. **`_TransactionList`**（StatelessWidget）：`summary.when()` 三态——loading `CircularProgressIndicator`、error 文本、data 则判断 `dailyGroups.isEmpty` → 空状态引导（咖啡图标 + "开始记第一笔吧 🐰"）或 `ListView.builder` 按天分组，每组日期 header（"4月25日 周六"）+ 流水 tile（`_TxTile`：类型 emoji + 标签 + 金额 ±¥0.00，当前 `noteEncrypted` 非空显示「[已加密]」否则显示 `tags`）。
  - **FAB**：`FloatingActionButton`（圆角 20、theme primary 色、`+` 图标），onPressed 空（Step 3.2 接入路由 `/record/new`）。
- `lib/features/record/.gitkeep`：删除（目录已有真实文件）。
- `lib/app/home_shell.dart`：index=0 body 从 `_RecordTabBody` 改为 `const RecordHomePage()`。移除 `_RecordTabBody` 类定义和对应的 `currentLedgerIdProvider` / `ledgerRepositoryProvider` / `ledger.dart` import（改为 import `record_home_page.dart`）。
- `test/widget_test.dart`：重写——原有 4 条合并重排为 5 条：
  1. **HomeShell renders all 4 bottom-nav tabs**（不变）。
  2. **BottomNavigationBar background is cream yellow**（不变）。
  3. **Tapping "统计" tab switches body text**（不变）。
  4. **记账 Tab 无数据时显示空状态引导**（新增 Step 3.1）：覆盖 `recordMonthSummaryProvider` 为空汇总，验证顶栏账本名 📒、月份 "2026年4月"、三卡片标签、快捷输入条、"开始记第一笔吧 🐰" 空状态、FAB 存在。
  5. **有 mock 数据时流水列表按天分组**（新增 Step 3.1）：注入 2 条流水（4/25 支出 ¥30 + 4/24 收入 ¥100），验证日期 header "4月25日"/"4月24日"、金额显示 "-¥30.00"/"+¥100.00"、数据卡片 ¥100.00 / ¥30.00 / ¥70.00。
  - 新增 `_FakeTransactionRepository`（实现 `TransactionRepository`，`listActiveByLedger` 返回固定列表）。
  - `_standardOverrides()` 增加 `transactionRepositoryProvider.overrideWith` + `recordMonthSummaryProvider.overrideWith`。

**验证**
- `dart run build_runner build --delete-conflicting-outputs` → 22 outputs，0 error。
- `flutter analyze` → No issues found。
- `flutter test` → 63/63 通过（62 前 + 2 新 - 1 旧 _RecordTabBody 测试 = 63）。
- `dart run custom_lint` → No issues found。
- 用户本机 `flutter run` 待手工验证：记账 Tab 可见完整骨架（顶栏 📒 生活 + 月份导航 + 三色数据卡片 + 快捷输入条 + 空状态引导 + FAB）；点击月份左右箭头应切换月份标签；空状态引导文字显示。

**给后续开发者的备忘**
- **`recordMonthSummaryProvider` 目前做客户端过滤**——`listActiveByLedger` 拉全量活跃流水再按月份客户端过滤。这在流水量 < 1000 条时完全够用；Phase 5 统计聚合需要时再加 DAO 层的 `listActiveByLedgerBetween(ledgerId, from, to)` 方法，把过滤推到 SQL 层。
- **月份切换只改 `RecordMonth` 状态**——`recordMonthSummaryProvider` 通过 `ref.watch(recordMonthProvider)` 自动响应。数据库查询仍走 `listActiveByLedger`（全量），月度导航不触发新 SQL。Phase 10 同步后流水量增长可能有性能压力，届时优化。
- **_TxTile 的分类名称暂用 tags 字段占位**：`tx.tags ?? '未分类'`——Phase 3 Step 3.2 落地分类选择器后，需要改为 `tx.categoryId → CategoryRepository.getById` 的方式显示分类图标 + 名称。目前 _TxTile 里的 emoji 也是硬编码（💸/💰/🔁），届时统一替换。
- **FAB 未接线**：`onPressed` 目前是空函数，Step 3.2 创建 `/record/new` 路由后接入。届时同时需要给 `HomeShell` 的 `goRouter` 加路由——RecordHomePage 内部 `context.go('/record/new')`。
- **搜索图标未接线**：Phase 5+ 统计搜索功能上线后再接。
- **快捷输入条 onSubmitted 未接线**：Step 3.2 / Phase 9 快速输入落地后接。
- **RecordHomePage 使用了内层 Scaffold**（嵌套在 HomeShell 的 Scaffold 内）——这是 Flutter Tab 模式的惯用做法，内层 Scaffold 提供自己的 FAB。如果以后遇到 FAB 定位/安全的视觉问题（比如与 BottomNavigationBar 重叠），可改用 HomeShell 的外层 Scaffold 的 `floatingActionButton` 属性并通过 index 条件显示。
- **widget 测试用 `_FakeTransactionRepository`**——与 `_FakeLedgerRepository` 同模式。Phase 3 Step 3.2/3.3 落地后可能需要更多 fake 类型（CategoryRepository / AccountRepository），届时可考虑抽到 `test/fakes/` 目录共享。
- **`IntrinsicHeight` 用于数据卡片行**——让三个 `_CardChip` 等高。如果未来卡片内容变复杂（比如增进度条），可能需要改为固定高度或 `IntrinsicHeight` 在复杂布局下的性能影响需要关注。
- **`_MonthBar` 用 `StatelessWidget` + 构造注入 `WidgetRef`** 而非 `ConsumerWidget`——原因是月份切换按钮需要 `ref.read(recordMonthProvider.notifier)`。在 `StatelessWidget` + 注入 ref 与 `ConsumerWidget` + 从 `build` 参数拿 ref 之间，前者少一层 widget 嵌套。两种模式均可，本项目后续可自行统一风格。


### ✅ Step 3.2 新建记账页（2026-04-25，后续于 2026-04-26 完成分类模型重构）

**改动**
- 首版（2026-04-25）交付了 Step 3.2 的表单式记账页：金额表达式、分类选择、账户选择、时间备注、自定义数字键盘等（文件含 `record_new_page.dart`、`record_new_providers.dart`、`number_keyboard.dart`，并接入 `/record/new` 路由与首页 FAB 跳转）。
- 按后续需求于 2026-04-26 做了**不兼容重构**（一级/二级分类 + 收藏）并完成联动：
  - 数据模型重构：
    - `lib/data/local/tables/category_table.dart`：`category` 表移除 `ledger_id/type`，新增 `parent_key/is_favorite`。
    - `lib/data/local/dao/category_dao.dart`：新增 `listActiveByParentKey` / `listFavorites` / `updateFavoriteById` 等查询与写接口。
    - `lib/domain/entity/category.dart`、`lib/data/repository/entity_mappers.dart`、`lib/data/repository/category_repository.dart`：统一到新字段语义，并新增收藏开关能力（`toggleFavorite`）。
    - `lib/data/local/seeder.dart`：分类种子改为固定一级分类映射下的二级分类，默认非收藏。
    - `lib/data/local/app_database.dart`：`schemaVersion` 升至 v3，`v2 -> v3` 按需求直接重建 `category`（不兼容旧结构）。
  - 记一笔状态层重构：
    - `lib/features/record/record_new_providers.dart`：去除手动 `type` 切换，改为 `selectedParentKey` 驱动；新增自动收支判定（`parentKey == 'income'` => `income`，否则 `expense`）；保存时自动写入流水 `type`。
  - 记一笔 UI 重构：
    - `lib/features/record/record_new_page.dart`：移除顶部"收入/支出/转账 Tab"，新增底部一级分类单字 Tab：`☆/收/食/购/行/育/乐/情/住/医/投/其`；
    - 分类区改为按一级或收藏过滤二级分类；
    - `☆` 页签展示收藏二级分类，作为快捷入口。
- 测试与联调：
  - `test/features/record/record_new_providers_test.dart`、`test/features/record/record_new_page_test.dart` 完成重构适配；
  - 连同 `test/data/local/*`、`test/domain/entity/entities_test.dart` 的旧字段断言一起迁移，确保新分类结构下测试通过。

**验证**
- `dart run build_runner build --delete-conflicting-outputs` 成功（含 `record_new_providers.g.dart` 与 drift/riverpod 相关产物更新）。
- `flutter analyze`：重构收口后为 0 issue。
- `flutter test`：核心用例（`record_new_providers_test` / `record_new_page_test`）及受影响数据层/实体测试均完成适配并通过。
- 用户侧流程验收关注点更新为：
  1. 记账首页 FAB → 新建页；
  2. 底部一级分类单字 Tab 可切换；
  3. 选中一级为 `收` 的二级分类保存后，流水自动记为 `income`；
  4. 其余一级分类保存后自动记为 `expense`；
  5. 切到 `☆` 可快速使用收藏二级分类。

**给后续开发者的备忘**
- **`copyWith(amount: null)` 语义 = "不改"**：`RecordFormData.copyWith` 对所有 `T?` 参数用 `??` 兜底，null 表示保持旧值。这意味着 `onKeyTap` 在表达式不完整（如 `1+`）时 `_parseExpr` 返回 null → copyWith 保留上一步的 amount。`_AmountDisplay` 用 `expression.isEmpty ? '0'` 控制表达式显示，amount 则用 `form.amount ?? 0` 兜底——两者独立，保证 UI 不会因 copyWith 语义而"卡住"。
- **`_parseExpr` 是递归下降**：从右向左找最后一个 `+`/`-` 做分割点，左右递归求值。不支持 `*`/`/` 和括号——记账场景只需加减。括号键虽在键盘上但 `onKeyTap` 的 default 分支直接把 `(` `)` 拼进 expression 字符串，`_parseExpr` 会因为不匹配数字正则也不含 `+`/`-` 而返回 null（括号非法 token）。
- **转账 Tab 目前 disabled**：`_TypeTabs.onSelected` 里 `if (value == 'transfer') return;`——Step 3.4 转账表单落地上线后移除这行。
- **`NumberKeyboard` 的 `✓` 键 disabled 与保存按钮同步**：`canSave` 同时传给 `NumberKeyboard` 和 `_SaveButton`，确保两处都无法提交不完整表单。
- **“再记一笔”已移除（2026-04-26）**：`RecordFormData` 不再含 `keepOpen`，`RecordForm` 不再提供 `toggleKeepOpen`，`save()` 不再执行“保存后清空并停留本页”的分支，统一为保存成功后由页面 `Navigator.pop()` 返回。相关单测已同步删除/改写。
- **widget 测试中的滚动问题**：`RecordNewPage` 内容超出 test viewport（800×600），Switch 和保存按钮需要 `scrollUntilVisible` 才能点到。新增的 `scrollToVisible` helper 封装了这一操作。
- **`recordMonthSummaryProvider` override 在 save 测试中必要**：`save()` 内部 `ref.invalidate(recordMonthSummaryProvider)` 会触发 FutureProvider 重建；若不 override，测试环境 dispose 时可能报 "Future already completed"。`_saveOverrides()` 专门为此场景提供完整 override 集合。




### ✅ Step 3.2 键盘布局与测试回归修正（2026-04-26）

**改动**
- `lib/features/record/widgets/number_keyboard.dart`：将数字键盘布局统一为 4 行设计稿版本：
  - `7 8 9 ⌫`
  - `4 5 6 +`
  - `1 2 3 -`
  - `CNY 0 . ✓/=`
- 移除 `C` 清空键与括号键，底部左侧改为币种键 `CNY`；右下动作键保持动态（表达式态显示 `=`，普通态显示 `✓`）。
- `memory-bank/implementation-plan.md`：修正 Step 3.2 中错误的旧键盘描述，使计划文档与当前实现一致。
- `test/features/record/record_new_page_test.dart`：删除 `C` 键相关测试/断言，调整键盘渲染断言以匹配新布局与动态动作键行为。

**验证**
- `flutter test test/features/record/record_new_page_test.dart test/features/record/record_new_providers_test.dart`：通过（Exit code 0）。
- 关键回归点确认：
  1. 键盘完整渲染用例通过（新 4 行布局）；
  2. 记账页金额输入/退格/保存态用例通过；
  3. provider 侧表达式与保存逻辑用例通过。

**给后续开发者的备忘**
- 动作键是**动态文案**（`showEquals ? '=' : '✓'`），widget 测试不要把 `=` 当成全局静态存在项；建议按场景断言（表达式态断言 `=`，可保存态断言 `✓` 或断言动作键组件存在）。
- `C` 键已经从产品设计中移除；后续若引入“清空表达式”能力，应通过明确的新交互入口实现，不要复用旧测试。
- 此次仅做 Step 3.2 回归修正与文档纠偏，未开始 Step 3.4（转账）。


### ✅ Step 3.3 流水详情/编辑复制/删除（2026-04-26）

**改动**
- `lib/features/record/record_home_page.dart`：
  - 首页流水点击从“直接进入编辑”改为“先进入只读详情底部页”。
  - 新增 `_RecordDetailSheet`（只读展示金额、类型、日期、备注等）与 `_DetailAction` 操作流。
  - 详情页提供 3 个动作：`编辑` / `复制` / `删除`。
  - `编辑` 与 `复制` 统一复用 `RecordNewPage`，通过 `recordFormProvider.notifier.preloadFromEntry(...)` 预填；`asEdit=true` 进入编辑语义，`asEdit=false` 进入复制新建语义。
  - 首页列表新增左滑删除（`Dismissible`），并带二次确认弹窗；确认后执行软删除、刷新月汇总、提示“已删除”。
  - FAB 新建前显式重置 `recordFormProvider`，避免上次编辑态残留到新建表单。
- `test/data/repository/transaction_repository_test.dart`：
  - 增强 update 用例：断言第二次保存 `updated_at` 晚于第一次，且第二条 upsert payload 包含新的 `updated_at` 与覆写后的 `device_id`。
  - 增强 soft delete 用例：除 `listActiveByLedger` 不可见外，额外直查 `transaction_entry` 物理行，断言 `deleted_at != null`（验证“软删除而非硬删除”）。

**验证**
- `flutter test test/data/repository/transaction_repository_test.dart` 通过（4/4）。
- 已覆盖 Step 3.3 关键数据契约：
  1. 编辑保存会刷新 `updated_at` 并入队 upsert；
  2. 软删除后首页数据源不可见，但库内行仍在且 `deleted_at` 非空；
  3. 删除动作会入队 delete，同步 payload 含 `deleted_at` 与 `device_id`。

**给后续开发者的备忘**
- 当前 Step 3.3 的“详情页”以 bottom sheet 形式实现，保持与“新建/编辑页”交互层级一致；若后续要改为独立路由页，优先保留现有动作分发语义（详情只读 + 编辑/复制/删除分支）不变。
- `复制` 复用 `preloadFromEntry(..., asEdit: false)`，确保不会覆盖原流水 id；任何后续表单重构都应保留该约束。
- 本步未进入 Step 3.4（转账），与转账字段（`toAccountId`、双分录等）无耦合改动。

### ✅ Step 3.4 转账功能（2026-04-26）

**改动**
- `lib/features/record/record_home_page.dart`：
  - 顶栏搜索图标左侧新增转账入口（`Icons.swap_horiz`），点击打开转账底部页（`RecordNewPage(isTransfer: true)`）。
  - 流水列表 `_TxTile` 增加转账展示分支：图标统一 `🔁`，金额色改为蓝色系（`#6C8CC8`），副标题展示账户流向 `转出账户 → 转入账户`。
  - 转账金额显示改为中性（不加 `+/-`），收入/支出仍保留符号。
  - 引入 `accountRepositoryProvider` 并在 tile 内解析 `accountId/toAccountId` 对应账户名。
- `lib/features/record/record_new_page.dart`：
  - `RecordNewPage` 增加 `isTransfer` 入参，支持“记一笔 / 转账”双模式。
  - 转账模式标题显示“转账”，并改为“先选账户后输金额”流程：
    1. 进入页先显示 `_TransferEntryStage`（转出账户、日期、转入账户、备注）；
    2. 仅当转出/转入账户均已选择后，“输入金额”按钮可用；
    3. 进入键盘态后复用现有金额输入与时间/备注编辑。
  - `_MetaToolbar` 扩展为转账双账户形态：左侧“转出账户”、右侧“转入账户”；普通记账模式保持“分类 + 日期 + 钱包”。
  - 保存前增加 UI 校验：若转出账户与转入账户相同，阻断提交并提示 `转出账户和转入账户不能相同`。
  - 新增 `_WalletPillButton` 的 `emptyText` / `icon` 参数，适配转入/转出语义。
- `lib/features/record/record_new_providers.dart`：
  - `RecordFormData` 新增 `isTransfer`、`toAccountId` 字段。
  - `inferredType` 在转账模式返回 `transfer`。
  - `canSave` 在转账模式改为：金额 > 0、`accountId` 非空、`toAccountId` 非空、且两者不同。
  - 新增 `setTransferMode(bool)` 与 `setToAccount(String?)`。
  - `save()` 在转账模式下写入：
    - `type = 'transfer'`
    - `accountId`（转出）
    - `toAccountId`（转入）
    - `categoryId = null`
- `lib/data/repository/transaction_repository.dart`：
  - 在仓库 `save()` 中补强 transfer 防御校验（UI 之外的第二道护栏）：
    - `type == 'transfer'` 时要求 `accountId` / `toAccountId` 非空；
    - 且两者不可相同；
    - 不满足则抛 `ArgumentError`。
- 测试更新：
  - `test/features/record/record_new_providers_test.dart`：
    - 新增“转账模式 canSave 依赖双账户且不可相同”用例。
    - 新增“转账保存写入 transfer + toAccountId 且 categoryId 为空”用例。
    - 为涉及 `SharedPreferences` 的保存路径补充 `TestWidgetsFlutterBinding.ensureInitialized()` 与 `SharedPreferences.setMockInitialValues`，避免测试环境绑定未初始化报错。
  - `test/features/record/record_new_page_test.dart`：
    - 新增“转账页标题与入口渲染”用例。
    - 新增“转账模式需选择两个不同账户后才能进入金额输入”用例。
    - `_testAccount` 改为可传 `id/name`，用于转账双账户场景构造。

**验证**
- 运行：
  - `flutter test test/features/record/record_new_providers_test.dart test/features/record/record_new_page_test.dart`
- 结果：
  - 首轮失败 1 条（`Binding has not yet been initialized`，来源于新增 provider 保存用例走到 `SharedPreferences`）。
  - 修复测试初始化后复跑通过：`All tests passed!`（32 个用例通过）。

**给后续开发者的备忘**
- Step 3.4 当前采用“单条 transfer 记录”语义（一条流水持有 `accountId` + `toAccountId`），未拆成“双分录”记账模型；这与现有统计口径（仅统计 income/expense）兼容，且首页展示已区分。
- 转账模式下 `categoryId` 明确置空；任何后续统计/筛选逻辑不要假设 transfer 一定有分类。
- UI 与仓库已做双层“同账户禁止”校验：UI 层用于即时反馈，仓库层用于防御式约束（防止绕过 UI 的非法写入）。
- 本步已完成 Step 3.4 的功能与测试收口；按当前约束，尚未开始 Step 3.5（图片附件）。

### ✅ Step 3.5 图片附件（2026-04-26）

**改动**
- `pubspec.yaml`：
  - 新增依赖 `image_picker: ^1.1.2`，用于“从相册选择/拍照”两条入口。
- `lib/features/record/record_new_providers.dart`：
  - `RecordFormData` 新增 `attachmentPaths`（`List<String>`）字段，`copyWith` 同步扩展。
  - `RecordForm` 新增附件能力：
    - `canAddAttachment`（最多 3 张约束）；
    - `pickAndAttachFromGallery()` / `pickAndAttachFromCamera()`；
    - `removeAttachmentAt(int index)`；
    - `_attachPickedFile(XFile)`：把选择结果复制到应用沙盒 `<documents>/attachments/<tx_id>/...`；
    - `_encodeAttachmentPaths(List<String>)` / `_decodeAttachmentPaths(Uint8List?)`：附件路径数组与 `attachmentsEncrypted`（BLOB）之间做 UTF-8 JSON 编解码。
  - `preloadFromEntry(...)` 增加附件读回：从 `TransactionEntry.attachmentsEncrypted` 解析出路径数组并写入表单态（用于编辑/复制回显）。
  - `save()` 增加附件写入：将 `attachmentPaths` 编码后写入 `TransactionEntry.attachmentsEncrypted`（当前为“明文 JSON bytes”语义，字段级加密仍属 Phase 11）。
- `lib/features/record/record_new_page.dart`：
  - `_NotePillButton` 从 `StatelessWidget` 调整为 `ConsumerWidget`，直接监听 `recordFormProvider` 读取附件状态。
  - 备注弹层新增附件区：
    - 缩略图横向列表（`Image.file`）；
    - 单张删除入口；
    - “相册”与“拍照”两个添加按钮；
    - 附件计数显示（`x/3`）；
    - 达上限时通过 Snackbar 提示。
- `test/features/record/record_new_providers_test.dart`：
  - 新增保存路径断言：`attachmentPaths` 会被编码进 `attachmentsEncrypted`，且解码后 JSON 数组与原路径列表一致。

**验证**
- 测试链路：
  1. 初次运行受 Windows 开发者模式（symlink）限制，按提示启用后继续；
  2. 引入附件 UI 后出现一次编译错误（`_NotePillButton` 中 `form` 未定义），修复为 `ref.watch(recordFormProvider)` 后收口。
- 最终执行：
  - `flutter test test/features/record/record_new_providers_test.dart test/features/record/record_new_page_test.dart`
- 结果：
  - `All tests passed!`（33/33）。

**给后续开发者的备忘**
- Step 3.5 当前把附件列表写入 `transaction_entry.attachments_encrypted` 的**明文 JSON bytes**（UTF-8），这是实施计划要求；Phase 11 Step 11.2 接字段级加密时，应把该 JSON 先经 `BianbianCrypto.encrypt(...)` 后再落库，并保持向后兼容旧明文记录的迁移策略。
- 附件文件已复制到应用沙盒路径，数据库仅保存本地路径字符串数组。若后续做“导出/同步”，需要同时处理文件实体（仅同步路径会丢失内容）。
- 当前上限为 3 张，约束在 provider 层（`canAddAttachment`）与 UI 层双重生效。若未来调整为配置化上限，优先抽成共享常量并同步测试断言。
- 本步严格停在 Step 3.5；按约束“在用户验证测试前不开始 Step 4.1”，未进行任何 Step 4.1 开发。

---

## Phase 4 · 多账本

### ✅ Step 4.1 账本 Tab 列表（2026-04-26）

**改动**
- `lib/data/local/dao/transaction_entry_dao.dart`：新增 `countActiveByLedger(ledgerId)` 方法——按账本统计未软删流水条数，供账本列表展示"流水总数"。
- `lib/data/repository/providers.dart`：`currentLedgerId` 从 `Future<String>` 升级为 `AsyncNotifier`（`@riverpod class CurrentLedgerId extends _$CurrentLedgerId`）：
  - `build()` 先查 `user_pref.current_ledger_id` → 校验该账本仍存在且活跃 → 命中直接返回；否则回退到第一个活跃账本并写回 `user_pref`。
  - 新增 `switchTo(String newId)`：持久化到 `user_pref.current_ledger_id` 然后 `invalidateSelf()` 触发重建。依赖方（`record_home_page` / `record_providers` / `record_new_providers`）通过 `ref.watch(currentLedgerIdProvider)` / `.future` 等标准访问方式不受影响。
  - 新增 `import '../local/app_database.dart';` 以直接引用 `UserPrefTableCompanion`。
- `lib/features/ledger/ledger_providers.dart`（新建）：`LedgerTxCounts`（`AsyncNotifier`，`keepAlive: true`）——遍历活跃账本，逐个调 `countActiveByLedger`，产出 `Map<String, int>`（账本 id → 流水条数）。暴露 `invalidate()` 供切换账本 / 写流水后刷新。
- `lib/features/ledger/ledger_list_page.dart`（新建）：
  - `LedgerListPage`（`ConsumerWidget`）：`watch(ledgerRepositoryProvider)` + `watch(currentLedgerIdProvider)` + `watch(ledgerTxCountsProvider)`，loading/error/data 三态。
  - `LedgerGroups` 数据类 + `ledgerGroupsProvider`（`@riverpod FutureProvider`）：`repo.listActive()` 后客户端按 `archived` 分两组。
  - `_LedgerListContent`（`ConsumerWidget`）：`ListView` 渲染。活跃区：每张 `_LedgerCard` 显示 `coverEmoji`（36px）+ 名称 + "N 笔流水 · CNY" 副标题，当前账本高亮奶油黄底 + ✓ 图标，点击调 `switchTo` 切换。归档区：标题 "已归档" + 置灰卡片（archive 图标）。
- `lib/app/home_shell.dart`：
  - 移除 `_LedgerPreviewBody` 及其 `ConsumerStatefulWidget` 全部定义（Step 1.7 临时预览正式退役）。
  - 移除 `data/local/app_database.dart`、`data/local/providers.dart`、`flutter_riverpod.dart` 三行 import。
  - index=2 分支改为 `const LedgerListPage()`；新增 `features/ledger/ledger_list_page.dart` import。
- `lib/features/ledger/.gitkeep`：删除（目录已有真实文件）。
- `test/widget_test.dart`：新增 `_TestCurrentLedgerId extends CurrentLedgerId`（覆盖 `build()` 返回固定 id）；两处 `currentLedgerIdProvider.overrideWith` 从 `(ref) => '...'` 改为 `() => _TestCurrentLedgerId('...')` 以匹配 `AsyncNotifierProvider` 的 override 签名。
- `test/features/record/record_new_providers_test.dart`：import 中 `show` 追加 `CurrentLedgerId`；新增同名 `_TestCurrentLedgerId` 类；两处 override 语法同步升级。
- `test/features/record/record_new_page_test.dart`：同上——新增 `_TestCurrentLedgerId` 类 + override 语法升级。

**验证**
- `dart run build_runner build --delete-conflicting-outputs` → 成功，产出 `ledger_providers.g.dart` / `ledger_list_page.g.dart` + `providers.g.dart` 重生成（`currentLedgerIdProvider` 从 `FutureProvider` 变 `AsyncNotifierProvider`）。
- `flutter analyze` → 0 新增 issue（7 条预存 info/warning 均来自 `record_home_page.dart`，与本步无关）。
- `flutter test` → 95/95 通过（数据层 + 领域层 + 仓库层 + record feature + widget 测试全线回归）。
- `dart run custom_lint` → 3 条预存 INFO（`record_new_providers.dart` 的 `avoid_public_notifier_properties`），与本步无关。
- 用户本机 `flutter run` 待手工验证：
  1. 账本 Tab 可见「📒 生活」卡片 + 「0 笔流水 · CNY」副标题 + 奶油黄高亮 + ✓ 图标。
  2. 点击"生活"卡片无反应（已是当前账本）。
  3. （需 Step 4.2 新建账本后验证）切换账本后：首页顶栏账本名立即切换、流水列表切换、账本 Tab 高亮迁移。
  4. 归档区当前为空（种子账本未归档）。

**给后续开发者的备忘**
- **`currentLedgerIdProvider` 现在是 `AsyncNotifierProvider`**——任何未来新增的 test 文件需要 override 它时，必须用 `() => _TestCurrentLedgerId(id)` 模式，不能用旧的 `(ref) => id` FutureProvider 语法。
- **`switchTo` 与 `build` 的协作**：`switchTo` 写 `user_pref` → `invalidateSelf` → `build` 重跑并读到刚写入的值。这就是为什么 `build` 必须先查 `user_pref.current_ledger_id`——否则 invalidate 后又会回退到"第一个活跃账本"而不是刚切换的目标。如果未来发现切换后偶尔"跳回第一个"的 race，排查方向是该次 build 是否在 `switchTo` 的 update 提交之前就跑了。
- **`LedgerTxCounts` 目前全量重建**：`invalidate()` 会让整个 `Map<String, int>` 重建（所有账本各一次 COUNT 查询）。在 V1 阶段账本数 ≤ 10 时完全OK；若 Phase 10 同步后某用户有 50+ 账本，可改为"单账本增量刷新"（加一个 `increment(id, delta)` 方法或在 `recordMonthSummaryProvider` 里顺便刷新）。
- **`ledgerGroupsProvider` 走了 `ledgerRepositoryProvider.future`**——这意味着它隐式依赖 `appDatabaseProvider` + `deviceIdProvider`。务必确保在 `ProviderScope` 内这两个底层的 override 也存在（widget_test 中已有 `_standardOverrides()` 提供）。
- **`_LedgerCard` 的归档区点击是空操作**（`onTap: () {}`）——Step 4.2 的"取消归档"功能接入后，应把归档卡片的 onTap 改为"弹出取消归档确认"。
- **本步完成了 Step 4.1；按约束，在用户验证测试前不开始 Step 4.2。**

### ✅ 千分位分隔符 + 数据卡片纵向布局（2026-04-26）

**改动**
- `lib/features/record/record_home_page.dart`：
  - 新增 `final _fmt = NumberFormat('#,##0.00');`（`package:intl`），用于所有金额显示的千分位分隔。
  - `_DataCards` 从水平 `Row` 改为垂直 `Column`（spacing: 6px），每张卡片占一整行，避免百万级金额换行溢出。
  - `_CardChip` 从纵向叠放（label 上 / amount 下）改为横向 `Row(spaceBetween)`（label 左 / amount 右），适配整行宽卡片。
  - 修复括号语法错误：`Container` 闭括号多余逗号导致多余的 `);`。
  - 3 处金额显示（收入/支出/结余）改用 `_fmt.format(amount)` 替代 `.toStringAsFixed(2)`。

**验证**
- `flutter analyze` → No issues found。
- `flutter test` → 95/95 通过。
### ✅ Step 4.2 新建/编辑/归档/软删除账本（2026-04-27）

**改动**
- `lib/data/local/dao/transaction_entry_dao.dart`：新增 `softDeleteByLedgerId(ledgerId, {deletedAt, updatedAt})`——批量软删除某账本下所有未软删流水，返回受影响行数。
- `lib/data/local/dao/budget_dao.dart`：新增 `softDeleteByLedgerId(ledgerId, {deletedAt, updatedAt})`——批量软删除某账本下所有未软删预算，返回受影响行数。
- `lib/data/repository/transaction_repository.dart`：接口新增 `softDeleteByLedgerId(String ledgerId)`；`LocalTransactionRepository` 实现：先查出所有将被软删的流水 → 调 DAO 批量写 `deleted_at`/`updated_at` → 逐条入队 sync_op delete。
- `lib/data/repository/budget_repository.dart`：接口新增 `softDeleteByLedgerId(String ledgerId)`；`LocalBudgetRepository` 实现同上模式。
- `lib/data/repository/ledger_repository.dart`（重写）：
  - 接口新增 `setArchived(String id, bool archived)`——归档/取消归档，返回更新后的实体快照。
  - `LocalLedgerRepository` 新增持有 `TransactionEntryDao` / `BudgetDao`。
  - `softDeleteById` 改为级联：先调 `_txDao.softDeleteByLedgerId` → 再调 `_budgetDao.softDeleteByLedgerId` → 最后软删账本自身。全部在同一事务内完成。
  - `setArchived` 实现：查行 → 覆写 `archived`/`updated_at`/`device_id` → 入队 sync_op upsert。
- `lib/features/ledger/ledger_edit_page.dart`（新建）：`LedgerEditPage`（ConsumerStatefulWidget）——支持新建/编辑双模式。表单含名称、封面 Emoji、默认币种下拉（CNY/USD/EUR/JPY/KRW/GBP/HKD）；编辑模式额外显示归档开关。保存时新建走 `const Uuid().v4()` 生成 id，编辑走 `copyWith` 更新；保存后 invalidate 相关 provider。
- `lib/app/app_router.dart`：新增路由 `/ledger/edit`（可选 query 参数 `id` 进入编辑模式）。
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

**验证**
- `dart run build_runner build --delete-conflicting-outputs` → 成功，102 outputs，0 error。
- `flutter analyze` → No issues found。
- `flutter test` → 95/95 通过（全线回归）。
- `dart run custom_lint` → 3 条预存 INFO（`record_new_providers.dart` 的 `avoid_public_notifier_properties`），与本步无关。
- 用户本机 `flutter run` 待手工验证：
  1. 账本 Tab 底部出现"新建账本" FAB，点击进入新建页。
  2. 新建页填写名称/emoji/币种后保存，返回账本列表可见新卡片。
  3. 长按活跃账本卡片 → 弹出菜单（编辑/归档/删除）。
  4. 归档后账本移至"已归档"折叠区；长按可取消归档。
  5. 删除非当前账本 → 二次确认 → 删除成功（级联删除流水+预算）。
  6. 当前账本删除按钮置灰，提示"请先切换到其他账本"。
  7. 编辑账本可修改名称/emoji/币种/归档状态。

**给后续开发者的备忘**
- **级联删除在仓库层而非 SQLite FK 层**：`softDeleteById` 在同一事务内依次调 `_txDao.softDeleteByLedgerId` → `_budgetDao.softDeleteByLedgerId` → 软删账本自身。分类已全局化（无 `ledger_id`），不需要级联。若未来某张新表也挂 `ledger_id`，需在此处补一行调用。
- **`setArchived` 与 `softDeleteById` 的区别**：归档只改 `archived` 列，不碰 `deleted_at`；软删除写 `deleted_at` 并级联。两者都入队 sync_op（归档走 upsert、软删走 delete），确保对端同步。
- **`LedgerEditPage` 的 `_loadLedgerFuture` 在 `initState` 中初始化**——这是为了避免 `build` 中多次触发异步加载。编辑模式下若 ledgerId 对应的账本已被删除，页面显示"账本不存在"。
- **账本列表的 FAB 是 `FloatingActionButton.extended`**——带文字标签"新建账本"，比纯图标 FAB 更直观。底部 padding 88px 为 FAB 留出空间，避免最后一张卡片被遮挡。
- **删除确认对话框使用 `showDialog<bool>`**——返回 `true` 才执行删除，防止误操作。删除后若为当前账本，`currentLedgerIdProvider` 的 `build()` 会自动回退到第一个活跃账本。
- **本步完成了 Step 4.2；按约束，在用户验证测试前不开始 Step 4.3。**


### ✅ Step 4.3 顶栏账本切换器（2026-04-28）

**改动**
- `lib/features/record/record_home_page.dart`：
  - 顶栏账本名称区域（emoji + 名称 + 下拉箭头）从只读展示升级为可点击切换入口（`InkWell`）。
  - 点击后弹出底部账本选择面板，数据源使用 `ledgerGroupsProvider`，仅展示未归档账本。
  - 当前账本项显示勾选状态；点击其他账本后调用 `currentLedgerIdProvider.notifier.switchTo(...)` 持久化切换。
  - 切换成功后显式 `invalidate(recordMonthSummaryProvider)` 与 `invalidate(ledgerTxCountsProvider)`，确保首页汇总/流水与账本页计数同步刷新。
  - 引入 `ledger_list_page.dart`（`ledgerGroupsProvider`）与 `ledger_providers.dart`（`ledgerTxCountsProvider`）依赖。
- 其它文件未改动业务逻辑；`CurrentLedgerId.build()` 的“重启恢复上次账本”能力沿用 Step 4.1 既有实现。

**验证**
- `flutter analyze` → No issues found。
- `flutter test` → All tests passed（95/95，全量回归通过）。

**给后续开发者的备忘**
- Step 4.3 的“跨页面同步”当前通过 `ref.invalidate(...)` 显式触发，目标是首页与账本页即时一致。后续若统计/预算/资产页接入账本维度（Phase 5+），应保持同一策略（或统一抽象为“账本切换事件”）。
- 顶栏切换面板依赖 `ledgerGroupsProvider`，其内部基于 `ledgerRepository.listActive()` 再按 `archived` 客户端分组；若后续账本规模显著增大，可考虑 DAO 层拆分“仅活跃”查询以减少列表处理成本。
- 本步已完成 Step 4.3。按用户约束：**在用户验证测试前不开始 Step 5.1**。

### ✅ Step 5.1 时间区间选择器（2026-04-28）

**改动**
- `lib/features/stats/stats_range_providers.dart`（新建）：
  - 新增 `StatsRangePreset`：`thisMonth / lastMonth / thisYear / custom`。
  - 新增 `StatsDateRange`：提供 `month(...)` / `year(...)` 构造及 `normalize(start, end)`（支持跨年、起止反转自动纠正，并落到整天边界）。
  - 新增 `StatsRangeState`：承载当前 preset 与当前区间。
  - 新增 `@Riverpod(keepAlive: true) class StatsRange`：
    - `build()` 默认“本月”；
    - `setPreset(...)` 支持本月/上月/本年快速切换；
    - `setCustomRange(...)` 写入自定义区间。
- `lib/features/stats/stats_page.dart`（新建）：
  - 新增统计页 `StatsPage`（ConsumerWidget），顶部接入区间选择器（本月/上月/本年/自定义）。
  - 自定义区间通过 `showDateRangePicker` 选择后写回 `statsRangeProvider`。
  - 页面展示当前生效区间文案，为 Step 5.2+ 图表联动提供统一状态源。
- `lib/features/stats/.gitkeep`：删除（该目录已有真实文件）。
- `lib/app/home_shell.dart`：
  - 统计 Tab（index=1）从占位 `_PlaceholderTab(label: '统计')` 替换为 `const StatsPage()`，正式接入 Step 5.1 页面。
- `test/features/stats/stats_range_providers_test.dart`（新建）：
  - 新增区间计算测试：
    1. 本月/上月/本年边界计算正确；
    2. 自定义区间跨年且传入反序时能被 normalize 成正确顺序与日边界。

**验证**
- `dart run build_runner build --delete-conflicting-outputs`：成功（生成 `stats_range_providers.g.dart` 等产物）。
- `flutter analyze`：No issues found。
- `flutter test`：All tests passed（97/97，全量回归通过）。

**给后续开发者的备忘**
- Step 5.1 仅完成“区间状态 + 选择器 UI + 统计 Tab 接入”，**未开始 Step 5.2 折线图**。
- 后续图表（Step 5.2/5.3/5.4/5.5）应统一订阅 `statsRangeProvider` 作为时间过滤来源，避免各图表重复维护各自时间状态。

### ✅ Step 5.2 收支折线图（2026-04-28）

**改动**
- `lib/features/stats/stats_range_providers.dart`：
  - 新增 `StatsLinePoint` 数据类（`day/income/expense`）。
  - 新增 `@Riverpod(keepAlive: true) Future<List<StatsLinePoint>> statsLinePoints(...)`：
    1. 读取当前统计区间（`statsRangeProvider`）；
    2. 读取当前账本（`currentLedgerIdProvider.future`）；
    3. 读取流水仓库（`transactionRepositoryProvider.future`）；
    4. 拉取当前账本活跃流水后，按区间过滤；
    5. 排除 `type='transfer'`；
    6. 按天聚合收入/支出金额并按日期升序输出。
- `lib/features/stats/stats_page.dart`：
  - 引入 `fl_chart`，将 Step 5.1 的占位文本替换为真实图表卡片。
  - 新增 `_IncomeExpenseLineCard`（订阅 `statsLinePointsProvider`，处理 loading/error/data 三态）。
  - 新增 `_LineChartView`：绘制“收入（绿）/支出（红）”双折线，X 轴按日期、Y 轴按金额动态缩放，支持触摸提示。
  - 新增 `_LineChartEmptyState`：空数据显示“暂无收支数据”占位。
  - 颜色来源为 `BianBianSemanticColors`（success/error），与设计语义一致。
- `test/features/stats/stats_range_providers_test.dart`：
  - 维持 Step 5.1 的区间边界测试（本月/上月/本年 + normalize）。
  - 移除无效的 `StatsLinePoint` 手工构造用例（该类型不应作为 provider 聚合逻辑替代测试）。

**验证**
- `flutter test test/features/stats/stats_range_providers_test.dart` → 2/2 通过（All tests passed）。
- 本步未引入 Step 5.3（分类饼图）任何代码。

**给后续开发者的备忘**
- `statsLinePointsProvider` 当前采用“仓库拉当前账本全量活跃流水 + 客户端区间过滤 + 客户端分组聚合”的策略，V1 数据规模下可接受；若后续流水量显著增大，可在 DAO/Repository 增加按区间聚合 SQL（例如 `GROUP BY date(occurred_at)`）以减轻 UI 侧计算压力。
- 折线图 Y 轴上限当前用“最大值 × 1.15”留顶部呼吸区；若未来要与预算阈值联动，可改成“max(预算阈值, 当前最大值) × padding”。
- 按用户约束：**在用户验证测试前不要开始 Step 5.3**，本步已严格遵守。

### ✅ Step 5.3 分类饼图（2026-04-28）

**改动**
- `lib/features/stats/stats_range_providers.dart`：
  - 新增 `StatsPieSlice` 数据类（`categoryId/categoryName/categoryColor/amount/percentage`）。
  - 新增 `aggregatePieSlices(...)` 纯函数：从流水列表中提取支出、按分类聚合金额、取 Top 6 + 其余归入"其他"，百分比求和为 100%。
  - 新增 `_piePalette`（6 色奶油兔板）与 `_parseHexColor` 辅助函数——分类自身有颜色时优先使用，否则按索引循环取调色板色。
  - 新增 `@Riverpod(keepAlive: true) statsPieSlices(...)`：依赖 `statsRangeProvider` + `currentLedgerIdProvider` + `transactionRepositoryProvider` + `categoryRepositoryProvider`，拉取当前账本活跃流水与全量分类，调 `aggregatePieSlices` 产出饼图切片列表。
  - 修复 `package:flutter/foundation.dart` 导入冲突：限制为 `show visibleForTesting`，避免 `Category` 与 domain entity 同名歧义。
- `lib/features/stats/stats_page.dart`：
  - `StatsPage` 统计区从单一 `_IncomeExpenseLineCard` 重构为 `SingleChildScrollView` + `Column` 双卡片布局。
  - 新增 `_CategoryPieCard`（ConsumerWidget）：订阅 `statsPieSlicesProvider`，处理 loading/error/data 三态。
  - 新增 `_PieChartView`（StatefulWidget）：`fl_chart` `PieChart`，支持触摸反馈（选中切片放大 + 标签显示金额），颜色来自 `StatsPieSlice.categoryColor`，文字颜色按背景亮度自动切换黑白。
  - 新增 `_PieChartEmptyState`：空数据显示"暂无支出数据"占位。
  - 新增 `_LegendList`：饼图右侧图例列表（圆点 + 分类名），可滚动。
- `test/features/stats/stats_range_providers_test.dart`：
  - 新增 `makeTx` / `makeCat` 本地辅助函数。
  - 新增 7 条 `aggregatePieSlices` 测试：
    1. 空列表返回空；
    2. 排除 income/transfer 类型；
    3. 4 分类百分比和 = 100%；
    4. >6 分类时 Top 6 + 其他；
    5. 排除超出时间范围的流水；
    6. 使用分类自身颜色；
    7. 无颜色时回退调色板首色。
- `test/widget_test.dart`：
  - `_standardOverrides()` 新增 `statsLinePointsProvider` / `statsPieSlicesProvider` override（空列表），修复 StatisticsPage 引入后由于异步 provider 未 override 导致的 `pumpAndSettle` 超时。

**验证**
- `dart run build_runner build --delete-conflicting-outputs` → 成功。
- `flutter analyze` → No issues found。
- `flutter test` → 104/104 通过（97 前 + 7 新 pie 测试，全线回归）。
- `dart run custom_lint` → 3 条预存 INFO（`record_new_providers.dart`），与本步无关。

**给后续开发者的备忘**
- `aggregatePieSlices` 作为纯函数从 provider 中抽出，方便单元测试；后续若需调整分组逻辑（如改为 Top 8、按百分比过滤微小项），直接改这个函数即可，provider 不变。
- 饼图触摸交互当前展示分类名 + 金额，未接"跳转到分类流水列表"的导航（目标页尚未实现）。Phase 5 Step 5.4/5.5 落地后可在 `_PieChartViewState._touchedIndex` 变更时添加导航。
- 分类颜色解析 `_parseHexColor` 要求 `#RRGGBB` 格式；如果未来支持其他格式（`#RGB`、`0xRRGGBB`），需增强该函数。
- 本步已完成 Step 5.3；按用户约束：**在用户验证测试前不开始 Step 5.4**。
### ✅ Step 5.4 收支排行榜（2026-04-29）

**改动**
- `lib/features/stats/stats_range_providers.dart`：
  - 新增 `StatsRankItem` 数据类（`categoryId`/`categoryName`/`categoryColor`/`amount`/`percentage`/`isIncome`）。
  - 新增 `_CategoryAgg` 内部聚合辅助类。
  - 新增 `aggregateRankItems(...)` 纯函数：从流水列表中排除 transfer、按时间区间过滤、按 `type|categoryId` 聚合金额，分别计算收入/支出各自的总和，产出按金额降序排列的排行榜列表。百分比按各自类型（收入/支出）的总和计算。
  - 新增 `@Riverpod(keepAlive: true) statsRankItems(...)` FutureProvider：组合 `statsRangeProvider` + `currentLedgerIdProvider` + `transactionRepositoryProvider` + `categoryRepositoryProvider`，产出 `List<StatsRankItem>`。
- `lib/features/stats/stats_page.dart`：
  - `StatsPage` 的 `Column` children 中新增 `SizedBox(height: 360, child: _RankingCard())` 卡片。
  - 新增 `_RankingCard`（ConsumerWidget）：订阅 `statsRankItemsProvider`，loading/error/data 三态渲染；空数据显示 `_RankingEmptyState`。
  - 新增 `_RankingEmptyState`：空状态占位（"暂无排行数据" + "记几笔就能看到排名啦 🐰"）。
  - 新增 `_RankingList`（StatelessWidget）：`ListView.separated` 渲染排行榜。每行含排名序号（前 3 名用分类颜色高亮）、分类颜色圆点、分类名称、占比进度条（`FractionallySizedBox` 按 `amount/maxAmount` 比例填充分类颜色）、金额（收入绿色 `+` 前缀、支出红色 `-` 前缀）。
- `test/features/stats/stats_range_providers_test.dart`：
  - 新增 8 条 `aggregateRankItems` 测试：空数据、排除 transfer、同分类聚合、百分比计算、排除超时、使用分类颜色、回退调色板、混合收支正确分组与百分比。
- `test/widget_test.dart`：
  - `_standardOverrides()` 新增 `statsRankItemsProvider.overrideWith((ref) async => [])`。
  - 第二个测试用例的 override 列表同步追加 `statsRankItemsProvider`。

**验证**
- `dart run build_runner build --delete-conflicting-outputs` → 成功。
- `flutter analyze` → No issues found。
- `flutter test` → 112/112 通过（104 前 + 8 新 rank 测试，全线回归）。
- `dart run custom_lint` → 3 条预存 INFO（`record_new_providers.dart`），与本步无关。

**给后续开发者的备忘**
- `aggregateRankItems` 的百分比按"收入总和"和"支出总和"分别计算——这意味着收入排行榜的百分比之和 = 100%，支出排行榜的百分比之和也 = 100%。两者在同一个列表中按金额降序混排，通过 `isIncome` 字段区分。
- 排行榜颜色回退策略与饼图一致：优先使用分类自身颜色，无颜色时按 `_piePalette` 索引循环取色。
- 排行榜卡片高度设为 360px，与饼图卡片（300px）和折线图卡片（260px）形成差异化布局。若未来分类数量很多导致列表溢出，`ListView` 会自动滚动。
- 本步已完成 Step 5.4；按用户约束：**在用户验证测试前不开始 Step 5.5**。

### ✅ Step 5.5 日历热力图（2026-04-29）

**改动**
- `lib/features/stats/stats_range_providers.dart`：
  - 新增 `StatsHeatmapCell` 数据类（`day` / `amount` / `intensity` / `isInRange`）。
  - 新增 `quantileNormalize(...)` 与 `_quantileValue(...)`：对每日支出强度做分位数归一化，默认采用 90 分位作为上限基准，避免“某天极端高支出导致其它日期几乎全白”。
  - 新增 `aggregateHeatmapCells(...)` 纯函数：仅统计 `expense`，按天聚合当前区间内支出金额，并补齐区间内缺失日期为 0 金额 cell。
  - 新增 `statsHeatmapCells(...)` FutureProvider：组合 `statsRangeProvider` + `currentLedgerIdProvider` + `transactionRepositoryProvider`，产出热力图 cells。
- `lib/features/stats/stats_page.dart`：
  - `StatsPage` 卡片区新增 `SizedBox(height: 320, child: _HeatmapCard())`。
  - 新增 `_HeatmapCard`（ConsumerWidget）：订阅 `statsHeatmapCellsProvider`，处理 loading/error/data 三态；空数据显示 `_HeatmapEmptyState`。
  - 新增 `_HeatmapView`：把区间日期排成“按周分列、按星期分行”的横向滚动热力图网格。
  - 新增 `_WeekdayHeader`：显示 `一/二/三/四/五/六/日` 星期标题。
  - 新增 `_HeatmapCellTile`：单日方块采用 `surfaceContainerHighest → danger` 插值着色，并通过 `Tooltip` 展示 `M月d日 + 支出金额`。
  - 新增 `_HeatmapEmptyState`：空状态占位（"暂无支出热力数据"）。
- `test/features/stats/stats_range_providers_test.dart`：
  - 新增 6 条热力图相关测试：`quantileNormalize` 的空输入/非正数、分位数归一化抑制极端值、按区间补齐每日 cell、排除 income/transfer、排除超时数据、极端值场景下普通日期仍保有可见强度。
- `test/widget_test.dart`：
  - `_standardOverrides()` 与第二个测试用例的 override 列表均新增 `statsHeatmapCellsProvider.overrideWith((ref) async => [])`，避免统计页引入新 provider 后 widget 测试超时。
- `lib/features/stats/stats_range_providers.g.dart`：
  - build_runner 重生成，新增 `statsHeatmapCellsProvider` 对应产物。

**验证**
- `dart run build_runner build --delete-conflicting-outputs` → 成功（新增 `statsHeatmapCellsProvider` 生成代码）。
- `flutter test test/features/stats/stats_range_providers_test.dart test/widget_test.dart` → 28/28 通过（统计聚合 + 首页/widget 回归全部通过）。
- 命令输出含 1 条 `analyzer` 语言版本提示（3.11.0 vs 3.9.0），不影响本步通过。

**给后续开发者的备忘**
- `quantileNormalize(...)` 当前默认 quantile = `0.9`，这是为了满足“极端值不会把其他天压成全白”的验收；若未来想让热力图更敏感/更保守，可把该值上调或下调，但要同步调整对应单测阈值。
- 当前热力图只展示当前区间内的日期，不补前后整月；在 UI 上通过 `_buildWeeks(...)` 扩展到完整周列，因此会出现前后若干个空白占位 cell，这些空白不是数据缺失 bug，而是为了保持“星期对齐”。
- `StatsHeatmapCell.isInRange` 目前恒为 `true`（因为 provider 只产出区间内 cell）；字段仍被保留，是为了将来若要渲染“完整月份 + 区间外置灰”时无需再改模型。
- 本步已完成 Step 5.5；按用户约束：**在用户验证测试前不开始 Step 5.6**。

### ✅ Step 5.6 导出视图（2026-04-29）

**改动**
- `pubspec.yaml`：新增依赖 `share_plus: ^10.1.4`（实际解析到 10.1.4），用于通过系统 Share Sheet 分享导出文件。10.x 而非最新 13.x 是为了与当前 Flutter SDK 约束保持稳妥兼容。
- `lib/features/stats/stats_export_service.dart`（新建）：
  - `encodeStatsCsv({entries, categoryMap, accountMap, range})` 顶层 `@visibleForTesting` 纯函数：UTF-8 BOM `\uFEFF` 前缀 + 中文列头 `日期/类型/金额/币种/分类/账户/转入账户/备注`，按 RFC 4180 规则转义（值含 `,` / `"` / `\n` / `\r` 时整体加引号、内部 `"` 转义为 `""`），按 `occurredAt` 升序排列，区间外/categoryId 缺失/accountId 缺失等都已处理。
  - `buildExportFileName({prefix, extension, now, range})` 顶层 `@visibleForTesting` 纯函数：产出 `bianbian_stats_<startDate>_<endDate>_<timestamp>.<ext>`，全部使用本地时间 + 8 位日期格式，便于排序与 Windows 文件系统兼容。
  - `StatsExportService` 类：注入 `documentsDirProvider` / `shareXFiles` / `now` 三个测试钩子；`exportCsv(...)` / `exportPng({boundary, range, pixelRatio = 3.0})` / `shareFile(file, {subject, text})` 三个公开 API；`writeExportFile(filename, bytes)` 负责 `<documents>/exports/` 目录创建 + 写盘；`capturePng(boundary, pixelRatio)` 走 `RenderRepaintBoundary.toImage(pixelRatio: 3.0)` 默认值满足验收"PNG 分辨率 ≥ 2x"。
- `lib/features/stats/stats_page.dart`：
  - `StatsPage` 从 `ConsumerWidget` 重构为 `ConsumerStatefulWidget`，持有 `_chartsBoundaryKey`（`GlobalKey`）+ `_exportService`（`StatsExportService` 实例）+ `_exporting`（bool）。
  - 标题行从 `Text('统计分析')` 改为 `Row` 三段式：左占位 40px / 居中标题 / 右侧 40px 区域承载 `IconButton(Icons.ios_share)`；导出中显示 `CircularProgressIndicator(strokeWidth: 2)`。
  - 点击导出按钮 → `showModalBottomSheet` 选择 PNG / CSV → 走 `_exportPng()` 或 `_exportCsv()`；失败时通过 `ScaffoldMessenger` 提示「导出失败：$e」。
  - PNG 路径：`_chartsBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?` → `_exportService.exportPng(boundary: ..., range: ...)` → `shareFile`。
  - CSV 路径：`ref.read` 拉 `currentLedgerIdProvider.future` / `transactionRepositoryProvider.future` / `categoryRepositoryProvider.future` / `accountRepositoryProvider.future` → 取活跃流水/分类/账户 → `_exportService.exportCsv(...)` → `shareFile`。
  - 图表区被 `RepaintBoundary(key: _chartsBoundaryKey, child: Container(color: surface, ...))` 包裹（`Container` 给截图填充背景，避免透明区域看起来像截图失败）。
  - 顺手清理 Step 5.5 留下的预存 warning：`_HeatmapCard` 删除未消费的 `super.key` 形参（之前 `flutter analyze` 在 stats 子目录报 1 条 unused_element_parameter）。
- `test/features/stats/stats_export_service_test.dart`（新建）：8 条用例覆盖 CSV 编码与文件名规则——
  - `encodeStatsCsv` × 6：① UTF-8 BOM + 中文列头；② income/expense 行按 `occurredAt` 升序、字段顺序与格式（`yyyy-MM-dd HH:mm` / `0.00` / 类型中文）；③ transfer 行的 `转入账户` 解析；④ RFC 4180 转义（含 `,` / `"` / `\n` 三种边缘情形）；⑤ 区间外行被丢弃；⑥ category/account 缺失时空字段。
  - `buildExportFileName` × 2：① 含起止区间日期 + 时间戳；② 扩展名参数生效。
  - 文件内嵌一个迷你 `LineSplitter` 类（仅识别 `\n` / `\r\n`，简化外部依赖），不污染顶层 import。

**验证**
- `flutter pub get` → 成功解析 share_plus 10.1.4 + share_plus_platform_interface 5.0.2。
- `flutter analyze` → No issues found（含顺手清理的 _HeatmapCard 未消费 key warning）。
- `flutter test` → 126/126 通过（118 前 + 8 新 CSV / 文件名用例，全线回归）。
- `dart run custom_lint` → 3 条预存 INFO（`record_new_providers.dart` 的 `avoid_public_notifier_properties`），与本步无关，与 Step 5.5 状态一致。
- 用户本机 `flutter run` 待手工验证：
  1. 统计 Tab 右上角出现导出图标（`ios_share`）；
  2. 点击 → 弹出底部菜单"导出 PNG（当前视图截图）" / "导出 CSV（当前区间明细）"；
  3. 选 PNG → 系统 Share Sheet 弹出携带 PNG 文件 + 文案"统计区间：2026-04-01 ~ 2026-04-30"；分享到本地图库后 PNG 分辨率应为 device DPR × 3（验证 ≥ 2x）；
  4. 选 CSV → 系统 Share Sheet 弹出携带 CSV 文件；分享到电脑后用 Excel 打开应正确显示中文列头与 UTF-8 中文内容（依赖 BOM）；
  5. 文件应保存在 `<applicationDocumentsDirectory>/exports/` 内，文件名格式 `bianbian_stats_<起>_<止>_<时间戳>.{png|csv}`。

**给后续开发者的备忘**
- **CSV 列头是中文 + UTF-8 BOM**：BOM 是为了让 Excel（特别是 Windows 中文版 Excel）默认以 UTF-8 解读 CSV，否则中文会乱码。代价是 Linux/Mac 上某些纯文本工具会把 `\uFEFF` 当成可见字符；当前 V1 阶段验收"Excel 能打开"优先级更高。若 Phase 13 做"导入 CSV"时遇到第三方导出，需要注意可能不带 BOM——自家解析器要兼容两种。
- **PNG 截当前视图而非整个滚动内容**：`RepaintBoundary` 包在 `SingleChildScrollView` 的 child 内，理论上 `toImage` 会渲染整个 Column 高度——但 `_HeatmapView` / `_RankingList` 内部还有自己的 `SingleChildScrollView`（横向）/ `ListView`（垂直），它们的非可视区域是惰性渲染的，PNG 上**只能拿到当前 layout pass 已 paint 的部分**。这是 Flutter `RepaintBoundary` 的固有约束，非本步引入。如果未来要"截全部图表"，需要把 boundary 移到一个非滚动容器内，或先程序化滚动到底再截图（成本高，本期不做）。
- **导出按钮不阻断双击/重入**：用 `_exporting` 状态守护，按钮在导出中变为 `CircularProgressIndicator`，按钮 onPressed 入口先 `if (_exporting) return;`。错误（含 `RepaintBoundary` 未挂载、share 取消等）通过 `try/finally` 还原 `_exporting`。
- **分享路径用 `XFile`（来自 `share_plus`），不直接传 `File`**：share_plus 10.x 的 API 是 `Share.shareXFiles(List<XFile>, ...)`；`XFile` 在 `cross_file` 包里，已被 share_plus 间接引入。`XFile(file.path)` 即可。
- **`Share.shareXFiles` 在 widget test 下会失败**：测试环境没有 platform channel mock，因此本步**没有写 widget 级别的"点击导出 → 分享"测试**——只测了纯逻辑（CSV 编码 / 文件名）。如果 Phase 12 / 14 真的需要端到端 widget 测试导出流程，`StatsExportService` 已经接受 `shareXFiles` 注入，写 fake 实现即可绕过 channel。
- **`writeExportFile` 用 `flush: true`**：保证写盘完成后再返回 `File`。否则 share sheet 可能在文件还没真正落盘时就尝试读取，特别是 Android 上若分享给的是另一个进程，会因为竞态读到空文件。
- **目录策略：`<documents>/exports/` 子目录**：与 `attachments/` 平级，分别承担"用户主动导出"与"流水附件"。两者在卸载时同时清空（属于 application sandbox），不需要额外 GC。Phase 12 垃圾桶若需要"导出文件保留 N 天"策略，再加一个 sweep 任务即可。
- **不导出哪些字段**：当前不导出 `id` / `ledgerId` / `deviceId` / `noteEncrypted`（base64）等"系统字段"——CSV 是给人看的，不是为了 round-trip 导入。Phase 13 Step 13.3 做"本 App 格式导入/导出"时，应该用单独的 JSON 格式（直接 `entry.toJson()` 列表），而不是基于这里的 CSV 反向解析。
- **本步已完成 Step 5.6；按用户约束：在用户验证测试前不开始 Step 6.1。**

---

## Phase 6 · 预算

### ✅ Step 6.1 预算设置页（2026-05-01）

**改动**
- `lib/data/repository/budget_repository.dart`：
  - 新增 `BudgetConflictException`（`Exception` 而非 `Error`，业务可恢复）：表示同账本 + 同周期 + 同分类（含 `categoryId == null` 总预算）下重复创建的冲突。
  - `LocalBudgetRepository.save()` 在事务内 `dao.upsert` 之前调 `_findActiveDuplicate(ledgerId, period, categoryId, excludeId)`：按三键查询未软删行，命中即抛 `BudgetConflictException`。`_findActiveDuplicate` 用 `t.id.isNotIn([excludeId])` 排除自身（同 id 二次保存视为更新而非冲突）；`categoryId == null` 走 `t.categoryId.isNull()`、否则 `t.categoryId.equals(...)`，覆盖"总预算"特殊路径。
  - 新增静态 `_periodLabel(period)`，把 `'monthly'` / `'yearly'` 映射为中文"月" / "年"，仅服务于异常 message 拼接。
- `lib/features/budget/budget_providers.dart`（新建）：
  - 常量 `kParentKeyLabels`：一级分类 key → 中文标签（与 `seeder.dart::categoriesByParent.keys` 同集合，仅展示翻译）。
  - `activeBudgets(Ref)`（`@riverpod FutureProvider`）：当前账本未软删预算列表，客户端排序"先 monthly 后 yearly、再 categoryId=null 优先"。依赖 `currentLedgerIdProvider` + `budgetRepositoryProvider`。
  - `budgetableCategories(Ref)`（`@riverpod FutureProvider`）：从 `categoryRepositoryProvider.listActiveAll()` 过滤 `parentKey == 'income'`——预算只对支出。
- `lib/features/budget/budget_list_page.dart`（新建）：
  - `BudgetListPage`（ConsumerWidget）：`Scaffold` + `FloatingActionButton.extended('新建预算')` → `context.push('/budget/edit')`，返回 `true` 时 `invalidate(activeBudgetsProvider)`。
  - `_BudgetCard`：左 emoji（来自分类 icon，总预算用 💰 兜底）+ 标题（分类名 / "总预算"）+ 副标题（"月预算 · 结转"）+ 金额（`NumberFormat('#,##0.00')`）+ 删除 `IconButton`。点击卡片进入编辑；删除走 `showDialog<bool>` 二次确认 + `repo.softDeleteById` + Snackbar。
  - `_EmptyState`：💰 图标 + "还没有预算" + "点右下角加一个吧 🐰"。
- `lib/features/budget/budget_edit_page.dart`（新建）：
  - `BudgetEditPage`（ConsumerStatefulWidget，`budgetId` 可选 → 新建 / 编辑双模式）。
  - `_loadBudget()` + `FutureBuilder`：编辑模式异步从 `repo.listActiveByLedger` 提取（不存在抛 `StateError`）。`_hydrate(...)` 守 `_initialized` flag 仅首次写入字段，避免重渲染覆盖用户编辑。
  - 字段：周期 `SegmentedButton<String>('monthly'/'yearly')`、分类 `DropdownButtonFormField<String?>`（首项 null = "总预算（不限分类）"，其余按"中文 parentKey + sortOrder"排序，每项展示"中文 · 二级名"）、金额 `TextFormField`（`numberWithOptions(decimal: true)` + 正则 `^\d*\.?\d{0,2}` 限制最多两位小数）、结转 `SwitchListTile`（subtitle 提示"Step 6.4 实装"）。
  - 保存：编辑模式**直接构造 `Budget(...)`**（不走 copyWith——领域实体的 `copyWith` 不能把 `categoryId` 清回 null，会让用户"分类预算 → 总预算"失败）；新建走 `const Uuid().v4()` + `startDate` 取本月（monthly）或本年（yearly）的第一天。捕获 `BudgetConflictException` → SnackBar 友好提示；其他异常 → "保存失败：$e"。`_saving` 守按钮防双击。
- `lib/app/app_router.dart`：新增两条路由 `/budget` → `BudgetListPage`、`/budget/edit?id=...` → `BudgetEditPage`。
- `lib/app/home_shell.dart`：
  - 移除占位 `_PlaceholderTab`；`_pages[3]` 改为 `const _MeTab()`。
  - 新增 `_MeTab` 文件内私有 StatelessWidget：`Scaffold` + `AppBar('我的')` + `ListView`，目前唯一项 `ListTile('预算')` → `context.push('/budget')`。Phase 17 扩展为完整设置/同步/锁等入口。
  - 新增 import `package:go_router/go_router.dart`（`_MeTab` 内 `context.push` 用）。
- `test/data/repository/budget_repository_test.dart`（新建）：8 用例覆盖唯一性约束的所有边界——
  1. 同账本同周期同分类（categoryId 非空）二次保存抛 `BudgetConflictException`。
  2. 同账本同周期 `categoryId == null` 总预算二次保存抛冲突（覆盖 `isNull` 路径）。
  3. 同账本同周期不同分类可共存。
  4. 总预算与同账本同周期分类预算可共存。
  5. 同分类不同周期（月 / 年）可共存。
  6. 不同账本同周期同分类可共存。
  7. 同 id 二次保存视为更新（金额 1000 → 2000）。
  8. 软删除已存在预算后允许重建（验证 `_findActiveDuplicate` 走 `deletedAt.isNull()` 过滤）。
- `test/widget_test.dart`（修复时间敏感失败）：
  - 新增 `_FixedRecordMonth extends RecordMonth`（覆盖 `build()` 返回固定 `DateTime(2026, 4)`），并在 `_standardOverrides()` + 测试用例 5 的 inline overrides 中各加一行 `recordMonthProvider.overrideWith(() => _FixedRecordMonth(DateTime(2026, 4)))`。
  - 此前用例 4 / 5 硬编码 "2026年4月" / "4月25日" / "4月24日"，但 `RecordMonth.build()` 调 `DateTime.now()`——跨月（如 2026-05-01）跑会因 month 漂移到 5 月而 flaky；固定后测试与真实日期解耦。

**验证**
- `dart run build_runner build --delete-conflicting-outputs` → 成功（`budget_providers.g.dart` 新生成）。
- `flutter analyze` → No issues found（一次清理：`not()` 不存在于 drift Expression 改为 `isNotIn([excludeId])`；`Ref` 未导入 → 加 `flutter_riverpod` import；`(_, __)` 改为 `(_, _)` 通配；移除占位 `_PlaceholderTab`）。
- `flutter test` → 134/134 通过（126 前 + 8 新 budget repo 用例 + widget_test 时间敏感修复后仍 5/5）。
- 用户本机 `flutter run` 待手工验证：
  1. "我的"Tab 出现"预算"入口，点击进入预算列表（空态显示空状态引导）。
  2. 点击"新建预算" FAB → 选周期/分类（含"总预算"）/ 金额 / 结转 → 保存返回列表。
  3. 同账本同周期同分类二次新建 → SnackBar 提示"该分类的月预算已存在"。
  4. 编辑预算可改周期/分类/金额/结转，金额变化在卡片立即体现。
  5. 删除预算二次确认后从列表消失；同账本同周期同分类可重新新建。

**给后续开发者的备忘**
- **唯一性放在仓库层而非数据库 UNIQUE 约束**：`budget` 表无 `UNIQUE(ledger_id, period, category_id)` 约束。原因：① `category_id` 可空，SQLite UNIQUE 对 NULL 不去重（按 spec NULL 视为不同），所以"总预算"无法靠数据库强约束；② 软删后唯一性需要释放（重建合法），数据库层 UNIQUE 不区分软删，必须 partial index——但 drift 注解不支持 partial index，得手写 SQL 迁移。综合权衡，仓库层一次 SELECT + 业务异常足够清晰，且测试可直接覆盖。**若 Phase 10 引入云端镜像后需要服务端约束**，再在 Supabase 加 partial UNIQUE 即可；本地仓库层判断仍保留作前哨。
- **`copyWith` 不能把 `categoryId` 清回 null**——Step 2.1 的实体约定。`BudgetEditPage` 编辑分支因此走"裸构造 `Budget(...)`"路径（保留 id / startDate / deletedAt / deviceId 等不变字段，重写其它）。如果未来 `Budget` 加新字段，记得在这个裸构造点也补上。
- **`BudgetConflictException` 是 `Exception` 不是 `Error`**：业务可恢复，UI 必须 catch 并友好提示。Step 1.6 `DecryptionFailure` 同选择，理由相同。
- **`budgetableCategories` 排除 `parentKey == 'income'`**：预算覆盖支出。如果未来产品要加"收入达标预算"（"本月需赚至少 X"），新建一个 provider `incomeBudgetableCategories` 而不是放宽这个，避免 UI 误把"工资"当作支出预算分类。
- **路由 `/budget` 与 `/budget/edit` 是顶层独立页面**——不在 HomeShell 的 IndexedStack 里。返回值约定 `Pop(true)` 表示已保存，触发 `invalidate(activeBudgetsProvider)`。如果未来想做"预算 Tab"（不是子页），需要把列表页改成 `ConsumerWidget` 在 `_pages` 里渲染（不再 push 路由），但 `BudgetEditPage` 仍可保持独立路由。
- **widget_test 的"当前月"必须 override**——以后 `RecordHomePage` 系测试如果要断言月份相关 UI（"2026年4月"标签、按月过滤的列表），必须同步 override `recordMonthProvider`。`_FixedRecordMonth` 是简单注入点，后续测试照搬即可。
- **空状态 emoji 用 💰**：与设计文档"温馨可爱风"基调一致；分类预算的卡片左侧 emoji 走分类自身 `icon`，总预算回退 💰——这两处保持视觉差异。
- **本步完成了 Step 6.1；按用户约束：在用户验证测试前不开始 Step 6.2。**

### ✅ Step 6.2 预算进度计算（2026-05-01）

**改动**
- `lib/features/budget/budget_progress.dart`（新建）：纯 Dart 工具集（不依赖 Flutter / Riverpod / drift）。
  - `BudgetProgressLevel { green, orange, red }` + `BudgetProgress(spent, limit, ratio, level)` 数据类。
  - `computeBudgetProgress({spent, limit})`：色档纯函数，严格按 implementation-plan Step 6.2 边界——`<70%` 绿、`70%` / `100%` 归橙、`>100%` 红。`limit <= 0` 视为"未设置上限"返回 ratio=0 / level=green，避免误震动。
  - `budgetPeriodRange(period, now)`：返回半开区间 `[start, end)`。`monthly` = now 所在自然月、`yearly` = now 所在自然年。Step 6.4 接入结转后会改造为以 `Budget.startDate` 起算。
  - `computePeriodSpent({budget, transactions, now})`：仅累加 `type == 'expense'` + `occurredAt ∈ [start, end)` + 未软删 + `categoryId` 与预算匹配（总预算不限）的流水。
  - `shouldTriggerBudgetVibration({level, alreadyVibrated})`：把"是否触发震动"的决策抽出为纯函数，UI 调用方负责 `HapticFeedback.heavyImpact()` 实际执行——便于单元测试覆盖"仅首次"语义。
- `lib/features/budget/budget_providers.dart`：
  - 新增 `BudgetClock` typedef + `budgetClock(Ref)` provider（`keepAlive`，默认 `DateTime.now`）。生产路径不动，测试可 override 锁定参考时间避免 flaky。
  - 新增 `budgetProgressFor(Ref, Budget)`（`@riverpod` family FutureProvider）：`watch(transactionRepositoryProvider.future)` + `watch(budgetClockProvider)` → `listActiveByLedger(budget.ledgerId)` → `computePeriodSpent` → `computeBudgetProgress`。Family key = Budget 实体，预算金额变化时旧 cache entry 由 autoDispose 回收。
  - 新增 `BudgetVibrationSession`（`@Riverpod(keepAlive: true) class`）：状态 `Set<String>`，提供 `hasVibrated(id)` / `markVibrated(id)`（幂等：重复 mark 不重建 state）/ `clear(id)`。冷启动自然清空，符合"session 标记"语义。
- `lib/features/budget/budget_providers.g.dart`：build_runner 重生成（含 `BudgetProgressForFamily` / `BudgetProgressForProvider` / `BudgetProgressForRef` / `BudgetVibrationSessionProvider` 全套产物）。
- `lib/features/budget/budget_list_page.dart`：
  - `_BudgetCard` 从 `StatelessWidget` 升级为 `ConsumerWidget`。卡片 body 从单 `Row` 改为 `Column`，下方追加 `_ProgressSection`。
  - 新增 `_ProgressSection`（ConsumerWidget）：`progressAsync.when` 三态——loading 显示 `_ProgressPlaceholder`（占位进度条 + "进度计算中…"），error 显示红色错误文本，data 渲染：
    - 彩色 `LinearProgressIndicator`：value = `ratio.clamp(0, 1)`（避免 >100% 撑爆动画），`backgroundColor` = `color.withValues(alpha: 0.18)`，`valueColor` 跟档位变化。颜色取自 `BianBianSemanticColors`（success=抹茶绿 / warning=蜜橘 / danger=苹果红）。
    - 一行 "已花 ¥X / ¥Y · N%"——金额用 `NumberFormat('#,##0.00')`，百分比 ≥100% 时取整、否则保留 1 位小数。
    - 震动决策：`shouldTriggerBudgetVibration(level, session.hasVibrated(id))` 为真时，**整段** `markVibrated + HapticFeedback.heavyImpact()` 都放进 `WidgetsBinding.addPostFrameCallback`。回调内再做一次 `hasVibrated` 检查防重，确保同帧多次 build 只震一次。**初版只把 HapticFeedback 推迟、把 markVibrated 留在 build 里同步调用**——结果首次进入预算页就抛 `Tried to modify a provider while the widget tree was building`（state= 在 build pass 中被禁用）。修复后两步都放进 postFrame，state 变更也搬到下一帧。
  - 新增 `_ProgressPlaceholder`：进度条 + "进度计算中…" 文案，加载态一致体验。
  - import 新增 `package:flutter/services.dart`（`HapticFeedback`）、`../../app/app_theme.dart`（`BianBianSemanticColors`）、`budget_progress.dart`。
- `test/features/budget/budget_progress_test.dart`（新建，16 用例）：
  1. `computeBudgetProgress`：< 70%（=0.69）、= 70%（→橙）、85%（→橙）、= 100%（→橙）、100.01%（→红）、limit ≤ 0（→绿、ratio=0）、spent = 0（→绿） 共 7 条。
  2. `budgetPeriodRange`：monthly 当月 / monthly 12 月跨年 / yearly 当年 共 3 条。
  3. `computePeriodSpent`：总预算累加全分类、分类预算只计自身、yearly 累加全年 共 3 条。
  4. `shouldTriggerBudgetVibration`：green / orange 不触发、red 首次触发、red 已触发不再触发 共 3 条。
- `test/features/budget/budget_vibration_session_test.dart`（新建，5 用例）：① 初始空；② markVibrated 后 hasVibrated true；③ 重复 mark 同 id `identical(stateA, stateB)` 验证幂等不重建；④ 多 id 独立标记；⑤ clear(id) 移除单项。

**验证**
- `dart run build_runner build --delete-conflicting-outputs` → 64 outputs，0 error（新增 `budgetClockProvider` / `budgetProgressForProvider` family / `budgetVibrationSessionProvider` 等产物）。
- `flutter analyze` → No issues found。
- `flutter test` → 155/155 通过（134 前 + 16 budget_progress + 5 vibration_session）。
- `dart run custom_lint` → 仍是 3 条预存 INFO（`record_new_providers.dart`），与本步无关。
- 用户本机 `flutter run` 待手工验证：
  1. 进入"我的 → 预算"，每张预算卡片下方显示彩色进度条 + "已花 / 上限 · 百分比"文案。
  2. 已花 < 70% 上限 → 进度条抹茶绿。
  3. 已花介于 70%~100% → 进度条蜜橘。
  4. 已花 > 100% → 进度条苹果红，**第一次进入卡片时**触发一次重震动；离开页面再回来或刷新仍不再震动；冷启动重开 App 后该预算仍超额时再震动一次。
  5. 编辑预算金额（比如把 1000 改 100）后，已超额的预算变红——若该 id 是首次进入红档，触发一次震动；若之前就已超额（已 mark），不重复震动。

**给后续开发者的备忘**
- **震动决策与执行分离**：`shouldTriggerBudgetVibration` 只决策，UI 负责 `HapticFeedback.heavyImpact()` 真调用。这种拆分让单元测试可纯逻辑验证"仅首次"语义，不需要触碰 platform channel 或 widget tester。Step 6.4 接入结转后若加新震动场景（比如"当月可用为负"），应继续遵循同一模式：判定函数纯化、副作用归 UI。
- **`postFrameCallback` 不能省，且必须把 provider 写操作一起推迟**：Riverpod 在 build pass 内禁止 `state=`（`NotifierBase.state= → ProviderElement.setState → _debugCanModifyProviders` 抛断言）。所以 `markVibrated` **不能**在 build 同步调用——必须放进 `addPostFrameCallback` 一起推迟。`HapticFeedback.heavyImpact()` 同理推迟（platform channel 副作用别在 build 期间发出）。回调内做 `if (session.hasVibrated(id)) return;` 守护，避免 build 多次注册多个 postFrame 时重复震动。
- **`BudgetVibrationSession` 是 `keepAlive`**：与 `currentLedgerIdProvider` 同模式。`autoDispose` 会在没有 watcher 时清空 state，那样从预算页返回主页再回来 set 就空了，导致每次进入预算页都重震一次——这违反"仅首次"语义。`keepAlive` 让 set 跟随整个应用生命周期，冷启动时由 Notifier 的 `build()` 重新初始化为空。
- **family 的 cache key 是 Budget 实体的 ==/hashCode**：Budget 包含 `updatedAt`，编辑后是新对象、新 hashCode，会创建新 cache entry——这是想要的（金额改了进度要重算）。但请勿在 list rebuild 时构造"内容相同但实例不同"的 Budget（例如随手 `copyWith()`），那样会生成无谓的 cache entry。当前 `budgetListPage` 直接 forward `activeBudgetsProvider` 列表里的实体，没有这个问题。
- **`ratio.clamp(0, 1)` 仅给进度条**——文案百分比仍显示真实 ratio（"125.5%"）。如果未来产品想让进度条在 >100% 时"红色填满 + 第二条溢出层"，应在 `_ProgressSection` 加第二个进度指示器，不要修改 clamp 语义。
- **本步完成了 Step 6.2；按用户约束：在用户验证测试前不开始 Step 6.3。**

### ✅ Step 6.3 统计页联动（2026-05-01）

**改动**
- `lib/features/budget/budget_providers.dart`：新增 `totalBudget(Ref)` FutureProvider——`watch(activeBudgetsProvider)` 后过滤 `categoryId == null` 的总预算，月度优先于年度，无则返回 `null`。复用 `activeBudgetsProvider` 与 `budgetProgressForProvider`，保证与"我的 → 预算"页"已花/上限"完全同源。
- `lib/features/budget/budget_providers.g.dart`：build_runner 重生成（`totalBudgetProvider` 等产物）。
- `lib/features/stats/stats_page.dart`：
  - 新增 `_TotalBudgetRing`（ConsumerWidget，44×44）：`Tooltip('查看预算')` + `InkWell(onTap: context.push('/budget'))` + `Stack` 套 `CircularProgressIndicator`（值取 `progress.ratio.clamp(0,1)`、color 跟随档位）+ 中心整数百分比文字。loading 时显示小转圈，error 时显示 `error_outline`。
  - `_CategoryPieCard` 头部从单 `Text('支出分类占比')` 升级为 `Row(Expanded(title), totalBudgetAsync.maybeWhen(data: ring, orElse: SizedBox.shrink))`：`totalBudget == null` 或 loading/error 时区域留空（验收要求"无预算时进度环隐藏"）。
  - import 新增 `package:go_router/go_router.dart`、`domain/entity/budget.dart`、`features/budget/budget_progress.dart`、`features/budget/budget_providers.dart`。
- `test/features/budget/total_budget_provider_test.dart`（新建）：5 用例覆盖优先级与过滤——
  1. 仅有分类预算 → null；
  2. 月度+年度同存 → 月度优先（且不被列表顺序左右）；
  3. 仅年度总预算 → 回退到年度；
  4. 仅有分类预算（含分类年度）→ null；
  5. 混合分类预算与总预算 → 只挑总预算。
- `test/widget_test.dart`：`_standardOverrides()` 与"统计 Tab 切换"用例 5 inline overrides 中各加 `activeBudgetsProvider.overrideWith((ref) async => [])`——`_CategoryPieCard` 引入 `totalBudgetProvider` 后，没有这个 override 会让 `activeBudgets` 链路尝试触达真实 DB 导致 widget 测试 flaky。新增 import `features/budget/budget_providers.dart`。

**验证**
- `dart run build_runner build --delete-conflicting-outputs` → 22 outputs，0 error。
- `flutter analyze` → No issues found。
- `flutter test` → 160/160 通过（155 前 + 5 新 totalBudget 用例）。
- 用户本机 `flutter run` 待手工验证：
  1. 在"我的 → 预算"创建一个总预算（不选分类）→ 进入统计 Tab，饼图卡顶部右侧出现进度环，百分比与预算页一致；
  2. 删除该总预算 → 进度环立刻消失；
  3. 同时存在月度+年度总预算时，进度环显示月度数据；
  4. 仅有年度总预算时，进度环显示年度数据；
  5. 仅有分类预算（无总预算）时，进度环不显示；
  6. 点击进度环跳转至"我的 → 预算"页面。

**给后续开发者的备忘**
- **进度环只取总预算（categoryId == null）**：实施计划原文"统计页饼图旁显示预算进度环（总预算）"明确范围，不展示分类预算。如果未来产品需要"按当前饼图选中分类显示其预算环"，应另起一个 family `categoryBudgetForCategoryId(catId)` provider；不要扩展 `totalBudgetProvider` 的语义，否则破坏"无总预算时隐藏"的验收线。
- **月度优先策略**：实施计划没明确说月/年优先，本步选月优先——理由是统计页区间默认"本月"，月度总预算与默认视图天然对齐；用户若同时设置月+年总预算，月更接近"当前在看的图表"。如果以后想跟随统计页区间选择动态切换（区间是本年时显示年度预算），需要把 provider 改为 `family<StatsRangePreset>` 或 watch `statsRangeProvider`；目前不做。
- **`maybeWhen(data: ..., orElse: SizedBox.shrink)`**：刻意把 loading/error 都吞成空白——进度环是辅助信息，不应在网络/DB 慢的瞬间用 spinner 抢饼图标题视觉重心。`_TotalBudgetRing` 内部仍处理 loading/error（一旦真的拿到总预算，再算其进度时短暂 loading 显示小 spinner 是合理的）。
- **进度环复用 `budgetProgressForProvider(budget)` family**：与预算列表页同 cache，`budget.updatedAt` 变就 invalidate 一次。如果以后发现统计页/预算页打开同一预算时双重计算（理论上不会，但 family key 是 `Budget.==`），检查是否两边传的是同一个实体引用——`activeBudgets` 列表是同源的，正常情况只算一次。
- **路由 `/budget` 是 push 而非 go**：保持"返回上一页（统计）"的导航栈语义，与预算编辑页返回列表页同模式。`context.push` 不需要 await 返回值（这里不需要刷新统计页的进度环——它已经在 watch 同源 provider）。
- **本步完成了 Step 6.3；按用户约束：在用户验证测试前不开始 Step 6.4。**

### ✅ Step 6.3 进度刷新补丁（2026-05-01）

**问题**：用户反馈"流水更新后，预算页/统计页的进度条都未刷新，需要切换账本再切回才行"。原因是 `budgetProgressForProvider`（family）依赖 `transactionRepositoryProvider.future`——一次性 future，仓库实例不变，故流水写入不会触发它重建；只有切换账本时 `currentLedgerId → activeBudgets → Budget` 实体引用更替才"碰巧"换 cache key。

**改动（不改语义，仅补 invalidate）**：
- `lib/features/record/record_new_providers.dart::save()` 末尾追加 `ref.invalidate(budgetProgressForProvider)`；新增 import `features/budget/budget_providers.dart`。
- `lib/features/record/record_home_page.dart`：账本切换块、左滑删除、详情页编辑/复制/删除 共 5 处 invalidate 块都补上 `ref.invalidate(budgetProgressForProvider)`；账本切换块还额外加 `ref.invalidate(activeBudgetsProvider)`（不同账本预算不同）。
- `lib/app/home_shell.dart::_onTabTap`：进入统计 Tab（`i == 1`）时 invalidate `budgetProgressForProvider` 作兜底；新增 import。

**验证**：`flutter analyze` 0 issue；`flutter test` 160/160 通过；用户手工验收"记一笔后立即看预算进度条更新"通过。

**给后续开发者的备忘**
- **family 的 invalidate 不传参数**：`ref.invalidate(budgetProgressForProvider)` 失效整族，所有 family entry（不同 Budget 实体作为 key）都被清空。这正是流水变化场景所需——任何预算的"已花"都可能被影响。如果未来该 family 的 entry 数量变得很多（>50），可考虑只 invalidate 与变更流水的 ledgerId / categoryId 相关的 entry，但当前规模不需要。
- **不写在 `transactionRepositoryProvider` 上**：仓库 provider 本身不应感知"哪些上层依赖应该跟着失效"——那会造成强耦合。把 invalidate 放在写入路径（save / softDelete 调用方），是 Riverpod 一贯的"事件源驱动失效"模式，与现有 `recordMonthSummaryProvider` / `statsXxxProvider` 的处理保持一致。

---

### ✅ Step 6.4 预算结转（2026-05-01）

**改动**

数据层 / 实体层：
- `lib/data/local/tables/budget_table.dart`：新增两列——`carry_balance REAL NOT NULL DEFAULT 0`、`last_settled_at INTEGER`（nullable）。前者是已累计结转余额，后者是已结算到的周期 end（epoch ms）。
- `lib/data/local/app_database.dart`：`schemaVersion` 从 v3 升 v4；`onUpgrade` 新增 `if (from < 4)` 分支，调 `m.addColumn(budgetTable, budgetTable.carryBalance)` + `m.addColumn(budgetTable, budgetTable.lastSettledAt)`。schema 版本注释同步更新。
- `lib/domain/entity/budget.dart`：实体加 `double carryBalance = 0` 与 `DateTime? lastSettledAt`；`copyWith` / `toJson` / `fromJson` / `==` / `hashCode` / `toString` 全部同步。`fromJson` 里 `(json['carry_balance'] as num?)?.toDouble() ?? 0`、`json['last_settled_at']` null 兜底——保持向旧 JSON 备份的兼容。
- `lib/data/repository/entity_mappers.dart`：`rowToBudget` / `budgetToCompanion` 两侧都补两个字段映射（`int? epoch ms` ↔ `DateTime?`）。

纯函数层（领域 usecase + features 内部）：
- `lib/domain/usecase/budget_carry_over.dart`（新建）：`applyCarryOverToggle({prev, next, now})` 纯函数。
  - prev=null（新建）：`carryOver=true → lastSettledAt = currentPeriodStart, carryBalance = 0`；`carryOver=false → 全 null/0`。
  - prev != null（编辑）：`prev.carryOver=false && next.carryOver=true` 时 `lastSettledAt` 重置为当前周期 start、`carryBalance` 沿用 prev；其余分支两字段一律继承 prev——这是"重新打开不回溯历史"的关键约束。
  - 自带 `_currentPeriodStart` 私有 helper，**不**依赖 `features/budget/budget_progress.dart::budgetPeriodRange`，保证 `data/` → `domain/` 单向依赖，不让仓库层回头 import features。
- `lib/features/budget/budget_progress.dart`：新增 `settleBudgetIfNeeded({budget, transactions, now})` 懒结算函数；移除原 `budgetPeriodRange` 头注释里"Step 6.4 接入结转后会改造为 startDate 起算"的过渡说明，改写为"已用作 anchor 推进"。新增 `_nextPeriodEnd` / `_spentBetween` 私有 helper。语义：
  - `carryOver=false` 直接 short-circuit 返回原 budget。
  - 否则 anchor = `lastSettledAt ?? currentPeriodStart`；若 anchor >= currentPeriodStart 直接返回（无完整结束周期可结算）。
  - 否则按周期推进，每个完整结束周期累加 `max(0, amount - spentInThatPeriod)`；最后把 `lastSettledAt` 推到当前周期 start。
  - 不改 `updatedAt`：结算只是派生数据维护，不应让同步层把它当业务变更。

仓库 / Provider / UI：
- `lib/data/repository/budget_repository.dart`：
  - `BudgetRepository` 接口新增 `getById(id)` 与 `updateCarrySettlement({id, carryBalance, lastSettledAt})` 两个方法；后者**仅**写两列，**不**入队 `sync_op`、**不**改 `updated_at`。
  - `LocalBudgetRepository.save()` 在写库前先调 `getById(entity.id)` 取 prev，然后 `applyCarryOverToggle(prev, next: entity, now)` 决定最终的 `carryBalance` / `lastSettledAt`，再走原有的唯一性检查 + upsert + sync_op enqueue。
  - import 调整：新增 `domain/usecase/budget_carry_over.dart`。
- `lib/features/budget/budget_providers.dart::budgetProgressFor`：
  - 计算前先 `settleBudgetIfNeeded(budget, txs, now)`；若结果与原 budget 在 `carryBalance` / `lastSettledAt` 任一字段不同，就调 `repo.updateCarrySettlement(...)` 持久化（注意：**没有** `ref.invalidate(activeBudgetsProvider)`，避免与 family rebuild 形成循环；底层 `_dao.upsert` 写完后下次 list 会自动取到新值）。
  - `limit = settled.amount + (settled.carryOver ? settled.carryBalance : 0)`，传给 `computeBudgetProgress`——这是"本期可用"。
- `lib/features/budget/budget_list_page.dart::_BudgetCard`：
  - 副标题在 `carryOver=true && carryBalance > 0` 时追加 `· 结转 ¥X.XX`；
  - 右上金额下方追加 `可用 ¥(amount + carryBalance)`（仅在结转有累积时显示，使用 success 绿）；
  - 进度条文案 `已花 ¥X / ¥Y` 中 `Y` 来自 `progress.limit`（已是结转后的可用），无需额外改动。
- `lib/features/budget/budget_edit_page.dart`：`SwitchListTile` 副标题去掉"（Step 6.4 实装）"提示，改为简洁的"未花完金额累加到下个周期"。

测试：
- `test/features/budget/budget_carry_over_test.dart`（新建）：15 用例覆盖
  1. `applyCarryOverToggle` 新建 3 条（true / false / yearly）；
  2. `applyCarryOverToggle` 编辑 3 条（false→true / true→false / true→true）；
  3. `settleBudgetIfNeeded` 不结算 2 条（carryOver=false / anchor 已在当前周期 start）；
  4. `settleBudgetIfNeeded` 周期结算 5 条（基础结算 / 超预算不负转 / 跨两周期 / 累加而非覆盖 / 分类预算只统计自己）；
  5. **Step 6.4 验收场景** 2 条：
     - 上月剩 200 + 本月预算 1000 → 本月可用 1200；
     - 完整时间线模拟"4 月开 → 5 月关 → 6 月再开 → 7 月结算"：4 月剩 200 与 5 月剩 400 都未被回溯；7 月仅累加 6 月剩余 900。

**验证**
- `dart run build_runner build --delete-conflicting-outputs` → 139 outputs，0 error。
- `flutter analyze` → No issues found。
- `flutter test` → 175/175 通过（160 前 + 15 新 carry over 用例）。
- 用户本机 `flutter run` 待手工验证：
  1. 全新装 App → DB 直接走 `onCreate` 建到 v4 schema（含两列）；既装过 v3 旧版的设备 → drift 走 `onUpgrade` v3→v4 路径执行两条 `ALTER TABLE` ADD COLUMN，原有预算的 `carry_balance` 默认 0、`last_settled_at` 为 NULL。
  2. 创建一个开启结转的月度预算 → 4 月花 800 → 5 月初进入预算页 → 卡片副标题出现"结转 ¥200.00"、右上多一行绿色"可用 ¥1,200.00"、进度条文案"已花 ¥0.00 / ¥1,200.00 · 0%"。
  3. 验收第二条：开启结转的预算 → 关闭结转 → 跨月 → 重新开启 → 验证"重新打开后不会把关闭期间未结算的月份补结转"。
  4. 总预算（不限分类）也支持结转——`settleBudgetIfNeeded` 在 `categoryId == null` 时累加全分类支出。

**给后续开发者的备忘**
- **`applyCarryOverToggle` 放在 `domain/usecase/`，`settleBudgetIfNeeded` 放在 `features/budget/`**：前者被 `data/repository/` 调用，按 layered 依赖必须落在 `data/` 不会反向 import 的位置（`domain/`）；后者被 `features/budget/budget_providers` 调用，留在 features 内部即可，且依赖了 `computePeriodSpent` / `_nextPeriodEnd` 等私有 helper。**未来若把更多结转相关纯函数也搬到 domain/usecase/**，两份就可以合并；目前刻意保留分裂以维持依赖单向。
- **结算的"懒触发点"是 `budgetProgressForProvider`**：每次 UI 渲染预算进度都顺手结算一次。这意味着——如果用户从来不打开预算页（即使已开启结转），结转累加永远不会发生。这是有意的：① 我们没有 background worker；② 用户看不到的状态没必要落库；③ 一旦用户打开预算页，所有需要的累加在 0.x 秒内全部补齐。**禁忌**：不要把结算挂到"记账保存路径"——那会让记账热路径承担与当前流水无关的多预算 settle 计算，体验下降。
- **`updateCarrySettlement` 不入队 sync_op、不改 updated_at**：结算产物完全可以从流水重算，对端拿到流水后自然能算出同样的 carryBalance。如果在云端镜像里也存这两列，会出现"两端都算一次结算 + 两端 last_settled_at 时间 race"的复杂性。当前选择是：**云端的 budget 表只承载 amount / carryOver / category / period 等"用户意图"字段**（Phase 10 同步设计时再具体落表），结转产物本地派生。`carryBalance` 与 `last_settled_at` 在 `payload` JSON 里仍会出现（因为 `Budget.toJson` 包含），但 sync engine 在 push 时应在序列化前剪掉这两个字段——届时另写一个 `toSyncPayload` 接口而非污染 `toJson`。
- **AppDatabase v3→v4 用 `addColumn`**：drift 帮我们把 SQLite 的 `ALTER TABLE … ADD COLUMN` 自动生成。`carry_balance` 有 `withDefault(const Constant(0))`，drift 会把默认值放进 ADD COLUMN 语句，**已有行**也立即拿到 0；`last_settled_at` 是 nullable 不带默认，旧行直接为 NULL。
- **测试场景"4 月开 → 5 月关 → 6 月再开 → 7 月结算"**是 implementation-plan 验收的核心。任何后续重构若改动了 anchor 或 toggle 路径，**必须**保持这条用例为绿——它单独覆盖了"重新打开不回溯历史"的行为契约。
- **进度条 `LinearProgressIndicator.value = ratio.clamp(0, 1)`**已经在 Step 6.2 写过，不需要本步动；但要注意 `ratio` 现在的分母是"本期可用"而非"原始 amount"——即结转 200 + amount 1000 = limit 1200，spent 600 → ratio=0.5 而非 0.6。这是**正确**的语义：用户期望进度条反映"还有多少可花"，而非"原始预算花了几成"。
- **本步完成了 Step 6.4；按用户约束：在用户验证测试前不开始 Step 7.1。**

---

## Phase 7 · 资产账户

### ✅ Step 7.1 账户列表（2026-05-01）

**改动**

纯函数层（features 内部）：
- `lib/features/account/account_balance.dart`（新建）：纯 Dart 工具集（不依赖 Flutter / Riverpod / drift）。
  - `AccountBalance` 数据类（`accountId` / `initialBalance` / `netAmount` + 派生 `currentBalance`）。
  - `aggregateNetAmountsByAccount(transactions)` → `Map<String, double>`：按账户聚合流水净额。规则：`expense` 从 `accountId` 减，`income` 向 `accountId` 加，`transfer` 从 `accountId` 减、向 `toAccountId` 加；`deletedAt != null` 流水跳过；`accountId` 为 null 的非 transfer 流水忽略。
  - `computeAccountBalances({accounts, transactions})` → `List<AccountBalance>`：保持 accounts 入参顺序，未发生流水的账户 `netAmount = 0`，UI 不会"消失"。
  - `computeTotalAssets({accounts, transactions})` → `double`：仅累加 `Account.includeInTotal == true` 的账户 `currentBalance`。

Provider 层：
- `lib/features/account/account_providers.dart`（新建）：3 个 `@riverpod` FutureProvider，自动 dispose（无 keepAlive，跟随路由生命周期）：
  - `accountsList` → `Future<List<Account>>`：`accountRepositoryProvider.future` → `repo.listActive()`。
  - `accountBalances` → `Future<List<AccountBalance>>`：组合 `accountsListProvider` + `currentLedgerIdProvider` + `transactionRepositoryProvider`，对当前账本流水计算余额。
  - `totalAssets` → `Future<double>`：同源依赖，输出 design-document §5.1.4 要求的"当前账本维度"总资产。
- 三个 provider 都按 design-document §5.1.4「统计页、预算、资产均在'当前账本'维度内聚合」的约束消费 `listActiveByLedger(currentLedgerId)`——不跨账本求和。

UI 层：
- `lib/features/account/account_list_page.dart`（新建）：
  - `AccountListPage`（ConsumerWidget）：`Scaffold('资产')` + `ListView`，三态守护（`accountsList` / `accountBalances` 各自 loading/error/data）。
  - `_TotalAssetsCard`：奶油黄底（`primaryContainer`）大卡片，标题"总资产（当前账本）"+ `¥{NumberFormat('#,##0.00')}`，挂 `Key('total_assets_amount')` 便于测试。
  - `_AccountCard`：左 emoji（账户 icon，缺省 💳）+ 名称 + 类型副标（cash/debit/credit/third_party/other → 中文）+ 当前余额；负值改用 `BianBianSemanticColors.danger` + 加 `-` 前缀（信用卡欠款视觉区分）。`includeInTotal == false` 在副标后追加"· 不计入总资产"提示，与"为何不影响总数"形成自解释。每张卡片金额挂 `Key('account_balance_<accountId>')`。
  - `_EmptyState`：兜底（理论上 seeder 已注入 5 个默认账户，几乎不会触发）。
- `lib/features/account/.gitkeep`：删除（目录已有真实文件）。
- `lib/app/app_router.dart`：新增 `GoRoute('/accounts')` → `const AccountListPage()`；新增 import `features/account/account_list_page.dart`。
- `lib/app/home_shell.dart`：`_MeTab` 在"预算"项之后追加"资产"项（`Icons.account_balance_wallet_outlined` → `context.push('/accounts')`）。
- `lib/features/account/account_providers.g.dart`：build_runner 产物。

测试：
- `test/features/account/account_balance_test.dart`（新建，16 用例）：
  1. `aggregateNetAmountsByAccount` 8 条：空、单 expense、单 income、transfer 双向、混合、软删过滤、null accountId 忽略、transfer toAccountId 缺失仅扣 from。
  2. `computeAccountBalances` 3 条：未发生流水仍输出（含 currentBalance = initialBalance）、保留入参顺序、流水净额应用到对应账户。
  3. `computeTotalAssets` 5 条：空、`includeInTotal=false` 排除、信用卡负余额计入为减项、叠加流水净额、**Step 7.1 验收**——切换 includeInTotal 后总资产数值跟随变化（同一账户切到 false 后从总资产中扣除）。

**验证**
- `dart run build_runner build --delete-conflicting-outputs` → 82 outputs，0 error（含 `account_providers.g.dart`）。
- `flutter analyze` → No issues found。
- `flutter test` → 192/192 通过（前 175 + 16 account_balance 用例 + 1 widget 测试已在 Step 6.4 时点通过，无需变更）。
- 用户本机 `flutter run` 待手工验证：
  1. "我的"Tab 出现"资产"入口（钱包图标），点击进入 `/accounts`。
  2. 顶部"总资产"卡片展示金额（含千分位 + 两位小数）。
  3. 5 个种子账户卡片渲染：现金 ¥0.00 / 工商银行卡 ¥0.00 / 招商信用卡 ¥0.00 / 支付宝 ¥0.00 / 微信 ¥0.00（实际数额取决于已记流水）。
  4. 信用卡当前余额若为负（如 -300），金额变红并以 "-¥300.00" 显示。
  5. 把某账户编辑为 `include_in_total = false`（Step 7.2 落地）后，总资产对应减少；卡片副标追加"· 不计入总资产"提示。

**给后续开发者的备忘**
- **"当前账本维度"是 design-document §5.1.4 的硬约束**：账户虽然是全局资源（同一张工商卡可在多账本里被引用），但资产页/总资产展示走"当前账本流水净额"路径——切账本时 `accountBalancesProvider` / `totalAssetsProvider` 自动 invalidate（依赖 `currentLedgerIdProvider`）。如果将来产品改口径要求"全局总资产"（跨账本累加），应**新加一个 provider**（如 `globalTotalAssetsProvider`），不要让 `totalAssetsProvider` 跨语义切换——会让所有现有消费者突然口径变化。
- **流水净额公式与账户类型解耦**：信用卡余额为负通过"`initialBalance` 用户填负值"驱动，而不是 `aggregateNetAmountsByAccount` 对 type=credit 做特殊处理。原因：① 信用卡用户填的是"当前已欠多少"，那就是负的初始余额；② 后续的 expense（消费）继续 -amount、income（还款）+amount，行为完全统一；③ 一旦把"信用卡 expense 不减反加（视为加大欠款）"这种语义塞进聚合函数，会让测试矩阵爆炸。当前实现的好处是 `expense -amount / income +amount / transfer -from +to` 三条规则在所有账户类型下都自洽。
- **transfer 流水统计语义**：在统计页的折线图/饼图/排行/热力图里 transfer 都被排除（"非真实收支"），但**资产页要计入**——因为转账是"钱从口袋 A 到口袋 B"，影响每个口袋的余额。两套口径不冲突：聚合纯函数各自实现，不要共用。
- **未发生流水的账户也输出 `AccountBalance(netAmount: 0)`**：`computeAccountBalances` 保证返回列表与入参 `accounts` 等长且同序，UI 拿 Map 索引就能得到 0 而不是 null。如果将来 UI 要"过滤掉零余额且无流水的账户"，应在**消费方**做过滤，不要在聚合层提前丢——否则会让 `_AccountCard` 拿不到对应行。
- **Step 7.2 即将引入的"删除账户 → 占位"**：Step 7.1 的 `_AccountCard` 还没有"删除"操作；Step 7.2 落地软删后，挂在该账户下的未删流水仍有 `accountId` 指向已软删的账户，资产页这里 `byId[acc.id]` 自然就拿不到余额——但这种情况不应出现，因为 `accountsListProvider` 走 `listActive()` 已过滤掉软删账户。Step 7.2 还需要补"流水详情显示'（已删账户）'"的兜底（不是本步范围）。
- **Provider 不带 `keepAlive: true`**：与 `activeBudgetsProvider` 同模式——离开资产页时 dispose；下次进入时重新计算。资产页通常仅作为"我的→资产"独立路由进入，频次不高，不需要持久缓存。如果未来发现切回首页/记账后再切回资产页"加载闪烁"明显，可改为 `keepAlive: true`，但要注意搭配显式 `invalidate`（在记一笔 / 切账本 / 编辑账户的路径上）。
- **本步完成了 Step 7.1；按用户约束：在用户验证测试前不开始 Step 7.2。**


### ✅ Step 7.2 账户 CRUD（2026-05-01）

**改动**

仓库层：
- `lib/data/repository/account_repository.dart`：
  - `AccountRepository` 接口新增 `Future<Account?> getById(String id)` 方法——**不**过滤 `deleted_at`，软删账户也能查到。
  - `LocalAccountRepository.getById` 实现：`select(accountTable)..where(id == id)..getSingleOrNull()` → `rowToAccount`。语义上"找到（含软删）"与"未找到"分别返回非空 / null。
  - 注释明确 Step 7.2 用途：流水详情兜底显示"（已删账户）"占位标签。

UI 层：
- `lib/features/account/account_edit_page.dart`（新建）：`AccountEditPage`（`ConsumerStatefulWidget`），支持新建/编辑双模式（`accountId` 可选）。字段集合按 design-document §5.6：
  - **名称**（`TextFormField`，`validator` 必填空校验）。
  - **类型**（`DropdownButtonFormField<String>`，5 项 `(cash, '现金') / (debit, '储蓄卡') / (credit, '信用卡') / (third_party, '第三方支付') / (other, '其他')`）。
  - **图标 emoji**（`TextFormField`，可空）。
  - **初始余额**（`TextFormField` + `numberWithOptions(decimal: true, signed: true)` + `FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d{0,2}'))` 限两位小数 + 可负号）。信用卡欠款填负值。
  - **默认币种**（下拉同账本编辑页 7 种）。
  - **计入总资产**（`SwitchListTile`）。
  - 编辑模式 `_loadFuture` 在 `initState` 启动；`_hydrate(acc)` 守 `_initialized` flag 仅首次写入字段，避免 setState 后覆盖用户编辑。
  - `_save()` 编辑模式走 `existing.copyWith(...)` 路径（避免裸构造遗漏字段）；新建模式 `Account(id: const Uuid().v4(), ..., deviceId: '')` 让 repo 覆写 `deviceId`/`updatedAt`。保存成功后 `ref.invalidate(accountsListProvider)` / `accountBalancesProvider` / `totalAssetsProvider` 三连击，再 `Navigator.pop(true)`。`_saving` 守按钮防双击。
- `lib/features/account/account_list_page.dart`（重写）：
  - 新增 `FloatingActionButton.extended('新建账户', heroTag: 'account_list_fab')` → `context.push<bool>('/accounts/edit')`，返回 `true` 触发 3 个 provider invalidate。
  - `_AccountCard` 接收 `onTap` / `onLongPress` 回调；`InkWell` 包裹卡片内容，点击直接进入 `/accounts/edit?id=<acc.id>`。
  - 长按弹出 `showModalBottomSheet`：编辑（同 onTap）+ 删除（红色 ListTile，触发 `_confirmDelete`）。
  - `_confirmDelete(...)`：`AlertDialog` 二次确认 → `repo.softDeleteById(account.id)` → 3 个 provider invalidate + Snackbar `「{name}」已删除`。catch 异常显示 `删除失败：$e` Snackbar。
  - 列表底部 padding 88px（与账本列表对称）为 FAB 留出空间。
- `lib/app/app_router.dart`：新增 `GoRoute('/accounts/edit')`，可选 query `id` 进入编辑模式；与 `/accounts` 路由列表平行。

流水详情兜底：
- `lib/features/record/record_home_page.dart::_TxTile` 的 `accountName(id)` 回退逻辑修订：
  - id == null / 空字符串 → `'账户'`（保持旧版"未填写账户"语义）。
  - id != null 且不在 `accountRepo?.listActive()` 结果中 → `'（已删账户）'`（**Step 7.2 验收关键**）。
  - 同时影响 3 处 UI：① 转账流水副标题 `A → B`；② 详情底部页 `_RecordDetailSheet` 的"钱包" / "转出" KV 行；③ "转入" KV 行（通过父 widget 传 `toAccountName` 注入）。

测试：
- `test/data/repository/account_repository_test.dart`（新建，7 用例）：
  1. `save → 写入并入队 sync_op upsert`（覆写 device_id/updated_at + payload 断言）。
  2. `getById 命中活跃账户`（基础正向）。
  3. `getById 不存在的 id 返回 null`。
  4. `softDeleteById → listActive 不可见，但 getById 仍能查到（含 deletedAt）`——Step 7.2 兜底实现的关键契约：流水详情兜底**不**走 `getById`（性能考量），但单元测试需要保证 `getById` 可以拿到软删账户，未来若 UI 改实现时不会破坏契约。
  5. `softDeleteById 不存在的 id 静默跳过（不入队）`。
  6. `save (update) 同 id 二次保存视为更新`（步进 clock + 单行 + 2 条 upsert）。
  7. `返回实体是纯 Dart 类型（不含 drift 专属类型）`。
- `test/widget_test.dart`：
  - 新增 `_FakeAccountRepository`（实现 `AccountRepository`：`listActive` / `getById` 内存匹配 / `save` `softDeleteById` 走 `fail()`）。
  - 新增第 6 条用例 `删除账户后转账流水显示"（已删账户）"占位`：注入 1 条 transfer 流水（`accountId='deleted-account-out'` / `toAccountId='deleted-account-in'`）+ 空账户列表 → 验证副标题 `（已删账户） → （已删账户）` 渲染 + 金额 `¥200.00` 渲染（不崩溃）。
- `test/features/record/record_new_page_test.dart`：`_FakeAccountRepository` 补 `getById`（按 id 内存匹配）以保持 implements 接口完整。

**验证**
- `flutter analyze` → No issues found。
- `flutter test` → 200/200 通过（前 192 + 7 account_repository_test + 1 widget_test 已删账户兜底）。
- 用户本机 `flutter run` 待手工验证：
  1. "我的 → 资产"右下角出现"新建账户" FAB，点击进入 `/accounts/edit`。
  2. 新建页填写名称/类型/图标/初始余额/币种/计入总资产 → 保存返回资产列表，新卡片可见，总资产数值跟随刷新。
  3. 长按账户卡片 → 弹出菜单（编辑/删除）；点击卡片直接进入编辑。
  4. 编辑模式预填字段；修改后保存返回，列表卡片立即体现。
  5. 删除账户：二次确认 → 软删除 → 卡片从资产页消失，总资产对应减去（若 includeInTotal=true）。
  6. **关键验收**：删除账户后，回到记账首页，原本挂在该账户下的流水：
     - 普通流水（expense/income）：副标题不变（不展示账户名）→ 不崩溃。
     - 转账流水：副标题从 `工商卡 → 招商卡` 变为 `（已删账户） → （已删账户）`（或单边删除时一侧仍显示原名）→ 不崩溃。
     - 点击进入流水详情底部页：钱包/转出/转入字段显示"（已删账户）"→ 不崩溃。

**给后续开发者的备忘**
- **`AccountRepository.getById` 不过滤 `deleted_at` 是 Step 7.2 设计要点**：`listActive` 与 `getById` 形成"软删账户的两套视图"——前者在资产 Tab 透明剔除（用户看不到），后者保留在数据层（流水可追溯）。如果未来引入"垃圾桶 → 恢复账户"功能（Phase 12），`getById` 仍是核心查询入口；UI 层在垃圾桶页拿到 `Account` 后调 `Account.copyWith(deletedAt: null)` 重写——但 `copyWith` 不能把 `deletedAt` 清回 null（Step 2.1 约定），届时**要么**裸构造 `Account(...)`（保留所有其它字段），**要么**给实体加专门的 `restored()` 方法。Phase 12 落地时再决定，本步不预判。
- **`_TxTile.accountName` 走 `listActive` 内存查找而非 `getById` 异步查询**：每条流水若都 await `getById`，即使一个账本几百条流水也会在 UI 渲染层堆积大量 Future，引起首屏卡顿。`listActive()` 一次查全部活跃账户（通常 <10 个）后做 `id == acc.id` 内存查找——这是渲染热路径的合理选择。代价是软删账户的"原账户名"丢失（统一显示"（已删账户）"），但符合实施计划"挂到'（已删账户）'占位标签上"的简洁约束。如果产品后续要"`原账户名（已删）`"格式，可改为 `accountRepo?.listAll()` 或 `getById` 异步查询，并加个 `Account` 缓存。
- **`AccountEditPage` 用 `existing.copyWith(...)` 而非裸构造**：与 `LedgerEditPage` 同模式。`Account.copyWith` 对所有字段都接受 `T?` 参数，不能把已有字段清回 null——Account 的字段中只有 `icon` / `color` / `deletedAt` 是 nullable，新建时直接传 null 即可，编辑时 `copyWith` 路径下 icon 通过 `_iconController.text.trim()` 后 `iconText.isEmpty ? null : iconText`，所以**清空 icon 输入框** = 让 `iconValue` 为 null，但 `copyWith(icon: null)` 在我们的实体约定里 = "保持旧值"。这意味着**用户清空 icon 后保存，icon 不会变成 null，仍保留原值**——这是当前已知的小限制；若 Phase 后续要支持"清空 icon"，需要给 `Account.copyWith` 加 `bool clearIcon` 标志位或用 `Optional<String>` 包装；本步不处理。
- **`/accounts/edit` 路由的 `id` 用 query 参数**：与 `/ledger/edit?id=...` / `/budget/edit?id=...` 同模式。这样新建模式 = `/accounts/edit`（无 query）、编辑模式 = `/accounts/edit?id=xxx`，同一 builder 通过 `state.uri.queryParameters['id']` 区分。
- **删除账户**不**级联软删流水**：与账本（Step 4.2 级联软删流水/预算）不同，账户的软删保留对应流水。原因：① 流水的"账户"只是分类标签（design-document §5.6 "账户是'标签'不是'账本'"），删账户不应吞掉历史流水；② 用户可能只是想"清理不再使用的账户"，但仍要看历史；③ 流水继续显示"（已删账户）"标签提示用户当前账户身份。这与账本（账本承载该账本所有流水的归属）的"删账本=失去整段历史"语义不同。
- **本步完成了 Step 7.2；按用户约束：在用户验证测试前不开始 Step 7.3。**


### ✅ Step 7.2 刷新补丁（2026-05-01）

**问题**：用户反馈"删除账户后，流水详情未及时更新为'（已删账户）'，需要切换账本再切回才显示"。

**根因**：`_TxTile.build()` 走 `ref.watch(accountRepositoryProvider).valueOrNull` + 内层 `FutureBuilder<List<Account>>(future: accountRepo?.listActive(), ...)` 模式获取账户列表。`accountRepositoryProvider` 是仓库实例 provider，**实例本身从不变化**——`accountsListProvider` 被 invalidate 不会触发 `accountRepositoryProvider` watcher 重建，于是 `_TxTile` 不重建、FutureBuilder 不重发查询、缓存的账户名维持陈旧。切换账本之所以"撞对"，是因为它会经 `currentLedgerIdProvider → recordMonthSummaryProvider` 链路触发首页整体重建，顺带让所有 `_TxTile` 重建。

**修复（不改语义，仅切换响应式数据源）**：
- `lib/features/record/record_home_page.dart`：
  - 移除 `final accountRepo = ref.watch(accountRepositoryProvider).valueOrNull;` 与内层 `FutureBuilder<List<Account>>` 包裹层。
  - 改为 `final accounts = ref.watch(accountsListProvider).valueOrNull ?? const <Account>[];`——该 provider 在账户 save / softDeleteById 后已被 `account_list_page.dart` / `account_edit_page.dart` invalidate，watch 它即可让 tile 在 invalidate 当帧自动 rebuild。
  - 与之配套：import 由 `data/repository/providers.dart` 的 `accountRepositoryProvider` 切换为 `features/account/account_providers.dart` 的 `accountsListProvider`。
  - `accountName(id)` / 转账副标题 / `_RecordDetailSheet` 的 KV 文案逻辑均不变——只是数据源变了。
- `test/widget_test.dart`：
  - `_FakeAccountRepository.accounts` 由 `final` 改为可变（`List<Account> accounts`）以支撑下一条用例。
  - 新增第 7 条用例 `删除账户后流水副标题立即刷新（无需切换账本）`：用 `ProviderContainer` + 可变 fake，先 pump 验证显示真实账户名 → 改 `fakeAccount.accounts = []` + `container.invalidate(accountsListProvider)` → pumpAndSettle → 验证副标题立即变为 `（已删账户） → （已删账户）`、原账户名（`工商卡 → 招商卡`）从 widget 树消失。这是修复路径的回归保护。

**验证**：`flutter analyze` → No issues found；`flutter test` → 201/201 通过（200 前 + 1 新刷新回归用例）。

**给后续开发者的备忘**
- **同款风险存在于 `categoryRepositoryProvider`** 的 `_TxTile` 用法（line 543 / 546）——目前还是 `ref.watch(categoryRepositoryProvider).valueOrNull` + `FutureBuilder<List<Category>>`。若未来分类 CRUD 落地后用户报"删/改分类后流水图标/名未刷新"，按相同思路把它替换成 `categoriesListProvider`（届时 `features/record/category_manage_page.dart` 一带应该已经创建过类似 provider）。本次刻意不顺手改——保持本次补丁聚焦"用户报告的账户问题"。
- **修复模式可复用**：任何"在 `_TxTile` / 流水列表 tile 内 watch 仓库 provider + FutureBuilder 拉清单"的代码都有同款 bug 风险。**正确模式**：watch 上层"清单 provider"（`accountsListProvider` / `activeBudgetsProvider` / `ledgerGroupsProvider` 等），让 invalidate 自然驱动 tile 重建；**反模式**：watch 仓库实例 provider + 在 builder 里手动调 `repo.listXxx()`，因为仓库实例不变 → tile 不重建 → 查询不重发。
- **`AsyncValue.valueOrNull` 在 invalidate 期间的语义**：Riverpod 2.x 当 `ref.invalidate(p)` 被调用时，`p` 进入 `AsyncLoading` 状态但**保留前值**——`valueOrNull` 仍返回旧 list；下个 microtask `p.build()` 跑完后状态变 `AsyncData(newList)` → tile 再 rebuild 一次拿到新 list。所以理论上修复后会有 1 帧"还显示旧账户名"的中间态——但毫无视觉感知，因为 invalidate + rebuild + future 完成都在同一个 vsync 区间内。


### ✅ Step 7.3 信用卡字段（2026-05-02）

**改动**

数据层 / 实体层：
- `lib/data/local/tables/account_table.dart`：`AccountTable` 新增两列——`billing_day INTEGER`（nullable）、`repayment_day INTEGER`（nullable）。两列对所有账户都允许 null；非信用卡保持 null，信用卡也允许暂时不填。文件头注释补充 Step 7.3 用途说明。
- `lib/data/local/app_database.dart`：`schemaVersion` 从 v4 升 v5；`onUpgrade` 新增 `if (from < 5)` 分支，调 `m.addColumn(accountTable, accountTable.billingDay)` + `m.addColumn(accountTable, accountTable.repaymentDay)`。schema 版本注释同步更新。
- `lib/domain/entity/account.dart`：实体加 `int? billingDay` 与 `int? repaymentDay`；`copyWith` / `toJson` / `fromJson` / `==` / `hashCode` / `toString` 全部同步。`fromJson` 用 `(json['billing_day'] as num?)?.toInt()` 兜底——保持向旧 JSON 备份的兼容。文件头 dartdoc 补充 Step 7.3 用途说明。
- `lib/data/repository/entity_mappers.dart`：`rowToAccount` / `accountToCompanion` 两侧都补两个字段映射。

UI 层：
- `lib/features/account/account_edit_page.dart`：
  - 类内新增 `_billingDayController` / `_repaymentDayController` 两个 `TextEditingController`，对应 dispose。
  - `_hydrate(acc)` 编辑模式回填两字段（null → 空字符串、非空 → `toString()`）。
  - 当 `_type == 'credit'` 时条件渲染一行双 `TextFormField`：账单日 / 还款日，`keyboardType: TextInputType.number` + `FilteringTextInputFormatter.digitsOnly` + `LengthLimitingTextInputFormatter(2)`；`validator` 走 `_validateDay` 共用方法（空字符串放行、非空时校验 `1 ≤ n ≤ 28`）。两个字段挂 `Key('billing_day_field')` / `Key('repayment_day_field')` 便于测试。
  - 类型切换为非 credit 时，`onChanged` 内 `setState` 同时清空两个 controller，避免"再切回 credit 又出现旧值"的视觉残留。
  - `_save()` 编辑分支改为**裸构造 `Account(...)`**（不走 copyWith）——`copyWith` 不能把 `T?` 清回 null，否则用户从信用卡切换到 cash / debit / 其它类型时，`billingDay` / `repaymentDay` 仍保留旧值。新建分支沿用裸构造（本来就是）。`billingDay` / `repaymentDay` 只在 `_type == 'credit'` 时取 controller 值，其它类型一律落 null。
- `lib/features/account/account_list_page.dart`：
  - `_AccountCard` 新增 `_creditDayLine(billingDay, repaymentDay)` 静态辅助方法：根据填写情况组合 `'账单日 X 号 · 还款日 Y 号'`；任一字段缺失时仅显示已填字段；两者都缺失返回 null。
  - `build()` 内仅当 `account.type == 'credit' && creditInfo != null` 时在副标行下方渲染第三行 `Text(creditInfo)`，挂 `Key('credit_info_<accountId>')`。

测试：
- `test/domain/entity/entities_test.dart::Account` 组：
  - `full` 实体加两个字段（`billingDay: 5` / `repaymentDay: 22`），原"全字段 roundtrip"用例自然覆盖含信用卡日的序列化。
  - `minimal`（cash 账户）的预期断言新增"`billingDay` / `repaymentDay` 均为 null"。
  - `copyWith` 用例 reason 改为"改 initialBalance 不动 includeInTotal / 信用卡日"，并断言两字段不被改动。
  - 新增第 4 条 `信用卡日仅存其一也能 roundtrip`：仅填 `billingDay = 10`、不填 `repaymentDay`，roundtrip 后两字段值均维持。
- `test/data/repository/account_repository_test.dart`：
  - `makeAccount` 工厂新增 `billingDay` / `repaymentDay` 两个可选参数。
  - 新增 2 条测试：① `Step 7.3：信用卡 billingDay/repaymentDay 持久化并可读回`——构造 `type='credit'` + `billingDay: 5` + `repaymentDay: 22` 的卡，save → getById 后断言两字段 + sync_op payload 含 `billing_day` / `repayment_day` 数值；② `Step 7.3：非信用卡保存时 billingDay/repaymentDay 为 null（即使被传入）`——cash 账户保存后两字段为 null。

**验证**
- `dart run build_runner build --delete-conflicting-outputs` → 成功，147 outputs，0 error。
- `flutter analyze` → No issues found。
- `flutter test` → 204/204 通过（前 201 + 1 entities + 2 account repo = 204）。
- `dart run custom_lint` → 仍是 3 条预存 INFO（`record_new_providers.dart`），与本步无关。
- 用户本机 `flutter run` 待手工验证：
  1. 全新装 App → DB 直接走 `onCreate` 建到 v5 schema（含两列）；既装过 v4 旧版的设备 → drift 走 `onUpgrade` v4→v5 路径执行两条 `ALTER TABLE` ADD COLUMN，原有账户的 `billing_day` / `repayment_day` 默认 NULL。
  2. 资产页"新建账户" → 类型选"信用卡" → 出现"账单日 / 还款日"两字段（label 含"1-28"提示）；填 5 / 22 后保存。
  3. 资产页该信用卡卡片副标显示三行：第二行类型 "信用卡"、第三行 "账单日 5 号 · 还款日 22 号"（挂 Key 便于测试）。
  4. 编辑该信用卡 → 两字段已回填；改成 type='cash' 后两字段消失，保存后再编辑发现两字段为 null（不会"切回信用卡又出现旧值"）。
  5. 边界校验：填 0 / 29 / 30 时 form 校验提示"请输入 1-28 的整数"，不允许保存；空字符串放行（信用卡也允许暂不填）。
  6. 现金、储蓄卡、第三方支付、其他四种类型下，两字段不可见——验证"非信用卡类型字段不可见"。

**给后续开发者的备忘**
- **`Account.copyWith` 不能清 `billingDay` / `repaymentDay`**：与 Step 2.1 所有实体的"`T?` 即不改"约定一致——这是 `_save()` 编辑分支换裸构造的原因。如果未来要给账户实体加新的 nullable 字段（比如最低还款比例、利率、信用额度），同样要在编辑保存路径上**改裸构造**才能正确处理"由非空 → null"的清空场景；千万别只补 copyWith 而漏掉构造路径。
- **1-28 的硬编码上限**：design-document §5.6 与 implementation-plan Step 7.3 都明确"仅数值 1-28"——这是因为 30 / 31 在 2 月就不存在；选 28 让任何月份都能命中。如果未来产品想升级为"账单日 1-31，缺失的月份顺延到月末"，需要在仓库 / UI 层都做月长判断，复杂度上一个台阶；当前 V1 不需要。
- **不生成提醒 / 通知**：implementation-plan 明确"仅展示，不生成提醒"。Phase 16 Step 16.1 / 16.2 引入提醒系统时，可以**单独**给信用卡用 cron-style 触发器（比如"每月还款日前 N 天 push 通知"），但这是新功能、不是回填本字段语义。**不要**在 Step 7.3 的字段语义里偷塞"通知开关"——保持单一职责。
- **同步语义**：`billing_day` / `repayment_day` 已进入 `Account.toJson()`，因此 sync_op payload 自动包含；Phase 10 Supabase 表也需要这两列（或忽略多余字段，看 schema 配置）。account_repository_test 的"信用卡持久化"用例同时验证 payload 含这两个 key，作为 Phase 10 schema 设计的契约提示。
- **本步完成了 Step 7.3；按用户约束：在用户验证测试前不开始 Step 8.1。**



---

## Phase 8 · 多币种

### ✅ Step 8.1 币种开关与数据表（2026-05-02）

**改动**

数据层 / Schema：
- `lib/data/local/tables/user_pref_table.dart`：`UserPrefTable` 追加一列 `multi_currency_enabled INTEGER NULLABLE DEFAULT 0`——`0` / `null` 视为关闭、`1` 视为开启，与生产默认一致。
- `lib/data/local/tables/fx_rate_table.dart`（新建）：`FxRateTable` + `@DataClassName('FxRateEntry')`。**工具表**——`code` (TEXT PK) / `rate_to_cny` (REAL NOT NULL) / `updated_at` (INTEGER NOT NULL) 三列，无 `deleted_at` / `device_id` / sync_op 入队。设计文档 §5.7 的"汇率快照"职责。
- `lib/data/local/dao/fx_rate_dao.dart`（新建）：`FxRateDao` 暴露 3 个方法——`listAll()`（按 code 升序）/ `getByCode(code)` / `upsert(companion)`。不走 Step 1.4 的"业务表 4 方法"模式；不需要 softDelete / hardDelete。
- `lib/data/local/app_database.dart`：`schemaVersion` 从 v5 升 v6；`@DriftDatabase` 注册 `FxRateTable` + `FxRateDao`；schema 注释加 v6 行；`onUpgrade` 新增 `if (from < 6)` 分支：`m.addColumn(userPrefTable, userPrefTable.multiCurrencyEnabled)` + `m.createTable(fxRateTable)`。**onUpgrade 不写入 fx_rate 快照**——把"种子化"职责留给 `seeder.dart` 的独立判空，与 ledger 路径解耦。

常量层：
- `lib/core/util/currencies.dart`（新建，原目录 `[空]` 退役）：
  - `Currency` 数据类（`code` / `symbol` / `name`）。
  - 顶层 `kBuiltInCurrencies` (11 种：CNY / USD / EUR / JPY / KRW / HKD / TWD / GBP / SGD / CAD / AUD)，按 design-document §5.7 顺序固定。
  - 顶层 `kFxRateSnapshot: Map<String, double>`（写死的初始汇率快照，以 CNY 为基准；CNY 自身 = 1.0；2026-05 的"合理参考"值，Step 8.3 联网刷新会覆盖）。

种子化：
- `lib/data/local/seeder.dart`：`seedIfEmpty()` 重构为**两段独立判空**——
  - 第一段（旧）：`ledger` 表为空 → 插入账本 + 分类 + 账户。
  - 第二段（Step 8.1 新增）：`fx_rate` 表为空 → 按 [kFxRateSnapshot] 批量插入 11 行，`updated_at = _clock()` ms。
  - 两段都在同一个 `_db.transaction` 内，任一失败整体回滚。新增 import `../../core/util/currencies.dart`。

UI 层 / 设置入口：
- `lib/features/settings/settings_providers.dart`（新建）：`@Riverpod(keepAlive: true) class MultiCurrencyEnabled extends _$MultiCurrencyEnabled`。`build()` 读 `user_pref.multi_currency_enabled` → bool；`set(bool enabled)` 写 user_pref + `invalidateSelf()`。与 Step 4.1 的 `CurrentLedgerId` AsyncNotifier 同模式，作为后续 settings 模块"单字段开关"的基底。
- `lib/features/settings/multi_currency_page.dart`（新建）：`MultiCurrencyPage` ConsumerWidget。三段：① `SwitchListTile`（挂 `Key('multi_currency_switch')`，subtitle "开启后，记账页可选择币种；统计按账本默认币种换算展示"）；② "内置币种" ListTile 展示 `kBuiltInCurrencies.map(code).join(' · ')`；③ "汇率管理"占位 ListTile（disabled，subtitle "Step 8.3 接入联网刷新与手动覆盖"）。
- `lib/app/app_router.dart`：新增 `GoRoute('/settings/multi-currency')` → `const MultiCurrencyPage()`。
- `lib/app/home_shell.dart`：`_MeTab` 在"资产"项之后追加"多币种"项（`Icons.public` → `context.push('/settings/multi-currency')`）。

记账页接线：
- `lib/features/record/widgets/number_keyboard.dart`：`NumberKeyboard` 加 `bool showCurrencyKey = true` 参数；构建左下角 'CURRENCY' 位时用 `key == 'CURRENCY' && !showCurrencyKey ? const SizedBox(height: 65) : _KeyButton(...)` 决定渲染。**保持 4×4 网格布局**——只是把币种按钮替换成等高空 `SizedBox`，不让其它键变形或换位。点击事件在该位为空时也不响应。
- `lib/features/record/record_new_page.dart`：`_RecordNewPageState.build` 内 `final showCurrencyKey = ref.watch(multiCurrencyEnabledProvider).valueOrNull ?? false;`，把结果作为 `NumberKeyboard.showCurrencyKey` 透传。loading/error 期间默认按"关闭"显示——避免短暂闪现币种键的不一致体验。新增 import `../settings/settings_providers.dart`。

测试：
- `test/data/local/fx_rate_test.dart`（新建，11 用例）：
  1. `FxRateDao` × 3：`upsert + listAll` 升序 / `upsert` 同 code 二次更新 / `getByCode` 命中与未命中。
  2. `DefaultSeeder` fx_rate 路径 × 4：空库 → 写入 [kFxRateSnapshot] 全集 / CNY = 1.0 且 11 种内置币种全覆盖 / 已有 fx_rate 不被覆盖（独立判空）/ ledger 已存在但 fx_rate 为空 → 仅种子化 fx_rate（验证 v5→v6 升级路径）。
  3. 内置币种常量 × 4：codes 顺序锁定 / [kFxRateSnapshot].keys 与 [kBuiltInCurrencies] 同集 / CNY 自身 = 1.0 / 每种币种有非空 symbol+中文 name。
- `test/features/settings/multi_currency_page_test.dart`（新建，5 用例）：覆盖 SwitchListTile 在 initial=false / 切换后 true / initial=true 三种状态；内置币种行展示三个 code 抽样；汇率管理行 disabled。`_TestMultiCurrencyEnabled` fake notifier 走"override `build` + override `set` 直接 `state = AsyncValue.data(...)`"模式，避免依赖真 DB。
- `test/features/record/record_new_page_test.dart`：
  - `_baseOverrides` 加 `bool multiCurrencyEnabled = false` 参数 + `_TestMultiCurrencyEnabled` 类（与生产默认一致）。
  - 原"数字键盘完整渲染"用例改为传 `multiCurrencyEnabled: true`（含 'CNY' 键断言）。
  - 新增 2 条 Step 8.1 验收用例：① 开关关闭时 'CNY' 不可见、其它键仍渲染保持布局；② 开关开启时 'CNY' 可见。

**验证**
- `dart run build_runner build --delete-conflicting-outputs` → 155 outputs，0 error。
- `flutter analyze` → No issues found。
- `flutter test` → 222/222 通过（204 前 + 11 fx_rate + 5 multi_currency_page + 2 record_new_page Step 8.1 = 222）。
- `dart run custom_lint` → 仍是 3 条预存 INFO（`record_new_providers.dart`），与本步无关。
- 用户本机 `flutter run` 待手工验证：
  1. 全新装 App → DB 直接走 `onCreate` 建到 v6 schema（含 multi_currency_enabled + fx_rate 表）；既装过 v5 旧版的设备 → drift 走 `onUpgrade` v5→v6 路径执行 1 条 ADD COLUMN + 1 条 CREATE TABLE，下次冷启动 seeder 把 fx_rate 11 行写入。
  2. "我的"Tab 出现"多币种"入口（`Icons.public`），点击进入 `/settings/multi-currency`。
  3. 开关默认关闭 → 记一笔 → 数字键盘左下角是空白占位，**不显示 CNY 键**。
  4. 打开开关后回到记一笔 → 左下角立即显示 'CNY' 键，点击可在 CNY/USD 间切换（Step 8.1 暂保留 Step 3.2 的简易切换；Step 8.2 才接入完整下拉）。
  5. 关闭开关 → 再回记一笔 → CNY 键又消失。
  6. "内置币种"行展示 `CNY · USD · EUR · JPY · KRW · HKD · TWD · GBP · SGD · CAD · AUD`，"汇率管理"行 disabled 显示 Step 8.3 提示。

**给后续开发者的备忘**
- **fx_rate 是工具表，不是同步实体**：故意没有 `deleted_at` / `device_id`；写入路径不进 sync_op。Step 8.3 联网刷新与用户手动覆盖都直接 `dao.upsert`。Phase 10 Supabase 不需要为 fx_rate 建对应表——汇率属于"机器观察值"，每端独立维护即可；如果两端都接同一个汇率 API，它们各自的 fx_rate 内容会自动一致。
- **fx_rate 的"独立判空"语义**：`seedIfEmpty` 中 fx_rate 与 ledger 完全解耦，是为支持两个升级路径——
  - 路径 A（既有 v5 用户首次冷启 v6）：ledger 已非空但 fx_rate 是新表为空 → seeder 仅补齐 fx_rate；
  - 路径 B（用户清空 ledger 自建账本，但保留了手动覆盖的 USD 汇率）：ledger 重新空了，fx_rate 已有用户值 → seeder 重新种子化 ledger，但**不**碰 fx_rate（fx_rate 整体非空 → 整段跳过）。
  这意味着 fx_rate 的种子化是"全有或全无"——不做"逐 code 增量补齐"。如果未来要支持"添加新币种"（比如 Step 8.3 后增加 INR），逐 code 补齐应在该步骤的迁移代码里手动处理，**不**改这里的判空粒度。
- **`multi_currency_enabled` 走 sync 还是不走 sync？**：当前没在 sync_op 里入队（user_pref 整张表都不走 sync_op，与 design-document §7.1 设计一致——它是"单设备偏好"）。Phase 10 同步引擎只 push transaction/category/ledger/account/budget 五张实体表；user_pref 维持本地。这意味着开关在新设备上重装后**会回退到默认（关闭）**，这是产品决策——用户在新设备上重新选择即可。如果将来要做"跨设备同步设置"，需要单独设计 settings 同步路径，不要混进现有 sync_op。
- **`MultiCurrencyEnabled.set` 与 `CurrentLedgerId.switchTo` 同模式**：写入 user_pref 后 `invalidateSelf()`。如果 settings 模块未来扩展更多字段（主题、字号、AI endpoint 等），应该把这种"单字段 AsyncNotifier"再抽象一层（例如 `UserPrefField<T>(column, defaultValue, encode, decode)`）以避免重复样板代码。当前只有 1 个开关 + 1 个 currentLedgerId，没必要提前抽象。
- **`NumberKeyboard.showCurrencyKey=false` 时左下角是 `SizedBox(height: 65)`**：保持等高占位让其它三键（0/./✓） 在视觉中心；如果未来产品想"开关关闭时数字键盘高度变矮一行"或"该位换成另一个键比如『00』"，改这里再一处即可。当前选项最保守。
- **测试中默认 `multiCurrencyEnabled = false`**：`_baseOverrides` 与生产默认一致。任何后续测试要断言"显示 CNY 键"必须显式传 `multiCurrencyEnabled: true`；忘了的话默认行为是"开关关闭、CNY 不显示"，相比"默认开启"更不容易掩盖回归。
- **本步未触动 `record_new_providers.dart` 的 `currency` 字段语义**：保留 Step 3.2 的简易 CNY/USD 切换 + 默认 CNY 行为。Step 8.2 才会做"全球开关开启后金额旁出现币种下拉、保存时把 currency + fx_rate 一起存"——届时 `_amountDisplay` 与 `transactionRepository.save` 路径都要动；本步只控显示。
- **本步完成了 Step 8.1；按用户约束：在用户验证测试前不开始 Step 8.2。**


### ✅ Step 8.2 记账页币种选择（2026-05-02）

**改动**

Provider 与纯函数：
- `lib/features/settings/settings_providers.dart`：补 `package:flutter_riverpod/flutter_riverpod.dart` import（`Ref` 类型需要）；新增 `@Riverpod(keepAlive: true) Future<String> currentLedgerDefaultCurrency(Ref ref)`——依赖 `currentLedgerIdProvider` + `ledgerRepositoryProvider`，账本切换或编辑时（Step 4.x ledger_edit_page 完成后会 invalidate `ledgerRepositoryProvider`）自动重算；读取失败兜底 `'CNY'`，与 design-document §7.1 `ledger.default_currency DEFAULT 'CNY'` 一致。新增 `@Riverpod(keepAlive: true) Future<Map<String, double>> fxRates(Ref ref)`——直接 dump `fx_rate` 表为 `code → rate_to_cny` 的快照（Step 8.1 种子化已保证 11 行）。新增顶层纯函数 `double computeFxRate(String from, String to, Map<String, double> ratesToCny)`：`from == to` → 1.0；任一码缺失或 `toRate == 0` → 兜底 1.0（防御除零）；否则 `fromRate / toRate`（CNY 基准下，`from → to = ratesToCny[from] / ratesToCny[to]`）。

记账表单：
- `lib/features/record/record_new_providers.dart`：保留 `toggleCurrency()`（不再被 UI 调用，移除留给 Step 8.3）；新增 `setCurrency(String code)`（直接写 `state.currency`）；新增 `Future<void> initDefaultCurrency()`——读 `currentLedgerDefaultCurrencyProvider` 后把 form.currency 设为账本默认币种；当 `state.currency != 'CNY'` 时 early return（避免覆盖已选/已 preload 的值）。`save()` 在保存前 `ref.read currentLedgerDefaultCurrencyProvider + fxRatesProvider`，调 `computeFxRate(d.currency, ledgerCurrency, rates)` 算出"原币 → 账本默认币种"换算因子写入 `tx.fxRate`，与 `currency` 一同持久化到 `transaction_entry`。
- `lib/features/record/record_new_page.dart`：新增 import `../../core/util/currencies.dart`。`_RecordNewPageState.initState` 内 `WidgetsBinding.instance.addPostFrameCallback((_) { ref.read(recordFormProvider.notifier).initDefaultCurrency(); })` 触发默认币种填充（fire-and-forget，与 `initDefaultAccount` 同模式）。`_AmountDisplay` 改为按 `kBuiltInCurrencies.firstWhere((c) => c.code == form.currency, orElse: () => kBuiltInCurrencies.first).symbol` 查 symbol（移除硬编码 `¥` / `$`）。`NumberKeyboard.onCurrencyTap` 不再走 `notifier.toggleCurrency`，改为 `await showModalBottomSheet<String>(... _CurrencyPicker(selectedCode: form.currency)) → 若 picked != null && picked != form.currency` 调 `notifier.setCurrency(picked)`。新增 `_CurrencyPicker extends StatelessWidget`：`ListView.builder` 渲染 11 内置币种（`Key('currency_picker_${code}')`），当前选中尾部 `Icons.check`，点击 `Navigator.pop(context, c.code)` 把 ISO 码回传。

记账首页 / 流水：
- `lib/features/record/record_home_page.dart`：新增 import `../../core/util/currencies.dart` + `../settings/settings_providers.dart`。新增顶层 `_symbolFor(String code)` 私有 helper（命中 `kBuiltInCurrencies` → symbol；未命中回退 `¥`）。新增顶层 `@visibleForTesting String formatTxAmountForDetail(TransactionEntry tx, String ledgerCurrency)`：同币种 → `±¥10.00`；跨币种 → `±USD 10.00（≈ ¥72.00）`；转账（type == 'transfer'）无符号；income +、expense -。`_TxTile` 列表金额改用 `_symbolFor(tx.currency)`（保留原币展示，例如 USD 流水显示 `-$10.00`）。`_DataCards` 升级为 `ConsumerWidget`，watch `currentLedgerDefaultCurrencyProvider` 取 symbol 传给 `_CardChip`（卡片显示账本默认币种 symbol；CNY 账本展示 `¥`，USD 账本展示 `$`）。`_CardChip` 新增 `String symbol = '¥'` 参数。`_RecordDetailSheet` 升级为 `ConsumerWidget`，watch 同 provider 后调 `formatTxAmountForDetail(tx, ledgerCurrency)`；金额 Text 挂 `Key('detail_amount')`。

统计聚合（V1 单币种行为零回归——同币种 `fxRate = 1.0` 时 `amount * 1.0 == amount`）：
- `lib/features/record/record_providers.dart`：`recordMonthSummary` 收入/支出累加从 `tx.amount` 改为 `tx.amount * tx.fxRate`。
- `lib/features/stats/stats_range_providers.dart`：`aggregatePieSlices` / `aggregateRankItems` / `aggregateHeatmapCells` / `statsLinePoints` 内累加全部 `tx.amount * tx.fxRate`。
- `lib/features/budget/budget_progress.dart`：`computePeriodSpent` 与 `_spentBetween` 同样改为 `tx.amount * tx.fxRate`——预算金额本身是账本默认币种，两侧单位一致。
- **未触动** `lib/features/account/account_balance.dart`：账户余额按原币累加（每个账户有自己的 `account.currency`）。跨币种"总资产"换算超出 Step 8.2 范围（V1 简化：跨币种转账留空，记账时账户币种应与流水 currency 一致）。

测试（247 用例，222 前 + 25 新）：
- `test/features/settings/fx_rate_compute_test.dart`（新建，8 用例）：`computeFxRate` 同币种 → 1.0 / USD → CNY = 7.20 / CNY → USD = 1/7.20 / USD → EUR / 验收"USD 10 × 7.2 = 72 CNY" / 源缺失兜底 / 目标缺失兜底 / `toRate == 0` 除零保护。
- `test/features/stats/stats_range_providers_test.dart`：新增 3 用例（pie / rank / heatmap 在 USD 10、fxRate 7.2 下计入 72 CNY）。
- `test/features/record/record_new_providers_test.dart`：新增 `_FakeLedgerRepository` + `_testLedger` + 在 `makeContainer` 注入 `ledgerRepositoryProvider` / `currentLedgerDefaultCurrencyProvider` / `fxRatesProvider` overrides；新增 6 用例（setCurrency 写入 / initDefaultCurrency 把 'CNY' → 'USD' 当账本默认 USD / initDefaultCurrency 不覆盖已选 'JPY' / save USD 10 → fxRate=7.2 折合 72 CNY / save 同币种 fxRate=1.0 / save 跨币种到 USD 账本 → fxRate≈1/7.2）。原"附件序列化"用例的 `container.updateOverrides` 同步补齐三个新 override。
- `test/features/record/record_new_page_test.dart`：`_baseOverrides` 注入 `currentLedgerDefaultCurrencyProvider`（用 `_testLedger().defaultCurrency`）+ `fxRatesProvider`（写死 CNY/USD/EUR 三种）。新增 2 用例（点 CNY 键打开下拉 → 选 `currency_picker_USD` → 金额前缀从 `¥ 10` 变 `$ 10`、键盘 label 变 `USD` / 保存 USD 10 → 写入 currency=USD、fxRate=7.2、折合 72 CNY）。
- `test/features/record/record_home_page_format_test.dart`（新建，6 用例）：`formatTxAmountForDetail` USD 10×7.2 → `-USD 10.00（≈ ¥72.00）` / 收入用 `+` / 转账无符号 / 同币种 → `-¥50.00` / CNY 50 → USD 账本 → `-CNY 50.00（≈ $6.94）` / JPY 1500×0.048 → `-JPY 1,500.00（≈ ¥72.00）` 验证 NumberFormat 千分位。

**验证**
- `dart run build_runner build --delete-conflicting-outputs` → 70 outputs，0 error。
- `flutter analyze` → No issues found（修复 2 处 `Undefined class 'Ref'` + 1 处 `unnecessary_import`）。
- `flutter test` → 247/247 通过（222 前 + 8 fx_rate_compute + 3 stats + 6 record_new_providers + 2 record_new_page + 6 record_home_page_format = 247）。
- `dart run custom_lint` → 仍是 3 条预存 INFO（`record_new_providers.dart`），与本步无关。
- 用户本机 `flutter run` 待手工验证（顺序按"开关关 → CNY 单币种"+"开关开 → 跨币种"两条路径）：
  1. 多币种开关**关闭**时（默认）：FAB 进入记一笔 → `initDefaultCurrency` 把 `currency` 设为账本默认（CNY 账本 → 仍 CNY）；键盘左下角无 CNY 键（Step 8.1 行为）；记一笔 50 → 流水 tile 显示 `-¥50.00`；详情显示 `-¥50.00`；卡片显示 `¥X.XX`。
  2. 多币种开关**开启**时：键盘左下角出现当前币种 label（默认 CNY）；点击该键 → 弹出 11 内置币种下拉 + 当前选中带 ✓；选 USD → 金额前缀变 `$`、键盘 label 变 USD；输入 10 → 保存 → tile 显示 `-$10.00`、详情显示 `-USD 10.00（≈ ¥72.00）`；统计页（饼图/排行/热力图）按 fxRate 折算 → USD 10 计入 72 CNY；预算"已花" 同步增加 72。
  3. 多账本切换：把账本默认币种从 CNY 改到 USD（Step 4.x ledger_edit_page）→ `currentLedgerDefaultCurrencyProvider` 自动 invalidate → 顶部卡片 symbol 变 `$`、详情对 USD 流水不再显示括号折合（同币种）；CNY 50 旧流水的 fxRate 仍是保存时的"CNY → CNY = 1.0"，所以折合显示 `≈ $50.00`（注：技术上不准确，留给 Step 8.3 + 未来 fxRate 重算讨论）。
  4. 编辑/复制流水（preloadFromEntry 路径）：currency 字段沿用 entry 自带值，`initDefaultCurrency` 检测到 `currency != 'CNY'` 时跳过（除非原 entry 就是 CNY，那里跳过本来就无害）。

**给后续开发者的备忘**

- **fxRate 在保存时 freeze、读取时不重算**：每条流水的 `fx_rate` 字段保存时计算一次（基于当时的 fx_rate 表 + 账本默认币种），之后即使汇率变化、账本默认币种改变，旧流水的 fxRate 也不会自动更新。这是为了"账本历史是事实记录"而非"基于当前汇率的实时换算"——好处是统计稳定可重现；副作用是用户改了账本默认币种（CNY → USD）后，老 CNY 流水的 fxRate 仍是 1.0，会被错误折合（如上场景 3）。Step 8.3 引入手动覆写后可以暴露"重算所有流水 fxRate"按钮；当前不做。
- **`initDefaultCurrency` 跳过非 CNY 的语义**：检测到 `state.currency != 'CNY'` 直接 return 是保守策略——情景 A（用户在新建页选了 JPY 后被打断、再次进入页面）：保留 JPY 不被覆盖；情景 B（用户的账本默认币种是 USD，开页时 `state.currency = 'CNY'`，第一次 init 后变 'USD'，第二次 init 不再触发）：正确。但若账本默认是 'EUR' 而用户先手选了 'CNY'（与 form 默认同），之后 init 会错把 EUR 写进来——这是已知边界，权衡下保守优先。要彻底解决需引入 `_didInitDefaultCurrency` flag。
- **键盘左下角的"币种 label"在多币种关闭时仍消失**（Step 8.1 行为不变）：因为 `showCurrencyKey = ref.watch(multiCurrencyEnabledProvider).valueOrNull ?? false`。开关关闭时即便 `setCurrency` 被调用，键盘也无入口可见——但 `_AmountDisplay` 的 symbol 仍跟随 `form.currency`。这意味着开关关闭时 `form.currency` 始终被 `initDefaultCurrency` 锁定为账本默认，UI 不暴露任何切换路径，安全。
- **`_CurrencyPicker` 没有搜索/过滤**：11 种内置币种的列表足够短（~一屏），不必加搜索。Step 8.3 手动覆写汇率时如果允许添加新币种，picker 才需要分组/搜索；当前不做。
- **统计聚合改为 `amount * fxRate` 后的零回归保证**：所有现有测试（包括 stats / budget / record_new_providers / 业务表 CRUD 等）都用 `TransactionEntry(...)` 构造，未指定 `fxRate` → 默认 1.0；因此 `amount * 1.0 = amount`，行为未变。新增的"USD 10 fxRate 7.2"用例需显式传 `fxRate: 7.2` 参数。
- **未触动 `account_balance.dart` 的理由**：账户余额按账户自己的 currency 累加；总资产换算到账本默认币种的"跨币种总和"是另一个产品决策（design-document §7.1 给 `account.currency` 留了字段，但未给"总资产显示币种"指定来源）。Step 7 + Step 8 都没承诺这一点；需要时新开 Step 处理（届时也涉及 `_TxTile` 转账路径"USD 账户 → CNY 账户"的语义，比想象复杂）。
- **本步完成了 Step 8.2；按用户约束：在用户验证测试前不开始 Step 8.3。**





### ✅ Step 8.3 汇率自动与手动更新（2026-05-02）

**改动**

数据层 / Schema（v6 → v7）：
- `lib/data/local/tables/fx_rate_table.dart`：`FxRateTable` 追加 `is_manual INTEGER NOT NULL DEFAULT 0` 列。`1` = 用户手动覆盖（`setManualRate` 写入），自动刷新跳过；`0` = seeder 写死或 `setAutoRate` 写入，可被覆盖。CNY 永远保持 `is_manual=0` + `rate=1.0`，UI 层禁用 CNY 行 + 服务层在 fetcher 返回时过滤掉 CNY，保证基准不动。
- `lib/data/local/tables/user_pref_table.dart`：追加 `last_fx_refresh_at INTEGER`（nullable）。每日刷新节流锚点；NULL = 从未刷新。**只在 `refreshIfDue` 写入成功时推进**——失败路径不动，保证下次启动还能重试。
- `lib/data/local/app_database.dart`：`schemaVersion` 从 v6 升 v7；`onUpgrade` 新增 `if (from < 7)` 分支：`m.addColumn(fxRateTable, fxRateTable.isManual)` + `m.addColumn(userPrefTable, userPrefTable.lastFxRefreshAt)`。Schema 版本注释同步追加 v7 行。
- `lib/data/local/dao/fx_rate_dao.dart`：在原 `listAll` / `getByCode` / `upsert` 之外新增 3 个方法。
  - `setAutoRate({code, rateToCny, updatedAt})`：自动刷新写入。先 `getByCode`：不存在 → insert（默认 `is_manual=0`）；存在且 `is_manual=0` → update；存在且 `is_manual=1` → 直接 return 0（被手动行跳过）。返回 1 表示已写入。
  - `setManualRate({code, rateToCny, updatedAt})`：用户手动覆盖。`insertOnConflictUpdate` 写入并把 `is_manual=1`。
  - `clearManualFlag(code)`：把 `is_manual` 置回 0；汇率本身不动，等下次自动刷新覆盖（避免出现"无值"中间态）。

服务层：
- `lib/features/settings/fx_rate_refresh_service.dart`（新建）：`FxRateRefreshService` 三公开 API。
  - `refreshIfDue({force=false})`：受 `user_pref.last_fx_refresh_at` 节流（默认 24h）。`force=true` 绕过节流（"立即刷新"按钮）。fetcher 抛异常 / 返回空 Map → 返回 false 且**不**推进 `last_fx_refresh_at`。fetcher 返回的非有限/非正数被防御性跳过；CNY 在写入前过滤掉。任一币种成功写入即返回 true。
  - `setManualRate(code, rate)`：参数校验后调 DAO；CNY / 非正数 / 非有限抛 `ArgumentError`。
  - `resetToAuto(code)`：调 DAO `clearManualFlag`。
  - `defaultFxRateFetcher`（顶层）：默认 fetcher 走 `https://open.er-api.com/v6/latest/CNY`（免费、无 API key、ECB+Fed 数据源）。该 API 返回 `1 base=CNY = X target`，需要倒数得到 `rate_to_cny[code] = 1 / X`。仅对 [kBuiltInCurrencies] 中的非 CNY 币种返回结果；任何字段缺失或非法都跳过该币种（不抛异常，整体仍可成功）。
  - `FxRateFetcher` typedef：`Future<Map<code, rate_to_cny>> Function()`。测试可注入伪造 fetcher 验证 throttle / failure / manual-skip 行为而不依赖网络。

Provider 层：
- `lib/features/settings/settings_providers.dart`：
  - 新增 `fxRateRowsProvider`（`@Riverpod(keepAlive: true)`）：dump `fx_rate` 全字段行（含 `is_manual` / `updated_at`），供"汇率管理"列表渲染。
  - 新增 `fxRateRefreshServiceProvider`（`@Riverpod(keepAlive: true)`）：返回 `FxRateRefreshService(db: ref.watch(appDatabaseProvider))`，生产 fetcher 默认走 `defaultFxRateFetcher`。
- `lib/main.dart`：bootstrap `await defaultSeedProvider.future` 之后追加 `unawaited(container.read(fxRateRefreshServiceProvider).refreshIfDue().then(...).catchError(...))`。成功后 invalidate `fxRatesProvider` / `fxRateRowsProvider`；catchError 静默吞掉，不影响首帧。新增 `import 'dart:async';` 提供 `unawaited`。

UI 层：
- `lib/features/settings/multi_currency_page.dart`（重写，从 `ConsumerWidget` 升级为 `ConsumerStatefulWidget`）：
  - AppBar 右侧 `IconButton(Icons.refresh, key: 'fx_refresh_now')`：刷新中显示 `CircularProgressIndicator`，点击触发 `service.refreshIfDue(force: true)`，成功 → SnackBar `"汇率已更新"`，失败 → SnackBar `"联网失败，使用现有快照"`。
  - 三段：① 多币种 SwitchListTile（与 Step 8.1 一致）；② 内置币种概览（与 Step 8.1 一致）；③ "汇率管理"标题 + 11 行 `_FxRateTile`。每行渲染 `code` + 中文名 + 4 位小数 rate + 更新时间（`yyyy-MM-dd HH:mm`，本地时区）+ 手动/自动徽章（橙色/绿色/灰色"基准"）。CNY 行 disabled。
  - 入页 `addPostFrameCallback` fire-and-forget `service.refreshIfDue()`（节流，不 force）；成功后 invalidate 行列表。
  - 点击非 CNY 行 → `_ManualRateDialog`（StatefulWidget）：TextField 数字输入 + 校验（正有限数）+ "保存"按钮。手动行额外显示"重置为自动"按钮 + "当前为手动覆盖，自动刷新不会修改它"提示。返回 `_ManualResult(rate?, reset)` 由父组件分发到 `service.setManualRate` / `service.resetToAuto`。
  - 视图模型 `FxRateRow.fromEntry(FxRateEntry)`：把 drift 行解耦成 UI 用结构（`isManual: bool`），便于 widget 测试 + 服务层 fake。

测试：
- `test/features/settings/fx_rate_refresh_service_test.dart`（新建，15 用例）：
  - 节流 × 4：从未刷新即触发 / < 24h 跳过 / >= 24h 重发 / `force=true` 绕过节流。
  - 失败静默 × 3：fetcher 抛异常 → 不更新 fx_rate 也不推进 `last_fx_refresh_at` / 返回空 Map → false / 返回非有限/非正数（NaN / 负数 / 0）跳过该币种但其他正常币种仍写入。
  - 手动覆盖与重置 × 8：手动行不被自动刷新覆盖 / `resetToAuto` 后下次刷新可覆盖 / CNY 在 fetcher 返回时被服务层过滤掉永远保持 1.0 / `setManualRate` 拒绝 CNY / 拒绝非正数 / 写入新行（fx_rate 表中不存在的 code 也能被手动覆盖）。
- `test/data/local/fx_rate_test.dart`：原 11 用例基础上补 6 个 Step 8.3 DAO 用例（默认 `is_manual=0` / `setAutoRate` 在新行插入 / `setAutoRate` 跳过手动行 / `setManualRate` 写入并标 1 / `clearManualFlag` 清标记保留 rate / `clearManualFlag` 对不存在 code 返回 0）。
- `test/features/settings/multi_currency_page_test.dart`（重写）：注入 `_FakeRefreshService`（`implements FxRateRefreshService`，记录 `refreshCalls` / `refreshForceCalls` 并在 `setManualRate` / `resetToAuto` 调用时同步更新内存 rows）。共 11 用例：开关 3 用例 + 内置币种行 1 用例 + Step 8.3 新 7 用例（汇率列表渲染 / CNY 行禁用 + "基准"徽章 / 点击 USD 行 → 输入 → setManualRate / 点击 EUR（手动行）→ "重置为自动" / 点击 CNY 行无反应 / AppBar 立即刷新成功提示 / 立即刷新失败降级提示 / 入页 fire-and-forget refreshIfDue）。

**依赖**
- `pubspec.yaml`：新增 `http: ^1.2.0`（`open.er-api.com` GET 请求）。在此之前 `http` 已是 `supabase_flutter` 的间接依赖；显式声明以满足 `depend_on_referenced_packages` 规则。

**验证**
- `dart run build_runner build --delete-conflicting-outputs` → 38 outputs，0 error（部分 g.dart 已增量重建）。
- `flutter analyze` → No issues found。
- `flutter test` → 270/270 通过（247 前 + 15 fx_rate_refresh_service + 6 fx_rate_dao Step 8.3 + 7 multi_currency_page Step 8.3 - 5 multi_currency_page 老用例移除/合并 = 270）。
- `dart run custom_lint` → 6 条 INFO（3 条预存 `record_new_providers.dart` + 3 条新 `multi_currency_page_test.dart` 的 `scoped_providers_should_specify_dependencies`，仅测试 override 风格，不影响生产）。
- 用户本机 `flutter run` 待手工验证：
  1. **断网测试（implementation-plan §8.3 验证 1）**：关掉网络 → 启动 App → bootstrap fire-and-forget `refreshIfDue` 失败但不阻塞 → 进入"我的 → 多币种" → 列表展示 11 种内置币种的现有快照（USD 7.20 / EUR 7.85 …）→ 进入记账页选 USD 输 10 → 保存 → 不崩溃，统计折合按现有快照 = 72 CNY。
  2. **手动覆盖测试**：联网启动 → 进入"我的 → 多币种" → 点击 USD 行 → 输入 6.50 → 保存 → SnackBar "USD 汇率已手动设为 6.5" → 行徽章变"手动"（橙色）。点 AppBar"立即刷新"按钮 → SnackBar "汇率已更新" → USD 仍是 6.50（手动行不被覆盖；implementation-plan §8.3 验证 2）；其他自动币种被刷新到最新值。
  3. **重置测试**：再次点击 USD 行 → 弹窗显示"重置为自动"按钮 → 点击 → SnackBar "USD 已恢复自动刷新" → 行徽章变"自动"（绿色），rate 仍是 6.50。点"立即刷新" → USD 被新值覆盖。
  4. **节流测试**：刚启动 App → 第一次自动刷新成功 → 立即重启 App（< 24h）→ bootstrap `refreshIfDue` 静默 return false（不发起请求，可在 logcat 观察无 http 请求）。"立即刷新"按钮仍然 force 触发，证明用户主动操作不被节流。
  5. **CNY 不可改**：CNY 行 disabled、点击无反应；即使后端 API 返回 `rates['CNY'] = 0.42` 也被服务层过滤；`setManualRate('CNY', x)` 抛 `ArgumentError`。
  6. **DB 升级路径**：装过 v6 旧版的设备 → drift 走 `onUpgrade` v6→v7 路径执行 2 条 ADD COLUMN，原有 fx_rate 行的 `is_manual` 默认 0（自动），原有 user_pref 行的 `last_fx_refresh_at` 默认 NULL（首启会立即触发刷新）。

**给后续开发者的备忘**
- **节流锚点为什么用 user_pref 而不是 SharedPreferences**：`last_fx_refresh_at` 与 fx_rate 一并是用户的"汇率状态"；放在同一个 SQLCipher 加密 DB 内更一致——同步、备份、清空等操作可统一处理。SharedPreferences 是 Android 上的明文 XML，与"加密优先"原则冲突。
- **fetcher 失败不推进 `last_fx_refresh_at` 的语义**：implementation-plan §8.3 写"每日最多刷新一次"——只对**成功**的刷新计数；失败应允许下次启动重试。当前实现把"成功"宽松定义为"fetcher 返回非空"——即使所有币种都被手动行跳过（`anyWritten=false` 但仍走到末尾），`last_fx_refresh_at` 仍被推进。这是有意的：避免"用户把所有币种都手动覆盖后，每次启动都重新发请求"的频繁失败。
- **API 选择 open.er-api.com 而不是 Frankfurter**：Frankfurter 只覆盖欧央行（ECB）的 30+ 主流币种但**不含 CNY 基准**；open.er-api.com 免费、无 API key、刷新频率每天 1 次（与我们 24h 节流契合）、支持 CNY 基准且包含 11 种内置币种全集。**注意**：open.er-api.com 的免费层有匿名 IP 调用频率限制（约每分钟数次），未来若引入"用户多次点击立即刷新"场景需加客户端去抖。
- **CNY 是基准，rate 永远 1.0**：服务层、DAO 层、UI 层三处合力守护——服务层 fetcher 返回时过滤、`setManualRate` 拒绝、UI 行 disabled。这是"基准"的语义不变量；如果 V2 改为支持"USD 基准账本"用户，需要把基准改成 user_pref 的可配置字段，同时所有 fxRate 计算重新走 `from / to` 而非"以 CNY 为枢轴"。当前架构对 V2 友好（`computeFxRate` 已经是基于"以 X 为基准的 ratesToX"通用形式）。
- **fxRate 在保存时 freeze 的语义不变（继承 Step 8.2）**：本步只新增"汇率源"的管理，不改"流水保存时把当前 fxRate 写入"的逻辑。账本默认币种变更后，旧流水的 fxRate 仍是历史值；需要"重算所有流水 fxRate"按钮的话，要在 transaction_repository 层加批量更新方法 + UI 二次确认（数据破坏性操作，不能默默改历史）。本步未做。
- **`fxRateRefreshServiceProvider.overrideWithValue(...)` 的测试模式**：因为服务实例是非 keep 状态的纯对象（无 stream），用 `overrideWithValue` 比 `overrideWith((ref) => fake)` 更直观。注意：当生产代码改为 `@Riverpod(keepAlive: true)` 函数返回 `XxxService` 时，测试必须用 `overrideWithValue(fake)` 而不是 `overrideWith((ref) => fake)`——后者签名不匹配。
- **本步完成了 Step 8.3；按用户约束：在用户验证测试前不开始 Step 9.1。**



---

## Phase 9 · 混合 AI 快速输入

### ✅ Step 9.1 本地规则解析器（2026-05-02）

**改动**

新建 `lib/core/util/quick_text_parser.dart`：

- `QuickParseResult`（`@immutable`）：纯数据类，承载本地解析结果——`amount` / `categoryParentKey` / `categoryLabel` / `confidence` / `occurredAt` / `note` / `rawText`。`categoryParentKey` 与 `seeder.dart::categoriesByParent.keys` 同集（`food` / `transport` / `shopping` / `entertainment` / `social` / `housing` / `medical` / `education` / `investment` / `income` / `other`）；`categoryLabel` 与 `budget_providers.dart::kParentKeyLabels` 同义（餐饮 / 交通 / …）。`note` 为剥离已识别片段后的残余文本。
- `QuickTextParser({clock})`：纯函数式解析器，注入 `DateTime Function()` 钩子让测试锁定参考时间（避免 `今天 / 昨天 / 上周X / N天前` 等相对时间随真实时钟 flaky）。生产路径默认 `DateTime.now`。
- 解析流程（5 步串行，**故意把时间放在金额之前**）：
  1. **时间**：依次匹配「内置相对天数关键词（大前天/前天/昨天/今天/明天/后天/大后天，并含口语化"昨儿/今儿"）」→「上周X/这周X/下周X/上个星期X/下个星期X（X ∈ 一/二/.../六/日/天）」→「N 天前」。**先于金额扫描**——避免 `3天前 烧烤 88` 被金额正则先吃掉 `3` 导致 `(\d+)\s*天前` 失配。
  2. **金额**：先跑阿拉伯数字正则 `[¥￥]?(\d+(?:\.\d+)?)\s*(?:元|块|RMB|CNY|￥|¥)?`（caseInsensitive）；未命中再跑中文数字回退 `[零一二两三四五六七八九十百千万]+` + 可选尾缀 `元 / 块 / ￥ / ¥`。中文数字解析支持 `0..99,999`（递归下降，覆盖 `三十块` / `两万五千元`）。**单字中文数字（如 `一`）若无单位尾缀视为非金额**——避免 `买了一些菜` 中 `一` 误判。
  3. **分类**：关键词词典（53 个常用词），按"长词优先"扫描——`午饭` / `早饭` / `淘宝` 等不会被泛 `饭` / `饭` 截断。词典覆盖 implementation-plan 重点：餐饮（20 词）+ 交通（13 词）+ 购物（13 词）+ 娱乐（9 词），其余一级分类各放 5-7 个高频词，留长尾给 Step 9.3 LLM 增强。
  4. **置信度**：base 0；阿拉伯金额 +0.5 / 中文金额 +0.4；分类 +0.4；时间 +0.1；上限 1.0。`午饭 30` = 0.9（≥0.8 验收线），`昨天 午餐 28` = 1.0；`三十块` 仅 0.4（< Step 9.2 阈值 0.6 → UI 高亮"请核对"或显示 AI 增强按钮）。
  5. **备注**：每识别一段就把对应 substring 替换为单空格，最终 `replaceAll(\s+, ' ').trim()`；空字符串返回 null。
- 内部辅助类型 `_Range<T>` / `_TimeMatch` / `_CategoryMatch` 私有，仅承载 `(value, start, end)` 元组。
- `parseChineseNumber(String)` 暴露为 `@visibleForTesting` 静态方法，便于针对中文数字分支单独覆盖。
- **故意不依赖 Flutter / Riverpod / drift**——`core/util` 是 V0 公共层，下游 `features/record` 在 Step 9.2 会注入 `QuickTextParser` provider，但本文件本身保持纯 Dart。
- **故意不读 JSON 资产文件**：implementation-plan 提到"分类关键词词典（JSON 文件）"——当前实现选择**const Dart Map** 替代外部 JSON。理由：① 避免 `rootBundle.loadString` 引入异步初始化竞态（解析器要在 UI 输入框 `onChanged` 路径上同步调用）；② 避免 `pubspec.yaml` 加 assets 项；③ 词典体量极小（53 词），编译期常量比运行期 IO 更稳。如果未来 V2 想让用户**自定义**词典，再迁移到"const 默认 + JSON 覆盖"两层结构。

新建 `test/core/util/quick_text_parser_test.dart`（34 用例，覆盖 implementation-plan §9.1 验收的 "20+ 条典型输入"）：

- **`parseChineseNumber` × 5**：个位 / 十位组合 / 百千组合（`一百二十三`）/ 万级（`两万五千`）/ 非法输入返回 null。
- **金额 × 7**：裸数字 `30` / `¥30` / `30元` / `30.5` / `三十块` / `两万五千元` / 单字中文数字若无尾缀不视为金额。
- **分类 × 7**：`午饭 30` → 餐饮 + 30 + 置信度 ≥0.8（implementation-plan 验收线）/ `打车 25` → 交通 / `淘宝买衣服 99` → 购物（长词优先）/ `看电影 50` → 娱乐 / `工资 5000` → 收入 / `房租 3500` → 居家 / 未命中词典返回 null。
- **时间 × 7**：`今天` → 当日 / `昨天打车 25`（金额 + 分类 + 时间三件套，confidence 1.0）/ `前天 50` / `大前天 早饭 12`（不被 `前天` 截断）/ `上周五 100` 基于 2026-05-04 周一 → 2026-05-01 / `3天前 烧烤 88`（修复时间在金额前的关键回归）/ `5 天前` 数字与"天前"间允许空格。
- **note + confidence × 6**：残留为空 / 残留含中文备注 / 中文金额单维 0.4 < 0.6 / 三件套满分 1.0 / 空输入零置信度 / `rawText` 保留原始 trim 前。
- **QuickParseResult × 2**：`toString` 含关键字段、`@immutable` 编译期保护占位。

测试基准时间：`DateTime(2026, 5, 4)`（周一），所有相对时间断言均锚定此值。

**验证**

- `flutter analyze` → No issues found。
- `flutter test test/core/util/quick_text_parser_test.dart` → 34/34 通过。
- `flutter test`（全量）→ 304/304 通过（270 前 + 34 新 = 304）。
- `dart run custom_lint` → 仍是 6 条预存 INFO（3 条 `record_new_providers.dart` + 3 条 `multi_currency_page_test.dart` 关于 scoped_providers_should_specify_dependencies），与本步无关。
- 用户本机验证暂不涉及 `flutter run`——本步仅新增纯 Dart 工具类，UI 接线在 Step 9.2 才发生。implementation-plan §9.1 的两条验收已闭环：① 单元测试覆盖 20+ 条典型输入（实际 34 条）；② "午饭 30" → 金额 30、分类 餐饮、置信度 0.9 ≥ 0.8。

**给后续开发者的备忘**

- **解析顺序：时间 → 金额 → 分类**，绝不能交换前两步。`3天前 烧烤 88` 是关键回归——若让金额先扫描，正则会优先吃掉 `3`，导致 `(\d+)\s*天前` 失配，结果 `amount=3 / occurredAt=null`，与用户意图（`amount=88 / occurredAt=3天前`）相反。当前测试中第 24 条用例就是该回归的钉子。
- **置信度阈值 0.6 是 Step 9.2 的事**：本步只产出分数；Step 9.2 在确认卡片实现"低置信度 → 高亮请核对 / 显示 AI 增强按钮"。如果未来要调阈值，改 Step 9.2 的常量，不动本文件的评分公式。
- **置信度评分是加性而非乘性**：单维识别（如仅金额 / 仅分类）不会归零，便于 Step 9.2"部分识别"的 UX——卡片预填能识别的字段，让用户补全剩余。如果改成乘性（`amount * cat * time`），任一维 0 全归零，UX 差。
- **词典扩展指引**：往 `_keywordDict` 加新词时务必检查"长词优先"是否生效——例如加 `"早午餐"` 后要确认它排在 `"早餐"` / `"午餐"` 之前。`_sortedKeywords` 静态闭包按 `length.compareTo` 倒序排，无需手工维护。
- **中文数字解析的覆盖边界**：当前支持 `0..99,999`，不支持 `亿`、不支持小数（`三点五元`）、不支持负数。如果用户报告"消费一亿元"被误识别为 `0`，再加 `亿` 单位（10^8）即可；当前不预先实现以保持代码简洁。
- **Step 9.3 LLM 增强的对接点**：Step 9.2 在确认卡片上展示本地结果；当 `confidence < 0.6` 时显示"✨AI 增强"按钮，按钮调用 LLM 后**用 LLM 返回的 JSON 重写卡片字段**——不动 `QuickParseResult` 本身（保持纯本地结果作为兜底）。
- **本步完成了 Step 9.1；按用户约束：在用户验证测试前不开始 Step 9.2。**


### ✅ Step 9.2 首页快捷输入条接线（2026-05-02）

**改动**

新增 `lib/features/record/quick_input_providers.dart`：
- `@Riverpod(keepAlive: true) QuickTextParser quickTextParser(Ref ref)`——返回 `QuickTextParser()`，clock 默认 `DateTime.now`。`keepAlive` 让首页输入实例复用同一个 parser；测试可 `quickTextParserProvider.overrideWith((ref) => QuickTextParser(clock: () => fixedNow))` 注入固定时钟，让"昨天 / N天前 / 上周X"断言稳定。
- `const double quickConfidenceThreshold = 0.6`——implementation-plan §9.2 建议阈值。常量而非 provider，因为阈值是产品决策不随会话/账本变化。Step 9.3 LLM 增强按钮也使用同阈值决定是否暴露。

新增 `lib/features/record/quick_confirm_sheet.dart`：
- 顶层函数 `Future<bool> showQuickConfirmSheet({context, parsed})`：弹出 modal bottom sheet 包裹 [QuickConfirmCard]，返回 true=保存成功 / false=取消。
- `QuickConfirmCard`（ConsumerStatefulWidget）：4 个可编辑字段——
  - **金额**：`TextField` + `numberWithOptions(decimal:true)` + `FilteringTextInputFormatter.allow(r'^\d*\.?\d{0,2}')` 限两位小数。前缀走账本默认币种 symbol（`kBuiltInCurrencies` 查 `currentLedgerDefaultCurrencyProvider` 命中码）。挂 `Key('quick_confirm_amount_field')`。
  - **分类**：`InkWell` 行显示 `parentLabel / categoryName`，点击弹 `_CategoryPickerList`（`DraggableScrollableSheet(initialChildSize:0.6)` 内的 `ListView` + 按 `_parentKeyOrder` 分组的 ListTile）。每个 ListTile 挂 `Key('quick_confirm_picker_${c.id}')`，已选项 trailing 显示 `Icon(Icons.check)`。
  - **时间**：`InkWell` 行显示 `yyyy-MM-dd HH:mm`，点击 `showDatePicker(locale: zh_CN, lastDate: now) → showTimePicker` 串联。文本挂 `Key('quick_confirm_time_text')`。
  - **备注**：`TextField` + 挂 `Key('quick_confirm_note_field')`。
- 置信度 `< quickConfidenceThreshold` 时顶部展示红色横幅（挂 `Key('quick_confirm_low_conf_banner')`），文案"识别置信度较低，请核对"，色板取苹果红 `#E76F51`。Step 9.3 "AI 增强"按钮将出现在同一区。
- 初始化路径（`initState`）：
  - 从 `QuickParseResult.amount` 格式化填入 `_amountController`（`25.0` → `"25"`、`25.50` → `"25.5"`、`25.55` 保持原样）；
  - `_noteController` 填入 `parsed.note`（剥离已识别片段后的残余）；
  - `_parentKey` 取自 `parsed.categoryParentKey`；
  - `_occurredAt` = `parsed.occurredAt` 的日期 + "现在"的时分（解析未识别时回退当前时间）；
  - `WidgetsBinding.addPostFrameCallback` 触发 `_loadCategories`（fire-and-forget）：从 `categoryRepositoryProvider` 拉全量活跃分类 → 按 `_parentKeyOrder` + `sortOrder` 排序 → 解析的 `parentKey` 命中时默认选其下首个二级分类。
- 保存路径（`_save`）：
  - `_canSave` = `amount > 0 && categoryId != null`；不满足时按钮 disabled。
  - 构造 `TransactionEntry`（`type` 由 `_parentKey == 'income' ? 'income' : 'expense'` 自动判定，与 `record_new_page` 同语义；`currency` 取账本默认币种、`fxRate=1.0` 同币种简化、`accountId/toAccountId` 留空——快速输入暂不暴露账户选择，由后续 LLM 增强或全屏新建页处理）→ `transactionRepository.save` → invalidate 月度汇总 + 4 个 stats provider + budgetProgressFor。
  - `_saving` 状态守按钮防双击；保存成功 `Navigator.pop(true)`；异常 SnackBar 提示"保存失败：$e"。

修改 `lib/features/record/record_home_page.dart`：
- `_QuickInputBar` 由 `StatelessWidget` 改为 `ConsumerStatefulWidget`——持有 `TextEditingController _controller` + `bool _busy`。
- TextField 加 `Key('quick_input_field')` + `textInputAction: TextInputAction.send` + `onSubmitted: (_) => _handleSubmit()`。
- 识别按钮加 `Key('quick_input_recognize_button')`，`onPressed: _busy ? null : _handleSubmit`。
- `_handleSubmit()` 流程：trim 后空文本 → `ScaffoldMessenger.showSnackBar('请先输入一段话再点识别')`；非空 → `ref.read(quickTextParserProvider).parse(text)` → `await showQuickConfirmSheet(...)` → 返回 true 时 `_controller.clear()`。`_busy` 在 await 期间锁住按钮，避免重复提交。
- 顶部 import 增加 `quick_confirm_sheet.dart` + `quick_input_providers.dart`。

**测试**

`test/features/record/quick_confirm_sheet_test.dart`（新建，9 用例）：
1. **`昨天打车 25` → 金额=25 / 分类=交通/地铁公交 / 时间=2026-05-03**——验收 §9.2 主用例。固定 parser 时钟 `2026-05-04`（与 quick_text_parser_test 对齐）。
2. **低置信度（仅金额命中）→ 红色横幅 + 保存 disabled**——`30` 输入，confidence=0.5 < 0.6。
3. **备注字段显示残余文本**——`今天 午饭 30 跟同事` → note=`跟同事`。
4. **`昨天打车 25` 点保存 → tx 写为 `expense + cat-transport-1`**——validates 默认选 transport 下 sortOrder=0 的分类。
5. **`工资 5000` → 自动判定 `income` type 并保存**——validates `_parentKey == 'income'` 自动推导 income type。
6. **用户改写金额 → 保存使用最终值**——`enterText('42.5')` 后 `lastSaved.amount == 42.5`。
7. **点取消 → 不保存；showQuickConfirmSheet 返回 false**——验证 sheet pop 回值正确。
8. **点击分类行 → 选择器显示分组 + 已选高亮**——`Icon(Icons.check)` 在 cat-transport-1 的 ListTile trailing。需要 `tester.view.physicalSize = (800, 1600)` 把 DraggableScrollableSheet 的 ListView 视口拉到 960px，让"打车"也在 tree 里（默认 600px 视口下 0.6 高度只能渲染前 4 行，后面的 sliver 是 lazy 的）。
9. **点击"打车"切换分类 → 卡片标题更新 + 保存 categoryId 切换**——同样需要扩展视口。

`test/features/record/quick_input_bar_test.dart`（新建，2 用例）：
1. **首页输入"昨天打车 25" → 弹确认卡片 → 保存 → 流水落库**——通过 `BianBianApp` + 完整 ProviderScope override 走完链路。验证：① 输入"昨天打车 25" + 点识别按钮 → 卡片打开；② 卡片金额=25、分类=交通/地铁公交、时间=2026-04-25；③ 点保存 → 卡片关闭、输入框清空、`txRepo.lastSaved` 含 `amount=25 / type=expense / categoryId=cat-trans-1 / fxRate=1.0 / occurredAt 日期=2026-04-25`。RecordMonth 锚定 2026-04 + parser 时钟锚定 2026-04-26 → "昨天" = 2026-04-25 落在测试月内，避免 flaky。
2. **空文本时点识别 → SnackBar 提示，不弹卡片**——验证防御分支。

需要新建的 fake：`_RecordingTransactionRepository`（区别于 widget_test.dart 里那个 fail 的同名类，记录 lastSaved）+ `_FakeCategoryRepository`（widget_test 没有的）。`_FakeLedgerRepository / _FakeAccountRepository` 复用既有模式。

**验证**
- `dart run build_runner build --delete-conflicting-outputs` → 52 outputs，0 error。
- `flutter analyze` → No issues found。
- `flutter test` → 315/315 通过（前 304 + 9 confirm sheet + 2 integration = 315）。
- `dart run custom_lint` → 6 条预存 INFO（3 条 `record_new_providers.dart` + 3 条 `multi_currency_page_test.dart`），与本步无关。
- 用户本机 `flutter run` 待手工验证：
  1. 首页输入"昨天打车 25"按回车 / 点 "✨ 识别" → 弹出确认卡片，金额预填 25、分类显示"交通 / 地铁公交"（或种子化首条 transport 子类）、时间显示昨天日期 + 当前时分、备注空。
  2. 卡片置信度高（≥0.6）→ 不显示红色横幅。
  3. 输入"30"按识别 → 卡片金额 25 替换为 30，分类显示"请选择"占位、保存按钮置灰、顶部红色"识别置信度较低，请核对"横幅可见。
  4. 点击分类行 → DraggableScrollableSheet 弹出 → 分类按"食/购/行/育/乐/情/住/医/投/收/其"分组展示，每行 emoji + 名称 + 当前选中处 trailing ✓。点选另一个分类 → 卡片更新。
  5. 点击时间行 → 系统 datePicker → timePicker 串联 → 卡片时间字段更新。
  6. 修改备注/金额 → 点保存 → 卡片关闭、输入框清空、首页流水列表当日组出现新条目（金额、分类 emoji、时间正确）。
  7. 点取消 / 关闭按钮 → 卡片关闭、输入框保留原文本（便于用户继续编辑）。
  8. 空输入直接点识别 → SnackBar "请先输入一段话再点识别"，不弹卡片。

**给后续开发者的备忘**
- **快速输入暂不支持账户选择**：保存路径里 `accountId / toAccountId` 都为 null。设计意图是"快速一句话记一笔，不强制选账户"——保留账户为"未填写"，事后用户可在流水详情页编辑。如果产品后续要求"快速输入也用上次记录的账户"，可以借鉴 `RecordForm.initDefaultAccount` 的模式：在 `_save` 前读 `SharedPreferences.last_used_account_id` 兜底。
- **快速输入暂不支持币种切换**：保存写入账本默认币种 + `fxRate=1.0`。Step 8.2 的多币种开关只影响 `record_new_page` 的键盘 CNY 键，不影响快速输入卡片。如果用户在外币账本下用快速输入"打车 25"，会落入"账本默认币种 + amount=25"。这与 record_new_page 行为一致。如果产品要求快速输入也支持币种下拉（例如解析 "USD 25 打车"），需要在 [QuickTextParser] 加币种识别 + 卡片金额前 prefix 改为可点击的币种选择器；当前不做。
- **`_loadCategories` 在 postFrameCallback 而非 initState 直接调**：如果在 initState 直接 `await ref.read(...)`，会触发 Riverpod 的 "ref read in initState before first build" 警告（虽然实际不会抛错，但破坏 frame 模型）。`addPostFrameCallback` 把 IO 推迟到第一帧之后，干净。
- **DraggableScrollableSheet 内部 ListView 是 lazy 的**：测试视口默认 600px，0.6 高度 = 360px，只能渲染 4-5 行；后面的项不在 widget tree 里，`find.byKey` 直接 fail。本步采用的解决方案：测试时 `tester.view.physicalSize = const Size(800, 1600)` 把视口拉到 960px 让所有项渲染。生产路径不动。如果未来分类总数 >50 让选择器列表很长，考虑用 `tester.dragUntilVisible` 替代视口扩展。
- **保存后 invalidate 6 个 provider 与 record_new_page.save 完全一致**——确保首页流水列表、统计页、预算进度、账户余额都即时刷新。Phase 10 同步上线后这些 invalidate 不需要修改（同步引擎走另一路径触发 ref.invalidate）。
- **Step 9.3 接入路径**：在 [QuickConfirmCard] 内置信度 < 0.6 时**额外**渲染一个"✨ AI 增强"按钮（紧邻"请核对"横幅）。点击调用用户配置的 LLM endpoint，把返回的 JSON 重写卡片字段（amount / categoryId / occurredAt / note）—**不动** [QuickParseResult] 本身（保留本地基线作为兜底）。`features/settings/ai_input_settings.dart` 之类的新文件承载 LLM 配置；当前不预创建。
- **本步完成了 Step 9.2；按用户约束：在用户验证测试前不开始 Step 9.3。**


### ✅ Step 9.2 hotfix：showModalBottomSheet builder 误用外层 context（2026-05-02）

**现象**：用户实机验收时出现红屏 —— `Looking up a deactivated widget's ancestor is unsafe.`，stack 指向 `record_home_page.dart:764`（即 `_DetailAction.edit` 分支二次开 sheet 的 `Theme.of(context).colorScheme.surface`）。复现路径：保存流水（Step 9.2 quick input 或既有 FAB）→ 列表 invalidate → 用户在 `_TxTileState` 上点开详情 → 选"编辑" → 第二层 sheet 在 build 时外层 `_TxTileState` 已被 deactivate（Dismissible / FutureBuilder 重排）→ `Theme.of(outerContext)` 抛错。

**根因**：4 处 `showModalBottomSheet(builder: (sheetContext) => ... Theme.of(context) ...)` 全都用了**外层闭包 context** 而非 builder 注入的 `sheetContext`。Flutter 文档明确："builder 内不要用外层 context 做 ancestor 查找"。这是 Step 9.2 之前就有的潜在 bug；Step 9.2 的快速保存让"保存→列表重建"路径更短，更容易让用户撞上。

**修复**：`record_home_page.dart` 4 处全部把 `Theme.of(context)` 改为 `Theme.of(sheetContext)`：
1. `RecordHomePage.build` FAB onPressed → 第一层 sheet（line 114）
2. `_TopBar` 转账按钮 onPressed → 第一层 sheet（line 224）
3. `_TxTileState` `_DetailAction.edit` → 第二层 sheet（line 764，**用户实机崩的那一行**）
4. `_TxTileState` `_DetailAction.copy` → 第二层 sheet（line 798）

`Image.errorBuilder` 内 `Theme.of(context)`（line 1094）保留——那个 `context` 是 `_RecordDetailSheet.build` 注入的 sheet 自身的 context，不是外层。

`quick_confirm_sheet.dart` 自身两处 builder（`showQuickConfirmSheet` 与 `_pickCategory`）从一开始就用 `sheetCtx`，无需修补。

**验证**
- `flutter analyze` → No issues found。
- `flutter test` → 315/315 仍全绿（修复路径无逻辑变化，颜色源切换为 sheet 自己的 Theme，用户视觉无差别——sheet 在 MaterialApp 主题作用域内）。

**给后续开发者的备忘**
- **`showModalBottomSheet(builder: (ctx) {...})` 的 `ctx` 才是 sheet 自己的 context**。在 builder 内**绝不能**用闭包捕获的外层 `context` 做 `Theme.of` / `MediaQuery.of` / `Navigator.of` 等 ancestor 查找——sheet 关闭、外层重建期间外层 context 会被 deactivate。这条规则同样适用于 `showDialog` / `showMenu` / `showGeneralDialog` 等所有"内联子树"API。本项目内已知合规位点：`account_list_page._confirmDelete`、`ledger_list_page` 各处删除/编辑菜单——它们 builder 内只用 builder 注入的 context。
- **回归保护建议**：可以加一个 `flutter analyze` 自定义 lint 规则，在 `showModalBottomSheet`/`showDialog` 的 builder 闭包里禁止使用闭包捕获的 `context`。本步未做（成本/收益不平衡），但若未来再撞同款，写一条规则比反复 review 更稳。


### ✅ Step 9.3 LLM 增强（2026-05-02）

**改动**

数据层 / Schema（v7 → v8）：
- `lib/data/local/tables/user_pref_table.dart`：追加 3 列。
  - `ai_input_enabled INTEGER NULLABLE DEFAULT 0`：master switch。0/null = 关闭（确认卡片不显示 AI 增强按钮），1 = 开启（且需 endpoint/key/model 三件齐全才真正显示按钮）。
  - `ai_api_model TEXT NULLABLE`：用户填写的模型名（如 `gpt-4o-mini`）。
  - `ai_api_prompt_template TEXT NULLABLE`：用户填写的 prompt 模板（含 `{NOW}` / `{TEXT}` / `{CATEGORIES}` 占位符）；为空时使用 `kDefaultAiInputPromptTemplate` 兜底。
  - 历史遗留列 `ai_api_endpoint TEXT` / `ai_api_key_encrypted BLOB`（自 Step 4.2 user_pref 表初次落库即声明但未消费）：Step 9.3 起被消费。`ai_api_key_encrypted` 在 V1 落 UTF-8 raw bytes（DB 由 SQLCipher 加密保护，故 at-rest 安全已由 DB 级别覆盖；Phase 11 会改为 BianbianCrypto 字段级加密，列名 `_encrypted` 是为该用法预留的）。
- `lib/data/local/app_database.dart`：`schemaVersion` 从 v7 升 v8；`onUpgrade` 新增 `if (from < 8)` 分支：3 个 `m.addColumn(userPrefTable, ...)`。Schema 版本注释同步追加 v8 行。

Provider 层 / 服务：
- `lib/features/settings/ai_input_settings_providers.dart`（新建）：
  - `AiInputSettings`（`@immutable` 数据类）：5 字段 + `hasMinimalConfig` getter（enabled + endpoint/key/model 三件齐全才 true，决定确认卡片是否显示 AI 增强按钮，implementation-plan §9.3 验证 1 的核心守门）+ `effectivePromptTemplate` getter（用户值优先，否则走默认）+ `copyWith` + `==` / `hashCode`。
  - `AiInputSettingsNotifier`（`@Riverpod(keepAlive: true) class`）：`build()` 从 `user_pref` 加载；`save(AiInputSettings)` 全量覆盖写入 + `invalidateSelf()`。空白字段（empty / whitespace-only）一律落 NULL，便于 `hasMinimalConfig` 用 `isNotEmpty` 判断。API key 经 `_encodeApiKey`（UTF-8 → Uint8List）/ `_decodeApiKey`（反向）转换。
  - `aiInputEnhanceServiceProvider`（`@Riverpod(keepAlive: true)`）：返回 `AiInputEnhanceService(settings: aiSettings)`，settings 变更（用户在配置页保存）时自动重建。测试可 `overrideWithValue(fakeService)`。
  - `kDefaultAiInputPromptTemplate`（顶层 const）：默认 prompt 模板。强调"只输出 JSON" + 字段允许 null + snake_case 字段名。

- `lib/features/record/ai_input_enhance_service.dart`（新建）：
  - `AiEnhanceResult`（`@immutable` 数据类）：4 字段 amount / categoryParentKey / occurredAt / note。LLM 命中视作高置信度，无 confidence 字段。
  - `AiEnhanceException`（`Exception`，含 message）：所有失败的统一异常类型——UI 层 catch 后展示 SnackBar `'AI 解析失败：$message'`。
  - `kValidParentKeys`（顶层 const Set）：合法 parent_key 集（与 `seeder.dart::categoriesByParent.keys` 同集），用于校验 LLM 返回的 `category_parent_key`。
  - `AiInputEnhanceService` 类：构造参数 `settings` + 可注入的 `httpClient` / `clock` / `timeout`（默认 30s）。
    - `enhance(String rawText)`：① 校验配置完整 → ② 校验 endpoint URL 合法 → ③ 替换 prompt 占位符 → ④ POST OpenAI Chat Completions（`{model, messages: [{role:user, content:prompt}], temperature:0, response_format:{type:'json_object'}}`，`Authorization: Bearer <key>`，30s 超时）→ ⑤ HTTP 200 → 抽取 `choices[0].message.content` → ⑥ 调 `parseEnhanceJson`。任一步失败抛 `AiEnhanceException`（implementation-plan §9.3 验证 2 "网络失败回退本地结果"在此守护）。
    - `_buildPrompt`：替换 `{NOW}` → `yyyy-MM-dd HH:mm`、`{TEXT}` → 用户原文、`{CATEGORIES}` → `kValidParentKeys.join(' / ')`。
    - `buildPromptForTesting`：`@visibleForTesting` 暴露给单测验证占位符替换。
  - `parseEnhanceJson(String)`（顶层 + `@visibleForTesting`）：严格 schema 校验。`amount` 必须 number 且 isFinite 且 > 0；`category_parent_key` 必须在 `kValidParentKeys` 内；`occurred_at` 必须 ISO 日期；`note` 必须 string。任一字段类型 / 取值 / 格式不符抛 `AiEnhanceException`——不返回部分解析结果，避免半成品污染卡片（implementation-plan §9.3 验证 3 "JSON 不符合 schema 不崩溃"在此守护）。

UI 层：
- `lib/features/settings/ai_input_settings_page.dart`（新建）：`AiInputSettingsPage` ConsumerStatefulWidget。5 字段表单 + 底部"保存"按钮。
  - 字段：SwitchListTile（开关）+ 4 个 TextField（endpoint URL / API key（默认 obscureText=true，可点眼睛切换）/ model / prompt 模板，多行 6-12 行）。
  - 控制器在第一次拿到 settings 时一次性 `_hydrate`（`_hydrated` flag 守门，避免后续 settings 变更覆盖用户编辑）。
  - 保存路径：构造完整 `AiInputSettings` → `notifier.save(...)` → SnackBar `'AI 增强配置已保存'`；失败 → `'保存失败：$e'`。`_saving` 状态守按钮防双击。
  - 关键 Key：`ai_input_enabled_switch` / `ai_input_endpoint_field` / `ai_input_api_key_field` / `ai_input_show_api_key` / `ai_input_model_field` / `ai_input_prompt_field` / `ai_input_save_button`。

- `lib/features/record/quick_confirm_sheet.dart`（修改）：
  - `_QuickConfirmCardState` 新增字段 `bool _aiEnhancing = false`。
  - 新增 `_runAiEnhance()` 方法：调 `aiInputEnhanceServiceProvider.enhance(parsed.rawText)`。
    - **成功**：setState 用返回值重写 `_amountController` / `_parentKey`（并自动选首个二级分类，与 `_loadCategories` 兜底策略一致）/ `_occurredAt`（保留时分）/ `_noteController` → SnackBar `'AI 已更新'`。
    - **失败**（catch `AiEnhanceException`）：SnackBar `'AI 解析失败：${e.message}'`，**字段不变**（implementation-plan §9.3 验证 2 "网络失败回退本地结果"）。
    - **其他异常**：SnackBar `'AI 解析失败：$e'`，同样不变字段。
  - `build()` 内新增局部变量 `showAiButton = lowConfidence && (aiSettings?.hasMinimalConfig ?? false)`——三个条件同时满足才显示按钮（implementation-plan §9.3 验证 1 "没有配置 API 时按钮不显示"）。
  - 低置信度横幅 Row 末尾新增 `TextButton.icon(✨ AI 增强)`：挂 `Key('quick_confirm_ai_enhance_button')`，loading 时显示小 spinner + 文字 "解析中…"，完成后回到 `'AI 增强'`。颜色取苹果红与横幅一致。

- `lib/app/home_shell.dart`：`_MeTab` 新增 `ListTile(Icons.auto_awesome, '快速输入 · AI 增强')` → `context.push('/settings/ai-input')`。
- `lib/app/app_router.dart`：新增 `GoRoute('/settings/ai-input')` → `AiInputSettingsPage`。

**测试**

- `test/features/settings/ai_input_settings_providers_test.dart`（新建，10 用例）：
  - **AiInputSettings 数据类 × 5**：默认空 / hasMinimalConfig 四件齐全断言（5 case：缺各字段 + 空白 + 全齐）/ effectivePromptTemplate 用户值优先 / `==` 全字段参与 / copyWith 仅修改指定字段。
  - **DB 集成 × 5**：build 默认 → 全空 / save → 持久化 → 重读校验 5 字段 + DB 直查 user_pref 5 列 + API key BLOB UTF-8 bytes 断言 / save 空白字段一律 NULL / save API key 含中文 / emoji UTF-8 往返 / user_pref 不存在的极端兜底（删除 user_pref 单行后重建 container 仍能返回空 settings 不崩溃）。
- `test/features/record/ai_input_enhance_service_test.dart`（新建，24 用例）：
  - **parseEnhanceJson 正常路径 × 4**：全字段命中 / 仅 amount / amount=null 仍可用 / 空字符串等价缺失。
  - **parseEnhanceJson schema 严格校验 × 9**：content 非 JSON / 数组非对象 / amount 类型非法（字符串）/ amount ≤ 0 / amount 0.0 / category 取值非法（'breakfast'）/ category 类型非法（数字）/ occurred_at 非 ISO（'昨天'）/ note 类型非法（对象）。
  - **AiInputEnhanceService.enhance × 8**：未配置兜底 / endpoint URL 非法 / 成功路径（验证 Authorization header / model / response_format / prompt 替换）/ HTTP 非 200（429）/ 网络异常（client throws ClientException）/ 缺 choices / content 非 JSON / amount schema 非法。
  - **buildPromptForTesting × 3**：默认模板三占位符替换 / 用户自定义模板替换 / 空 promptTemplate 走默认。
  - 注意：http.Response 默认 Latin1 编码，含中文测试响应必须显式 `headers: {'content-type': 'application/json; charset=utf-8'}`。
- `test/features/settings/ai_input_settings_page_test.dart`（新建，3 用例）：① 入页根据 settings 预填 5 字段（SwitchListTile.value / 4 个 controller.text / API key obscureText=true）；② 切开关 + enterText 4 字段 + 保存 → notifier.lastSaved 收到完整 settings + SnackBar `'AI 增强配置已保存'`；③ 点击眼睛 → API key obscureText 切到 false，再点切回 true。
- `test/features/record/quick_confirm_sheet_test.dart`（追加 4 用例 = 13 → 17）：
  - `_overrides` 新增 `aiInputSettingsNotifierProvider.overrideWith(() => _TestAiInputSettings(aiSettings))` + 可选 `aiInputEnhanceServiceProvider.overrideWithValue(aiService)` 注入。
  - 新增 `_TestAiInputSettings extends AiInputSettingsNotifier`（覆盖 `build` 返回 fixed initial、覆盖 `save` 直接 `state = AsyncValue.data(...)`）+ `_FakeAiEnhanceService implements AiInputEnhanceService`（记录 callCount + lastInput；可注入 result 或 error）。
  - 4 用例：① 无 AI 配置 + 低置信度 → 横幅在但 AI 按钮不在；② AI 配置完整 + 低/高置信度 → 按钮分别可见/不可见（验证 `showAiButton` 三条件守门）；③ 点 AI → 成功结果改写 amount=88.5 / parentKey=transport（自动选 sortOrder=0 = 地铁公交）/ occurredAt=2026-05-01 / note='AI 推断备注' + SnackBar `'AI 已更新'`；④ 点 AI → 失败 SnackBar `'AI 解析失败：网络请求失败：模拟断网'`，amount 仍 30 / 分类仍 '请选择'（implementation-plan §9.3 验证 2 兜底）。

**依赖**

本步未新增 `pubspec.yaml` 依赖。`http: ^1.2.0` 已在 Step 8.3 引入，本步直接复用。`http/testing.dart` 的 `MockClient` 同样已在 supabase_flutter 间接依赖中。

**验证**

- `dart run build_runner build --delete-conflicting-outputs` → 增量重建 6+ outputs（schema v8 改动 + 新 provider g.dart）。
- `flutter analyze` → No issues found。
- `flutter test` → 360/360 通过（315 前 + 4 quick_confirm_sheet AI 按钮 + 24 service + 10 settings provider + 3 settings page + 4 quick_confirm_sheet 重构净增量 = 360）。
- `dart run custom_lint` → 8 条 INFO（6 条预存 + 2 条新 `ai_input_settings_page_test.dart` 关于 `avoid_public_notifier_properties` / `scoped_providers_should_specify_dependencies`，仅测试 fake 风格，不影响生产）。
- 用户本机 `flutter run` 待手工验证：
  1. **未配置时按钮不显示（implementation-plan §9.3 验证 1）**：进入"我的 → 快速输入 · AI 增强"→ 不开启开关；返回首页输入"30" → 弹出确认卡片 → 红色"识别置信度较低"横幅可见 + AI 增强按钮**不显示**。
  2. **配置后按钮显示**：回到 AI 配置页 → 开启开关 → 填写 endpoint（如 `https://api.openai.com/v1/chat/completions`）+ API key + model（如 `gpt-4o-mini`）→ 保存 → SnackBar `'AI 增强配置已保存'`。返回首页输入"30" → 卡片横幅 + AI 增强按钮（✨）**同时显示**。输入"昨天打车 25"→ 高置信度 → 横幅 + 按钮**都不显示**。
  3. **点击 AI 增强成功**：低置信度卡片点 ✨ → 按钮变 spinner "解析中…" → LLM 返回结果 → 卡片字段更新 + SnackBar `'AI 已更新'`。
  4. **网络失败兜底（implementation-plan §9.3 验证 2）**：飞行模式 / 错误 endpoint → 点 ✨ → SnackBar `'AI 解析失败：网络请求失败：...'`，卡片字段保持本地解析值不变。
  5. **schema 校验（implementation-plan §9.3 验证 3）**：模拟 LLM 返回 `{"amount":"30"}`（字符串）→ SnackBar `'AI 解析失败：amount 字段类型非法...'`，不崩溃。
  6. **API key 安全**：配置页打开 → API key 字段默认显示 `••••••` 遮蔽；点眼睛图标 → 明文展开；再点 → 重新遮蔽。
  7. **DB 升级路径**：装过 v7 旧版的设备 → drift 走 `onUpgrade` v7→v8 路径执行 3 条 ADD COLUMN，原 user_pref 行的 `ai_input_enabled` 默认 0（关闭，不影响行为），其他 2 列默认 NULL。

**给后续开发者的备忘**

- **Step 9.3 暂不接入 Phase 11 加密**：API key 当前以 UTF-8 raw bytes 存入 `ai_api_key_encrypted` BLOB 列（实际未加密；DB 由 SQLCipher 加密保护已足够 V1）。Phase 11 引入 BianbianCrypto 字段级加密时，会增加 `_encryptedApiKey(plaintext, syncKey)` 路径，迁移逻辑：① 用户登录同步 → 派生 syncKey → ② 读现有 BLOB 视为 plaintext → ③ 用 syncKey 重新加密写回。本步**不**新增独立 `ai_api_key_plain` 列，避免后续迁移碎片。
- **endpoint URL 校验只查 `Uri.tryParse + hasAbsolutePath`，未校验 https**：用户可填 `http://` 本地代理（如 LM Studio）。如果产品要求强制 https，加 `if (url.scheme != 'https') throw ...`，但要在 settings page 给出"测试连接"按钮配套验证。
- **prompt 模板留空 → 走默认**：在 `AiInputSettings.effectivePromptTemplate` 处统一兜底，UI 配置页只显示 hint，不在 onChanged 时强制覆写——保留用户清空的语义（`null`）。
- **fake service 实现 AiInputEnhanceService 接口**：因 service 是 class 而非 mixin，fake 必须 `implements`（非 `extends`）。`buildPromptForTesting` 在 fake 中抛 `UnimplementedError`——当前 UI 路径不调用，若未来调用需补 mock。
- **测试中 http.Response 含中文必须显式 utf-8 头**：`http.Response('{"note":"中文"}', 200, headers: {'content-type': 'application/json; charset=utf-8'})`。否则默认 Latin1 编码会在 `resp.body` 抛 `Invalid argument: Contains invalid characters`。
- **Step 9.3 LLM 增强路径与 Step 9.1 本地 parser 完全解耦**：LLM 失败时本地 `QuickParseResult` 仍是兜底结果——卡片用户始终能保存（手动补全）。这就是"hybrid"的语义：AI 是 nice-to-have 的增强，不是关键路径。
- **本步完成了 Step 9.3，也完成了 Phase 9 全部三个步骤**。按用户约束：在用户验证测试前不开始 Step 10.1 Supabase Schema 与 RLS。Phase 10 同步上线后会与 Phase 11（字段级加密）紧密耦合——届时可能需要返回 Step 9.3 调整 API key 存储路径（plaintext bytes → BianbianCrypto 加密）。

---

## Phase 10 · 多后端云同步

### ✅ Step 10.1 + 10.2 同步抽象 + UI + 快照引擎（2026-05-03）

**前置**：Phase 10 上半段在前一轮 agent 实施时**留下了大面积破坏**，需先恢复基线再继续：

1. `lib/data/local/providers.dart` 与 `lib/data/repository/providers.dart` 被简化重写（去掉了 `deviceIdProvider / defaultSeedProvider / 5 个 repo provider / currentLedgerIdProvider`）；对应的 `.g.dart` 产物被删除——80+ 编译错误，全项目无法构建。
2. `user_pref` 表加了未消费的 `sync_provider_type / sync_provider_config` 两列、schema 升到 v9（孤儿列）。
3. `sync_engine.dart` 与 `sync_provider.dart` 类型全错（`int ledgerId` vs domain 实体的 `String id`、drift 字段名不存在、`AccountEntry.fromJson` 不存在）。

**修复路径（与用户协商后执行）**：

A. 用 `git checkout HEAD -- lib/data/local/providers.dart lib/data/local/providers.g.dart lib/data/repository/providers.dart lib/data/repository/providers.g.dart` 恢复到 Step 9.3 基线。
B. 用 `git checkout HEAD -- lib/data/local/app_database.dart lib/data/local/app_database.g.dart lib/data/local/tables/user_pref_table.dart` 回滚 schema v9 升级——保持 v8。云配置由 `flutter_cloud_sync` 包通过 `SharedPreferences` 持久化（包内现有设计），不入 user_pref。
C. 删除 `lib/features/sync/sync_engine.dart`，重写为下面的 4 个文件。
D. 跳过 BeeCount Cloud 后端：`packages/flutter_cloud_sync/lib/src/providers/beecount_cloud_provider.dart` 与配置/工厂分支保留为死代码（包内自包含，不删以减少改动），但项目层不暴露任何 UI 入口。

**改动**：

新增 4 个文件 + 修改 3 个文件 + pubspec 加 `crypto: ^3.0.3`。

- `lib/features/sync/sync_service.dart`（重写）：
  - `SyncService` 抽象——`upload(ledgerId)` / `downloadAndRestore(ledgerId)` / `getStatus(ledgerId, {forceRefresh})` / `deleteRemote(ledgerId)` / `clearCache()`。所有方法用 `String ledgerId`（与项目其余地方一致；旧版用 `int` 是 Phase 10 的 typo）。
  - `LocalOnlySyncService` 兜底实现——所有写操作抛 `UnsupportedError`，`getStatus` 返回 `SyncState.notConfigured` + 哨兵消息 `__SYNC_NOT_CONFIGURED__`。
  - `SnapshotSyncService` V1 实现——包装包内 `CloudSyncManager<LedgerSnapshot>`。`_path(ledgerId)` 返回 `users/<userId>/ledgers/<ledgerId>.json`（Supabase RLS 依赖此约定；其他 backend 用 deviceId 替代 userId）。`download` 后校验 `snapshot.ledger.id == ledgerId` 防止恢复别人的备份。`deleteRemote` catch `CloudStorageException` 视为幂等成功。

- `lib/features/sync/snapshot_serializer.dart`（新建）：
  - `LedgerSnapshot` 不可变数据类（`version: 1`）：`ledger / categories / accounts / transactions / budgets` + `exportedAt / deviceId`。`fromJson` 校验版本号大于 `kVersion` 抛 `FormatException`。
  - `LedgerSnapshotSerializer implements DataSerializer<LedgerSnapshot>`：`serialize` = `jsonEncode`、`deserialize` = `jsonDecode`、`fingerprint` = `sha256(utf8(data))`。
  - `exportLedgerSnapshot(...)` 顶层函数：从 5 个仓库拉**活跃**实体（不含已软删）→ 组装 snapshot。**不**读 sync_op / fx_rate / user_pref。
  - `importLedgerSnapshot(...)` 顶层函数：单事务内 → ① `delete .. where ledger_id = ?` 物理清空当前账本的 transactions / budgets（含已软删）→ ② `db.batch + InsertMode.insertOrReplace` 写 ledger / categories / accounts / transactions / budgets。**故意绕过 repository 层 save**——避免 import 触发 sync_op 队列累积，形成"刚下载的数据立刻又被排队上传"循环。categories / accounts 是全局资源，只 upsert 不 delete（避免破坏其他账本依赖）。

- `lib/features/sync/sync_provider.dart`（重写）：
  - 全部用普通 `Provider` / `FutureProvider`（不走 `@riverpod` 代码生成）。链式：`cloudServiceStoreProvider` → `activeCloudConfigProvider` → 3 个 backend 配置 provider（UI 配置对话框预填用）→ `cloudProviderInstanceProvider`（实例化具体 backend；初始化失败返回 null 让上层走 LocalOnly 兜底；`ref.onDispose` 清理连接）→ `authServiceProvider`（无云服务时 `NoopAuthService`）→ `syncServiceProvider`（组合 5 个 repository + DB + deviceId 构造 SnapshotSyncService）。
  - 切换激活后端 / 保存配置后调 `ref.invalidate(activeCloudConfigProvider)` 即可下游链式重建。

- `lib/features/sync/cloud_service_page.dart`（修改）：去掉旧的 `hide SyncStatus`、新增 `_SyncStatusCard`：
  - 顶部 `_SyncStatusCard`（仅 active != local 时显示）：watch `currentLedgerIdProvider` + `syncServiceProvider` → `_SyncStatusBody`：标题行（后端名 + obfuscated URL + 刷新按钮）+ 状态行 `_StatusLine`（彩色圆点 + 文字 + 上次同步时间 + 本地/云端流水数 + 错误文案）+ 操作行（上传 FilledButton / 下载 OutlinedButton 二次确认 / 删除云端 IconButton 二次确认）。`_busy` 状态守门防双击；操作后 `clearCache + _refresh(force: true)`。
  - 4 个后端选择卡（iCloud 仅 iOS / WebDAV / S3 / Supabase）保留旧版逻辑，`_saveConfig` 修复为用 `CloudServiceConfig` 主构造（之前调用不存在的 `.supabase()` / `.webdav()` / `.s3()` named constructors）。

- `pubspec.yaml`：新增 `crypto: ^3.0.3`（用于 SHA256 指纹）。

**重要决策**：

1. **同步语义采用快照模型而非 implementation-plan §10.2 的 sync_op 增量队列**——与"蜜蜂记账云同步方案.md"一致。理由：① 实现简单可靠（无需冲突合并器）；② 与 BeeCount 用户预期一致；③ 单设备主力 + 备份恢复场景足够。多设备双向增量同步留给 V2，届时切换为队列模型时本接口（`SyncService`）保持稳定。
2. **不动 schema**：云配置由 `flutter_cloud_sync` 包通过 `SharedPreferences` 持久化（包内设计）。代价：配置在 Android 是明文 XML、iOS 是 NSUserDefaults plist——Phase 11 字段级加密时再迁移到 SQLCipher 加密的 user_pref 表（届时 schema 升一版）。
3. **后端覆盖 4 种**：iCloud（仅 iOS）/ WebDAV / S3 / Supabase。**故意不开启 BeeCount Cloud**——它是 BeeCount 内部服务，本项目用户用不到。

**验证**

- `flutter analyze` → 主项目 lib/ 零 errors 零 warnings。`packages/` 子包内有 63 个 info/warning（avoid_print / use_super_parameters / override_on_non_overriding_member 等 BeeCount 上游代码风格问题），不影响功能。
- `flutter test` → 360/360 通过——所有 Phase 0-9 的既有测试继续全绿；本步未新增同步层测试（手动验收为主，单元测试留给后续 step）。
- `dart run build_runner build` → **不**需要跑——`sync_provider.dart` 不用 `@riverpod` 代码生成；其他文件没动 `@riverpod` 注解。
- 用户本机 `flutter run` 待手工验证：
  1. 「我的 → 云服务」可见 4 个后端卡片（iOS 才有 iCloud），active 默认是 local，状态卡不显示。
  2. 配置任一非 iCloud 后端 → 切换激活 → 状态卡显示。点上传 → SnackBar "已上传到云端"。点刷新 → 状态变 "已同步"。再次记一笔后点刷新 → 状态变 "本地较新（建议上传）"。
  3. 在另一台设备配同样的后端 → 点下载 → 二次确认 → SnackBar "已恢复 N 条流水" → 切到记账页能看到从云端来的流水。
  4. 断网 → 点上传 → SnackBar "操作失败：..." → 状态卡显示错误，本地数据不受影响。
  5. 点删除云端 → 二次确认 → SnackBar "云端备份已删除" → 状态变 "云端无备份"。

**给后续开发者的备忘**

- **沙盒污染保护**：本步保留了被前一轮 agent 误删的 `lib/data/local/providers.g.dart` 与 `lib/data/repository/providers.g.dart`——这些是 `riverpod_generator` 产物，绝**不能**手动删！它们包含 `appDatabaseProvider / deviceIdProvider / defaultSeedProvider / currentLedgerIdProvider / 5 个 xxxRepositoryProvider` 共 9 个 provider，被项目几乎每个 feature 引用。如果未来确实需要重生成，应跑 `dart run build_runner build --delete-conflicting-outputs` 让生成器重新产出（前提是源文件 `providers.dart` 仍带 `@riverpod` 注解 + `part 'providers.g.dart'`）。
- **`SyncService` 接口的稳定性**：本接口刻意只用 `String ledgerId`，不暴露 `LedgerSnapshot` / `CloudProvider` / `CloudSyncManager` 等内部类型。V2 切换为增量队列模型时，`SnapshotSyncService` 替换为 `IncrementalSyncService`，UI 不需要改一行（仍然是 `upload / download / getStatus / deleteRemote / clearCache` 5 个方法）。
- **`importLedgerSnapshot` 的「绕过 repository」决策**：直接调 `db.batch + insertOrReplace` 而非 `repository.save`，因为 `repository.save` 会写 sync_op 队列，导致下次同步把刚下载的数据又上传回去（无限循环）。如果 V2 真要走增量队列，import 应该用专门的 `saveFromRemote(...)` 路径——保留远端 `updated_at / device_id / deletedAt`，不入队 sync_op，但通过 `LWW + device_id tiebreak` 解决冲突。
- **categories / accounts 是全局资源，import 时只 upsert 不删**：避免破坏其他账本的依赖。代价：如果用户在 A 设备删了一个 category 然后从 B 设备恢复，A 设备会把 category 找回来——这是设计上的简化。完整正确的做法是「按 ledgerId 范围分隔 categories」，但这与当前数据模型矛盾（categories 没有 ledger_id）。Phase 12 垃圾桶 + Phase 11 同步密码场景再决定。
- **路径 `users/<userId>/ledgers/<ledgerId>.json` 是统一约定**：Supabase RLS 依赖 `(storage.foldername)[2] = auth.uid()`，所以 userId 必须等于 Supabase 的 auth.uid()。其他 backend（WebDAV/iCloud/S3）的 userId 退化为 `deviceId`——相当于在用户根目录下又加了 `users/<deviceId>/` 前缀，无害。如果用户跨 backend 迁移，路径不兼容（deviceId vs Supabase userId 不同），需要重新上传。
- **`crypto: ^3.0.3` 依赖**：用于 `LedgerSnapshotSerializer.fingerprint` 的 SHA256。本项目其他地方未用——如果 `LedgerSnapshotSerializer` 被废弃，可一并删 `crypto` 依赖。
- **本步完成 Step 10.1 + 10.2**。Step 10.3-10.6 各 backend 实现已经在 `packages/flutter_cloud_sync_*` 子包内提供，本项目层不需要单独实施。Step 10.7 触发时机暂未实施（当前仅手动触发），待用户验证后续要不要接入 App 启动 / 前台恢复 / 记账后防抖 / 下拉刷新 / 定时器。

### ✅ Step 10.7 同步触发与 UI 状态（2026-05-03）

**改动**

新增 2 个文件 + 修改 4 个文件 + 更新 2 个测试：

- `lib/features/sync/sync_trigger.dart`（新建）：
  - `SyncTrigger extends Notifier<SyncTriggerState>`——把"5 个触发源"统一在同一个调度器下。`build()` 注册 `ref.onDispose` 取消所有内部计时器。
  - 三大不变量：① `_running` 标记拦截重复触发（前一次未完成则返回 `SyncTriggerOutcome.skipped`）；② `LocalOnlySyncService` 实例直接返回 `notConfigured`，不抛异常；③ `_isNetworkError` 把 `SocketException` / `Failed host lookup` / `connection refused` / `connection reset` / `connection closed` / `HandshakeException` / `TimeoutException` / `Network is unreachable` / `No address associated` 共 9 类异常归一化为 `networkUnavailable`（小写文本子串匹配）。
  - 公开方法：`trigger()` 主入口（fire-and-forget 安全，所有异常被外层 try/catch 兜住，含 `MissingPluginException`）；`scheduleDebounced({delay = 5s})` 重置式防抖；`startPeriodic({interval = 15min})` / `stopPeriodic()` 由生命周期管控；`cancelTimers()` 显式清理（`BianBianApp.dispose` 调用）。
  - `SyncTriggerState`：`isRunning` / `isConfigured` / `lastSyncedAt` / `lastError` 4 字段；`copyWith` 支持 `clearError` / `clearLastSyncedAt` 显式清空（避免 `??` 语义把 `null` 当成"不改"）。
  - `SyncTriggerClock` typedef 注入测试。`syncTriggerProvider = NotifierProvider<SyncTrigger, SyncTriggerState>(() => SyncTrigger())`——注意 `Notifier.new` tear-off 不能直接用（`SyncTrigger({SyncTriggerClock? clock})` 的可选命名参数与 `Notifier Function()` 签名不兼容），改为 lambda。

- `lib/app/app.dart`（重写）：`BianBianApp` 由 `StatelessWidget` 升级为 `ConsumerStatefulWidget` + `WidgetsBindingObserver`。
  - `initState`：`addPostFrameCallback` 后读 `syncTriggerProvider.notifier`，`unawaited(trigger.trigger())` + `trigger.startPeriodic()`。延迟到首帧避免 Riverpod 警告 "watched a provider before init"。
  - `didChangeAppLifecycleState`：`resumed` → trigger + startPeriodic；`paused/detached/hidden` → stopPeriodic；`inactive`（来电覆盖等短暂态）不动定时器。
  - `dispose`：`removeObserver` + `cancelTimers`（带 `// ignore: avoid_ref_inside_state_dispose`，因为 INFO 级 lint 但仍是合理路径）。
  - 新增 `enableSyncLifecycle = true` 构造参数：测试传 `false` 跳过整套生命周期，避免 `syncServiceProvider` 链触达 `SharedPreferences` 抛 `MissingPluginException`，以及悬挂的 `Timer.periodic` 让 `tester.pumpAndSettle()` 报"Timer still pending"。

- `lib/features/record/record_new_providers.dart`（修改）：`save()` 末尾追加 `ref.read(syncTriggerProvider.notifier).scheduleDebounced()`。`// ignore: avoid_manual_providers_as_generated_provider_dependency`——`syncTriggerProvider` 是 `NotifierProvider`（非 `@riverpod` 生成），custom_lint 报 INFO，业务路径合理保留。

- `lib/features/record/record_home_page.dart`（修改）：
  - 新增 `_SyncStatusBadge`（ConsumerWidget）：watch `syncTriggerProvider` → 仅当 `isConfigured` 为真时渲染。4 态 icon + tooltip：① running → 14×14 `CircularProgressIndicator(strokeWidth: 2, tertiary)`；② lastError != null → `cloud_off_outlined` + error 色 + tooltip 含错误消息；③ lastSyncedAt != null → `cloud_done_outlined` + tertiary 色 + 旁边小字 `_formatRelative(t)`（"刚刚 / N 分钟前 / N 小时前 / N 天前 / MM-dd HH:mm"）；④ 其余 → `cloud_outlined` 暗色"尚未同步"。点击 `context.push('/sync')`。`_TopBar` Row 中插入位置：`Spacer()` 之后、`Icons.swap_horiz`（转账按钮）之前。
  - `_TransactionListState.build`：空状态与列表态都包 `RefreshIndicator(onRefresh: _onPullToRefresh)`。空状态用 `ListView` + `AlwaysScrollableScrollPhysics` + `SizedBox(height: screenH*0.5, child: Center(...))`，让无数据时也能下拉。列表态 `SingleChildScrollView` 加 `physics: AlwaysScrollableScrollPhysics()` 触发短列表也能拉。
  - `_onPullToRefresh`：`ref.read(syncTriggerProvider.notifier).trigger()` → switch 5 种 outcome 显示 SnackBar：`success` "已同步"；`networkUnavailable` "网络不可用"；`failure` "同步失败：$msg"；`skipped` 与 `notConfigured` 静默退出（前一次还在跑 / 本地模式下不打扰）。

- `test/features/sync/sync_trigger_test.dart`（新建）：8 用例。
  - `未配置云服务时返回 notConfigured`（注入 `LocalOnlySyncService`）。
  - `成功路径：upload + clearCache 被调用，state 写入 lastSyncedAt`（注入固定 clock、断言 `_FakeSyncService.uploadedLedgerIds` 与 `clearCacheCalls`）。
  - `SocketException 归类为 networkUnavailable`（断言 `SyncTriggerResult.message == '网络不可用'` 且 state.lastError 同步）。
  - `TimeoutException 归类为 networkUnavailable`（覆盖文本子串匹配路径，与 SocketException 不同分支）。
  - `普通 Exception 归类为 failure`（401 unauthorized 文本透传）。
  - `前一次未完成时第二次调用直接返回 skipped`（用 `Completer<void>` 阻塞第一次的 upload，第二次在同一 microtask 内调度即被 `_running` 拦截）。
  - `防抖窗口内重复调度只触发一次 upload`（200ms / 800ms / 400ms / 50ms 真实 Timer 顺序，验证第一个 timer 被第二次 schedule 重置后不触发；总 1450ms）。
  - `cancelTimers 取消未触发的防抖任务`。

- `test/widget_test.dart` / `test/features/record/quick_input_bar_test.dart`：所有 `BianBianApp()` 改为 `BianBianApp(enableSyncLifecycle: false)`（共 9 处）。

**验证**

- `flutter analyze` → 主项目零 errors 零 warnings。
- `flutter test` → **368/368** 通过（前 360 + 新增 8 SyncTrigger 用例）。
- `dart run custom_lint` → 8 issues 全部为 Step 10.7 之前已存在的 INFO（`avoid_public_notifier_properties` × 4 / `scoped_providers_should_specify_dependencies` × 4），新代码零新增 issue。
- 用户本机 `flutter run` 待手工验证：
  1. 未配置云服务时，首页顶栏状态徽标隐藏（`isConfigured == false`）。
  2. 配置 + 切换激活后端 → 首页顶栏出现状态徽标。冷启动后 5s 内自动 upload 一次（startup trigger），徽标变 `cloud_done_outlined` + "刚刚"。
  3. 记一笔 → 5 秒后自动 upload；徽标短暂转圈 → 变 `cloud_done_outlined`。连续记多笔只触发最后一次。
  4. 下拉首页流水列表 → 立即触发 upload。成功 SnackBar "已同步"。
  5. 飞行模式下下拉 → SnackBar "网络不可用"，徽标变 `cloud_off_outlined`。
  6. App 切到后台再切回前台 → 触发一次 upload（前台恢复）。
  7. App 在前台保留超过 15 分钟 → 自动触发一次 upload；切到后台 15 分钟后回到前台不会重复触发（_running 拦截 + paused 时已 stopPeriodic）。
  8. 同步进行中再次手动下拉 → 立即返回（skipped），无 SnackBar。

**给后续开发者的备忘**

- **`enableSyncLifecycle` 是测试逃生口**：所有现存 widget 测试都跳过同步生命周期（`BianBianApp(enableSyncLifecycle: false)`）。新增的 widget 测试若 pump `BianBianApp` 必须显式传 `false`，否则会触发 `MissingPluginException`（`SharedPreferences` 未 mock）→ 虽然内部 try/catch 吞掉异常，但悬挂的 `Timer.periodic(15min)` 让 `pumpAndSettle()` 报 "Timer still pending"。直接在 `BianBianApp` 里加 try/catch 会掩盖真实 bug——逃生口比"防御式编程"更明确。
- **`syncTriggerProvider` 是 `NotifierProvider`**——故意没走 `@riverpod` 生成器。理由：① `sync_provider.dart` 已经维持手写 `Provider` / `FutureProvider` 风格（与 `flutter_cloud_sync` 包对外类型耦合，写生成器反而更绕）；② 测试 override 用 `() => SyncTrigger(clock: ...)` 比生成版本更直观。代价：`record_new_providers.save` 里 `ref.read(syncTriggerProvider.notifier)` 会触发 `avoid_manual_providers_as_generated_provider_dependency` INFO——单点 `// ignore` 即可。
- **网络错误识别是文本子串匹配，不是异常类型 isInstance**：跨 backend 各包（supabase / webdav / s3 / icloud）抛的网络异常类型不同，`Storage` 子类异常 message 中包含 SocketException 或 timeout 的可能性高。子串匹配是覆盖最广的路径——但代价是 false positive（比如服务端 message 里恰好包含 "timeout" 字样）。Phase 11 之后如果做"重试与退避"逻辑，可能需要更精细的分类。
- **防抖延迟 5 秒**是 `scheduleDebounced` 的默认值（`Duration(seconds: 5)`），与 implementation-plan §10.7 的 "保存流水后 5 秒" 一致。如果产品后续要求更短/更长，调用方可显式传 `delay`。Step 12.2 永久删除流水时也应该走防抖路径——届时直接复用 `scheduleDebounced()`。
- **15 分钟定时器只在 resumed 状态下运行**：`startPeriodic` 由 `initState` 与 `didChangeAppLifecycleState(resumed)` 调用，`stopPeriodic` 由 `paused/detached/hidden` 调用。`inactive` 是短暂态（如 iOS 来电、Android 通知中心下拉），故意不停，避免反复 start/stop 抖动。
- **状态徽标的 4 态优先级**：running > error > synced > unsynced。`running` 通过 `state.isRunning`（trigger 入口写 true、出口写 false）驱动；`error` 通过 `lastError` 非空；`synced` 通过 `lastSyncedAt` 非空。一次失败后，下一次成功会清掉 `lastError` → 徽标恢复绿色。如果用户希望"曾经失败过的红圈持续到下次手动确认"，需要在 SyncTrigger 加 acknowledgedError 状态——目前 V1 不做。
- **`_formatRelative` 不依赖时区**：返回 "刚刚 / N 分钟前 / N 小时前 / N 天前 / MM-dd HH:mm"。`MM-dd HH:mm` 用 local 时间（通过 `DateFormat`），与 cloud_service_page 的 `yyyy-MM-dd HH:mm` 长格式互补——首页要求紧凑，云服务页要求精准。
- **下拉刷新只触发 upload，不触发 download**：implementation-plan §10.7 验收标准是"刷新显示网络不可用 / 同步中… / 状态更新"，没指定 download。当前设计：upload 成功即"已同步"，download 留给云服务页的"下载"按钮（避免用户误把下拉当作"双向同步"）。如果 V2 要做增量同步，再改 SyncTrigger.trigger() 的内部逻辑。
- **本步完成 Step 10.7，也完成 Phase 10 全部步骤**。Phase 11（字段级加密 + 同步码）会在 SyncService 上层做"上传前加密、下载后解密"——届时 `SnapshotSyncService.upload/downloadAndRestore` 内部增加加解密包装层，`SyncTrigger` 接口完全不动。Step 11.4 同步码导入会触发一次 force-download（绕过 SyncTrigger，直接调 `SnapshotSyncService.downloadAndRestore`），调用前应 `cancelTimers()` 避免与定期 timer 抢锁。


## Phase 12 · Step 12.1 + 12.2 + 12.3 一并完成（2026-05-03）

> **范围说明**：用户主动指示"跳过 Phase 11，开始实施 Phase 12"。本轮一并落地了 §12.1（垃圾桶列表）、§12.2（恢复/永久删除/一键清空）、§12.3（启动定时清理）。implementation-plan §12.2 描述的"入 sync_op delete 操作以告知云端硬删"在 V1 快照模型下退化为：永久删除 → `scheduleDebounced` → 下次 upload 整体覆盖云端快照——不写 sync_op，避免与现有快照引擎语义重复。

**改动**

DAO 层（5 个 DAO）：5 个 DAO 各加 `listDeleted()`（按 `deleted_at` 倒序）/ `listExpired(cutoffMs)`（GC 用）/ `restoreById(id, updatedAt)`（置 `deleted_at = null` + 刷新 `updated_at`）。

Repository 层（5 个仓库）：
- 4 个无级联仓库（Transaction / Category / Account / Budget）：接口扩 5 方法 `listDeleted` / `restoreById` / `purgeById` / `purgeAllDeleted` / `listExpired`。`purgeById` 调 DAO `hardDeleteById`，**不**入队 `sync_op`（V1 快照模型整体覆盖云端，不需要 delete op）。`purgeAllDeleted` 一条 `delete .. where deleted_at IS NOT NULL` 批量物理删。
- `LedgerRepository` 同 5 方法 + **级联恢复**：`restoreById` 在 transaction 内先 update `transaction_entry` / `budget`（按 `ledger_id == id AND deleted_at == ledger.deletedAt` 精确匹配同时间戳级联软删的子项）→ 再 `restoreById` 账本本身。**级联硬删**：`purgeById` 在 transaction 内 `delete .. where ledger_id == id` 物理移除该账本下所有流水/预算（含活跃 + 软删）→ 再 `hardDeleteById` 账本。**关键不变量**：恢复时不会误恢复用户单独软删的流水（其 `deletedAt` 与账本的不同）。

测试层 fake repos 同步扩展（widget_test / quick_confirm_sheet_test / quick_input_bar_test / record_new_page_test / record_new_providers_test）：每个 `_FakeXxxRepository` 加 5 个 stub（默认 `fail`，不消费这些方法的测试不受影响）。

新文件（lib/features/trash/）：
- **`trash_attachment_cleaner.dart`**：`TrashAttachmentCleaner` + `DocumentsDirProvider` typedef。`deleteForTransaction(txId)` 递归删除 `<documents>/attachments/<txId>/` 整目录；批量版本 `deleteForTransactions(ids)` 返回成功数。生产路径走 `getApplicationDocumentsDirectory`，测试注入临时目录。删除失败（权限/占用）静默吞掉，下次 GC 重试。`trashAttachmentCleanerProvider` 是 `Provider`（无状态单例）。
- **`trash_providers.dart`**：常量 `kTrashRetention = Duration(days: 30)`；纯函数 `trashDaysLeft({deletedAt, now, retention})` 返回向上取整的剩余天数（≤0 表示已过期，UI 不显示）；4 个 `FutureProvider.autoDispose` 列出软删项（`trashedTransactionsProvider` / `trashedCategoriesProvider` / `trashedAccountsProvider` / `trashedLedgersProvider`）+ 1 个隐藏的 `trashedBudgetsProvider`（UI 不暴露但 GC 用到）；`invalidateTrashFromWidgetRef(ref)` 一次性 invalidate 全部 5 个。
- **`trash_gc_service.dart`**：`TrashGcService.gcExpired({now})` 端到端清理：① 流水（先 cleaner.deleteForTransaction → 再 repo.purgeById）；② 预算（不暴露但仍清）；③ 分类；④ 账户；⑤ 账本（`purgeById` 自身级联硬删该账本下流水/预算）。返回 `TrashGcReport(transactions, attachmentsRemoved, categories, accounts, ledgers)`。`trashGcServiceProvider` 是 `FutureProvider`，`main.dart` bootstrap 链 fire-and-forget 触发，失败静默。
- **`trash_page.dart`**：`TrashPage`（ConsumerStatefulWidget）+ `TabController` 4 Tab：流水 / 分类 / 账户 / 账本。每个 Tab body：`FutureProvider.when` 三态 + 列表项 `_TrashRow`（左 emoji + 中标题/副标题/「剩余 X 天 · 删于 MM-dd HH:mm」+ 右 IconButton 恢复 + IconButton 永久删除）。AppBar 右侧 `IconButton(Icons.delete_sweep_outlined)` 触发"清空当前 Tab 类型"二次确认。所有永久删除走 `_confirmPurge(outerContext)` 二次确认（用 `dialogContext` 不用闭包外 context，沿用 Step 9.2 hotfix 的教训）。账本 Tab 的"永久删除"：先收集该账本下全部活跃 + 软删流水 id → `cleaner.deleteForTransactions` → 再 `ledgerRepo.purgeById`。完成后调 `_invalidateDownstream(ref)` 刷新 trash + recordMonthSummary + ledgerTxCounts + activeBudgets + accountsList + accountBalances + totalAssets + 4 个 stats provider + `syncTrigger.scheduleDebounced()`。

入口与路由：
- `lib/app/app_router.dart`：新增 `GoRoute('/trash')` → `TrashPage`。
- `lib/app/home_shell.dart`：`_MeTab` 新增 ListTile（`Icons.delete_outline` "垃圾桶"）→ `context.push('/trash')`。

启动钩子：
- `lib/main.dart`：bootstrap `await defaultSeedProvider.future` 之后追加 fire-and-forget `container.read(trashGcServiceProvider.future).then((s) => s.gcExpired(now: DateTime.now()))`，报告非空时 invalidate 5 个 trash provider。失败静默——不影响首帧。

**测试**

- `test/data/repository/trash_repository_test.dart`（新建，10 用例）：
  - **TransactionRepository × 5**：listDeleted 倒序 / restoreById 清 deleted_at + 刷新 updated_at / restoreById 不存在静默（用 `expectLater(future, completes)` 而非 `returnsNormally`——避免 future 在 tearDown 后才触达已关闭 db）/ purgeById 物理删 / purgeAllDeleted 不影响活跃 / listExpired cutoff 边界。
  - **Category / Account 各 1 条**：覆盖 restoreById + purgeById 基础路径。
  - **LedgerRepository × 2**：① **级联恢复**——A 单独软删 tx-l1-a 在 t=5000、然后级联软删账本 L1（含 tx-l1-b）在 t=10000 → 恢复 L1 → tx-l1-b 复活、tx-l1-a 仍在垃圾桶（精准时间戳匹配生效）。② **级联硬删**——`purgeById('L1')` 后 L1 下所有流水（活跃 + 软删）物理消失，L2 下流水不动。
- `test/features/trash/trash_attachment_cleaner_test.dart`（新建，4 用例）：目录不存在返回 false 幂等 / 空 txId 不操作 / 递归删除 `<docs>/attachments/<txId>/` 整目录 + 内含文件 / 批量返回成功数。临时目录走 `Directory.systemTemp.createTemp` + tearDown 清理。
- `test/features/trash/trash_providers_test.dart`（新建，7 用例）：`trashDaysLeft` 纯函数边界——刚删 30 / 1 天前 29 / 29 天 23 小时仍 1（向上取整）/ 满 30 天 = 0 / 超期 = 0 / 自定义 retention=7 / 未来 deletedAt 异常输入。
- `test/features/trash/trash_gc_service_test.dart`（新建，5 用例）：① 空 DB → report.isEmpty；② 31 天前软删的流水被硬删 + 附件目录被清，13 天前的不动；③ cutoff 在分类/账户/账本各类生效；④ 活跃项绝不被 GC 触碰；⑤ 自定义 retention=7 天 → 8 天前软删被清。fake `_RecordingCleaner implements TrashAttachmentCleaner` 记录 deletedTxIds 但不真实操作 fs。

**验证**

- `flutter analyze` → No issues found。
- `flutter test` → **394/394** 通过（前 368 + 10 trash repo + 4 attachment cleaner + 7 providers + 5 gc service = 394）。
- `dart run build_runner build` → 不需要跑：DAO 加普通方法不改 g.dart；新增的 trash provider 走手写 `Provider` / `FutureProvider`，不用 `@riverpod`。
- 用户本机 `flutter run` 待手工验证：
  1. 首页"我的"Tab 底部多出"垃圾桶"入口，点击进入 `/trash`。
  2. 流水 Tab：先在记账页删一笔流水（左滑或详情页"删除"）→ 进垃圾桶 → 看到该流水带剩余 30 天徽标 + 恢复 + 永久删除按钮。点"恢复"→ SnackBar"已恢复 1 条流水"+ 流水 Tab 列表减一 + 切回首页能看到该流水回来。
  3. 永久删除：选一条流水点"永久删除"→ 二次确认对话框 → 确认 → SnackBar"已永久删除"+ 流水 Tab 列表减一 + DB 直查无该 id 行。带附件的流水的附件目录也被清理。
  4. 账本 Tab：删一个账本 → 进入垃圾桶账本 Tab → 看到该账本 + 副标题"账本 · 恢复时会一并复活级联删除的流水/预算"。点"恢复"→ 该账本回来，且原账本下流水也回来（同时间戳级联恢复）。点"永久删除"→ 二次确认强提示"该账本下所有流水和预算也会一并永久删除（无法恢复）"→ 确认 → 账本 + 其下流水/预算 + 附件全部物理删除。
  5. 一键清空：AppBar 右侧 `Icons.delete_sweep_outlined` → 二次确认对话框 → 确认 → SnackBar"已清空「<Tab 名>」垃圾桶"+ 该 Tab 列表清空。
  6. 启动 GC：把测试设备日期前调 31 天，删一笔流水 → 把日期调回 → 重启 App → 该流水自动消失（GC 已清）+ 附件目录也消失。
  7. 剩余天数 ≤ 0 的项不再显示（即便仍在 DB 等下次 GC）。

**给后续开发者的备忘**

- **快照模型下不写 sync_op delete**：implementation-plan §12.2 原文是"永久删除 ... 入 sync_op 的 delete 操作以告知云端硬删"——这是为 V2 增量同步队列模型写的。V1 是快照模型（整体覆盖云端 JSON），永久删除后的下一次 upload 会自然把该项从云端移除。所以 `purgeById` / `purgeAllDeleted` 都**不**写 `sync_op`，只在收尾调 `syncTrigger.scheduleDebounced()` 排队下一次 upload。如果未来切换到增量队列模型，这里要补 `_syncOp.enqueue(op: 'delete', ...)`。
- **级联恢复的"同时间戳"约定**：`LedgerRepository.softDeleteById` 在 transaction 内用同一个 `nowMs` 写账本 + 流水 + 预算的 `deleted_at`。`restoreById` 反向匹配 `deleted_at == ledger.deletedAt` 精准复活级联软删项。用户在账本被软删之**前**或之**后**单独软删的流水/预算，其 `deleted_at` 与账本不同，**不**会被误恢复。这个不变量被 `test/data/repository/trash_repository_test.dart::级联恢复` 守护——如果将来改 `LedgerRepository.softDeleteById` 的实现（例如把级联子项的 deleted_at 拉早 1ms 以避免冲突），必须同步改 `restoreById` 的匹配条件，并更新该测试。
- **附件清理先于 DB 硬删**：`<documents>/attachments/<txId>/` 目录的删除依赖 `txId`，DB 行硬删后无法再查到 ledgerId 之类映射；但目录路径只用 txId 即可定位，所以无关。关键约束是**调用顺序**：cleaner.deleteForTransaction → repo.purgeById。GC 与 UI 永久删除路径都遵守这个顺序。
- **`Value(null)` 写空 vs `Value.absent()` 不动**：`Value(null)` 在 drift 中 = 显式写 NULL；`Value.absent()` = 不动该列。`restoreById` 走 `Value(null)` 把 `deleted_at` 真的清空。
- **`expectLater(..., completes)` vs `expect(() => ..., returnsNormally)`**：前者会 await future 完成；后者只看"调用瞬间是否抛"。涉及数据库 transaction 的 fire-and-forget 路径必须用前者，否则 tearDown 关 db 后台 transaction 撞墙报"This database has already been closed"。本步在 `restoreById 不存在静默` 用例中踩过这个坑。
- **`autoDispose` 用在 trash provider 上**：用户离开垃圾桶页后立即释放，节省内存——垃圾桶不是常驻视图，不需要 keepAlive。`invalidateTrashFromWidgetRef` 在恢复/永久删除/清空之后调用，强制刷新——autoDispose 不影响 invalidate 行为。
- **"清理任务也要同步到云端"**：implementation-plan §12.3 提到这点。V1 通过 `scheduleDebounced` 在 GC 完成时排队一次 upload；但 main.dart bootstrap 阶段的 GC 调用**没有**触发同步——理由是同步 trigger 还没初始化（`SyncTrigger` 由 `BianBianApp.initState` 启动），且首帧 fire-and-forget 太早调 `syncTriggerProvider` 可能踩 lifecycle 时序坑。V1 接受这个轻微不一致：冷启动 GC 后下一次用户操作（例如记账保存）会触发同步，把云端拉回最新。如果未来要求更强一致，需要在 `BianBianApp.initState` 后再补一次 GC + 显式 upload。

---

### ✅ Step 3.6 首页流水搜索（2026-05-03 · 补回 Phase 3 漏项）

**改动**

- `lib/features/record/record_search_filters.dart`（新建）：
  - `SearchTypeFilter` 枚举：`all / expense / income / transfer`，对齐 `TransactionEntry.type` 的取值。
  - `SearchQuery`（不可变 + `copyWith` + `clearXxx` 标志位 + `isEmpty`）：关键词、起止日期、类型、金额上下限。所有维度可选，未填即不约束。`copyWith` 故意保留 `clearStartDate / clearEndDate / clearMinAmount / clearMaxAmount` 而不用单参数 `null` 表达"清空"——后者会与"保持不变"语义冲突。
  - `searchTransactions(...)` 纯函数：关键词同时匹配备注（`tx.tags`）、分类名、账户名（含转账 `toAccountId`）。日期闭区间（按日比较），金额按绝对值闭区间，类型按取值精确匹配。所有维度取交集（AND）。`SearchQuery.isEmpty == true` 时直接返回空列表——避免一打开页面就把整本账本砸到屏幕。

- `lib/features/record/record_search_page.dart`（新建）：
  - `RecordSearchPage` ConsumerStatefulWidget：顶部关键词 TextField（autofocus，suffixIcon 清空按钮）+ `ExpansionTile` 包裹 3 段筛选（日期范围 OutlinedButton.icon → `showDateRangePicker`、类型 SegmentedButton 4 段、金额 上限/下限两个数字 TextField）+ AppBar 右侧 `Icons.refresh` 一键重置。
  - 筛选条件 `setState` 改 `_query`，`_ResultsView` 子组件接收 query + 4 个 provider AsyncValue，内部 `FutureBuilder<_SearchData>` 拉取 `txRepo.listActiveByLedger(ledgerId) / catRepo.listActiveAll() / accRepo.listActive()`，过滤后按 `occurredAt` 倒序展示。
  - 结果项 ListTile：左侧分类 emoji 圆形头像（着色等同 `_TxTile`），中间分类名 + `日期 · 账户名 · 备注` 副标题，右侧金额（带符号 + 颜色：支出红 / 收入绿 / 转账蓝）。
  - 三态空态：① 空查询 → "输入关键词或筛选条件后开始搜索"；② 命中 0 条 → "没有找到相关流水"；③ 加载中 → CircularProgressIndicator。

- `lib/app/app_router.dart`：新增 `GoRoute('/record/search')` → `RecordSearchPage`。
- `lib/features/record/record_home_page.dart`：`_TopBar` 中搜索图标 `onPressed` 由占位改为 `context.push('/record/search')`。

**测试**

- `test/features/record/record_search_filters_test.dart`（新建，11 用例）：
  - 空查询返回空列表；
  - 关键词匹配备注（"和同事的午餐" 命中"午餐"）；
  - 关键词匹配分类名（"餐饮"）；
  - 关键词匹配账户名（"工商" 同时命中 `accountId` 与 `toAccountId`）；
  - 大小写不敏感（"coffee" 命中 "Coffee"）；
  - 日期范围闭区间（含起止两端，跨天 23:59:59 边界）；
  - 类型筛选仅支出；
  - 金额范围 100-200 命中 [100, 200] 闭区间；
  - 多维度交集（关键词 + 类型 + 金额 + 日期 4 维同时约束，仅 1 条 hit）；
  - `SearchQuery.copyWith(clearMinAmount: true, clearMaxAmount: true)` 真的清空；
  - `SearchQuery.isEmpty` 边界（空白关键词、默认 type 都视为空）。

- `test/features/record/record_search_page_test.dart`（新建，3 用例）：
  - 空查询展示"输入关键词或筛选条件后开始搜索"提示；
  - 输入"午餐"后命中备注为"和同事的午餐"的流水；
  - 输入不存在的关键词显示"没有找到相关流水"。
  - 三个 fake repo（`_FakeTransactionRepository / _FakeCategoryRepository / _FakeAccountRepository`）实现接口必需方法，未消费的方法 `fail('unexpected')` 防御。

**验证**

- `flutter analyze` → No issues found。
- `flutter test` → 411/411 通过（前 397 + Step 3.6 新增 11 + 3 = 411）。注：实际新增 14（含 Step 3.7 的 3 用例），因两步同批落地。
- 用户本机 `flutter run` 待手工验证：
  1. 首页顶栏点搜索图标 → 进入 `/record/search`，关键词框 autofocus；
  2. 输入"午餐"后立即看到含"午餐"备注 / 含"餐饮"分类名的流水；
  3. 展开"筛选" → 选日期范围 2026-05-01 ~ 2026-05-31 + 类型"支出" + 金额 100-200，结果实时联动；
  4. 输入不存在关键词 → 显示空结果提示；
  5. 点 AppBar 刷新图标 → 重置全部筛选条件，退回空查询提示态。

**给后续开发者的备忘**

- **搜索粒度限定为「当前账本」**：`_loadAndSearch` 通过 `currentLedgerIdProvider` 拿当前账本 id 后只查该账本的流水。如果将来需要「跨账本搜索」，应在查询条件加 `ledgerScope: SearchLedgerScope.current/all`，并在 service 层把 `txRepo.listActiveByLedger(ledgerId)` 改为遍历所有未归档账本聚合。
- **关键词匹配的字段映射**：当前命中 `tx.tags`（drift 列名 = UI "备注"语义）+ 分类名 + 账户名（含 `toAccountId`）。Phase 11 字段级加密落地后，备注字段会迁移到 `noteEncrypted` —— 届时需要在解密后再喂给 `searchTransactions`，过滤逻辑本身不需要改。
- **数据加载没用 Riverpod family provider**：搜索 query 是页面局部 state，做成 `family` 要把 query 哈希成 key，反而复杂。`_ResultsView.FutureBuilder` 直接从 4 个 keepAlive provider 拉数据后内存过滤即可，V1 数据量在内存里完全可接受。如果未来流水量级达到 10k+，再考虑把 SQL 端 `WHERE` 推下去。
- **空查询 `isEmpty` 检查在 `searchTransactions` 与 `_ResultsView.build` 双重保护**：前者保证函数本身有意义不会"匹配全部"，后者保证 UI 显示"开始搜索"提示而非空列表。

---

### ✅ Step 3.7 首页月份选择器优化（2026-05-03 · 补回 Phase 3 漏项）

**改动**

- `lib/features/record/month_picker_dialog.dart`（新建）：
  - `showMonthPicker({context, initialMonth, firstDate?, lastDate?})` 顶层异步函数 → `Future<DateTime?>`。
  - `_MonthPickerDialog` StatefulWidget：标题行 = 上一年箭头 + "YYYY 年" + 下一年箭头；正文 = 4×3 月份网格（`GridView.count(crossAxisCount: 4, childAspectRatio: 1.6)`）；底部 = 取消（返回 null）+ 确定（返回 `DateTime(year, month)`）。
  - `_MonthCell` 着色规则：选中态 `colors.primary` 背景 + `onPrimary` 文字 + `FontWeight.w600`；可选态 `colors.primary.withAlpha(28)` 浅色背景；禁用态（超出 firstDate/lastDate 范围）灰色文字 + 不响应 onTap。
  - 默认 `firstDate = DateTime(2000)` / `lastDate = DateTime(now.year + 5, 12)`，覆盖 V1 用户的全部使用区间；调用方可显式覆盖。

- `lib/features/record/record_home_page.dart` `_MonthBar`：中间月份 `Text` 包裹一层 `InkWell`（key=`record_month_label`，`borderRadius: 8`），点击调 `showMonthPicker(context: context, initialMonth: month)` → 非 null 即 `recordMonthProvider.notifier.jumpTo(picked)`。左右切月箭头不动，旧的"先点 ← 再点 ←"快速回溯仍可用。

**测试**

- `test/features/record/month_picker_dialog_test.dart`（新建，3 用例）：
  - 默认高亮初始月份且确认返回该月份（`initialMonth = 2025-07` → 直接确定 → 返回 `DateTime(2025, 7)`，标题展示"2025 年"）；
  - 左右箭头切换年份后选月，返回选择的年-月（`initialMonth = 2026-05` → 上一年 → 1 月格 → 确定 → 返回 `DateTime(2025, 1)`，标题展示"2025 年"）；
  - 取消按钮返回 null。

**验证**

- `flutter analyze` → No issues found。
- `flutter test` → 411/411 通过（含 Step 3.7 月份选择器 3 个新用例）。
- 用户本机 `flutter run` 待手工验证：
  1. 首页月份"2026年5月"区域可点击，弹出对话框，默认高亮 5 月；
  2. 点上一年箭头 → 标题变 "2025 年" + 5 月仍高亮（保留 `_selectedMonth`，但显示年与选中年不同时不高亮单元格）；
  3. 选 1 月 → 单元格变奶油黄高亮 → 确定 → 首页月份变"2025年1月" + 数据卡片 + 流水列表刷新到 2025/1；
  4. 重新打开选择器 → 默认高亮 1 月（持久化的 `_selectedMonth` 由 `RecordMonthProvider.state` 重新驱动 initialMonth）；
  5. 取消按钮关闭对话框，首页月份保持不变；
  6. 左右箭头快速切月行为不变。

**给后续开发者的备忘**

- **`firstDate / lastDate` 仅按"年-月"粒度比较**：`_isMonthEnabled` 用 `DateTime(year, month)` 与 `DateTime(firstDate.year, firstDate.month)` 比，day/hour 信息丢弃。这意味着 `firstDate = DateTime(2024, 6, 15)` 与 `firstDate = DateTime(2024, 6, 1)` 行为完全相同——2024-06 整月都可选。
- **未引入 `month_picker_dialog` 等第三方包**：原生 widget 拼装即可，避免又多一个依赖。如果未来要做"长按区间选择"等复杂交互再考虑。
- **`showDatePicker(initialDatePickerMode: DatePickerMode.year)` 不适用**：它强迫"先选年再选日"，无法直接停在月粒度，跨年快速跳转体验差。`showDatePicker` 也无法用 `selectableDayPredicate` 实现"只允许某些月"。
- **返回值的 day 固定为 1**：与 `RecordMonth.build`（`DateTime(now.year, now.month)`）的语义对齐；`jumpTo` 内部 `state = DateTime(day.year, day.month)` 收敛任意 day 输入，不会因为偶发的 31 日参数破坏数据。

---

### ✅ Step 3.6 续：搜索结果点击复用流水详情/编辑/复制/删除（2026-05-03）

**改动**

用户验收 Step 3.6 后追问"搜索结果项能否点开详情，并支持复制 / 编辑 / 删除"。本次重构把首页 `_TxTile.onTap` 内的 ~250 行详情底表 + 三动作流程抽成共享 helper，搜索结果与首页流水共享同一份交互。

- `lib/features/record/record_tile_actions.dart`（新建）：
  - `RecordDetailAction` 公开枚举（原 `_DetailAction`）。
  - `RecordDetailSheet` 公开 ConsumerWidget（原 `_RecordDetailSheet`）：渲染流水详情（图标 + 名称 + 金额 + 类型 / 钱包 / 时间 / 备注 + 附件横滑 + 全屏放大查看 + 复制 / 编辑 / 删除三按钮）。
  - `openRecordTileActions({context, ref, tx, category, accountName, toAccountName, parentKey})`：异步 helper，封装"弹详情 → 收 RecordDetailAction → 编辑 / 复制 / 删除"全流程，含二次确认对话框、`preloadFromEntry` 调用、`_showRecordEditSheet` 半屏底表、`softDeleteById` + provider invalidate + 删除 SnackBar。
  - `inferParentKeyForTx(category, tx)`：原 `_TxTile._inferParentKey`，公开化。
  - 私有 `_DetailKV` widget 与 `_confirmDelete`、`_invalidateAfterChange`、`_showRecordEditSheet` helper 收敛在本文件不外泄。

- `lib/features/record/record_home_page.dart`：
  - `_TxTile.onTap` 改为 `await openRecordTileActions(...)` 单行调用——删除内部 switch + 三个 invalidate 块。
  - 删除随之失效的 `_DetailAction` 枚举、`_RecordDetailSheet` 类、`_DetailKV` 类、`dart:convert` / `dart:io` import。
  - `_RecordBottomSheetPage` 简化（参数收窄到无）——只服务于 FAB 新建入口。
  - `formatTxAmountForDetail` 摘掉 `@visibleForTesting` 注解：原本只 home page + 测试可见，搬到 helper 后需要跨 lib/ 文件访问。文档注释说明该原因。

- `lib/features/record/record_search_page.dart`：
  - `_ResultsView` 由 `ConsumerWidget` 升级为 `ConsumerStatefulWidget`，引入 `_refreshTick: int`。`FutureBuilder` 的 key 拼装 query 各字段 + tick——任一变化都会触发重拉。
  - `_ResultTile` 由 `StatelessWidget` 升级为 `ConsumerWidget`，新增 `onChanged: VoidCallback` 必填参数；`onTap` 调 `openRecordTileActions(...)` + 完成后 `onChanged()` 触发父级 `_bumpRefresh()`。结果列表立即反映出删除消失 / 编辑后金额变化。
  - 副标题里加 `toAccName` 反查（之前漏了），转账目标账户在 helper 里展示"转入"行需要它。

**测试**

- `test/features/record/record_search_page_test.dart` 升至 5 用例（前 3 + 新 2）：
  - **新 1：点击搜索结果弹出详情底部表单**——输入"午餐"后 `tester.tap(find.textContaining('和同事的午餐'))` → 详情应展示 `Key('detail_amount')` + "复制" + "编辑" + "删除" 三按钮。
  - **新 2：详情点删除 + 二次确认 → 列表刷新**——升级 `_FakeTransactionRepository` 模拟 DB（`listActiveByLedger` 排除 `softDeletedIds` 集合，`softDeleteById` 写入该集合）。两条匹配流水，点第一条 → "删除" → "删除这条记录？"对话框 → `widgetWithText(TextButton, '删除')` → 验证 `repo.softDeletedIds == ['t1']` + 第一条从列表消失 + 第二条仍在。

**验证**

- `flutter analyze` → No issues found。
- `flutter test` → **413/413** 通过（前 411 + 新 2）。
- 用户本机 `flutter run` 待手工验证：
  1. 首页搜索图标 → 输入关键词 → 命中流水点 tap → 弹出与首页同款的详情底表，可见金额 / 类型 / 钱包 / 时间 / 备注 / 附件；
  2. 点"复制" → 弹出半屏新建表单，金额 / 分类 / 钱包等已预填；改完保存 → 回到搜索页，列表多一条新流水（同关键词新数据被命中）；
  3. 点"编辑" → 弹出半屏编辑表单（编辑模式下保存会更新原条），改金额后保存 → 回到搜索页，原条目金额刷新；
  4. 点"删除" → 二次确认对话框 → 确认 → SnackBar"已删除" + 该条从搜索结果消失，仍可在垃圾桶恢复；
  5. 首页流水 tile 点击行为 100% 不变（同一 helper，回归覆盖）。

**给后续开发者的备忘**

- **搜索页不能靠 `ref.invalidate(recordMonthSummaryProvider)` 来刷新结果**——搜索数据是 `_ResultsView.FutureBuilder` 拉的 page-local future，**不**挂在 Riverpod provider 上。`openRecordTileActions` 内部已经 invalidate 了首页 / 统计 / 预算相关 provider，但搜索页自己的 future 无法被它带动。所以必须在 tile `onTap` 完成后通过 `onChanged` 回调让 `_ResultsView` 主动 `_bumpRefresh()`。如果未来把搜索结果做成 `family` provider（`searchResults(SearchQuery)`），可改成 `ref.invalidate(searchResultsProvider(query))`。
- **`formatTxAmountForDetail` 已不是 `@visibleForTesting`**：现在是 lib/ 内的公开纯函数，`record_home_page.dart` 与 `record_tile_actions.dart` 都依赖它。`record_home_page_format_test.dart` 仍可测它。
- **`_RecordBottomSheetPage` 与 `openRecordTileActions._showRecordEditSheet` 是双胞胎**：前者用于 FAB（新建空白），后者用于编辑/复制（带 `startAtKeyboard: true`）。两份代码差别只是 `RecordNewPage` 构造参数，故意没合并——如果 FAB 也要带"启动直达键盘"逻辑，再合并不迟。
- **`RecordDetailSheet` 不再 navigate Navigator.pop 到外层路由**：它只 pop 自己（modal sheet），返回 `RecordDetailAction`。这是 helper 拆分的前提——pop 出去之后 helper 才能根据返回值决定是否再弹编辑表单。
- **本次没改实施计划的状态记录**——Step 3.6 在前文已标记完成，此处仅是它的 follow-up，不开新 Step。`progress.md` 用"Step 3.6 续"标题区分。


## 现状澄清（2026-05-03）— Phase 10 已固化、Phase 11 重新定义

> 本段是**当前事实的权威说明**。前文 Phase 0~12 的历史记录保留原样不动；如果旧记录或其他 md（design-document / implementation-plan / architecture）与本段冲突，**以本段为准**。

### 实际跑在代码里的同步方案（Phase 10 落地形态）

1. **快照模型**：以"账本"为单位整库 JSON 上传/下载（`LedgerSnapshot`），覆盖式同步。**不**用 `sync_op` 增量队列（该表存在但仅用于本机审计）；**不**做 LWW 冲突合并（多设备并发以最后上传者覆盖）。
2. **4 个 backend，全部 BYO**：iCloud（仅 iOS）/ WebDAV / S3 / Supabase。BeeCount Cloud 集中托管模式作为死代码保留在 `packages/flutter_cloud_sync/`，但项目层不暴露任何入口。**不存在"官方托管 Supabase"模式**——曾在早期 design-document 出现的"官方托管 + BYO 双模"已废止。
3. **云端只有对象存储，没有数据库表**：所有 backend 只用 Storage / 文件层；Supabase 不建任何 PostgreSQL 业务表。早期设计的 `Supabase 同构镜像表 + RLS user_id = auth.uid()` 方案整段废弃。
4. **路径约定**（与 `lib/features/sync/sync_service.dart::_path()` 一致）：
   - 备份：`users/<uid>/ledgers/<ledgerId>.json`
   - 附件（Phase 11 待实施）：`users/<uid>/attachments/<txId>/<sha256><ext>`
   - `<uid>`：Supabase 用 `auth.uid()`；其它 backend 退化为 `deviceId`。
5. **云配置存储**：`flutter_cloud_sync` 包通过 `SharedPreferences` 持久化（Android 明文 XML / iOS NSUserDefaults plist）。`user_pref` 不增列、不参与云配置存储。
6. **触发时机**：Step 10.7 的 `SyncTrigger` 调度器统一管理 5 个触发源（冷启动 / 前台恢复 / 记账后防抖 5s / 下拉刷新 / 15min 定时器）。
7. **加密策略**：所有云端数据**明文上传**——云是用户自有空间，账号隔离 + RLS / ACL 已经提供机密性。**不**做字段级加密、**不**做快照级加密、**不**做端到端加密。

### Phase 11 已被重新定义

**原 Phase 11**（design-document v1 + implementation-plan v1）：「快照加密 + 派生密钥（PBKDF2）+ 同步码（Supabase refresh token + enc_salt 打包）+ 附件加密上传」。**整段于 2026-05-03 废止**——理由：① 云是用户自有空间，加密层是过度工程；② 用户已主动跳过原 Phase 11、直接做 Phase 12 垃圾桶；③ 真正未解决的痛点是「换设备图片丢失」。

**新 Phase 11 · 附件云同步**（implementation-plan §11，4 个 step）：
- **11.1 二进制存储扩展**：`packages/flutter_cloud_sync/lib/src/core/storage_service.dart::CloudStorageService` 加 `uploadBinary` / `downloadBinary` / `listBinary` 三个方法；4 个 backend 子包（Supabase / S3 / WebDAV / iCloud）各实现一份。
- **11.2 schema v10 迁移与上传管线**：`transaction_entry.attachments_encrypted` BLOB 内 JSON shape 从 `["path"]` 升级为含 `remote_key / sha256 / size / original_name / mime / local_path` 的对象数组；`SnapshotSyncService.upload(ledgerId)` 内部前置一段附件上传，先扫所有 `remote_key == null` 的元数据 `uploadPending` 再传 JSON 快照。
- **11.3 懒下载与本地缓存**：`AttachmentDownloader.ensureLocal(meta)` 命中本地走 file，没命中拉远端写到 `<cache>/attachments/`；500MB LRU（mtime 近似）；列表滚动 prefetch 限并发 3。
- **11.4 软删除 / GC / 回填迁移**：流水软删时只清 cache，硬删（30 天后）调 `delete` 删远端；7 天孤儿 sweep；v9→v10 升级后所有 meta 的 `remoteKey == null` 由下次同步自然回填上传。

**列名 `note_encrypted` / `attachments_encrypted` 是历史遗留**——v1 设计曾打算装字段级加密密文，现在 Phase 11 决策后改为明文。**不重命名列**（避免 schema 迁移代价 + 已有代码、测试、注释引用）；用文档与注释强调"列名是历史遗留，内容已不加密"即可。

### 配套文档

- **`docs/supabase-setup.sql`**（2026-05-03 新增）：仅 Supabase 后端用户在自己的 Supabase 项目里跑一次的初始化脚本——创建 `beecount-backups` + `attachments` 两个私有 bucket + 8 条 RLS 策略（每 bucket 4 条 SELECT/INSERT/UPDATE/DELETE，统一校验 `folder[2] = auth.uid()::text`）。**App 内不自动执行**（避免持有 service_role key）。其他 3 个 backend（iCloud / WebDAV / S3）无需后端配置。
- **`memory-bank/architecture.md`** 末尾「Phase 11 配套文档」段：详细说明上述 SQL 的设计决策（为什么不做 mime 白名单、为什么 folder[3] 不参与 RLS、为什么明文不加密），落地时按需查阅。

### 不再相信的旧描述

如果你看到下面这些描述，**默认按新方案理解，不要按字面执行**：

| 旧描述出处 | 旧描述内容 | 新现实 |
| :-- | :-- | :-- |
| design-document v1 §3 / §5.5 / §7.2 | "敏感字段加密上传"、"Supabase 同构镜像表 + RLS"、"派生加密密钥"、"同步码" | 全部废止；4 backend 纯对象存储 + 明文 |
| implementation-plan v1 Phase 11 Step 11.1~11.5 | "加密密码与密钥派生"、"快照加密层"、"同步码导出 / 导入" | 整段删除（已于 2026-05-03 改写为附件云同步 4 步） |
| architecture.md 早期备忘 | "Phase 11 字段级加密会改 BianbianCrypto" | 已逐条更新为"字段级加密计划废弃"，bianbian_crypto.dart 留作 Phase 13 `.bbbak` 可选加密的备件 |
| `transaction_entry.note_encrypted` / `attachments_encrypted` 列名 | "AES-GCM 加密的 BLOB" | 列名是历史遗留，前者暂未消费、后者装明文元数据 JSON 数组 |



