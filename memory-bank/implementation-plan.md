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

### Step 3.6 首页流水搜索
- **做什么**：点击首页顶栏的搜索图标，跳转到一个新的搜索页面 `/record/search`。页面包含搜索框、日期范围、类型、金额范围等筛选器。搜索关键词将匹配流水的备注、分类名、账户名。
- **验证**：
  - 单元测试：搜索"午餐"能找到备注为"和同事的午餐"的流水。
  - UI 测试：设置金额范围 100-200，结果列表中的流水金额都在此范围内。
  - 搜索页能正确处理空结果，显示"没有找到相关流水"的提示。

### Step 3.7 首页月份选择器优化
- **做什么**：点击首页顶栏的月份显示区域，弹出一个自定义的年月选择器，允许用户快速跳转到任意年份和月份。左右切换按钮功能保持不变。
- **验证**：
  - UI 测试：在选择器中选择 "2025-01"，首页数据应刷新为 2025年1月的统计和流水。
  - 选择器弹出后，默认高亮当前选择的月份。

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

## 阶段 10 · 多后端云同步（Phase 10 — Multi-Backend Sync）

V1 采用**账本快照模型**（与「蜜蜂记账云同步方案.md」一致）：账本视为一个 JSON 文件，每次上传/下载是整体覆盖。**不**实现「sync_op 队列 + LWW 增量合并」（保留为 V2 形态——届时通过同一个 `SyncService` 接口替换实现，UI 不需要改）。

后端覆盖 4 种：iCloud（仅 iOS）/ WebDAV / S3 / Supabase，由 vendored 子包 `packages/flutter_cloud_sync*` 提供（来自 BeeCount）。**故意不开启 BeeCount Cloud**——它是 BeeCount 内部服务，本项目用户用不到。

### Step 10.1 + 10.2 同步抽象 + 配置 UI + 快照引擎（已完成 2026-05-03）

- **做什么**：
  - 在 `lib/features/sync/` 下定义 `SyncService` 抽象（`upload(ledgerId)` / `downloadAndRestore(ledgerId)` / `getStatus(ledgerId, {forceRefresh})` / `deleteRemote(ledgerId)` / `clearCache()`，全部用 `String ledgerId`）；提供 `LocalOnlySyncService` 兜底（未配置时所有写操作抛 `UnsupportedError`，状态返回 `notConfigured`）与 `SnapshotSyncService` V1 实现（包装包内 `CloudSyncManager<LedgerSnapshot>`）。
  - `snapshot_serializer.dart`：`LedgerSnapshot` 数据类（`version: 1`，含 ledger / categories / accounts / transactions / budgets + `exportedAt + deviceId`，`fromJson` 校验版本号）+ `LedgerSnapshotSerializer`（`DataSerializer<LedgerSnapshot>` 实现，`fingerprint = sha256(utf8(data))`）+ `exportLedgerSnapshot` / `importLedgerSnapshot` 顶层纯函数。
  - 「我的 → 云服务」页（`cloud_service_page.dart`）：顶部 `_SyncStatusCard`（标题行 + 状态行 + 操作行：上传 FilledButton / 下载 OutlinedButton 二次确认 / 删除云端 IconButton 二次确认；`_busy` 状态守门防双击）+ 4 个后端选择卡 + 配置对话框。
  - Riverpod 链（普通 `Provider` / `FutureProvider`，不走 `@riverpod` 代码生成）：`cloudServiceStoreProvider → activeCloudConfigProvider → 3 个 backend 配置 provider → cloudProviderInstanceProvider →  authServiceProvider → syncServiceProvider`。切换激活后端 / 保存配置后调 `ref.invalidate(activeCloudConfigProvider)` 链式重建。
  - **不动 schema**：云配置由 `flutter_cloud_sync` 包通过 `SharedPreferences` 持久化；user_pref 不增列，schema 保持 v8（Phase 11 附件云同步会升到 v10，仅改 `attachments_encrypted` BLOB 内 JSON shape，不动云配置存储）。代价：配置在 Android 是明文 XML、iOS 是 NSUserDefaults plist——V1 接受这个权衡，因为 4 个 backend 均为用户自有空间，配置存储加密价值低于改动成本。
  - 路径约定 `users/<userId>/ledgers/<ledgerId>.json`——Supabase 的 userId 来自 `auth.uid()`（RLS 策略依赖）；其他后端无 auth，userId 退化为 `deviceId`。
  - `importLedgerSnapshot` **故意绕过 repository 层 save**——避免 import 触发 sync_op 队列累积，形成「刚下载的数据立刻又被排队上传」循环；直接走 `db.batch + InsertMode.insertOrReplace`。categories / accounts 是全局资源，只 upsert 不 delete（避免破坏其他账本依赖）。
  - 新增依赖：`crypto: ^3.0.3`（用于 SHA256 指纹）。
