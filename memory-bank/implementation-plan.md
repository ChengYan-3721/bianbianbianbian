# 边边记账 · 实施计划（Implementation Plan）

本计划基于 `memory-bank/design-document.md`，面向 AI 开发者协作者。每个步骤必须满足：

1. **粒度小**：一个步骤一次只改动一个可验证的关注点；
2. **指令具体**：明确要创建/修改什么文件、使用什么依赖、遵循什么约定；
3. **自带验证**：每一步末尾给出"验证方式"，只有验证全部通过才能进入下一步；
4. **本计划不写代码**：只描述"要做什么、要验证什么"。实现细节由开发者依据设计文档第 7-11 章完成。

> **全局前置规则**：任何一步开始前，必须先通读 `memory-bank/design-document.md` 与 `memory-bank/architecture.md`。每完成一个"阶段"（Phase），必须把该阶段新增/调整的架构决策补录到 `memory-bank/architecture.md`，并将完成状态写入 `memory-bank/progress.md`。

---

## 阶段 0 · 项目基线（Phase 0 — Foundation）

### Step 0.1 清理脚手架
- **做什么**：移除默认计数器 Demo。把 `lib/main.dart` 改造为一个空的 `MaterialApp`，仅显示一个标题为"边边记账"的空白首页；把 `test/widget_test.dart` 的计数器断言改为"标题文字存在"的断言。
- **验证**：
  - `flutter analyze` 零错误、零警告。
  - `flutter test` 全部通过。
  - `flutter run` 能启动到一个空白首页，AppBar 标题显示"边边记账"。

### Step 0.2 目录骨架
- **做什么**：在 `lib/` 下创建以下空目录：`app/`、`core/crypto/`、`core/network/`、`core/util/`、`data/local/`、`data/remote/`、`data/repository/`、`domain/entity/`、`domain/usecase/`、`features/record/`、`features/stats/`、`features/ledger/`、`features/budget/`、`features/account/`、`features/sync/`、`features/trash/`、`features/lock/`、`features/import_export/`、`features/settings/`。每个目录放一个 `.gitkeep`。
- **验证**：目录结构与设计文档 §8.3 完全一致；`flutter analyze` 仍零错误。

### Step 0.3 基础依赖接入
- **做什么**：在 `pubspec.yaml` 的 `dependencies` 中加入（按用途归类，暂不写死版本号——开发者应使用 pub.dev 最新稳定版）：
  - 路由：`go_router`
  - 状态管理：`flutter_riverpod`、`riverpod_annotation`
  - 本地 DB：`drift`、`sqlite3_flutter_libs`、`sqlcipher_flutter_libs`、`path_provider`、`path`
  - 远端：`supabase_flutter`
  - 偏好/密钥：`shared_preferences`、`flutter_secure_storage`
  - 加密：`cryptography`
  - 图表：`fl_chart`
  - SVG：`flutter_svg`
  - 生物识别：`local_auth`
  - 通知：`flutter_local_notifications`
  - 国际化：`intl`、`flutter_localizations`
  - UUID：`uuid`
- 在 `dev_dependencies` 中加入：`build_runner`、`drift_dev`、`riverpod_generator`、`custom_lint`、`riverpod_lint`。
- **验证**：`flutter pub get` 成功，`flutter analyze` 零错误。

### Step 0.4 路由与主题骨架
- **做什么**：
  - 在 `lib/app/` 下建立"应用根组件 + 路由配置 + 主题配置"三个文件（具体命名由开发者决定，但需显式暴露 `goRouter` 和 `appTheme` 两个入口）。
  - 路由先仅注册一个路径 `/`，指向一个叫 `HomeShell` 的骨架页，里面放一个包含 4 个 Tab（记账 / 统计 / 账本 / 我的）的 `BottomNavigationBar`，每个 Tab 仅显示占位文字。
  - 主题按设计文档 §10.2 实现"奶油兔"默认主题色板；圆角、阴影参数按 §10.5 实现。
  - `main.dart` 把 `ProviderScope` 包裹在最外层。
- **验证**：
  - 启动后 4 个 Tab 可切换，底部栏着色为奶油黄（`#FFE9B0`）。
  - 新增 Widget 测试：验证初始路由渲染出"记账"这个 Tab 文字。
  - `flutter analyze` 零错误。

---

## 阶段 1 · 本地数据层（Phase 1 — Local Persistence）

### Step 1.1 drift 数据库初始化
- **做什么**：在 `lib/data/local/` 下建立 drift 数据库类，先只注册一张 `user_pref` 表，字段按设计文档 §7.1 的 `user_pref` 定义。数据库文件名固定 `bbb.db`，位置走 `path_provider` 的 `ApplicationDocumentsDirectory`。
- **验证**：
  - 运行 `dart run build_runner build --delete-conflicting-outputs`（或 `flutter pub run build_runner build ...`）生成代码成功。
  - 新增单元测试：首次打开数据库能插入一行 `user_pref(id=1)` 并读出。
  - 应用启动不崩溃。

### Step 1.2 接入 SQLCipher
- **做什么**：
  - 让 drift 使用 SQLCipher 打开数据库；密钥由 `flutter_secure_storage` 托管。
  - 首次启动时，生成一个 32 字节随机密钥并存入 `flutter_secure_storage`（key 名：`local_db_cipher_key`）；之后启动直接读取。
  - 该密钥**仅用于本地 DB 加密**，与后续"用户同步密码派生密钥"是两件事，不要混用。
- **验证**：
  - 新增集成测试：生成 DB 文件后，用未带密钥的普通 sqlite 打开应报错/读不出表。
  - 第二次启动仍能正常读取原数据（密钥持久化正确）。
  - 卸载重装后是全新空库（`flutter_secure_storage` 在 iOS/Android 卸载行为差异已知，无需额外处理）。

