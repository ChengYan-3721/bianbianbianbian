# SVG 图标在备份导出/导入与云同步中支持 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 通过补 4 类 round-trip 测试，把"分类/账户/账本的 SVG 图标字段在 JSON / .bbbak 备份与云同步中完整往返、CSV 路径明确不带 SVG"这一不变量锁住；生产代码零改动。

**Architecture:** Entity 层 `toJson`/`fromJson` 与 mapper 已经在 git status 中扩展支持 `iconSvg`/`coverSvg`。所有导出/导入/同步通路本身委托 entity 层做序列化，自动满足新字段——本次仅补测试用例固化行为。CSV 路径已通过白名单列头天然不带 SVG，无需额外断言。

**Tech Stack:** Flutter 3.x、drift（SQLCipher）、flutter_test、`NativeDatabase.memory()`（内存测试 DB）、现有 `LedgerSnapshotSerializer` / `BackupExportService` / `BackupImportService`。

**Spec 引用：** `docs/superpowers/specs/2026-05-17-svg-icon-backup-sync-design.md`

---

## File Structure

| 文件 | 操作 | 责任 |
| :-- | :-- | :-- |
| `test/domain/entity/entities_test.dart` | 修改（追加用例） | 锁住 Category/Account/Ledger 三个 entity 的 SVG 字段在 `toJson`/`fromJson` 中往返 |
| `test/features/sync/snapshot_serializer_test.dart` | **新建** | LedgerSnapshot/MultiLedgerSnapshot SVG round-trip + fingerprint 对 SVG 变化敏感 |
| `test/features/import_export/import_service_test.dart` | 修改（追加 group） | `BackupExportService.exportJson` + `BackupImportService.apply` 端到端 round-trip 后 DB 列含 SVG |
| `memory-bank/progress.md` | 修改 | 在当前 Phase 段尾追加条目，注明本步未写 DB 迁移、需 dev 清库 |

不动文件：`lib/**`（生产代码零改动）。

---

## Task 1：Category / Account / Ledger entity SVG round-trip 用例

**Files:**
- Modify: `test/domain/entity/entities_test.dart`（在 `group('Ledger', ...)` / `group('Category', ...)` / `group('Account', ...)` 三组各加 1 个测试）

### Step 1.1：写 Ledger.coverSvg round-trip 失败测试（先验证基线）

- [ ] **写 failing test**

把以下测试**追加**到 `entities_test.dart` 的 `group('Ledger', ...)` 末尾（紧贴 `copyWith` 测试之后，本 group 闭合 `});` 之前）：

```dart
    test('fromJson(toJson(x)) == x （含 coverSvg）', () {
      final withSvg = Ledger(
        id: 'ledger-svg',
        name: '家庭',
        coverEmoji: '🏠',
        coverSvg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
            '<path d="M3 12l9-9 9 9"/></svg>',
        createdAt: DateTime.utc(2026, 4, 20),
        updatedAt: DateTime.utc(2026, 4, 20),
        deviceId: 'device-a',
      );
      expect(Ledger.fromJson(withSvg.toJson()), withSvg);
      expect(withSvg.toJson()['cover_svg'], isNotNull);
    });
```

- [ ] **运行该单测验证通过**

Run: `flutter test test/domain/entity/entities_test.dart --plain-name "含 coverSvg"`
Expected: PASS（entity 已在 git status 改动中加好 `coverSvg`，应直接通过；如果 FAIL，说明 entity 的 `toJson`/`fromJson`/`==` 还没盖到 `coverSvg`，那时需要排查 entity 实现而非测试）

### Step 1.2：写 Category.iconSvg round-trip 测试

- [ ] **追加测试到 `group('Category', ...)` 末尾**

```dart
    test('fromJson(toJson(x)) == x （含 iconSvg）', () {
      final withSvg = Category(
        id: 'cat-svg',
        parentKey: 'food',
        name: '咖啡',
        icon: '☕',
        iconSvg: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/></svg>',
        updatedAt: DateTime.utc(2026, 4, 21),
        deviceId: 'device-a',
      );
      expect(Category.fromJson(withSvg.toJson()), withSvg);
      expect(withSvg.toJson()['icon_svg'], isNotNull);
    });
```

