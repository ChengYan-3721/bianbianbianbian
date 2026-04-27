# 边编边变产品设计文档

| 项目 | 内容 |
| :-- | :-- |
| 文档版本 | v1.0 |
| 创建日期 | 2026-04-19 |
| 技术栈 | Flutter 3.x（iOS / Android） |
| 后端 | Supabase（官方托管 + 用户自建，双模兼容） |
| 参考产品 | 叨叨记账（UI / 交互）、BeeCount（开源 Flutter 记账 + Supabase 同步方案） |

---

## 1. 产品概述

### 1.1 一句话定位
一个"**离线优先、温馨可爱、云同步可选**"的个人/家庭记账 App，主打轻量、无账号门槛、数据主权在用户手中。

### 1.2 产品理念
- **离线优先（Offline-First）**：所有记账操作在本地完成，不依赖网络；云同步是可选增强能力。
- **零注册门槛**：App 开箱即用，用户不需要注册手机号 / 邮箱 / 微信；想要多设备同步时，填一串"同步凭证"即可。
- **数据主权**：数据文件始终保存在用户本地；云端只是一份加密备份/镜像。支持导出完整数据、支持自建 Supabase。
- **温馨可爱**：主视觉参考叨叨记账的手绘 / 奶油色 / 小动物元素，让记账不再是冷冰冰的数字。

### 1.3 目标用户
| 用户画像 | 主要诉求 | 使用场景 |
| :-- | :-- | :-- |
| 上班族 小周（25-35 岁） | 按月预算、工作与生活分账本 | 早上通勤记地铁、午饭记餐费 |
| 宝妈 小李（28-40 岁） | 家庭开销、多币种（跨境代购） | 记录宝宝奶粉尿不湿、记旅行消费 |
| 学生 小吴（18-24 岁） | 免费、颜值高、不强制登录 | 记饭卡、记奶茶 |
| 极客用户（任意） | 数据主权、自建后端、开源 | 连接自己的 Supabase，跨设备同步 |

### 1.4 非目标
- 不做企业记账 / 报销 / 多人协同账本（V1 不支持）。
- 不对接银行卡 / 支付宝 / 微信账单的自动导入（V1 不支持自动抓账单）。
- 不做理财 / 基金 / 股票资产跟踪。

---

## 2. 竞品对比

| 维度 | 叨叨记账 | 钱迹 | BeeCount | **边边记账（本产品）** |
| :-- | :-- | :-- | :-- | :-- |
| 主要交互 | 对话式聊天 | 传统表单 | 传统表单 | **传统表单 + 顶部快捷文本条（混合 AI）** |
| 视觉风格 | 温馨可爱 | 极简 | 极简 Material | **温馨可爱（近叠叠）** |
| 离线使用 | ✅ | ✅ | ✅ | ✅ |
| 云同步 | 官方账号 | 官方账号 | 用户自建 Supabase | **官方托管 + 自建 Supabase 双模** |
| 多账本 | ❌ | ✅ | ✅ | ✅ |
| 多币种 | ❌ | ❌ | 部分 | ✅ |
| 数据导入导出 | 部分 | ✅ | ✅ | ✅ |
| 应用锁 / 加密 | ❌ | 部分 | ❌ | ✅ |
| 开源 | ❌ | ❌ | ✅ | 待定 |

### 2.1 差异化卖点
1. **"一串字符即同步"**：不注册手机号，用户只要记住一段"同步凭证"（邮箱 + 自设密码，或导出的同步码），换手机时输入即可恢复全部数据。
2. **双模后端**：小白用官方托管的 Supabase，极客可一键切换到自建实例。
3. **账本 × 币种 × 加密** 三件套一次满足。

---

## 3. 核心设计原则

1. **本地 SQLite 为单一事实来源（Source of Truth）**，云端是可选镜像。
2. **所有写操作先写本地，再异步同步到云端**；网络不可用时无感继续使用。
3. **每条记录带 `updated_at` + `device_id` + `deleted_at`（软删除）**，用于后续冲突解决与垃圾桶恢复。
4. **端到端思路上的"加密可选"**：敏感字段（备注、附件）在上传云端前用用户派生密钥加密，Supabase 只看得到密文。
5. **视觉上**：大圆角、奶油白底、手绘插画、分类图标一律圆形贴纸风。