### Step 1.3 核心业务表建表
- **做什么**：按设计文档 §7.1 把其余表全部加入 drift：`ledger`、`category`、`account`、`transaction_entry`、`budget`、`sync_op`。字段名、类型、索引与文档完全一致；所有实体表都要包含 `updated_at` / `deleted_at` / `device_id` 三个同步字段。
- **验证**：
  - build_runner 通过。
  - 新增单元测试：分别对每张表做一次 insert → select → update(`updated_at` 变更) → soft-delete(`deleted_at` 非空) 的往返。
  - `flutter analyze` 零错误。

### Step 1.4 DAO 分层
- **做什么**：为每张业务表（ledger/category/account/transaction/budget）建立 DAO 类，只暴露"按 ledgerId 查询未删除记录"、"upsert"、"soft-delete by id"、"硬删除（仅用于垃圾桶清理）"四类方法。所有查询默认过滤 `deleted_at IS NULL`，硬删除接口需在方法注释里注明"仅垃圾桶定时任务可调用"。
- **验证**：
  - 单元测试覆盖每个 DAO 的 4 个方法；特别验证 soft-delete 后普通查询查不到，但硬删除接口能看到。
  - `flutter analyze` 零错误。

### Step 1.5 设备 ID 初始化
- **做什么**：在应用首次启动时生成 UUID v4 作为 `device_id`，存入 `user_pref` 同时也存一份到 `flutter_secure_storage`（冗余防丢）；提供一个 Riverpod provider 暴露当前 `device_id`。
- **验证**：
  - 首次启动后 `user_pref.device_id` 非空。
  - 冷启动再次读取得到同一个值。
  - 清除应用数据后重新生成一个新值。

### Step 1.6 加密工具封装
- **做什么**：在 `lib/core/crypto/` 下封装三个静态函数式工具：
  1. `deriveKey(password, salt, iterations=100000)` → 返回 32 字节密钥（PBKDF2-HMAC-SHA256）。
  2. `encrypt(plaintext, key)` → 返回 `{ciphertext, nonce, tag}` 打包成 bytes。
  3. `decrypt(ciphertext, key)` → 返回 plaintext，校验失败时抛 `DecryptionFailure`。
- **验证**：
  - 单元测试：对一段固定文本做 encrypt→decrypt 往返，结果相等；错误密钥解密抛异常。
  - KAT（Known-Answer Test）：用一组硬编码的 key/nonce/plaintext 验证密文字节一致（对照任意一个 AES-GCM 标准实现生成一次即可）。

### Step 1.7 种子数据
- **做什么**：应用首次启动且 `ledger` 表为空时，自动插入：
  - 默认账本 `📒 生活`；
  - 18 个默认支出分类 + 10 个默认收入分类（具体名称见设计文档 §5.1.2；图标先用 emoji 占位，颜色分配使用主题配色 6 色循环）；
  - 5 个默认账户：现金、工商银行卡、招商信用卡、支付宝、微信。
- **验证**：
  - 首次启动后账本 Tab 显示 1 个账本，新建记录页分类网格显示全部默认分类。
  - 第二次启动不会重复插入（通过 `user_pref.seeded_at` 或存在性判断保证幂等）。
  - 单元测试覆盖"空库 → 种子 → 再次调用不变"。

---

## 阶段 2 · 领域层与仓库（Phase 2 — Domain & Repository）

### Step 2.1 领域实体
- **做什么**：在 `lib/domain/entity/` 下定义不可变实体：`Ledger`、`Category`、`Account`、`TransactionEntry`、`Budget`。字段与 drift 数据类一一对应，但**不依赖 drift**（纯 Dart）。提供 `copyWith` 与 `toJson/fromJson`。
- **验证**：
  - 单元测试：`fromJson(toJson(x)) == x`。
  - 领域层文件不 import `package:drift/*`（可通过导入检查脚本或 `dart analyze` 的依赖规则检测）。

### Step 2.2 仓库接口与实现
- **做什么**：为每个聚合（Ledger / Category / Account / Transaction / Budget）定义仓库接口（抽象类），再写对应的 `LocalXxxRepository` 实现。仓库方法使用领域实体，不暴露 drift 数据类。仓库内部负责：
  - 生成/刷新 `updated_at`、`device_id`；
  - 软删除；
  - 向 `sync_op` 写入待同步记录（即使此时同步功能尚未启用，也要写队列，后续阶段才会消费）。
- **验证**：
  - 单元测试：对 Transaction 做一次 create → update → delete，检查 `sync_op` 表里增加了 3 条 upsert/delete 记录，`entity_id` 与 Transaction 的 id 一致。
  - 单元测试：仓库返回的实体不带 drift 专属类型。

### Step 2.3 Riverpod Provider 布线
- **做什么**：为每个仓库建立一个 `Provider`，并为"当前账本 id"建立 `StateProvider`（默认指向种子账本）。后续 UI 一律通过 Provider 读取仓库，不得直接 new 仓库。
- **验证**：
  - Widget 测试：用 `ProviderContainer.test` 覆盖 provider，注入假仓库，验证 UI 能读到 mock 数据。
  - 启动后首页能显示当前账本名称。

---

## 阶段 3 · 记账主流程（Phase 3 — Core Bookkeeping）