- **验证**：
  - 「我的 → 云服务」可见 4 个后端卡片（iOS 才有 iCloud），active 默认是 local，状态卡不显示。
  - 配置任一非 iCloud 后端 → 切换激活 → 状态卡显示。点上传 → SnackBar「已上传到云端」。点刷新 → 状态变「已同步」。
  - 在另一台设备配同样的后端 → 点下载（二次确认）→ SnackBar「已恢复 N 条流水」→ 切到记账页能看到从云端来的流水。
  - 断网时上传 → SnackBar「操作失败：…」，本地数据不受影响。
  - 点删除云端（二次确认）→ SnackBar「云端备份已删除」→ 状态变「云端无备份」。
  - 校验 `snapshot.ledger.id == 当前 ledgerId`，防止误恢复别人的备份。

### Step 10.3-10.6 各 backend 实现（由 vendored 包提供，无需重做）

由 `packages/flutter_cloud_sync_supabase / _webdav / _icloud / _s3` 实现 `CloudProvider` 接口，本项目层不需要单独实施。`provider_factory.createCloudServices(config)` 根据 active config 实例化对应 `CloudProvider` + `CloudAuthService`。配置项与「蜜蜂记账云同步方案.md」对齐：

| 后端 | 必填配置 | Auth 方式 | 备注 |
| :-- | :-- | :-- | :-- |
| **Supabase** | URL + anon key | 邮箱/密码 `signUp` / `signIn` | RLS 策略约束 `(storage.foldername)[2] = auth.uid()` |
| **WebDAV** | URL + username + password + remotePath | 无（凭据直连） | 路径下用 `users/<deviceId>/...` 前缀统一目录 |
| **iCloud** | 无（仅 iOS） | 系统 Apple ID | 应用私有沙盒，零配置 |
| **S3** | endpoint + region + accessKey + secretKey + bucket + useSSL + port | AK/SK 签名 | 覆盖 Cloudflare R2 / AWS S3 / MinIO 等 |

子包内部仍带 `BeeCountCloudProvider`（独立 BeeCount 后端的实现），**项目层未暴露 UI 入口**，视为死代码保留。

### Step 10.7 同步触发与 UI 状态

- **做什么**：
  - 当前仅手动触发（云服务页按钮）。后续接入：
    1. App 启动（main bootstrap 链中追加一次后台 `upload` / `getStatus`）；
    2. 前台恢复（`WidgetsBindingObserver.didChangeAppLifecycleState == resumed`）；
    3. 记账后防抖（保存流水后 5 秒静默触发 `upload`）；
    4. 首页下拉刷新；
    5. 定时器（每 15 分钟一次，仅前台）。
  - 统一通过 `ref.read(syncServiceProvider.future).then((s) => s.upload(...))` 调度。
  - 在首页顶栏增加同步状态指示（小图标 + 上次同步时间），点击跳转「我的 → 云服务」。
- **验证**：
  - 断网时手动下拉应显示「网络不可用」。
  - 同步过程中 UI 显示「同步中…」。
  - 成功或失败后 UI 状态更新。
  - 后台恢复时不重复触发（前一次未完成时跳过）。