---

## 4. 功能架构总览

```
边边记账
├─ 记账（首页）
│   ├─ 当日流水列表
│   ├─ 顶部快捷输入条（可选自然语言输入 → 混合 AI 解析）
│   ├─ 底部"+"按钮 → 传统表单式记账页
│   └─ 账本切换器（顶栏下拉）
├─ 账本
│   ├─ 账本列表（生活 / 工作 / 旅行 / 自定义）
│   ├─ 新建 / 编辑 / 删除 / 归档账本
│   └─ 账本级设置（默认币种、封面、成员【预留】）
├─ 统计
│   ├─ 按月 / 年 / 自定义区间
│   ├─ 收支折线、分类饼图、收支排行
│   └─ 预算进度（若设置）
├─ 资产（V1 轻量版：只做"账户"标签）
│   ├─ 现金 / 银行卡 / 信用卡 / 其他
│   └─ 仅用于分类统计，不做复杂对账
├─ 我的
│   ├─ 云同步（开关 + 状态）
│   ├─ 同步凭证（绑定 / 切换 / 导出）
│   ├─ 预算设置
│   ├─ 分类管理
│   ├─ 多币种与汇率
│   ├─ 导入 / 导出
│   ├─ 垃圾桶
│   ├─ 应用锁与加密
│   ├─ 主题与外观
│   └─ 关于与帮助
└─ 系统级
    ├─ 提醒（每日记账提醒）
    ├─ 小组件（Home Screen Widget）
    └─ 应用锁触发
```

---

## 5. 详细功能设计

### 5.1 记账（核心高频）

#### 5.1.1 首页（流水页）
- **顶栏**：账本切换下拉 + 月份切换 + 搜索。
- **数据卡片**：本月收入 / 支出 / 结余，三色气泡。
- **快捷输入条**（顶部）：单行文本框"写点什么，我来帮你记 🐰"，支持：
  - 纯文字 → 本地规则解析（正则 + 关键词词典）尝试识别金额 / 分类 / 备注；
  - 解析失败 或 用户点击"✨ AI 识别" → 调用大模型 API（用户在设置里填 key）；
  - 解析结果先弹出"确认卡片"，用户可改再保存。
- **流水列表**：按日期倒序分组，每条显示分类图标、备注、金额、账户。
- **长按流水**：编辑 / 复制 / 删除（进垃圾桶）/ 分享。
- **FAB 悬浮按钮**：点击跳转到传统表单式记账页（主要录入入口）。

#### 5.1.2 表单式记账页（主要录入入口）
```
┌────────────────────────────┐
│  [收入]  支出   转账         │  ← Tab
├────────────────────────────┤
│  金额：          ¥ 0.00     │
├────────────────────────────┤
│  分类（网格，手绘图标）      │
│  🍚 餐饮  🚇 交通  🛒 购物 │
│  🏠 住房  🎁 娱乐  💊 医疗 │
│  👕 服饰  📚 学习  ✈️ 旅行 │
│  [更多…]                    │
├────────────────────────────┤
│  账户：💳 工商卡 ▾           │
│  账本：📒 生活 ▾             │
│  时间：今天 20:18            │
│  备注：给猫买罐头             │
│  图片：[+]                   │
├────────────────────────────┤
│  数字键盘（0-9 . +/- ✔）     │
└────────────────────────────┘
```
- 金额支持 `12.5+3` 这类算式。
- 分类默认提供 18 个常用，用户可在"我的 → 分类管理"增删改并自定义图标与颜色。
- "再记一笔"开关：保存后自动打开空表单，便于连续输入。
- 图片附件：存本地私有目录；同步时先加密再上传 Supabase Storage。

#### 5.1.3 混合 AI 解析细节
| 步骤 | 处理方 | 说明 |
| :-- | :-- | :-- |
| 1. 金额提取 | 本地正则 | 支持 `30`、`¥30`、`30元`、`三十块`（数字 + 常见中文数字） |
| 2. 分类识别 | 本地词典 | 如 "午饭/晚饭/外卖" → 餐饮；"地铁/打车/高铁" → 交通 |
| 3. 时间识别 | 本地 | "昨天中午"、"上周五" 等相对时间解析到具体日期 |
| 4. 置信度判断 | 本地 | 金额未识别 or 分类置信度 < 阈值 → 提示 AI 增强 |
| 5. AI 增强 | 云端 LLM（可选） | 用户在设置中填入 OpenAI / Claude / DeepSeek 兼容 API，按需调用 |