### Step 3.1 首页骨架
- **做什么**：记账 Tab 替换为包含以下结构的页面：
  - 顶栏：账本下拉（暂时只显示名称，不可交互）、月份切换按钮（可切换并联动）、搜索图标（暂占位）；
  - 数据卡片：本月收入/支出/结余（数据读自仓库，空时显示 ¥0.00）；
  - 快捷输入条：单行输入框 + "✨ AI 识别"按钮（暂仅打印输入，不做解析）；
  - 流水列表：按日期倒序分组，每组一个日期 header；
  - 悬浮 FAB：`+` 按钮，点击后跳转到"新建记账页"（下一步创建）。
- **验证**：
  - Widget 测试：渲染首页；无数据时显示空状态插画+"开始记第一笔吧"；有 mock 数据时流水列表按天分组正确。
  - 月份切换能改变卡片上的月份标签并触发数据重查询。

### Step 3.2 新建记账页（叨叨式交互 + 一级/二级分类 + 收藏）

> **2026-04-26 不兼容重构**：本步骤在首版表单式实现后，按需求做了完整的交互与数据模型重写。以下描述的是**重构后的终态**，不再描述已废弃的旧版（收入/支出/转账顶部 Tab + 按 type 过滤分类）。

- **数据模型重构**（`category` 表 schema v3）：
  - `category` 表移除 `ledger_id` / `type` 两列，新增 `parent_key`（一级分类 key）+ `is_favorite`（收藏 0/1）。
  - 一级分类为**固定常量**，不落库：`income` / `food` / `shopping` / `transport` / `education` / `entertainment` / `social` / `housing` / `medical` / `investment` / `other`（共 11 个，加一个 `☆` 收藏伪页签）。`parent_key` 列有 CHECK 约束限定取值范围。
  - 二级分类全局共享（不区分账本），通过 `parent_key` 归属到一级分类。
  - `app_database.dart`：`schemaVersion` 升至 3，`v2→v3` 迁移直接重建 `category` 表（旧结构不兼容）。
  - DAO 层新增 `listActiveByParentKey` / `listFavorites` / `updateFavoriteById` / `listActiveAll` 四个方法；仓库层对应新增 `listFavorites` / `listActiveAll` / `toggleFavorite` 三个暴露。
  - 种子数据改为 `Map<String, List<(name, emoji)>>` 的固定一级映射结构，每个一级分类下各有 5 条默认二级分类（收入 10 条），默认非收藏。
  - 实体层 `Category` 移除 `ledgerId` / `type`，新增 `parentKey` / `isFavorite`。

- **UI 交互模型（叨叨式两态）**：
  - **分类选择态**：页面进入时先展示当前一级分类下的二级分类网格（5 列 GridView）。每格显示 emoji 图标 + 名称，点击选择分类后自动切入数字键盘态。网格末尾有一个"编辑"（或收藏页签下的"添加"）按钮，跳转到对应分类管理页 `/record/categories` / `/record/categories/parent`。
  - **数字键盘态**：选中二级分类后展开。上方为金额显示区（`¥ 表达式`），中间为元数据工具栏（二行 pill 按钮：第一行：分类名/日期/钱包；第二行：备注），下方为自定义数字键盘。
  - **底部一级分类单字 Tab**（12 个）：`☆` / `收` / `食` / `购` / `行` / `育` / `乐` / `情` / `住` / `医` / `投` / `其`。横滑 `ListView`，选中项高亮为奶油黄色。`☆` 页签展示用户收藏的二级分类，作为快捷入口。
  - 切一级 Tab 会自动清空已选二级分类（`categoryId = null`）。

- **表单数据与收支判定**（`RecordFormData` + `RecordForm` Notifier）：
  - 核心字段：`selectedParentKey`（当前一级分类 key，默认 `'favorite'`）、`expression`（算式字符串）、`amount`（解析结果 double?）、`categoryId`、`accountId`、`occurredAt`、`note`。
  - **自动收支判定**：`inferredType` → `selectedParentKey == 'income'` 时为 `'income'`，其余一律 `'expense'`。保存时写入流水 `type` 字段，用户无需手动切换收支。
  - 算式求值：`_parseExpr` 递归下降，从右向左找最后一个 `+`/`-` 做分割点，仅支持加减。`=` 键解析并固化 amount；`C` 清空；`⌫` 退格；`(` / `)` 键仅拼进 expression 字符串但不影响求值（括号非法 token 时 `_parseExpr` 返回 null）。表达式不完整时（如 `1+`）amount 保持为 null，保存按钮置灰。
  - `canSave` = `amount != null && amount > 0 && categoryId != null`。保存时构造 `TransactionEntry`（UUID v4、自动 type、金额、分类、账户、时间），通过 `transactionRepository.save()` 落库，然后 `ref.invalidate(recordMonthSummaryProvider)` 通知首页刷新。

- **数字键盘**（`NumberKeyboard`）：
  - 4 行布局：`7 8 9 ⌫` / `4 5 6 +` / `1 2 3 -` / `CNY 0 . ✓/=`（右下角为动态动作键：有运算符时显示 `=`，否则显示 `✓`）。
  - 普通键（数字、小数点、`+`、`-`、`⌫`）通过 `onKeyTap(String key)` 回调；右下角动态动作键走独立回调并与 `canSave` 联锁（不可保存时置灰）。

- **元数据工具栏**（_MetaToolbar pill 行）：
  - **分类 pill**：显示当前选中二级分类名或"切换"，点击退回分类选择态。
  - **日期 pill**：显示 `MM.dd` 格式，点击弹出 `showDatePicker` → `showTimePicker` 串联选择。日期上限为今天，语言为 zh_CN。
  - **钱包 pill**：`_WalletPillButton` ConsumerWidget，从 `accountRepositoryProvider` 读活跃账户列表，点击弹出 `showModalBottomSheet` 选择。未选时显示"钱包"占位。
  - **备注 pill**：显示备注文本或"备注"占位，点击弹出全屏 bottom sheet（`isScrollControlled: true`），内含多行 TextField + 图片选择占位按钮（`onPressed` 留空，Step 3.5 接线）+ 取消/确定双按钮。