---

## 阶段 11 · 附件云同步（Phase 11 — Attachment Cloud Sync）

> **2026-05-03 重构背景**：原 Phase 11 设计的「快照加密 + 派生密钥 + 同步码」整段废止。理由：① Phase 10 的 4 个 backend（iCloud / WebDAV / S3 / Supabase）云端均为**用户自有空间**，明文上传可接受，加密层是过度工程；② 用户主动跳过原 Phase 11 直接做了 Phase 12；③ 真正未解决的痛点是「换设备图片丢失」——`attachments_encrypted` BLOB 当前只装本地绝对路径数组，文件本体根本没上云。本阶段只解决这件事：让附件文件本体跟随快照同步到 4 个后端，新设备懒加载下载，明文直传无加密。
>
> **与 Phase 10 的关系**：本阶段不动 `LedgerSnapshot` JSON 结构、不动 `SyncService` / `SyncTrigger` 接口、不引入 sync_op 增量队列。所有改动收敛在「`attachments_encrypted` BLOB shape 升级 + 附件文件本体走对象存储」两件事上。
>
> **不做的事**（决策记录）：
> - ❌ 加密：云是用户自有的，明文足够。后人若要加密层，作为独立 Phase 加在本阶段之上。
> - ❌ 同步码 / refresh token：Phase 10 已用 `flutter_cloud_sync` 包通过 SharedPreferences 持久化云配置，跨设备恢复靠用户手动重输配置（V1 可接受）。
> - ❌ 缩略图预生成：直接传原图；客户端在保存时若 > 10MB 转 JPEG q=85 压缩。
> - ❌ 列名重命名：`transaction_entry.attachments_encrypted` 列名保留（Phase 11 之前所有代码、迁移脚本、测试都引用此名）；语义改为"附件元数据 JSON 数组（明文）"——文档与注释里强调"列名是历史遗留，内容已不加密"。

### Step 11.1 二进制存储扩展（CloudStorageService.uploadBinary）
- **背景**：`packages/flutter_cloud_sync/lib/src/core/storage_service.dart` 的 `CloudStorageService.upload` 当前签名只接受 `String data`——给 JSON 快照用足够，给图片用就要 base64 包装（+33% 体积、两端编解码开销）。本步直接扩展接口。
- **做什么**：
  - 在 `CloudStorageService` 抽象类加 3 个方法（保留旧 `upload` 不动以维持 JSON 快照路径不变）：
    ```dart
    Future<void> uploadBinary({
      required String path,
      required Uint8List bytes,
      String? contentType,           // image/jpeg 等，用于 HTTP Content-Type 头
      Map<String, String>? metadata,
    });
    Future<Uint8List?> downloadBinary({required String path}); // 不存在返回 null
    Future<List<CloudFile>> listBinary({required String prefix}); // GC sweep 用
    ```
    > `delete` / `exists` / `getMetadata` 复用现有方法，不区分二进制 vs 文本。
  - 4 个 storage service 实现类各加二进制方法：
    - `SupabaseStorageService`：`storage.from(bucket).uploadBinary(path, bytes, fileOptions: FileOptions(upsert: true, contentType: ...))` / `download(path)` 拿 `Uint8List` / `list(prefix)`。
    - `S3StorageService`：用 `minio.putObject(bucket, key, Stream.value(bytes), bytes.length, metadata: {...})` / `getObject` 流式读全 / `listObjects(prefix, recursive: true)`。
    - `WebDAVStorageService`：`client.write(path, bytes)` / `client.read(path)` / `client.readDir(prefix)`。WebDAV 需要先 `client.mkdirAll(parentDir)` 创建父目录，封装在 service 内一次完成。
    - `ICloudStorageService`：iCloud 走 `icloud_storage.upload(filePath: tempFile, destinationRelativePath: ...)`——iCloud SDK 不接受字节流，要求落到临时文件后再 upload；service 内部 `Directory.systemTemp.createTemp` + `writeAsBytes` + 调 SDK + 删临时文件。
    - 其余 mocks（`MockStorageService` / `MockCloudStorageService` / `BeeCountCloudStorageService` 死代码）按编译要求加占位实现（`UnsupportedError`）。
  - 路径约定（与 Phase 10 现有约定对齐）：
    - 备份：`users/<uid>/ledgers/<ledgerId>.json`（**不变**）
    - 附件：`users/<uid>/attachments/<txId>/<sha256><ext>`，`<ext>` 保留原始扩展名（`.jpg` / `.png` / `.heic` / `.pdf` 等），方便服务器侧 Content-Type 推断与用户在 cloud console 直接预览。
    - `<uid>` 与现有 `_path()` 方法一致：Supabase 走 `auth.uid()`、其它后端取 `deviceId`。
  - 路由 provider：`@Riverpod(keepAlive: true) Future<CloudStorageService?> attachmentStorageService(...)` → 直接返回 `cloudProviderInstanceProvider` 拿到的 `provider.storage`（不需要再造一层）。无云端配置时返回 null，调用方走"附件仅本地"分支。