**用户无 API Key 时**：只走本地，仍可用，仅分类识别能力弱一些。

### 5.2 多账本

- 默认账本：📒 生活。
- 用户可创建多个账本，每个账本：
  - 独立名称 / 封面 / emoji。
  - 独立默认币种。
  - 独立分类（可选择"复制自其他账本"）。
  - 独立流水集合。
- 统计页、预算、资产均在"当前账本"维度内聚合。
- 账本可归档（不删除，只隐藏）。
- V1 不做多人协作账本（预留字段 `owner_id`、`members[]`）。

### 5.3 统计

- **时间维度**：本月 / 上月 / 本年 / 自定义区间。
- **图表**：
  - 收支折线（按日）；
  - 支出分类饼图（Top 6 + 其他）；
  - 收支排行榜（按分类金额）；
  - 日历热力图（每日支出深浅）。
- **预算对比**：若设置了预算，饼图旁显示进度环。
- **导出**：当前视图可导出 PNG 或 CSV。

### 5.4 预算

- 两种粒度：
  - **总预算**（本月 / 本年）：整体上限。
  - **分类预算**：对某分类设单独上限。
- 进度条着色：<70% 绿色，70-100% 橙色，>100% 红色并震动提示。
- 支持"预算结转"开关：未花完金额是否带入下月。

### 5.5 云同步

#### 5.5.1 同步模型
- **后端**：Supabase（Postgres + Auth + Storage）。
- **双模式**：
  - **官方托管**：我们部署一个 Supabase 实例（同时自行承担成本）；用户用 `邮箱 + 密码` 作为"同步凭证"，本质上是 Supabase Auth 的用户。
  - **用户自建**：用户在设置里填自己的 `SUPABASE_URL` + `ANON_KEY` + 同步凭证，即可切换到私有实例。
- **"同步凭证"设计**：
  - UI 上弱化"账号"概念，统一称之为"同步凭证"。
  - 用户首次开启同步时，默认选择"创建凭证"——填邮箱 + 密码（邮箱仅用于找回，不做营销、不强制验证）。
  - 生成后可"导出为同步码"（一段 Base64 字符串，包含邮箱 hint + 刷新 token），在新设备上粘贴即可直接恢复，无需再记密码。

#### 5.5.2 同步流程

```
本地写入 ──→ local_ops_queue（待同步队列）
                │
         网络可用 + 同步开关 ON
                ▼
        批量 push 到 Supabase
                │
                ▼
        pull 远端 since `last_sync_at`
                │
                ▼
        冲突检测 → 合并 → 回写本地
                │
                ▼
        更新 last_sync_at
```

- **触发时机**：App 启动、回到前台、记账后 5 秒静默、手动下拉、每 15 分钟定时。
- **批量大小**：单次 push ≤ 500 条，避免大事务。
- **幂等键**：`(device_id, local_uuid)` 保证重试不重复。

#### 5.5.3 冲突解决（Last-Write-Wins + 软删除）
- 每条记录字段：`id (uuid) / updated_at / deleted_at / device_id / content_hash`。
- 合并规则：
  1. 同一 `id` 的记录，以 `updated_at` 较新的为准；
  2. 若 `deleted_at` 不为空，视为已删除但保留 30 天进垃圾桶；
  3. 若 `updated_at` 相等且 `content_hash` 不同，按 `device_id` 字典序决定胜者，并在本地生成"冲突记录"副本，提示用户人工确认。
- 垃圾桶内的记录 30 天后自动硬删除，云端同步清理。

#### 5.5.4 数据加密
- 敏感字段（`note`、`attachments`）使用 **AES-256-GCM** 本地加密后再上传。
- 密钥派生：`PBKDF2(用户同步密码, salt=device_salt, iter=100000)`，**密钥永不上云**。
- 换设备时：用户输入同步密码 → 本地派生密钥 → 解密云端数据。
- 用户忘密码 = 无法解密（这是特性不是 bug），UI 中显著提示。

### 5.6 资产账户（V1 轻量版）