- **保存行为**：
  - 保存成功后 `Navigator.pop()` 返回首页，不再支持"再记一笔"留在当前页继续录入。
  - 转账完全未实现——旧版"转账"Tab 在同一重构中移除，留待 Step 3.4。

- **验证**：
  - 金额区支持算式：输入 `12.5+3` 点 `=` 得到 `15.5`。
  - 未选分类时保存按钮置灰（`✓` 键 disabled）。
  - 表达式不完整（如 `1+`）时 amount 为 null，同样置灰。
  - 选中一级分类为 `收` 的二级分类保存后，流水 `type` 自动为 `'income'`；其余一级分类为 `'expense'`。
  - 成功保存后，首页流水列表立即出现新纪录（通过 `ref.invalidate(recordMonthSummaryProvider)`）。
  - `☆` 页签可快速使用已收藏二级分类。
  - 切一级 Tab 后 `categoryId` 自动清空，需重新选二级分类。

### Step 3.3 流水详情 / 编辑 / 删除
- **做什么**：
  - 点击首页任一流水进入详情只读页；
  - 详情页提供"编辑"→ 复用新建页组件并预填；"删除"→ 调用仓库软删除；"复制"→ 预填但不提交；
  - 列表左滑显示"删除"快捷按钮，确认后软删除。
- **验证**：
  - 单元测试：软删除的记录在首页消失但仍存在于库中（`deleted_at` 非空）。
  - UI 测试：编辑后金额与备注变化实时生效；`updated_at` 变更、`sync_op` 新增一条 upsert。

### Step 3.4 转账
- **做什么**：在首页右上角搜索按钮左边，增加转账按钮，点击后跳转转账页面：只显示金额、来源账户、目标账户、时间、备注；保存后**生成一条 `type=transfer` 的流水**，字段 `account_id` 与 `to_account_id` 分别指向两端。
- **验证**：
  - 单元测试：转账流水不计入收入/支出统计；来源与目标不能相同（UI 与仓库双重校验）。
  - 首页列表能展示转账条目，图标与颜色区别于普通流水。

### Step 3.5 图片附件（本地）
- **做什么**：记一笔备注中的"图片按钮"支持从相册选取或拍照，最多 3 张；图片复制到 App 沙盒私有目录（`<documents>/attachments/<tx_id>/xxx.jpg`）；`transaction_entry.attachments_encrypted` 字段目前先以明文 JSON 写入路径数组（加密留到阶段 11）。
- **验证**：
  - 选图保存后，重启应用能读回并渲染缩略图。
  - 软删除流水时附件不立刻删，由垃圾桶阶段统一处理。

---

## 阶段 4 · 多账本（Phase 4 — Multi-Ledger）

### Step 4.1 账本 Tab 列表
- **做什么**：账本 Tab 显示所有未归档账本卡片（封面 emoji + 名称 + 流水总数）；点击切换当前账本（同步更新 `user_pref.current_ledger_id` 与首页顶栏）。
- **验证**：
  - Widget 测试：切换账本后，首页数据卡片与流水列表应用新账本数据。
  - 归档的账本不出现在此列表，但出现在"归档"折叠区。

### Step 4.2 新建 / 编辑 / 归档 / 软删除账本
- **做什么**：新建页表单含名称、emoji 封面、默认币种（从多币种列表选，默认 CNY）、"分类模板"（空 / 复制自某账本）。编辑页同。归档仅置 `archived=1`。软删除会级联把该账本的分类与流水也软删除。
- **验证**：
  - 单元测试：删除账本后，属于它的流水均被软删除；归档账本不被软删除只是 `archived=1`。
  - UI：当前账本不允许被软删除（按钮置灰并提示"请先切换到其他账本"）。

### Step 4.3 顶栏账本切换器
- **做什么**：首页顶栏下拉展示未归档账本，点击切换；切换后所有页面（首页、统计、预算、资产）同步。
- **验证**：
  - 切换账本后，统计 Tab 的图表立即重绘（通过 provider invalidate）。
  - 切换被持久化：重启应用仍记得上次选中的账本。

---

## 阶段 5 · 统计（Phase 5 — Statistics）

### Step 5.1 时间区间选择器
- **做什么**：统计 Tab 顶部放区间选择器：本月 / 上月 / 本年 / 自定义。自定义弹出日期范围选择器，结果写入一个 `StateProvider` 驱动后续图表。
- **验证**：切换区间后，下方所有图表同步刷新；自定义区间跨年能正确处理。

### Step 5.2 收支折线图
- **做什么**：使用 `fl_chart` 绘制按日的收入（绿色）与支出（红色）双折线。数据由专门的 `StatsRepository` 聚合 SQL 出来（按 `occurred_at` 的日期分组，只算当前账本、非删除、非转账）。
- **验证**：
  - 单元测试：构造一天 3 条支出一条收入的测试数据，聚合结果金额正确、日期正确。
  - UI：空数据显示占位插画。

### Step 5.3 分类饼图
- **做什么**：支出按分类聚合，取 Top 6，其余归入"其他"。颜色与分类自身颜色一致。点击切片跳转到"分类流水列表"（过滤当前区间 + 当前分类的流水）。
- **验证**：
  - 单元测试：4 个分类的百分比和为 100%。
  - 无数据时显示空图占位。

### Step 5.4 收支排行榜
- **做什么**：按分类金额倒序列出，显示图标、分类名、金额、占比条。
- **验证**：排名与上一步饼图数据一致。