- **验证**：
  - 单元测试：4 个 storage service 各跑一遍 `uploadBinary` → `downloadBinary` 往返，bytes byte-equal（mock 真实 backend 用 `MockStorageService`；CI nightly 跑真 Supabase）。
  - 单元测试：`downloadBinary` 对不存在的 path 返回 null（不抛异常）。
  - 单元测试：`listBinary(prefix)` 返回 `CloudFile.path` 列表，命中规则路径，命中数与 putObject 次数一致。
  - `flutter_cloud_sync` 包内的 storage_service_test.dart（若存在）补充二进制相关用例；不存在则在主项目 `test/features/sync/binary_storage_smoke_test.dart` 写一遍 mock。

### Step 11.2 附件元数据 schema v10 迁移与上传管线
- **背景**：`attachments_encrypted` BLOB 当前装的是 `jsonEncode(["<docs>/attachments/<tx>/x.jpg", ...])`——纯本地路径数组。换设备后这些路径不存在，UI 也无法找回文件。本步把 BLOB shape 升级为含远端 key 的对象数组，并接入上传管线。
- **做什么**：
  - **schema v9 → v10 迁移**（`lib/data/local/app_database.dart::onUpgrade` 加 `if (from < 10)` 分支）：
    - 不加列、不改列类型，只改 BLOB 内 JSON shape：
      ```json
      // 旧 v9（明文路径数组）
      ["<docs>/attachments/tx-abc/IMG_1.jpg", "<docs>/attachments/tx-abc/IMG_2.jpg"]

      // 新 v10（明文元数据数组）
      [
        {
          "remote_key": null,           // 升级时一律 null，等下次同步上传后回填
          "sha256": null,               // 同上
          "size": 12345,                // File.lengthSync()，迁移时计算
          "original_name": "IMG_1.jpg",
          "mime": "image/jpeg",         // 由扩展名推断（lookupMimeType）
          "local_path": "<docs>/attachments/tx-abc/IMG_1.jpg"
        }
      ]
      ```
    - 迁移脚本：`select id, attachments_encrypted from transaction_entry where attachments_encrypted is not null` → 解码旧数组 → 包装成新 shape → `update transaction_entry set attachments_encrypted = ? where id = ?`。本地文件不存在时 `size = 0` + 加 `"missing": true` 标记（UI 上显示占位）。
    - schemaVersion 从 v9 升 v10。
  - **领域层数据类**：新建 `lib/domain/entity/attachment_meta.dart`：`AttachmentMeta`（不可变，`==` / `hashCode` / `toJson` / `fromJson`），字段与上面 JSON 一一对应。`record_new_providers.dart::_encodeAttachmentPaths` / `_decodeAttachmentPaths` 重命名为 `_encodeAttachmentMetas` / `_decodeAttachmentMetas`，内部从 `List<String>` 改为 `List<AttachmentMeta>`；`RecordFormData.attachmentPaths` 同步改名为 `attachmentMetas`；UI 渲染用 `meta.localPath ?? meta.remoteKey` 决策走本地还是触发下载。
  - **上传管线**（新建 `lib/features/sync/attachment/attachment_uploader.dart`）：
    - `Future<List<AttachmentMeta>> uploadPending(List<AttachmentMeta> metas, {required String txId, required String uid})`：对每个 `meta.remoteKey == null` 的项 → 读 `meta.localPath` 字节 → 算 sha256（明文 hash）→ 拼 `key = 'users/$uid/attachments/$txId/$sha256$ext'` → 调 `uploadBinary(path: key, bytes: bytes, contentType: meta.mime)` → 回填 `remoteKey / sha256 / size`。
    - **幂等保障**：上传前先 `exists(path)` 命中即跳过；同 sha256 视为同一对象，`uploadBinary` 走 upsert 语义。
    - **不阻塞主流程**：`RecordForm.save()` 走完本地 DB 写入后照常 `scheduleDebounced()` 触发快照同步——本步在 `SnapshotSyncService.upload(ledgerId)` 内部，**先**扫该账本下所有 `remoteKey == null` 的附件 `uploadPending`，再上传 JSON 快照。这样 B 设备拉到的快照里所有附件都已有 `remoteKey`。
    - **错误处理**：单个附件上传失败（网络中断 / 配额超限）→ 跳过该附件、继续后面的 + 把失败 meta 留 `remoteKey = null`，记 log（`debugPrint`）。整体快照上传**不**因附件失败而中断（用户的流水数据优先保住，附件下次同步重试）。
  - **超限保护**：保存图片到本地时（`record_new_providers._copyToTxDir`）若单文件 > 10MB，先用 `image` 包转 JPEG q=85 → 落盘 → 真实 size 再决定 `meta.size`。设置项暂不暴露（V1 硬编码常量 `kMaxAttachmentBytes = 10 * 1024 * 1024`）。