- [ ] **运行单测**

Run: `flutter test test/domain/entity/entities_test.dart --plain-name "含 iconSvg"`
Expected: PASS（两个测试同名都会跑——`Category` 与 `Account` 组都会用这个名字，没关系，两个都应 PASS）

### Step 1.3：写 Account.iconSvg round-trip 测试

- [ ] **追加测试到 `group('Account', ...)` 末尾**

```dart
    test('fromJson(toJson(x)) == x （含 iconSvg）', () {
      final withSvg = Account(
        id: 'acc-svg',
        name: '支付宝',
        type: 'third_party',
        icon: '💰',
        iconSvg: '<svg viewBox="0 0 24 24"><rect width="24" height="24"/></svg>',
        updatedAt: DateTime.utc(2026, 4, 21),
        deviceId: 'device-a',
      );
      expect(Account.fromJson(withSvg.toJson()), withSvg);
      expect(withSvg.toJson()['icon_svg'], isNotNull);
    });
```

- [ ] **运行 entities_test.dart 全部**

Run: `flutter test test/domain/entity/entities_test.dart`
Expected: 所有 group 全 PASS（新增 3 个用例 + 原有用例）

### Step 1.4：commit

- [ ] **stage 并 commit**

```bash
git add test/domain/entity/entities_test.dart
git commit -m "test(entity): lock SVG icon fields in Category/Account/Ledger toJson/fromJson"
```

---

## Task 2：LedgerSnapshot SVG round-trip + Serializer fingerprint 敏感性测试

**Files:**
- Create: `test/features/sync/snapshot_serializer_test.dart`

### Step 2.1：新建测试文件骨架

- [ ] **创建 `test/features/sync/snapshot_serializer_test.dart`，写入完整内容**