### Step 5.5 日历热力图
- **做什么**：展示当前区间内每日支出强度（越红越多）。点击某天跳转到该日的流水列表。
- **验证**：视觉审查：无支出日为浅色；极端值（某天 5 倍于均值）不会把其他天压成全白（使用分位数归一化而非线性）。

### Step 5.6 导出视图
- **做什么**：统计页右上角加"导出"按钮，可选导出当前视图为 PNG（截图当前图表）或 CSV（当前区间明细）。文件保存到 `<documents>/exports/`，导出后用系统 Share Sheet 分享。
- **验证**：导出的 CSV 能被 Excel 打开、列头正确；PNG 分辨率 ≥ 2x。

---

## 阶段 6 · 预算（Phase 6 — Budget）

### Step 6.1 预算设置页
- **做什么**：在"我的 → 预算"下，列出当前账本的总预算与各分类预算；支持新增、编辑、删除；周期仅选月/年；结转开关可选。
- **验证**：单元测试：同一分类同一周期只能存在一个预算。

### Step 6.2 预算进度计算
- **做什么**：对每个预算实时计算"已花 / 上限"。颜色按设计文档 §5.4 规则：<70% 绿、70-100% 橙、>100% 红并震动提示（震动仅在从绿/橙过渡为红时触发一次，通过一个 session 标记避免多次震动）。
- **验证**：
  - 单元测试：边界值 70% 归橙、100% 归橙、100.01% 归红。
  - UI：震动仅首次突破时触发一次。

### Step 6.3 统计页联动
- **做什么**：统计页饼图旁显示预算进度环（总预算），点击跳到预算详情页。
- **验证**：与预算设置页数据一致；无预算时进度环隐藏。

### Step 6.4 预算结转
- **做什么**：开启结转的预算，月末结算时把未花完金额累加到下月的"结转余额"字段（表中新增 `carry_balance` 列，通过迁移追加）。
- **验证**：
  - 单元测试：上月剩 200，下月预算 1000 + 结转 200 → 本月可用 1200。
  - 关闭结转重新打开，不回溯历史（只影响开启后的月份）。

---

## 阶段 7 · 资产账户（Phase 7 — Accounts）

### Step 7.1 账户列表
- **做什么**：资产 Tab 顶部显示"总资产 = 计入总资产的账户初始余额 + 流水净额"，下方列出所有账户卡片（图标、名称、类型、当前余额）。
- **验证**：
  - 单元测试：切换"是否计入总资产"后总资产数值对应变化。
  - 信用卡账户余额为负（欠款），颜色区分。

### Step 7.2 账户 CRUD
- **做什么**：新建/编辑/删除账户；删除走软删（进垃圾桶），该账户未删流水自动挂到"（已删账户）"占位标签上。
- **验证**：删除账户后，首页流水详情显示"（已删账户）"不崩溃。

### Step 7.3 信用卡字段
- **做什么**：信用卡类型的账户允许填账单日、还款日（仅数值 1-28）；仅展示，不生成提醒。
- **验证**：在详情页显示"账单日 5 号、还款日 22 号"；非信用卡类型字段不可见。

---

## 阶段 8 · 多币种（Phase 8 — Multi-Currency）

### Step 8.1 币种开关与数据表
- **做什么**：在"我的 → 多币种"加全局开关；新增 `currency` 常量列表与"汇率快照表"`fx_rate(code, rate_to_cny, updated_at)`；初始化时内置一次快照（开发者可手动填写一组合理的写死值）。
- **验证**：单元测试：开关关闭时记账页币种字段隐藏。

### Step 8.2 记账页币种选择
- **做什么**：全局开关开启后，金额旁新增币种下拉（默认账本默认币种）；保存时把 `currency` 与换算后的 `fx_rate`（该币种→账本默认币种）一起存。
- **验证**：
  - 单元测试：以 USD 记 10，汇率 7.2，则统计按账本默认（CNY）合计 72。
  - 流水详情显示"USD 10.00（≈ ¥72.00）"。

### Step 8.3 汇率自动与手动更新
- **做什么**：联网时每日最多刷新一次汇率（使用任一免费汇率 API，失败静默降级）；提供"手动设置某币种汇率"入口。
- **验证**：
  - 断网时记账不崩溃，使用现有快照。
  - 手动改写后不再被自动刷新覆盖，直到用户重置。

---

## 阶段 9 · 混合 AI 快速输入（Phase 9 — Hybrid AI Input）

### Step 9.1 本地规则解析器
- **做什么**：在 `lib/core/util/` 下建立 `QuickTextParser`，接收一段中文文本，输出 `{amount, categoryGuess, confidence, occurredAt, note}`。实现按设计文档 §5.1.3 的 5 步（金额/分类/时间/置信度）本地规则：
  - 金额正则覆盖 `30`、`¥30`、`30元`、`三十块`、`30.5`；
  - 分类关键词词典（JSON 文件）覆盖常见餐饮/交通/购物/娱乐词；
  - 相对时间关键词（昨天/今天/上周五/大前天…）解析到具体日期。
- **验证**：
  - 单元测试：覆盖 20+ 条典型输入的解析结果。
  - "午饭 30" → 金额=30 分类=餐饮 置信度≥0.8。

### Step 9.2 首页快捷输入条接线
- **做什么**：首页顶部输入条回车或点"✨识别"时调用解析器，弹出"确认卡片"含可编辑的金额/分类/时间/备注；确认即保存为一条流水。置信度 < 阈值（建议 0.6）时默认高亮提示"请核对"。
- **验证**：
  - UI 测试：输入"昨天打车 25"→ 卡片显示金额 25、分类 交通、时间 昨天。
  - 确认保存后回到首页可见。