- **验证**：
  - 单元测试：v9 → v10 迁移：旧 BLOB `["a.jpg","b.jpg"]`（含本地存在与不存在两种）升级后 shape 正确、`size` / `mime` / `original_name` 推断正确、不存在的有 `"missing": true`。
  - 单元测试：`AttachmentMeta` toJson/fromJson 往返；带 null 的 `remoteKey` 与 `sha256` 不丢。
  - 单元测试：`uploadPending` 同 sha256 调两次只产生一次 `uploadBinary`（mock storage 计数）。
  - 单元测试：`uploadPending` 中一个文件失败不影响其他文件（`failure` 项 `remoteKey` 仍 null，`success` 项已回填）。
  - 集成测试：保存带 2 张图的流水 → 触发 `SyncTrigger.scheduleDebounced` → `SnapshotSyncService.upload` 完成后 backend 上 `users/<uid>/attachments/<txId>/` 目录有 2 个对象 + JSON 快照里 `attachments_encrypted` 解码后 `remoteKey` 全部已填。
  - widget 测试：`record_new_page` 选 12MB 图片 → 落盘后实际 size < 10MB（被 JPEG 压缩）。

### Step 11.3 懒下载与本地缓存
- **做什么**：
  - 新建 `lib/features/sync/attachment/attachment_downloader.dart`：
    - `Future<File?> ensureLocal(AttachmentMeta meta, {required String txId})`：
      1. 若 `meta.localPath != null` 且 `File(localPath).existsSync()` → 直接返回 File。
      2. 否则按 `meta.remoteKey` 调 `downloadBinary(path: remoteKey)` → 写到 `<cache>/attachments/<txId>/<sha256><ext>` → 把 `local_path` 写回 DB（让下次直接命中）→ 返回 File。
      3. 网络失败 / 远端 404 → 返回 null（不抛异常），UI 显示「📎 附件未同步」占位。
    - `meta.remoteKey == null` 且 `localPath` 也不存在 → 直接返回 null（数据丢失，最终态）。
  - **缓存目录**：`getApplicationCacheDirectory()` 而非 documents——iOS 系统在空间紧张时会自动清理 cache，下次访问再懒下载即可。容量上限 500MB（常量 `kAttachmentCacheLimitBytes`）；超限按文件 mtime 升序淘汰，至少保留最近 7 天访问的。
    - **不**新增 schema 列追踪缓存大小——启动时扫一次目录算 `Directory.list` 的总 size，性能足够（500MB 上限 → 几百个文件级别）。
  - **UI 渲染调整**：
    - `RecordDetailSheet` 与流水列表的缩略图组件改为 `FutureBuilder<File?>`；loading 显示骨架屏，`null` 显示占位「📎 附件未同步，下拉刷新重试」，成功显示 `Image.file`。
    - 新建 `lib/features/record/widgets/attachment_thumbnail.dart`（`ConsumerWidget`），统一封装上述 FutureBuilder，所有附件渲染点（流水详情、流水列表、编辑表单）都用它。
    - **prefetch 策略**：流水列表滚动到含附件的 tile 时 fire-and-forget 调 `ensureLocal`（限并发 3，用全局 `Pool` 实例避免冷启动同步把网卡打满）。失败静默；下次滚动到时再触发。
  - **设置入口**：「我的 → 附件缓存」新增 `AttachmentCachePage`：显示当前占用 + "清除缓存"按钮（清空 cache 目录，不动 documents 与远端）。
