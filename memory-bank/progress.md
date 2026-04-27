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