### Step 9.3 LLM 增强（可选）
- **做什么**：在"我的 → 快速输入 → AI 增强"里让用户配置：endpoint、api key、model、prompt 模板。本地置信度低时，确认卡片上出现"✨AI 增强"按钮，点击后调用用户配置的 LLM（OpenAI 兼容协议），返回 JSON 后更新卡片。
- **验证**：
  - 没有配置 API 时按钮不显示。
  - 网络失败回退为本地结果并提示"AI 解析失败"。
  - 响应的 JSON 不符合 schema 时不崩溃（严格校验）。

---

## 阶段 10 · 云同步核心（Phase 10 — Sync Core）

### Step 10.1 Supabase Schema 与 RLS
- **做什么**：在 Supabase（官方实例 + 自建都需遵循）里创建与本地表同构的业务表（`ledger / category / account / transaction_entry / budget`），每张表额外加 `user_id UUID NOT NULL REFERENCES auth.users`，开启 RLS，策略统一为 `user_id = auth.uid()`。`attachments` Storage Bucket 策略同。
- **验证**：
  - 用 A 用户登录尝试 select B 用户的行，应被 RLS 拒绝。
  - 未登录匿名客户端 select 任何表应返回空或 401。
  - 建表脚本保存到 `supabase/schema.sql`，可幂等重跑。

### Step 10.2 Supabase 客户端双模配置
- **做什么**：在 `lib/core/network/` 封装 `SupabaseClientProvider`，支持两种构造来源：
  - 官方托管：URL/anonKey 来自 `--dart-define` 编译期注入（`SUPABASE_URL_OFFICIAL`、`SUPABASE_ANON_KEY_OFFICIAL`）；
  - 用户自建：URL/anonKey 来自 `user_pref`。
  - 切换模式时销毁旧 client、重建新 client、清理已登录会话。
- **验证**：
  - 集成测试：在测试用的空 Supabase 实例上能完成 signUp → signIn → signOut。
  - UI："我的 → 云同步 → 后端"可切换两模式，切换后显示新 URL。

### Step 10.3 同步凭证 UX
- **做什么**：在"我的 → 云同步"提供"创建凭证"与"恢复凭证"两种入口：
  - 创建：邮箱 + 密码（仅本地校验长度），调用 `signUp`；成功后派生加密密钥（见阶段 11）并持久化。
  - 恢复：两种子入口——"邮箱密码登录"、"粘贴同步码"。
  - 成功后显示"当前凭证状态"（已登录的邮箱 hint + 最近同步时间）。
- **验证**：
  - 错误邮箱/密码给出可读错误。
  - 已登录状态下再次进入页面显示 hint 与"登出/切换凭证"。

### Step 10.4 同步队列消费
- **做什么**：实现 `SyncEngine`（单例 Provider），核心职责：
  - Push：从 `sync_op` 表取未处理项，分表批量 upsert / delete 到 Supabase（单批 ≤ 500），成功则清空对应项；
  - Pull：按 `updated_at > last_sync_at` 拉取每张表变更；
  - 合并：按设计文档 §5.5.3 规则（LWW + device_id 字典序 + 冲突副本）写入本地；
  - 更新 `user_pref.last_sync_at`。
- **验证**：
  - 集成测试：两台"设备"（两套独立本地 DB 指向同一个 Supabase）互相同步后，任一方新增/修改/软删的流水最终在对方能看到。
  - 集成测试：同一条记录在两端 `updated_at` 相同但内容不同→ 生成一条冲突副本（原记录保留胜者内容）。

### Step 10.5 触发时机
- **做什么**：按设计文档 §5.5.2，下列事件触发同步：
  - App 启动；
  - 前台恢复；
  - 记账/编辑保存后 5 秒静默（防抖）；
  - 用户下拉首页；
  - 每 15 分钟定时（使用 `Timer.periodic`，仅在前台）。
  - 网络不可用时不触发，网络恢复自动补偿。
- **验证**：
  - 断网时不报红、不重试；恢复网络后 30 秒内自动跑一次。
  - 下拉后顶部显示"同步中…" → "已同步 X 条"。

### Step 10.6 同步状态 UI
- **做什么**：首页顶栏右侧或"我的 → 云同步"显示同步状态：
  - 空闲 / 同步中 / 失败（红点 + 最后错误信息，可点开查看）/ 已关闭。
- **验证**：模拟断网下同步，UI 显示失败；查看错误面板可见"Network unreachable"。

---

## 阶段 11 · 字段级加密与同步码（Phase 11 — Encryption & Sync Code）

### Step 11.1 密钥派生与持久化
- **做什么**：开启同步并成功登录后，向用户再请求一次"同步密码"（可复用登录密码，但 UI 强提示"这是加密密码，忘记无法找回"）；使用 PBKDF2(SHA256, 100k) 派生 32 字节密钥；派生用的 salt 存 `user_pref.enc_salt`（16 字节随机）；派生后的密钥存 `flutter_secure_storage`（key：`sync_enc_key`），同时在内存中缓存 session。
- **验证**：
  - 第二次启动时能无感读回密钥。
  - 清除密钥后再次打开同步流程要求重新输入密码。

### Step 11.2 敏感字段加密
- **做什么**：在仓库层对 `note` 与 `attachments` 做"写入 drift 前加密、从 drift 读出后解密"的透明处理（即上层看到的仍是明文）。加密后字节内容写入现有的 `note_encrypted` / `attachments_encrypted` 列。
- **验证**：
  - 单元测试：同一明文加密两次结果不同（nonce 随机），解密都能还原。
  - 直接用 DB 工具查表只能看到密文。
  - 未开同步时仍保持明文（通过 `user_pref.encryption_enabled` 开关控制）。