```dart
import 'package:bianbianbianbian/domain/entity/account.dart';
import 'package:bianbianbianbian/domain/entity/category.dart';
import 'package:bianbianbianbian/domain/entity/ledger.dart';
import 'package:bianbianbianbian/features/import_export/export_service.dart';
import 'package:bianbianbianbian/features/sync/snapshot_serializer.dart';
import 'package:flutter_test/flutter_test.dart';

/// 覆盖 SVG 图标字段在 LedgerSnapshot / MultiLedgerSnapshot 序列化与
/// LedgerSnapshotSerializer.fingerprint 中的行为。
///
/// 生产代码委托 entity 层 toJson/fromJson，理论上 SVG 自动随行；这里
/// 用测试把不变量钉死，防止未来重构（例如改 stable map 字段名时）漏掉。

const _devId = 'test-dev';

Ledger _ledger({String? coverSvg}) => Ledger(
      id: 'L1',
      name: '生活',
      coverEmoji: '📒',
      coverSvg: coverSvg,
      createdAt: DateTime.utc(2026, 5, 1),
      updatedAt: DateTime.utc(2026, 5, 1),
      deviceId: _devId,
    );

Category _category({String? iconSvg}) => Category(
      id: 'C1',
      name: '餐饮',
      parentKey: 'food',
      icon: '🍚',
      iconSvg: iconSvg,
      updatedAt: DateTime.utc(2026, 5, 1),
      deviceId: _devId,
    );

Account _account({String? iconSvg}) => Account(
      id: 'A1',
      name: '现金',
      type: 'cash',
      icon: '💵',
      iconSvg: iconSvg,
      updatedAt: DateTime.utc(2026, 5, 1),
      deviceId: _devId,
    );

LedgerSnapshot _snapshot({
  String? ledgerCoverSvg,
  String? categoryIconSvg,
  String? accountIconSvg,
}) =>
    LedgerSnapshot(
      version: LedgerSnapshot.kVersion,
      exportedAt: DateTime.utc(2026, 5, 4, 12),
      deviceId: _devId,
      ledger: _ledger(coverSvg: ledgerCoverSvg),
      categories: [_category(iconSvg: categoryIconSvg)],
      accounts: [_account(iconSvg: accountIconSvg)],
      transactions: const [],
      budgets: const [],
    );

void main() {
  group('LedgerSnapshot SVG round-trip', () {
    test('toJson / fromJson 保留 ledger.coverSvg', () {
      const svg = '<svg viewBox="0 0 24 24"><rect width="24" height="24"/></svg>';
      final snap = _snapshot(ledgerCoverSvg: svg);
      final decoded = LedgerSnapshot.fromJson(snap.toJson());
      expect(decoded.ledger.coverSvg, svg);
      expect(decoded, snap);
    });

    test('toJson / fromJson 保留 category.iconSvg', () {
      const svg = '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="8"/></svg>';
      final snap = _snapshot(categoryIconSvg: svg);
      final decoded = LedgerSnapshot.fromJson(snap.toJson());
      expect(decoded.categories.single.iconSvg, svg);
      expect(decoded, snap);
    });

    test('toJson / fromJson 保留 account.iconSvg', () {
      const svg = '<svg viewBox="0 0 24 24"><path d="M0 0h24v24"/></svg>';
      final snap = _snapshot(accountIconSvg: svg);
      final decoded = LedgerSnapshot.fromJson(snap.toJson());
      expect(decoded.accounts.single.iconSvg, svg);
      expect(decoded, snap);
    });

    test('MultiLedgerSnapshot 包一层后 SVG 仍然 round-trip', () {
      const svg = '<svg/>';
      final multi = MultiLedgerSnapshot(
        version: MultiLedgerSnapshot.kVersion,
        exportedAt: DateTime.utc(2026, 5, 4, 12),
        deviceId: _devId,
        ledgers: [
          _snapshot(
            ledgerCoverSvg: svg,
            categoryIconSvg: svg,
            accountIconSvg: svg,
          ),
        ],
      );
      final decoded = MultiLedgerSnapshot.fromJson(multi.toJson());
      expect(decoded.ledgers.single.ledger.coverSvg, svg);
      expect(decoded.ledgers.single.categories.single.iconSvg, svg);
      expect(decoded.ledgers.single.accounts.single.iconSvg, svg);
    });
  });

  group('LedgerSnapshotSerializer.fingerprint 对 SVG 变化敏感', () {
    const serializer = LedgerSnapshotSerializer();

    Future<String> fp(LedgerSnapshot s) async =>
        serializer.fingerprint(await serializer.serialize(s));

    test('改 ledger.coverSvg 指纹变化', () async {
      final a = _snapshot(ledgerCoverSvg: '<svg id="a"/>');
      final b = _snapshot(ledgerCoverSvg: '<svg id="b"/>');
      expect(await fp(a), isNot(await fp(b)));
    });

    test('改 categories[0].iconSvg 指纹变化', () async {
      final a = _snapshot(categoryIconSvg: '<svg id="a"/>');
      final b = _snapshot(categoryIconSvg: '<svg id="b"/>');
      expect(await fp(a), isNot(await fp(b)));
    });

    test('改 accounts[0].iconSvg 指纹变化', () async {
      final a = _snapshot(accountIconSvg: '<svg id="a"/>');
      final b = _snapshot(accountIconSvg: '<svg id="b"/>');
      expect(await fp(a), isNot(await fp(b)));
    });

    test('三处 SVG 全等时指纹相等（control case）', () async {
      const svg = '<svg id="same"/>';
      final a = _snapshot(
        ledgerCoverSvg: svg,
        categoryIconSvg: svg,
        accountIconSvg: svg,
      );
      final b = _snapshot(
        ledgerCoverSvg: svg,
        categoryIconSvg: svg,
        accountIconSvg: svg,
      );
      expect(await fp(a), await fp(b));
    });
  });
}
```

- [ ] **运行新建测试文件**

Run: `flutter test test/features/sync/snapshot_serializer_test.dart`
Expected: 全 PASS（7 个 test 用例）

