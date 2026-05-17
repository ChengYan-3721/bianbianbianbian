# SVG 图标在备份导出/导入与云同步中的支持

- **日期**：2026-05-17
- **范围**：分类（Category）/ 账户（Account）/ 账本（Ledger）的自定义 SVG 图标字段在 JSON、`.bbbak`、CSV 备份与云同步中的处理策略
- **背景**：本仓库已经为 `category.icon_svg` / `account.icon_svg` / `ledger.cover_svg` 三列追加了 schema、entity、mapper 与 `toJson`/`fromJson` 支持。本 spec 处理"如何让现有备份/同步通路把新字段也带上"。

---

## 1. 目标与非目标

### 目标

1. JSON 备份（`*.json`）导出与导入完整 round-trip 保留 SVG。
2. 加密备份（`*.bbbak`）导出与导入完整 round-trip 保留 SVG（与 JSON 路径同源，复用结论）。
3. 云同步（`flutter_cloud_sync` + `LedgerSnapshotSerializer`）上传下载完整 round-trip 保留 SVG。
4. CSV 备份**明确不包含 SVG**——`.csv` 的语义是"Excel 友好的轻量视图"，强制对二进制/长字符串裁剪。
5. 通过测试用例锁住上述四条不变量，防止未来回归。

### 非目标

- 不修改任何现有 UI 层（编辑页 / 列表页 / 选图标的 picker 等）。
- 不在 export / import / sync 服务里限制 SVG 长度。
- 不引入新的备份格式版本号（`MultiLedgerSnapshot.kVersion`、`LedgerSnapshot.kVersion` 保持 1）——新字段是 entity 内可选属性，JSON 老备份缺这三列时 `fromJson` 仍然成立（`json[xxx] as String?` 取出 null）。
- 不为老 schema（v12）写 ALTER TABLE 迁移代码——参见 §4。

---

## 2. 现状分析

完整数据通路已经因为 entity 层 `toJson`/`fromJson` 与 mapper 的扩展**自动**满足新字段需求：

```
JSON / .bbbak  ─── MultiLedgerSnapshot.toJson
                     └─ LedgerSnapshot.toJson
                          └─ entity.toJson  ←  iconSvg / coverSvg 已写入
                     ▲
                     └─ LedgerSnapshot.fromJson
                          └─ entity.fromJson  ←  iconSvg / coverSvg 已还原

云同步         ─── LedgerSnapshotSerializer.{serialize,deserialize,fingerprint}
                     └─ 同上走 entity.toJson
                        fingerprint 的 stable map 含 ledger/categories/accounts
                        三类实体的 SVG 变化 → JSON 变化 → 指纹变化 → 触发 push ✅

CSV 导出      ─── encodeBackupCsv：固定 10 列白名单（账本/日期/类型/金额/币种/
                 一级分类/二级分类/账户/转入账户/备注），从未引用 iconSvg/coverSvg
                 → 天然不带 SVG ✅
CSV 导入      ─── BillParser 家族按列名解析，无 SVG 列
                 → 天然不读 SVG ✅
```

结论：**生产代码无需任何改动**即满足功能需求。本 spec 的实际产出是测试覆盖与一份决策记录。

---

## 3. 测试方案

补 4 个测试用例，全部沿用现有 `test/` 目录组织风格与命名约定。新增用例不新建独立文件；如果目标文件不存在，则在最贴近的同类测试文件内追加分组。

### 3.1 Entity SVG 字段 round-trip

**目标**：固化 `Category` / `Account` / `Ledger` 的 `toJson`/`fromJson` 包含 SVG 字段，防止未来重构遗漏。

**用例**：
- 构造 entity，`iconSvg` / `coverSvg` 非空字符串
- `entity.toJson()` 输出含 `icon_svg` / `cover_svg` 键
- `Entity.fromJson(entity.toJson())` 与原 entity 相等（依赖 `==` 已扩展，git status 中 entity 已改）

**位置**：`test/domain/entity/{category,account,ledger}_test.dart`（按现有命名探查；若文件名不同则就近放）

### 3.2 LedgerSnapshot round-trip 含 SVG

**目标**：`LedgerSnapshot.toJson` → `fromJson` 跨该层后，三类实体的 SVG 字段全等。

**用例**：
- 构造一个 `LedgerSnapshot`，含 1 个 ledger（`coverSvg` 非空）、N 个 category（部分 `iconSvg` 非空）、M 个 account（部分 `iconSvg` 非空）
- 序列化为 JSON 字符串再反序列化
- 三类实体的 SVG 字段值与原值逐条相等

**位置**：`test/features/sync/snapshot_serializer_test.dart`（如已存在则追加分组；不存在则新建）

### 3.3 LedgerSnapshotSerializer fingerprint 对 SVG 变化敏感

**目标**：防止 SVG 改动被同步层认为是"无变更"而不上推。