### Step 11.3 附件加密
- **做什么**：上传 Supabase Storage 前，把本地附件文件先加密为 `.enc` 临时文件再上传；下载时反向解密到私有目录。
- **验证**：
  - 上传的对象字节与本地明文文件不同。
  - 新设备下载后能正常显示原图。

### Step 11.4 同步码导出 / 导入
- **做什么**：
  - 导出：把"邮箱 hint + 当前 refresh token + enc_salt"打包成 JSON，用一个固定的 app 常量密钥（非用户密钥）做对称加密后 Base64 编码，即得"同步码"。UI 提供复制、显示二维码。
  - 导入：在"恢复凭证 → 粘贴同步码"处反解，用 refresh token 调 Supabase 登录，`enc_salt` 写入本地后提示用户输入"同步密码"完成密钥派生。
- **验证**：
  - 导出后的字符串长度合理（≤ 512 字符）。
  - 错误或过期的同步码给出明确提示。
  - 集成测试：设备 A 导出 → 设备 B 导入 → 数据可见。

---

## 阶段 12 · 垃圾桶（Phase 12 — Trash）

### Step 12.1 垃圾桶列表
- **做什么**：在"我的 → 垃圾桶"展示 `deleted_at IS NOT NULL` 的所有实体（流水/分类/账户/账本），显示剩余天数（30 - 距今天数）。按实体类型分 Tab。
- **验证**：
  - 软删除流水后出现在列表。
  - 剩余天数 ≤ 0 的项目不再显示（但由下一步清理）。

### Step 12.2 恢复 / 永久删除
- **做什么**：每一项提供"恢复"（置 `deleted_at = null`、更新 `updated_at`）与"永久删除"（硬删 + 入 `sync_op` 的 delete 操作以告知云端硬删）。全局"一键清空"按钮。
- **验证**：
  - 恢复后立即回到原处可见。
  - 永久删除后云端也在下次同步被清理（集成测试）。

### Step 12.3 定时清理
- **做什么**：应用启动时跑一次"硬删 `deleted_at < now-30天` 的所有软删项"，同时清理其本地附件文件。该清理任务也要同步到云端。
- **验证**：
  - 单元测试：设置一条 `deleted_at = now-31天`，启动后应被硬删；附件文件也被物理删除。

---

## 阶段 13 · 导入 / 导出（Phase 13 — Import / Export）

### Step 13.1 CSV / JSON 导出
- **做什么**：在"我的 → 导入导出 → 导出"提供格式选择、范围（当前/全部账本）、时间区间。导出文件落地到 `<documents>/exports/`，用系统 Share Sheet 分享。CSV 列头按设计文档约定固定。
- **验证**：
  - 导出文件能被 Excel/Numbers 正常打开。
  - JSON 经"导入"功能再导回能完整恢复（下一步验证）。

### Step 13.2 加密备份（.bbbak）
- **做什么**：把完整 JSON 用用户输入的一次性密码 AES-GCM 加密后写入 `.bbbak` 文件（自定义扩展名，内部仍是二进制）。提示用户"该密码丢失无法恢复"。
- **验证**：
  - 错误密码解密应失败且 UI 给出明确错误。

### Step 13.3 导入（本 App 格式）
- **做什么**：支持导入本 App 的 CSV / JSON / .bbbak。流程：选文件 → 预览前 20 条 → 选择去重策略（跳过已存在 / 覆盖 / 全部作为新记录）→ 确认。
- **验证**：
  - 导出的 JSON 再导入后数据量一致；去重策略"跳过"能避免重复。

### Step 13.4 三方模板导入
- **做什么**：至少覆盖钱迹 CSV、微信账单 CSV、支付宝账单 CSV 三个模板，识别其列结构并映射到本 App 字段；分类采用"关键词→本地分类"的映射表，未命中归"其他"。
- **验证**：
  - 每个模板各准备一份 ≥ 50 行的样本 CSV，导入后条数一致、金额汇总一致。

---

## 阶段 14 · 应用锁与安全（Phase 14 — App Lock & Security）

### Step 14.1 PIN 设置
- **做什么**：在"我的 → 应用锁"提供开启开关与 4-6 位 PIN 设置（两次一致）。PIN 哈希（PBKDF2 + salt）存 `flutter_secure_storage`。
- **验证**：
  - 错误 PIN 三次后进入"冷却 30 秒"。
  - 忘记 PIN 的恢复提示清晰告知"会清空本地数据但云端可恢复"。

### Step 14.2 生物识别
- **做什么**：加"生物识别"开关，启用后优先提示 Face ID / 指纹；失败可降级到 PIN。
- **验证**：
  - 不支持的设备上开关置灰并给出说明。
  - 生物识别被系统取消时回到 PIN 界面。

### Step 14.3 前台锁触发
- **做什么**：App 冷启动、后台超过 N 分钟（默认 1、可配）、切到后台立即锁，基于 `WidgetsBindingObserver` 生命周期事件。
- **验证**：
  - 手动调回后台 2 分钟再回前台，应出现锁屏。
  - 锁屏期间无法通过深链跳过。

### Step 14.4 隐私模式
- **做什么**：多任务预览模糊（iOS `applicationWillResignActive` 展示遮盖层；Android 设置 `FLAG_SECURE`）；截屏阻止开关（Android 默认启用，iOS 仅能检测无法阻止，检测到做数据脱敏）。
- **验证**：
  - Android 多任务切换器下只看到一个遮罩，iOS 同。

---

## 阶段 15 · 主题与外观（Phase 15 — Themes）