- **验证**：
  - 单元测试：`ensureLocal` 在 `localPath` 已存在时不调 storage（mock 验证 0 次 downloadBinary 调用）。
  - 单元测试：`remoteKey == null && localPath == null` 直接返回 null。
  - 单元测试：mock storage 抛网络异常 → `ensureLocal` 返回 null（不抛异常，UI 不崩）。
  - 集成测试：B 设备 fresh install + 配置同 backend + 点云服务页"下载" → 流水列表打开**不立即下载所有附件**（mock storage 调用数 = 0）→ 滚动到含附件的 tile 触发 prefetch → 点详情正常显示图片。
  - 集成测试：填满 cache 到 600MB → 触发淘汰 → 总 size < 500MB 且最新 7 天文件保留。
  - widget 测试：`AttachmentThumbnail` 三态（loading / null / 成功）UI 都不崩。

### Step 11.4 软删除联动、GC 与回填迁移
- **做什么**：
  - **软删除联动**（不立刻删远端）：流水 `deleted_at` 写入时**只清本地 cache**（cache 目录的 `<txId>/` 子目录），**保留** documents 目录原图（垃圾桶可恢复）+ **保留** backend 远端对象。理由：30 天内若用户从垃圾桶恢复，附件还在；30 天后由 GC 统一硬删。`lib/features/trash/trash_attachment_cleaner.dart` 当前只清 documents——本步把 documents 清理推迟到硬删，软删时改清 cache 而非 documents。
  - **硬删 GC 扩展**（在现有 `lib/features/trash/trash_gc_service.dart` 基础上）：
    - `deleted_at < now - 30d` 的流水触发硬删时 → 删 documents 文件 + 调 `attachmentStorage.delete(path: meta.remoteKey)` 删远端对象。删失败不阻塞硬删（log error，下次孤儿 sweep 兜底）。
    - **孤儿对象 sweep**（每 7 天一次，触发于 startup +5 分钟，与现有 trash GC 同生命周期）：调 `listBinary(prefix='users/<uid>/attachments/')` → 与 DB 中所有 `attachments_encrypted` 解码后的 `remoteKey` 集合做 diff → 远端有但 DB 无的 → 按 `lastModified > now - 30d` 保留宽限期，超期再 `delete`。
  - **存量数据回填**（schema v10 迁移后第一次同步）：
    - v10 升级时所有 meta 的 `remoteKey` 都是 null。下一次 `SnapshotSyncService.upload` 走到 Step 11.2 的 `uploadPending` 分支会自动回填——**无需额外代码**，是上传管线的自然行为。
    - UI 提示：云服务页 `_SyncStatusCard` 在「正在同步…」副标题下加附件进度（`已同步附件 X/Y`），由 `attachmentUploader` 通过 `Stream<AttachmentUploadProgress>` 推送。回填完成后 SnackBar「附件已全部上云」。
  - **跨 backend 切换**：用户从 Supabase 切到 WebDAV 时（`activeCloudConfigProvider` 重建）→ 弹确认对话框「切换后新附件将上传到 WebDAV，已上传到 Supabase 的附件不会跨设备访问。是否把已有附件迁移到新 backend？（耗时较长）」。选迁移 → 把所有 `remoteKey != null` 的 meta `remoteKey` 清为 null + `localPath` 保留 → 下次同步时由 `uploadPending` 重新上传到新 backend；旧 backend 上的对象 7 天后由孤儿 sweep 清掉。