如果 fingerprint 三个"变化"测试有任何一个出现 `equals`，说明 `LedgerSnapshotSerializer.fingerprint` 的 stable map 没有包含相应实体——回去检查 `lib/features/sync/snapshot_serializer.dart:117-126`，stable map 必须含 `'ledger'` / `'categories'` / `'accounts'` 三个键。

### Step 2.2：commit

- [ ] **stage 并 commit**

```bash
git add test/features/sync/snapshot_serializer_test.dart
git commit -m "test(sync): cover SVG icons in LedgerSnapshot round-trip + fingerprint"
```

---

## Task 3：BackupImport JSON 路径端到端 SVG round-trip 测试

**Files:**
- Modify: `test/features/import_export/import_service_test.dart`（追加新 group 到 `main()` 内部最后位置）

### Step 3.1：在 `_ledger` / `_cat` / `_acc` 之外新增带 SVG 的构造帮手

- [ ] **在文件中现有 `_ledger` / `_cat` / `_acc` 顶层 helper 定义之后，追加以下 helper**

定位：在 `import_service_test.dart` 第 77 行的 `Account _acc(...)` 函数定义闭合 `};` 之后插入：

```dart
Ledger _ledgerWithSvg(String id, String name, {required String coverSvg}) =>
    Ledger(
      id: id,
      name: name,
      coverSvg: coverSvg,
      createdAt: DateTime.utc(2026, 4, 1),
      updatedAt: DateTime.utc(2026, 4, 1),
      deviceId: _devId,
    );

Category _catWithSvg(
  String id,
  String name, {
  required String iconSvg,
  String parentKey = 'food',
}) =>
    Category(
      id: id,
      name: name,
      parentKey: parentKey,
      iconSvg: iconSvg,
      updatedAt: DateTime.utc(2026, 4, 1),
      deviceId: _devId,
    );

Account _accWithSvg(String id, String name, {required String iconSvg}) =>
    Account(
      id: id,
      name: name,
      type: 'cash',
      iconSvg: iconSvg,
      updatedAt: DateTime.utc(2026, 4, 1),
      deviceId: _devId,
    );
```

### Step 3.2：写 JSON 路径端到端 round-trip 测试

- [ ] **在 `main()` 函数内部、最后一个 `group(...)` 闭合 `});` 之后、`main` 函数 `}` 之前，追加新 group**

```dart
  group('SVG 图标 JSON round-trip（Step 14.x）', () {
    test('export → import 后 DB 三类实体 SVG 列与原值一致', () async {
      const ledgerSvg = '<svg viewBox="0 0 24 24" id="ledger"/>';
      const catSvg = '<svg viewBox="0 0 24 24" id="cat"/>';
      const accSvg = '<svg viewBox="0 0 24 24" id="acc"/>';

      final ledger = _ledgerWithSvg('L-svg', '家庭', coverSvg: ledgerSvg);
      final category = _catWithSvg('C-svg', '咖啡', iconSvg: catSvg);
      final account = _accWithSvg('A-svg', '支付宝', iconSvg: accSvg);

      final multi = _multi([
        _snap(
          ledger,
          categories: [category],
          accounts: [account],
          transactions: const [],
        ),
      ]);

      // 模拟"导出"——直接复用 _jsonBytes（与 BackupExportService.exportJson
      // 的字节路径同源：jsonEncode(multi.toJson())）
      final bytes = _jsonBytes(multi);

      // 全新内存 DB（模拟跨设备恢复）
      final db = _createDb();
      addTearDown(db.close);

      final svc = BackupImportService(uuid: const Uuid());
      final preview = await svc.preview(
        bytes: bytes,
        fileType: BackupImportFileType.json,
      );
      expect(preview.fileType, BackupImportFileType.json);

      await svc.apply(
        preview: preview,
        strategy: BackupDedupeStrategy.overwrite,
        db: db,
        currentDeviceId: _devId,
      );

      // 直接拉 DB 行（绕过 mapper，验证字节层面落库正确）
      final ledgerRow = await (db.select(db.ledgerTable)
            ..where((t) => t.id.equals('L-svg')))
          .getSingle();
      final catRow = await (db.select(db.categoryTable)
            ..where((t) => t.id.equals('C-svg')))
          .getSingle();
      final accRow = await (db.select(db.accountTable)
            ..where((t) => t.id.equals('A-svg')))
          .getSingle();

      expect(ledgerRow.coverSvg, ledgerSvg);
      expect(catRow.iconSvg, catSvg);
      expect(accRow.iconSvg, accSvg);
    });

    test('SVG 字段为 null 时 round-trip 后 DB 列仍为 null（控制实验）', () async {
      final ledger = _ledger('L-nil', '工作'); // 没传 coverSvg
      final category = _cat('C-nil', '工资', parentKey: 'income');
      final account = _acc('A-nil', '现金');

      final multi = _multi([
        _snap(
          ledger,
          categories: [category],
          accounts: [account],
        ),
      ]);
      final bytes = _jsonBytes(multi);

      final db = _createDb();
      addTearDown(db.close);

      final svc = BackupImportService(uuid: const Uuid());
      final preview = await svc.preview(
        bytes: bytes,
        fileType: BackupImportFileType.json,
      );
      await svc.apply(
        preview: preview,
        strategy: BackupDedupeStrategy.overwrite,
        db: db,
        currentDeviceId: _devId,
      );

      final ledgerRow = await (db.select(db.ledgerTable)
            ..where((t) => t.id.equals('L-nil')))
          .getSingle();
      final catRow = await (db.select(db.categoryTable)
            ..where((t) => t.id.equals('C-nil')))
          .getSingle();
      final accRow = await (db.select(db.accountTable)
            ..where((t) => t.id.equals('A-nil')))
          .getSingle();

      expect(ledgerRow.coverSvg, isNull);
      expect(catRow.iconSvg, isNull);
      expect(accRow.iconSvg, isNull);
    });
  });
```