- 账户是"标签"不是"账本"：一笔流水挂在某账户下，只是为了分类统计。
- 默认账户：现金、工商银行卡、招商信用卡（示例）、支付宝、微信。
- 每账户字段：名称、类型（现金 / 储蓄卡 / 信用卡 / 第三方支付 / 其他）、图标颜色、初始余额、是否计入总资产。
- 信用卡账户：可设账单日、还款日（V1 仅展示，不做自动提醒，V1.1 再做）。

### 5.7 多币种

- 全局开关：默认关闭；开启后记账页出现"币种"字段。
- 内置常用币种：CNY / USD / EUR / JPY / KRW / HKD / TWD / GBP / SGD / CAD / AUD。
- **汇率**：
  - 默认使用内置"快照汇率"（首次启动时取一次）；
  - 开启联网时每日刷新一次（免费汇率 API）；
  - 支持手动覆盖某币种的汇率（出国时方便）。
- 统计时统一换算为"账本默认币种"展示，原始金额保留在流水详情中。

### 5.8 导入 / 导出

#### 5.8.1 导出
- 格式：
  - **CSV**（Excel 友好，含完整字段）；
  - **JSON**（结构化全量备份，含账本 / 分类 / 账户 / 流水 / 预算）；
  - **加密备份包（.bbbak）**：使用用户密码加密的 JSON，适合跨设备迁移且不走云。
- 范围：可选"当前账本"或"全部账本"，时间区间可选。

#### 5.8.2 导入
- 支持格式：
  - 标准 CSV（列头可配置映射）；
  - 本 App 导出的 JSON / .bbbak；
  - 预设模板：钱迹 CSV、随手记 CSV、微信账单 CSV、支付宝账单 CSV（V1 先做钱迹 + 微信 + 支付宝）。
- 导入流程：选文件 → 预览前 20 条 → 字段映射 → 去重策略（跳过 / 覆盖 / 全部导入）→ 确认。

### 5.9 垃圾桶

- 删除任何一条流水、分类、账户、账本都进入垃圾桶，而不是立刻硬删。
- 保留 30 天，可一键恢复。
- 超期自动清理（本地定时任务 + 云端触发）。
- 入口：我的 → 垃圾桶，显示剩余天数倒计时。

### 5.10 应用锁与安全

- **打开方式**：
  - 4-6 位 PIN；
  - 生物识别（Face ID / Touch ID / Android 指纹）；
  - 两者共存（生物识别失败可降级 PIN）。
- **触发条件**：App 启动、回到前台超过 1 分钟（可配置）、切到后台。
- **数据加密**：本地 SQLite 使用 SQLCipher 加密，密钥存于系统 Keystore / Keychain。
- **隐私模式**：开启后 App 在多任务预览中模糊，截屏受限（Android `FLAG_SECURE`）。

### 5.11 主题与外观

- 预置 4 套主题：
  - 🐰 奶油兔（默认，奶黄 + 粉）
  - 🐻 厚棕熊（暖棕 + 米）
  - 🌙 月见黑（深色模式）
  - 🍃 薄荷绿（清新）
- 自定义项：主色调、分类图标集、字体大小。
- 跟随系统深浅色自动切换。

### 5.12 提醒与小组件

- 每日记账提醒：可设固定时间，文案走"可爱风"（如"今天还没记一笔呢 🐻"）。
- 未记账天数提醒：连续 2 天没记时轻提醒一次。
- 小组件（iOS 14+ / Android 4.x+）：
  - 今日支出 / 本月结余 Widget；
  - 点击直达快速记账页。

---

## 6. 信息架构与导航

### 6.1 底部 Tab
`记账 / 统计 / 账本 / 我的`

### 6.2 典型路径
- **最高频**：打开 → 首页 FAB → 表单记账 → 保存 → 回首页。
- **次高频**：首页顶部快捷输入条 → 文字 → 确认卡片 → 保存。
- **每周**：统计页看本周花费。
- **换手机**：新设备 → 我的 → 开启云同步 → 粘贴同步码 → 自动恢复。

---

## 7. 数据模型

### 7.1 本地 SQLite 表设计