**用例**：
- 构造 snapshot A 与 B：仅 `categories[0].iconSvg` 不同，其它字段全等
- `serializer.fingerprint(serialize(A)) != serializer.fingerprint(serialize(B))`
- 对 ledger.coverSvg / account.iconSvg 各做一次同形验证

**位置**：同 3.2 文件。

### 3.4 BackupImportService JSON 路径 round-trip

**目标**：端到端验证"导出 → 导入"后 DB 里读出来的 SVG 与最初写入一致。

**用例**：
- 内存 `AppDatabase.forTesting`
- 种入 1 ledger + 2 categories + 2 accounts，三者各自含 SVG
- 通过 repository 读出后构造 `MultiLedgerSnapshot` 并 `encodeBackupJson` 编码
- 重置 DB（fresh memory db），用 `BackupImportService.preview` + `apply(strategy: overwrite)` 写回
- 直接 `db.select(...)` 拉行，断言 `icon_svg` / `cover_svg` 列与原值一致

**位置**：`test/features/import_export/import_service_test.dart`（如已存在则追加；不存在则新建）

### 3.5 测试不写

- `.bbbak` round-trip：与 JSON 路径同源（解密后是同样的字节流），已有套件覆盖加密层；这里再加一份相同形态的用例无新增收益。
- CSV 不含 SVG 的负向断言：CSV 列头是 10 列硬编码常量 `_backupCsvHeader`，无字段进入路径，断言无用。
- SVG 大小上限：本 spec §1 非目标已排除。

---

## 4. 数据库迁移策略

**结论：不写迁移代码。schemaVersion 保持 12。**

理由：
- 项目尚未发布到真实用户（最近 commit `Step 13.5(22/22)`，仍在 Phase 13）。
- 已装老版本的 dev 设备需手动清库（`adb uninstall` / 删 `bbb.db`），可接受。
- 写 v12→v13 ALTER TABLE 迁移代码会引入额外测试维护负担，与"最小改动"原则冲突。

落地动作：
- `lib/data/local/app_database.dart` 顶部的 schema 版本历史注释**不**新增条目（无版本变化）。
- 在 `memory-bank/progress.md` 当前 Phase 记录里追加一行说明："本步未写迁移，dev 设备升级需手动清库"，留下溯源线索。

如后续在发布前发现需要兼容老库，可单独起一个 spec 加 v12→v13 migration——届时纯加列、不动业务代码、风险极低。

---

## 5. 不改动的代码（显式锁定）

| 文件 | 不改原因 |
| :-- | :-- |
| `lib/features/import_export/export_service.dart` | CSV 路径白名单已正确排除 SVG；JSON 路径委托 `MultiLedgerSnapshot.toJson` → entity，已自动带 SVG |
| `lib/features/import_export/import_service.dart` | JSON 路径 `LedgerSnapshot.fromJson` → entity → `*ToCompanion` → DB 已自动写 SVG；CSV 路径不读 SVG 是正确行为 |
| `lib/features/sync/snapshot_serializer.dart` | `serialize` / `deserialize` 走 entity JSON；`fingerprint` 的 stable map 含 ledger/categories/accounts，自动反映 SVG 变化 |
| `lib/data/repository/entity_mappers.dart` | `iconSvg` / `coverSvg` 已在 git status 改动中加入 row↔entity 双向映射 |
| `lib/features/import_export/bbbak_codec.dart` | 编解码层透明，仅处理字节流，不感知字段 |
| 所有 UI 层 | 不在本 spec scope |

---

## 6. 风险与回滚

- **风险 1**：SVG 字符串体积可能让 JSON / .bbbak 备份显著增大。
  - 评估：单条 SVG 量级 KB，账本规模通常 <100 entity，总增量在数百 KB～MB 范围，远小于流水数据本身。
  - 接受。
- **风险 2**：云同步上传字节数增大，间接增加 Supabase 流量成本。
  - 评估：同上量级；同步触发与 fingerprint 绑定，未改 SVG 时不触发上传。
  - 接受。
- **风险 3**：未来若要新增 SVG 长度上限，需要在多处同时改（entity / serializer / fingerprint）。
  - 缓解：在 §1 非目标中明确"本 spec 不引入上限"，未来引入时另起 spec。

回滚路径：本 spec 仅新增测试，无生产代码改动；如发现问题，删除新增测试即可完全回滚。

---

## 7. 验收清单

实施完成后逐项验证：

- [ ] 新增 4 类测试全部通过（`flutter test` 全绿，新增用例计入 progress.md 的实际测试数）
- [ ] `flutter analyze` 无新增告警
- [ ] `memory-bank/progress.md` 加一条本步条目（含"未写迁移"说明）
- [ ] `memory-bank/architecture.md` 在「数据模型」「同步策略」相关段落补一句关于 SVG 字段已纳入 round-trip 的说明（如位置合适）
- [ ] 手动 smoke：dev 清库 → 启动 → 在分类/账户/账本编辑页选 SVG 图标 → 导出 JSON → 清库 → 导入 → SVG 还原可见