- **验证**：
  - 单元测试：流水软删后 cache 目录被清，documents 目录与 backend 对象均保留。
  - 单元测试：硬删触发时 `delete` 调用次数 = 流水的 `attachments_encrypted` meta 数。
  - 集成测试：v9 升级到 v10 后启动 → 触发同步 → 所有附件被上传，DB 中 `remoteKey` 全部回填 + UI 进度条正常推进。
  - 集成测试：A 设备删流水（30 天后硬删）→ 同步到 B → B 拉快照后该流水消失 → 7 天后孤儿 sweep 把 backend 对象也清掉。
  - 集成测试：A 设备从 Supabase 切到 WebDAV + 选迁移 → 所有附件在 WebDAV 上可见 + Supabase 上 7 天宽限期后被孤儿 sweep 清理。
  - 端到端：A 设备本地附件丢失（手动删 documents 目录）→ 触发上传队列 → 跳过该 meta（不报错、不清 `remoteKey`）+ 写 log；B 设备此时仍可正常 download（远端对象之前已存在）。

> **依赖与风险提示**：
> - Step 11.1 需要在 `packages/flutter_cloud_sync*` 4 个子包加二进制方法实现；这是 vendored 包，可直接改源码并提 PR 到上游（或就地维护 fork）。**无需新增 pubspec 依赖**——4 个 backend SDK 都已在子包里就位。
> - Step 11.2 schema v10 迁移**不可逆**（旧明文路径数组 → 元数据对象数组）。降级到 v9 会让 v10 插入的对象数组被旧代码当作"非法路径"处理，UI 不崩但附件不显示。约定：v10 上线后用户不允许降级。
> - 所有附件均为**明文**上传——用户的云端账户被攻破或 backend 被入侵 = 图片可被读。文档与设置项需明示「附件不加密。请确保使用受信任的云端账户。」如果未来要加密，作为独立 Phase（建议命名 Phase 11+），对象内容用 AES-GCM 包装、key 派生与本阶段独立设计，**不**在本阶段做。
> - Supabase 后端：用户需先跑 `docs/supabase-setup.sql` 创建 `attachments` bucket + RLS 策略。这步是手动一次性配置，App 内不自动执行（避免持有 service_role key）。其他 3 个 backend（iCloud / WebDAV / S3）无需后端配置。
> - 单测覆盖率门槛：附件管线总用例数预估 25+（4 binary storage 实现 × 2-3 用例 + uploader 4 + downloader 4 + GC 4 + 迁移 3），起步时若赶进度优先保证 uploader / downloader / 迁移三块。

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
- **做什么**：准备 iOS/Android 应用图标（含 iOS 多尺寸 + Android adaptive icon）；启动页使用自定义 png。
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
  - Android：`flutter build apk --release`或`flutter build appbundle --release` 并完成签名；
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