- [ ] **运行新增 group**

Run: `flutter test test/features/import_export/import_service_test.dart --plain-name "SVG 图标 JSON round-trip"`
Expected: 两个 test 都 PASS

如果 FAIL，常见原因：
- entity_mappers.dart 的 `categoryToCompanion` / `accountToCompanion` / `ledgerToCompanion` 没有把 `iconSvg`/`coverSvg` 映射进去（这是 git status 改动应当包含的——按 spec §2 现状已确认包含，若缺失需补）
- Drift 生成代码未含新列（重跑 `dart run build_runner build --delete-conflicting-outputs`）

### Step 3.3：跑整个 import_service_test.dart 防止回归

- [ ] **跑全套**

Run: `flutter test test/features/import_export/import_service_test.dart`
Expected: 所有 test（新增 2 个 + 原有用例）全 PASS

### Step 3.4：commit

- [ ] **stage 并 commit**

```bash
git add test/features/import_export/import_service_test.dart
git commit -m "test(import): cover SVG icon round-trip via JSON export+import path"
```

---

## Task 4：更新 progress.md，留下"未写迁移"的溯源说明

**Files:**
- Modify: `memory-bank/progress.md`（在最末尾一条已有 Step 条目之后追加新条目）

### Step 4.1：定位插入位置

- [ ] **打开 `memory-bank/progress.md`，找到最末一条 Step 条目（应为 Step 13.5 的总结条目）**

Run: `flutter analyze 2>&1 | head -5`（顺手做个静态检查不阻塞计划，但若有错误本任务前需先排查）

读完后，把"插入位置"定为：最末条 Step 条目 + 该条目下属任何 sub-bullet 之后；如有"# 下一步"或类似分隔，则在分隔之前。

### Step 4.2：追加条目

- [ ] **追加以下内容（按 progress.md 现有风格调整层级/缩进）**