### Step 15.1 四套主题实现
- **做什么**：把"奶油兔、厚棕熊、月见黑、薄荷绿"四套色板抽象为数据类，主题切换器改 `user_pref.theme`；深色主题支持跟随系统。
- **验证**：
  - 切换后所有页面（包括图表与图标底色）即时变色。
  - 深色模式下对比度符合 WCAG AA（手工抽查首页与新建页）。

### Step 15.2 字号调节
- **做什么**：在"外观"页提供小 / 标准 / 大三档字号，通过 `MediaQuery.textScalerOf` 覆盖。
- **验证**：切换"大"字号后所有关键按钮仍可点击（不裁切）。

### Step 15.3 自定义分类图标集
- **做什么**：提供 2 套内置图标包（手绘贴纸、扁平 emoji），用户可整体切换；保留单分类图标自定义能力。
- **验证**：切换图标包后，分类网格与流水列表图标同步更新。

---

## 阶段 16 · 提醒与小组件（Phase 16 — Reminders & Widgets）

### Step 16.1 每日记账提醒
- **做什么**：在"我的 → 提醒"开启每日提醒并设定时间；使用 `flutter_local_notifications` 注册本地通知；文案走可爱风（如"今天还没记一笔呢 🐻"）。
- **验证**：
  - 设定时间后真实等到时刻能收到通知（或用插件的测试触发接口）。
  - 关闭开关后通知取消。

### Step 16.2 未记账天数提醒
- **做什么**：应用打开时计算距最近一笔流水的天数；≥ 2 天时若当天未提醒过则在首页顶部卡片轻提示一次（不是通知）。
- **验证**：不会重复提醒同一天。

### Step 16.3 Home Screen Widget
- **做什么**：
  - iOS 14+：WidgetKit 展示"今日支出 / 本月结余"；
  - Android：AppWidgetProvider 同上；
  - 点击 Widget 深链跳转到"新建记账页"。
- **验证**：
  - Widget 数据与 App 内数据一致（延迟 ≤ 1 分钟）。
  - 深链命中。

---

## 阶段 17 · 国际化、可访问性与合规（Phase 17 — i18n, A11y, Compliance）

### Step 17.1 i18n 骨架
- **做什么**：引入 `arb` 文件；当前仅简中，但所有 UI 文本必须经本地化获取（为将来扩展）。
- **验证**：grep 检查无硬编码中文残留（除代码注释与调试日志外）。

### Step 17.2 可访问性
- **做什么**：
  - 所有可点击控件尺寸 ≥ 44×44pt；
  - 图片/图标提供 `Semantics` label；
  - 支持系统字号缩放到 130%。
- **验证**：打开 iOS / Android 的"字体更大"测试关键页可用。

### Step 17.3 合规文案
- **做什么**：首次启动展示"隐私政策与用户协议"同意弹窗；"我的 → 关于 → 隐私政策"可随时查看。文案按国内 PIPL + 欧盟 GDPR 通用要点：数据项、用途、存储位置、共享方。
- **验证**：同意前 App 不进入主界面；拒绝退出应用。

---

## 阶段 18 · 发版与验收（Phase 18 — Release）

### Step 18.1 图标与启动页
- **做什么**：准备 iOS/Android 应用图标（含 iOS 多尺寸 + Android adaptive icon）；启动页使用"兔团子"吉祥物 + 奶油底色。
- **验证**：在两端真机上冷启动观感一致。

### Step 18.2 端到端回归
- **做什么**：手工跑完以下 10 条关键路径并签收：
  1. 首次启动 → 引导 → 默认账本记一笔；
  2. 切主题 / 字号；
  3. 新建账本 + 切换；
  4. 设预算 → 超预算看到红色提醒；
  5. 统计页四种图表正常；
  6. 开启云同步 → 两设备互同步；
  7. 导出 `.bbbak` → 新设备导入恢复；
  8. 软删除 → 垃圾桶恢复；
  9. 启用应用锁 → 生物识别解锁；
  10. 断网 24 小时后恢复，数据无丢失。
- **验证**：逐条签收并在 `memory-bank/progress.md` 勾选。

### Step 18.3 性能与崩溃验收
- **做什么**：
  - Flutter DevTools 记录冷启动 < 1.5s（中端机）、记账保存 < 200ms、同步 100 条 < 2s；
  - 注入 10 万条流水，首页滚动仍 ≥ 55 fps；
  - 运行 `flutter analyze`、`flutter test`（覆盖率 ≥ 60%）全部通过。
- **验证**：达到所有指标后可进入发布构建。

### Step 18.4 发布构建
- **做什么**：
  - Android：`flutter build appbundle --release` 并完成签名；
  - iOS：`flutter build ipa --release`；
  - 打 tag `v1.0.0`，同步更新 `pubspec.yaml` 版本。
- **验证**：
  - 构建产物大小 Android ≤ 25MB、iOS ≤ 60MB；
  - 真机安装 release 包能走完 Step 18.2 的 10 条关键路径。

---

## 变更与追踪规则

1. **任何阶段完成**后，必须往 `memory-bank/progress.md` 追加形如 `- [x] Phase N · 标题（完成日期）` 的一行。
2. **任何架构层面的决策偏差**（例如换掉一个库、调整表结构），必须同步更新 `memory-bank/architecture.md`，并在 `memory-bank/design-document.md` 的对应章节追加"修订记录"块。
3. **任何步骤的"验证"不通过**都视为该步骤未完成，禁止跳步；允许把大步骤拆成两个小步骤，但不允许合并步骤而丢弃验证。
4. **禁止**在未完成所在阶段的加密/同步/垃圾桶依赖时发布任何"可选打开"的对应开关，避免产生无法回滚的脏数据。