```sql
-- 用户偏好（单行）
CREATE TABLE user_pref (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  device_id TEXT NOT NULL,
  current_ledger_id TEXT,
  default_currency TEXT DEFAULT 'CNY',
  theme TEXT DEFAULT 'cream_bunny',
  lock_enabled INTEGER DEFAULT 0,
  sync_enabled INTEGER DEFAULT 0,
  last_sync_at INTEGER,
  ai_api_endpoint TEXT,
  ai_api_key_encrypted BLOB
);

-- 账本
CREATE TABLE ledger (
  id TEXT PRIMARY KEY,             -- uuid
  name TEXT NOT NULL,
  cover_emoji TEXT,
  default_currency TEXT DEFAULT 'CNY',
  archived INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  device_id TEXT NOT NULL
);

-- 分类
CREATE TABLE category (
  id TEXT PRIMARY KEY,
  ledger_id TEXT NOT NULL,
  name TEXT NOT NULL,
  icon TEXT,                       -- 资源 key 或 emoji
  color TEXT,
  type TEXT NOT NULL,              -- income | expense
  sort_order INTEGER DEFAULT 0,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  device_id TEXT NOT NULL,
  FOREIGN KEY (ledger_id) REFERENCES ledger(id)
);

-- 账户（资产标签）
CREATE TABLE account (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL,              -- cash | debit | credit | third_party | other
  icon TEXT,
  color TEXT,
  initial_balance REAL DEFAULT 0,
  include_in_total INTEGER DEFAULT 1,
  currency TEXT DEFAULT 'CNY',
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  device_id TEXT NOT NULL
);

-- 流水（核心表）
CREATE TABLE transaction_entry (
  id TEXT PRIMARY KEY,
  ledger_id TEXT NOT NULL,
  type TEXT NOT NULL,              -- income | expense | transfer
  amount REAL NOT NULL,
  currency TEXT NOT NULL,
  fx_rate REAL DEFAULT 1.0,        -- 相对账本默认币种
  category_id TEXT,
  account_id TEXT,
  to_account_id TEXT,              -- 转账时目标账户
  occurred_at INTEGER NOT NULL,    -- 发生时间
  note_encrypted BLOB,             -- AES-GCM 加密
  attachments_encrypted BLOB,      -- JSON 密文
  tags TEXT,                       -- 逗号分隔
  content_hash TEXT,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  device_id TEXT NOT NULL,
  FOREIGN KEY (ledger_id) REFERENCES ledger(id)
);
CREATE INDEX idx_tx_ledger_time ON transaction_entry(ledger_id, occurred_at DESC);
CREATE INDEX idx_tx_updated ON transaction_entry(updated_at);

-- 预算
CREATE TABLE budget (
  id TEXT PRIMARY KEY,
  ledger_id TEXT NOT NULL,
  period TEXT NOT NULL,            -- monthly | yearly
  category_id TEXT,                -- null 表示总预算
  amount REAL NOT NULL,
  carry_over INTEGER DEFAULT 0,
  start_date INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  device_id TEXT NOT NULL
);

-- 同步队列
CREATE TABLE sync_op (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entity TEXT NOT NULL,            -- ledger | category | account | transaction | budget
  entity_id TEXT NOT NULL,
  op TEXT NOT NULL,                -- upsert | delete
  payload TEXT NOT NULL,           -- JSON
  enqueued_at INTEGER NOT NULL,
  tried INTEGER DEFAULT 0,
  last_error TEXT
);
```

### 7.2 Supabase 表设计（同构镜像）
- 表结构与本地一致，额外列：`user_id UUID REFERENCES auth.users` + RLS（Row-Level Security）。
- 每张业务表开启 RLS，策略：`user_id = auth.uid()`。
- Storage：`attachments` Bucket，路径 `user_id/{entity_id}/{filename}.enc`，对象是本地已加密后的 blob。

---

## 8. 技术架构

### 8.1 总体架构图

```
┌──────────────────────────────────────┐
│          Flutter UI (Widget)          │
│       温馨可爱风 / 多主题 / 动效       │
├──────────────────────────────────────┤
│      State Mgmt: Riverpod 2.x         │
├──────────────────────────────────────┤
│             Use Cases                 │
│  记账 / 统计 / 预算 / 同步 / 加密      │
├──────────────────────────────────────┤
│             Repositories              │
│  LedgerRepo / TxRepo / SyncRepo / ... │
├──────────────┬───────────────────────┤
│ LocalDataSource│  RemoteDataSource    │
│   drift/SQLite │   supabase_flutter   │
│   (SQLCipher)  │                      │
└──────────────┴───────────────────────┘
          ↕                    ↕
  Isar/Drift DB        Supabase (PG/Auth/Storage)
```