```markdown
- Step 14.0 SVG 图标在备份导入导出与云同步中的支持：
  - 范围：分类 / 账户 / 账本的 `iconSvg` / `coverSvg` 字段在 JSON / `.bbbak`
    / 云同步路径中完整 round-trip；CSV 路径明确不带 SVG。
  - 生产代码零改动——entity `toJson` / `fromJson` 与 mapper 已在前序提交里
    扩展；导出导入与同步全都委托 entity 层序列化，自动满足。
  - 测试：补 entities_test / snapshot_serializer_test（新建）/ import_service_test
    三个文件共 9 个用例，锁住 SVG round-trip 与 fingerprint 敏感性。
  - **未写 DB v12 → v13 迁移代码**——按设计文档（`docs/superpowers/specs/
    2026-05-17-svg-icon-backup-sync-design.md`）记录的决策，本步假定尚未发
    布到真实用户，已装老版本的 dev 设备需手动清库（`adb uninstall` 或
    删 `bbb.db`）；schemaVersion 保持 12 不变。
```

### Step 4.3：commit

- [ ] **stage 并 commit**

```bash
git add memory-bank/progress.md
git commit -m "docs(progress): record Step 14.0 SVG icon backup/sync support"
```

---

## Task 5：最终全量测试 + analyze 验收

**Files:** 无修改，仅运行验证

### Step 5.1：跑整套测试

- [ ] **执行**

Run: `flutter test`
Expected: 全部测试 PASS（基线 798/799；本步新增约 9 个用例 → 应为 807/808，其中那 1 个 pre-existing FAB widget 失败保持不变；如有其他新失败必须排查）

### Step 5.2：静态分析

- [ ] **执行**

Run: `flutter analyze`
Expected: 无新增告警 / error；既有告警与基线一致

### Step 5.3：手动 smoke 备忘（非阻塞，仅记录）

- [ ] **记录给后续手测**

把下面这段贴回给用户作为收尾交付的一部分（不写文件，仅放在最终汇报里）：

> 手测建议（在干净 dev 设备上）：
> 1. 清除应用数据 / 重装
> 2. 启动后到分类编辑页选一个 SVG 图标 → 保存
> 3. 在账户、账本编辑页重复同样动作
> 4. 设置 → 导出 → 选 JSON → 用文本编辑器打开导出文件，确认 `icon_svg` / `cover_svg` 字段存在且含 svg 源码
> 5. 再次清库 → 启动后到设置 → 导入选刚才的 JSON → 完成后到列表确认 SVG 图标显示
> 6. （可选）启用云同步 → 在第二台设备同样导入后能看到 SVG

### Step 5.4：无需 commit（本任务无文件改动）

---

## Self-Review

**1. Spec 覆盖**：
- Spec §1 目标 1（JSON round-trip）→ Task 3
- Spec §1 目标 2（.bbbak round-trip）→ 已在 spec §3.5 显式排除（与 JSON 同源）
- Spec §1 目标 3（云同步 round-trip）→ Task 2 fingerprint group 锁住
- Spec §1 目标 4（CSV 不含 SVG）→ Spec §3.5 显式排除（白名单列头，断言无新价值）
- Spec §1 目标 5（测试锁不变量）→ Task 1/2/3 全覆盖
- Spec §4（不写迁移）→ Task 4 记录决策
- Spec §7 验收清单：
  - 新增测试通过 → Task 5
  - analyze 无告警 → Task 5
  - progress.md 加条目 → Task 4
  - architecture.md 补说明：**Spec §7 列了 architecture.md，但 Spec §4 与 §5 显示"零生产改动"——架构层面无变化，progress.md 已足够。本计划未单独列 architecture.md 任务；若后续审视认为仍需，可单独追加一行说明。**
  - 手动 smoke → Task 5.3 备忘

**2. Placeholder 扫描**：每步都给出具体代码、文件位置（含行号）、命令、期望输出，无 TBD / TODO / "implement similar"。

**3. 类型一致性**：
- `Ledger.coverSvg` / `Category.iconSvg` / `Account.iconSvg` 在三个 task 中字段名统一
- `BackupDedupeStrategy.overwrite`、`BackupImportFileType.json` 等枚举值与现有 `import_service.dart` 一致
- Helper 命名 `_ledgerWithSvg` / `_catWithSvg` / `_accWithSvg` 与现有 `_ledger` / `_cat` / `_acc` 风格对齐

**4. 决策记录**：architecture.md 一项被审视后判定无需修改（架构本身没变化）。如果后续 review 时认为该判定不妥，再补一个轻量条目即可。