### 8.2 主要依赖

| 用途 | 包 |
| :-- | :-- |
| 路由 | `go_router` |
| 状态管理 | `flutter_riverpod` |
| 本地数据库 | `drift` + `sqlcipher_flutter_libs` |
| 云端 | `supabase_flutter` |
| 本地存储 | `shared_preferences` + `flutter_secure_storage` |
| 图表 | `fl_chart` |
| 图标字体 | 自绘 SVG + `flutter_svg` |
| 生物识别 | `local_auth` |
| 加密 | `cryptography`（AES-GCM、PBKDF2） |
| 国际化 | `flutter_localizations` + `intl`（V1 仅简中，预留 i18n） |
| 日期选择 | `syncfusion_flutter_datepicker` 或轻量自制 |
| 通知 | `flutter_local_notifications` |

### 8.3 目录结构建议

```
lib/
├─ app/                  路由、主题、国际化
├─ core/                 通用工具、常量、错误
│   ├─ crypto/          AES/PBKDF2 封装
│   ├─ network/         Supabase client
│   └─ util/
├─ data/
│   ├─ local/           drift 数据库、DAO
│   ├─ remote/          Supabase DataSource
│   └─ repository/      合并本地 + 远端
├─ domain/
│   ├─ entity/          不可变实体
│   └─ usecase/         业务用例
├─ features/
│   ├─ record/          记账主流程
│   ├─ stats/           统计
│   ├─ ledger/          账本管理
│   ├─ budget/
│   ├─ account/
│   ├─ sync/            同步 UI + 状态
│   ├─ trash/
│   ├─ lock/
│   ├─ import_export/
│   └─ settings/
└─ main.dart
```

---

## 9. 关键流程时序

### 9.1 首次启动
1. 生成 `device_id`（UUID v4）存 Keystore。
2. 引导页（3 屏）：离线优先 / 多账本 / 温馨可爱。
3. 自动创建"📒 生活"默认账本 + 默认分类/账户。
4. 不强制开启同步，直达首页。

### 9.2 启用云同步
1. 我的 → 云同步 → 开启。
2. 选择：**官方托管** / **自建 Supabase**。
3. 二选一：
   - **新建凭证**：填邮箱 + 密码 → Supabase Auth signUp → 派生加密密钥。
   - **已有凭证**：粘贴同步码 或 邮箱 + 密码登录。
4. 首次同步：拉取云端全量 → 合并本地 → 回写 → 完成。
5. 之后后台自动同步。

### 9.3 换新手机
1. 新手机安装 App → 引导页（可跳过）。
2. 我的 → 云同步 → 已有凭证 → 粘贴同步码 / 输邮箱密码。
3. 全量拉取 + 解密 → 覆盖本地空库。
4. 完成，用户无感继续使用。

---

## 10. UI / 视觉设计规范

### 10.1 品牌关键词
温馨 · 松弛 · 萌 · 记录的仪式感

### 10.2 主色板（奶油兔主题）
| 角色 | 颜色 | Hex |
| :-- | :-- | :-- |
| 主色 | 奶油黄 | `#FFE9B0` |
| 辅助 | 樱花粉 | `#FFB7C5` |
| 强调 | 可可棕 | `#8A5A3B` |
| 成功 | 抹茶绿 | `#A8D8B9` |
| 警告 | 蜜橘 | `#F4A261` |
| 错误 | 苹果红 | `#E76F51` |
| 背景 | 米白 | `#FFF9EF` |
| 次背景 | 雾白 | `#FDF3E7` |

### 10.3 字体
- 中文：系统默认 + "霞鹜文楷"（可选下载）作标题。
- 数字：`Nunito` 圆润字形。

### 10.4 插画与图标
- 分类图标统一 64×64 圆形贴纸，手绘风轮廓，填充低饱和色块。
- 空状态、引导页使用吉祥物"兔团子"（小圆兔）贯穿。

### 10.5 组件规范
- 卡片圆角 16dp，阴影 `0 4 12 rgba(138,90,59,.08)`。
- 按钮：主按钮填充主色 + 阴影；次按钮描边 1.5dp。
- 动画：记账完成后"兔团子比心"小动效（Lottie，300ms 内）。

### 10.6 交互微动效
- FAB 按下旋转 + 轻微缩放；
- 流水删除左滑带抖动；
- 统计页图表首次出现缓动进入。

---

## 11. 非功能性需求

| 维度 | 指标 |
| :-- | :-- |
| 启动时间 | 冷启动 < 1.5s（中端机） |
| 记账响应 | 保存并回首页 < 200ms |
| 崩溃率 | < 0.3% |
| 本地 DB 大小 | 10 万条流水时 < 50MB |
| 同步延迟 | 单次增量同步 < 2s（100 条以内） |
| 电量 | 后台每 15 分钟同步一次，24h 耗电 < 2% |
| 隐私合规 | 遵循中国《个人信息保护法》+ GDPR；隐私政策中明示数据项与用途 |
| 可访问性 | 支持系统字号放大；重要按钮 ≥ 44×44pt |
| 离线可用 | 100% 记账链路无网可用 |
| 兼容性 | iOS 13+ / Android 8+（API 26+） |

---

## 12. 里程碑与路线图（仅作研发排期建议，文档一次性覆盖全功能）

| 版本 | 周期 | 范围 |
| :-- | :-- | :-- |
| V0.1 内测 | 第 1-3 周 | 架构搭建、本地 DB、表单记账、首页、多账本 |
| V0.5 Alpha | 第 4-6 周 | 统计、预算、资产账户、主题 |
| V0.8 Beta | 第 7-9 周 | Supabase 双模同步、冲突解决、垃圾桶、导入导出 |
| V1.0 正式 | 第 10-12 周 | 多币种、应用锁、加密、AI 快速输入、提醒与小组件、合规文案 |
| V1.x | 后续 | 多人协作账本、自动账单解析、桌面端 |

---

## 13. 风险与待决策项

| # | 风险 / 待决策 | 影响 | 当前倾向 |
| :-- | :-- | :-- | :-- |
| R1 | 官方托管的 Supabase 成本与合规（中国大陆访问） | 高 | 官方使用海外节点 + 自建方案作为国内用户兜底；App 内明示 |
| R2 | 用户忘记同步密码 → 云端数据无法解密 | 中 | 在启用加密时强提醒 + 支持导出明文本地备份 |
| R3 | 多币种汇率不准 | 低 | 内置快照 + 手动覆盖，免费 API 日刷新 |
| R4 | AI API 费用由谁承担 | 中 | V1 完全由用户自带 Key；官方不代付 |
| R5 | 图标 / 插画版权 | 高 | 全部自绘或使用可商用素材；上线前做一次版权清查 |
| R6 | 应用商店审核（中国大陆安卓商店需备案） | 中 | 预留 ICP + 软著材料；应用锁避免描述为"记账密码保险箱" |
| R7 | 开源与否 | 中 | 暂不开源，保留后续开源计划；但数据格式、同步协议对用户透明 |

---

## 14. 附录

### 14.1 术语表
- **同步凭证**：面向用户的术语，实质 = Supabase Auth 用户（邮箱 + 密码）+ 派生加密密钥。
- **同步码**：加密后的短字符串，包含登录信息 hint + 刷新 token，用于新设备快速恢复。
- **账本**：用户自定义的流水集合容器，相互独立。
- **账户**：流水的"资金出入口"标签（现金 / 银行卡等），仅做归类不做严格对账。
- **bbbak**：本产品的加密备份文件格式（bian-bian BAcKup）。

### 14.2 开源参考
- **BeeCount**（<https://github.com/TNT-Likely/BeeCount>）：本项目的云同步方案主要参考，采用 Flutter + Supabase，支持用户自建后端。本项目在其基础上增加"官方托管"模式、加密字段、混合 AI 输入。
- **叨叨记账**：UI / 视觉风格与情绪化交互主要参考。

### 14.3 可讨论的设计假设
- 数据加密默认开启还是可选开启？本文默认"开启但可关"。
- 官方托管 Supabase 是否限制免费额度（如单用户流水条数）？本文未限制，待运营评估。
- AI API 是否支持我们自部署的聚合代理？本文倾向只让用户自填 Key，避免资金成本与合规风险。

---

**文档结束 · 待业务方评审后进入原型与视觉设计阶段**
