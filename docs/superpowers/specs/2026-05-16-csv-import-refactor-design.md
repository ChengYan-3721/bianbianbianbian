# Step 13.5 · CSV 导入重构(BeeCount 同构)设计

**日期**:2026-05-16
**作者**:边编边变 + Claude
**状态**:设计已确认,等待写实施计划
**前置**:Step 13.4 三方模板导入(2026-05-05)、Step 13.3 通用导入(2026-05-04)
**后续**:Step 14.x 系列(不阻塞;本次仅改 CSV 路径)

---

## 1 · 背景与动机

Step 13.4 在 CSV 路径上引入了「三方模板」机制——微信 / 支付宝 / 钱迹 CSV 自动检测 + 关键词→本地分类映射。运行 11 天后发现两类问题:

1. **关键词映射精度有限**。`kKeywordToCategory` 仅约 80 条,大量真实账单的「交易对方 / 商品名」是商户全名(如「上海某某美容会所」)或泛词(如「转账给个人」),命中率约 50-60%。剩余 40-50% 行落到 `kFallbackCategoryName='其他'`,用户事后还得手动重分类。
2. **可扩展性差**。新增一个银行卡 / 随手记 / 招商银行流水模板需要写一个独立的 `extends ThirdPartyTemplate` 类 + 维护一份关键词词典。新格式适配成本是「全套硬编码」。

**BeeCount**(`https://github.com/TNT-Likely/BeeCount`)的方案不同——它把 CSV 解析层抽象成 `BillParser` 接口,大量 CSV 通过「列名一致性识别 + 中英文 header 自动规范化」由 `GenericBillParser` 直接吃下;微信 / 支付宝 / 钱迹只在「找 header 行」启发式上做子类化。**分类不靠关键词推断,而是把账单中的分类名当字面值,导入时本地不存在就自动创建**。

本次重构把本 App 的 CSV 路径架构对齐 BeeCount,同时:
- 导出 CSV 新增「一级分类」中文标签列,使导入侧能精确还原父子关系;
- 完全废弃 13.4 的 `kKeywordToCategory`(用户决策);
- 微信 / 支付宝子类仅保留「找 header + 状态过滤」(钱迹无状态过滤);
- 新建的二级分类**进 sync_op 队列**,跨设备可见。

## 2 · 范围

### 2.1 必改

- `lib/features/import_export/csv/` 新建子目录,移入并扩展现有 CSV 解析逻辑。
- `lib/features/import_export/templates/third_party_template.dart` **整体删除**。
- `lib/features/import_export/import_service.dart`:`_previewCsvBytes` / `_applyCsv` 改造。
- `lib/features/import_export/export_service.dart`:`encodeBackupCsv` 9 列 → 10 列。
- `lib/features/import_export/import_page.dart`:加「高级映射」可展开区。
- `lib/core/util/parent_key_labels.dart` **新建**:`parent_key` ↔ 中文标签的双向映射(单一真值源,与 `quick_text_parser._parentKeyLabels` 合并)。
- 依赖新增:`gbk_codec: ^0.4.0`(GBK 文本解码,BeeCount 同构)。
- 测试与文档同步更新。

### 2.2 必不改

- **JSON / `.bbbak` 路径**:`_previewJsonBytes` / `_applySnapshot` 一字不动。
- 加密(`bbbak_codec.dart` / `bianbian_crypto`)。
- 同步层(Phase 10):本次只在分类侧改 sync_op 写入策略;同步管道、冲突规则、device_id 流转一律不变。
- Phase 14.x 锁屏 / 生物识别 / 字段加密策略。
- Repository / Dao 层接口签名。

## 3 · 不变量

设计必须保持以下约束:

1. **离线优先**:导入 / 导出全本地;`gbk_codec` 是纯解码,无网络。
2. **流水强制 asNew**:CSV 路径无 ID,与 13.4 一致;不引入流水级去重选项。
3. **流水不写 sync_op**:沿用 13.3 决策——大量记录涌入会撑满队列。
4. **分类写 sync_op**:新建二级分类数量小(几个到几十个),队列压力可忽略,且跨设备一致性必要(否则 B 设备拿到的同步流水会指向不存在的分类)。
5. **CSV 字段 ledgerLabel 仍 resolve 到 fallback**:本 App 自有格式以外的 parser(微信 / 支付宝 / 钱迹 / generic)产出的 `ledgerLabel` 设为 parser 的 `displayName`,DB 不会有同名账本,触发 unresolved → fallback。
6. **CHECK 约束保持**:`category.parent_key` 仍限定在 11 个固定 key 内;新建分类的 parentKey 必须解析到这 11 个之一,否则归 `'other'`。
7. **JSON / `.bbbak` 行为完全不变**:任何对这两种格式的导入 / 导出代码路径都不动,包括 round-trip 与 `MultiLedgerSnapshot.fromJson` 兼容性。

## 4 · 目录与文件改动

```
lib/features/import_export/
├─ csv/                                       ← 新建子目录(BillParser 抽象 + 5 个 parser + 工具)
│   ├─ csv_lexer.dart                         ← parseCsvRows / stripUtf8Bom(从 import_service.dart 抽出)
│   ├─ csv_text_decoder.dart                  ← UTF-8 BOM / UTF-16 LE/BE / GBK 自动识别
│   ├─ bill_parser.dart                       ← 抽象 BillParser 接口
│   ├─ csv_format_detector.dart               ← detectBillParser 注册表入口
│   └─ parsers/
│       ├─ generic_parser.dart                ← GenericBillParser(列数一致性 + 中英文 header 规范化)
│       ├─ bianbian_parser.dart               ← BianbianBillParser(本 App 10 列严匹配;旧 9 列兼容)
│       ├─ wechat_parser.dart                 ← WechatBillParser(继承 generic;状态过滤 + 收/支符号)
│       ├─ alipay_parser.dart                 ← AlipayBillParser(同上;account 固定支付宝)
│       └─ qianji_parser.dart                 ← QianjiBillParser(一级 / 二级分类列直接拿)
├─ import_service.dart                         ← _previewCsvBytes 改用 csv_format_detector;_applyCsv 加自动建分类
├─ export_service.dart                         ← 10 列 header;encodeBackupCsv 增 parentKey 中文标签
├─ import_page.dart                            ← 新增「高级映射」折叠区
└─ ...
[删] templates/third_party_template.dart      ← 整个文件移除

lib/core/util/
└─ parent_key_labels.dart                     ← 新建:parent_key ↔ 中文标签双向映射;
                                                quick_text_parser._parentKeyLabels 改为引用本文件
```

## 5 · BillParser 抽象

### 5.1 接口定义

```dart
/// CSV 账单解析器抽象(BeeCount 同构)。
///
/// 每个具体 parser 负责:
/// - [validateBillType]:扫前若干行判断是否能识别这个 CSV 的 header 签名。
/// - [findHeaderRow]:返回 header 行号(0-indexed),没有返回 -1。
/// - [mapColumns]:把 header 行转成「字段 key → 列索引」映射。
/// - [parseRow]:按 columnMapping 把单行解析为 [BackupImportCsvRow];
///   返回 null 表示该行应被跳过(空行 / 状态异常 / 无法解析的核心字段)。
abstract class BillParser {
  const BillParser();
  String get id;               // 'bianbian' / 'wechat_bill' / 'alipay_bill' / 'qianji' / 'generic'
  String get displayName;      // UI 「识别为:xxx」显示;不暴露 id
  bool validateBillType(List<List<String>> rows);
  int findHeaderRow(List<List<String>> rows);
  Map<String, int> mapColumns(List<String> headerRow);
  BackupImportCsvRow? parseRow(List<String> row, Map<String, int> columnMapping);
}
```

### 5.2 字段 key 集合

`GenericBillParser._normalizeToKey` 输出的 11 个字段 key:

| key | 中文别名(顺序敏感:先具体后宽泛) | 英文别名(toLowerCase + 去空格) |
| :-- | :-- | :-- |
| `date` | 交易时间 / 账单时间 / 创建时间 / 日期 / 时间 | date / time / datetime |
| `type` | 交易类型(注意:钱迹用「类型」单独占,微信「交易类型」实际是分类) | type / inout / direction |
| `amount` | 金额(元) / 金额 / 交易金额 / 变动金额 | amount / money / price / value |
| `currency` | 币种 | currency |
| `primary_category` | **一级分类 / 父分类 / 主分类**(新增) | primary category / parent category |
| `category` | 二级分类 / 子分类 / 次分类 / 分类 / 类别 / 账目名称 / 科目 | sub category / subcategory / category / cate / subject / tag |
| `account` | 账户 | account |
| `from_account` | 转出账户 | from account |
| `to_account` | 转入账户 | to account |
| `note` | 备注 / 说明 / 标题 / 摘要 / 附言 / 商品名称 / 商品说明 / 交易对方 / 商家 | note / memo / desc / description / remark / title |
| `status` | 当前状态 / 交易状态 | status |

**规范化策略**(`_normalizeToKey`):
- trim 输入;空字符串返回 null。
- 同时计算 `lower = toLowerCase()` 与 `noSpace = lower.replaceAll(\s+, '')` 两份。
- 英文匹配走精确(noSpace == 'date' 等);中文匹配走子串(`contains`)。
- **顺序敏感**:先匹配长 / 具体词,后匹配短 / 宽泛词。如「二级分类」必须在「分类」之前判定,否则会被「分类」截获归到 `category`。
- 同名列保留首个(`putIfAbsent`),与多数表格软件一致。
- 已识别但应忽略的列(账目编号 / 交易号 / 流水号 / 订单号 / 相关图片 / 单号)返回 null。

### 5.3 注册表与探测顺序

```dart
const List<BillParser> _kAllParsers = [
  BianbianBillParser(),    // 本 App 自有格式优先(避免被 generic 抢)
  WechatBillParser(),      // header 签名强
  AlipayBillParser(),      //
  QianjiBillParser(),      // 弱签名,排在三方后
  GenericBillParser(),     // 兜底,接受任意「列数一致」的 CSV
];

BillParser? detectBillParser(List<List<String>> rows) {
  if (rows.isEmpty) return null;
  for (final p in _kAllParsers) {
    if (p.validateBillType(rows)) return p;
  }
  return null; // 不会发生,Generic 兜底始终返回 true
}
```

钱迹放最后:它的 header 签名最弱(只看「金额」+「分类|类别」+「时间|日期」),容易把微信 / 支付宝带的同名列误命中;Bianbian 放最前,避免本 App 9/10 列 CSV 被 Generic 抢走解析权(Generic 不知道「账本」/「币种」列含义)。

## 6 · 各 Parser 详细行为

### 6.1 BianbianBillParser(本 App 自有格式)

- **validateBillType**:严格匹配 header 序列。
  - 10 列严匹配:`['账本','日期','类型','金额','币种','一级分类','分类','账户','转入账户','备注']`。
  - 9 列兼容(无「一级分类」):`['账本','日期','类型','金额','币种','分类','账户','转入账户','备注']`。
- **findHeaderRow**:第 0 行。
- **mapColumns**:按固定位置硬映射(不走规范化)。
- **parseRow**:沿用 13.3 的 `_parseCsvRow` 校验逻辑(date / type / amount 必填);`primaryCategoryName` 仅 10 列时填值,9 列时 null。
- 一级分类列值是**中文标签**(饮食 / 购物 / ...);apply 时 reverse map 到 parent_key。

### 6.2 GenericBillParser(BeeCount 同构)

- **validateBillType**:总是返回 true(兜底)。
- **findHeaderRow**:`_findHeaderByColumnConsistency`——在前 30 行中找一行,其列数 ≥ 3 且后续 10 行内至少有 5 行列数与之一致;否则回 0。
- **mapColumns**:对每个 header 单元格调 `_normalizeToKey`,输出 `{字段key: 列索引}`;未识别列被跳过。
- **parseRow**:按 columnMapping 取值,组装 `BackupImportCsvRow`;关键字段缺失 / 解析失败时返回 null。
- 状态过滤:无(Generic 不感知「状态」语义)。

### 6.3 WechatBillParser

- **继承 GenericBillParser**;仅覆写 `findHeaderRow` / `validateBillType` / `parseRow`。
- **validateBillType**:扫前 30 行找含「交易时间」+「交易类型」+「交易对方」+「收/支」的行。
- **findHeaderRow**:同上。
- **parseRow**:
  1. 调 super.parseRow 拿基础字段。
  2. status 列(「当前状态」)含「退款」/「失败」/「关闭」/「未支付」→ 返回 null。
  3. type 字段(微信 header 是「收/支」)→ 「支出」→ expense / 「收入」→ income / 其他(「/」、空) → 返回 null。
  4. amount 走 super 拿到的 raw,本 parser 不复写。
  5. **category 字段优先用「交易类型」列**(微信账单的分类语义在「交易类型」,例:「商户消费」/「转账」/「红包」/「扫码付」)——但 `_normalizeToKey` 默认把「交易类型」归到 `type` 而非 `category`,本 parser **覆写 mapColumns**:先调 super.mapColumns 拿默认 mapping,再做调整——把「交易类型」列从 `type` 移到 `category`,把「收/支」列保持/重置为 `type`。`parseRow` 沿用 super,无需特殊处理。
  6. **primary_category 留空**(让 apply 阶段挂到 other 下;微信「交易类型」无可推断的一级)。
  7. account = 「支付方式」列原值(无则 null)。
  8. ledgerLabel = `displayName='微信账单'`(触发 fallback)。
  9. currency = 'CNY'(微信账单固定人民币)。
  10. note = `_composeNote([交易对方, 商品, 备注])`(沿用 13.4 的 `_composeNote` 工具,但函数从 templates 移到 csv/parsers/util.dart)。

### 6.4 AlipayBillParser

- **continue**:继承 generic;覆写同上。
- **validateBillType**:扫前 30 行找含「交易号」+「交易创建时间」+「商品名称」+「金额」+「收/支」的行。
- **parseRow**:
  1. super.parseRow + 字段重映射。
  2. status 列(「交易状态」)含「退款」/「关闭」/「失败」→ 返回 null。
  3. type 字段(「收/支」)同微信。
  4. **category 优先用「类型」列**(支付宝账单的「类型」列是分类,如「餐饮美食」/「日用百货」)——同微信路径,本 parser **覆写 mapColumns**:先调 super.mapColumns,再把「类型」列从 `type` 移到 `category`,把「收/支」列保持/重置为 `type`。`parseRow` 沿用 super。
  5. **primary_category 留空**(原因同微信)。
  6. account = 固定 `'支付宝'`。
  7. ledgerLabel = `'支付宝账单'`。
  8. currency = `'CNY'`。
  9. note = `_composeNote([交易对方, 商品名称, 备注])`。

### 6.5 QianjiBillParser

- **继承 generic**;主要差异在 findHeaderRow。
- **validateBillType**:扫前 10 行找同时含「金额」+「分类」/「类别」+「时间」/「日期」的行,且**不含**「账本」/「币种」(护栏,避免误命中本 App 9/10 列 CSV)。
- **parseRow**:
  - 钱迹两种格式:8 列(时间, 类型, 金额, 一级分类, 二级分类, 账户1, 账户2, 备注) / 6 列(日期, 分类, 子分类, 账户, 金额, 备注)。
  - `_normalizeToKey` 已能识别「一级分类」/「二级分类」/「子分类」;直接用。
  - type:有「类型」列用之,否则 expense 兜底。
  - amount = `parseAmount(raw).abs()`(钱迹某些版本支出为正,统一 abs)。
  - account = 「账户1」/「账户」列(transfer 时同时填 to_account = 「账户2」)。
  - 状态过滤:无。
- ledgerLabel = `'钱迹'`(触发 fallback)。

## 7 · 数据契约变更

### 7.1 BackupImportCsvRow(新增字段)

```dart
@immutable
class BackupImportCsvRow {
  const BackupImportCsvRow({
    required this.ledgerLabel,
    required this.occurredAt,
    required this.type,
    required this.amount,
    required this.currency,
    this.primaryCategoryName,  // ← 新增。中文标签;null 表示"无信息,挂 other"
    this.categoryName,
    this.accountName,
    this.toAccountName,
    this.note,
  });
  // 其余字段沿用 13.4
  final String? primaryCategoryName;
}
```

### 7.2 BackupImportPreview(字段重组)

```dart
@immutable
class BackupImportPreview {
  // 删除:thirdPartyTemplateId / thirdPartyTemplateName / unmappedCategoryCount
  // 保留:fileType / ledgerCount / transactionCount / sampleRows / snapshot / csvRows / exportedAt / sourceDeviceId

  // 新增:
  final String? parserId;             // 命中 parser 的 id;null 表示 JSON / .bbbak 路径
  final String? parserDisplayName;    // 命中 parser 的 displayName;同上
  final int newCategoryCount;         // 本次预览统计:apply 时会新建的二级分类数(去重 by name)
  final int newAccountCount;          // 本次预览统计:apply 时会新建的账户数(去重 by name)
  final Map<String, int>? columnMapping;  // 命中 parser 的列映射;UI「高级映射」用
  final List<String>? csvHeader;      // 原始 header 行;UI「高级映射」用
}
```

### 7.3 BackupImportResult(新增字段)

```dart
class BackupImportResult {
  // 沿用 13.4 全部字段
  final int categoriesCreated;        // ← 新增。实际新建的二级分类数(apply 完成后由 service 上报)
  final int accountsCreated;          // ← 新增。实际新建的账户数(同上)
}
```

## 8 · 自动新建二级分类与账户语义

### 8.1 触发条件(分类)

CSV apply 阶段,第一遍扫描 `preview.csvRows`,对每条行的 `categoryName`(不为 null 不为空)做检查:

```
若本地 category 表中**任意 parentKey 下**已有同名二级分类 → 复用其 id;不新建。
否则 → 标记为"待新建",决定其 parentKey:
  1. 若 row.primaryCategoryName != null 且能 reverse map 到 11 个 parent_key 之一(中文标签 → key)→ 用该 key。
  2. 否则 → 'other'。
```

**同名复用策略说明**(关键决策,需在文档与代码注释中强调):
- 若本地已有 `parent_key='food'` 下的「早餐」,CSV 行 `primaryCategoryName='教育'+categoryName='早餐'` → **复用本地 food/早餐**(不新建一份挂到 education 下)。
- 理由:① 二级分类名重复在 UI 会引起混乱;② 用户的语义应当以本地"已存在"为准。
- 副作用:CSV 来源说"早餐属于教育",但本地落到 food 下——可能不符合用户预期。**这是已知 trade-off**;如果用户要严格归一,需手动到分类管理页改名后再导入。

### 8.1.1 触发条件(账户)

CSV apply 阶段,第一遍扫描 `preview.csvRows`,对每条行的 `accountName` / `toAccountName`(不为 null 不为空)做检查:

```
若本地 account 表中已有同名账户 → 复用其 id;不新建。
否则 → 标记为"待新建",新账户字段默认:
  - type        = 'other'(语义"未知";用户可在账户管理页改 cash/debit/credit/third_party)
  - icon        = null(账户管理页可编辑)
  - color       = null
  - currency    = 'CNY'(沿用账户表默认值)
  - includeInTotal = 1(默认计入总资产;与现有种子账户一致)
  - initialBalance = 0
```

**同名复用 + 账户共享**:account 不区分 parent,本地全局共享;同名直接复用,无层级冲突。

**accountName / toAccountName 都参与**:若 CSV 转账行同时含两个新账户名,会建两条账户记录。

### 8.2 写库流程

在单个 `db.transaction` 内:

```
1. 第一遍扫 csvRows:
   a. 收集 newCategorySpecs = [{name, parentKey, sortOrderHint}, ...](去重 by name)。
   b. 收集 newAccountSpecs  = [{name, type='other', currency='CNY'}, ...](去重 by name;来源 accountName + toAccountName 合并)。
2. 预拉本地 categories / accounts(均含软删行,避免新建撞同名;软删行同名 → 复活)。
   - 分类复活:把该 category row 的 deletedAt 改 null + parentKey 改为新决策的 parentKey + updatedAt 刷新 + deviceId 改 currentDeviceId。
   - 账户复活:把该 account row 的 deletedAt 改 null + updatedAt 刷新 + deviceId 改 currentDeviceId(type / currency / icon / color 等不动,保留用户原配置)。
3. 对每条 newCategorySpec / newAccountSpec(各自循环):
   a. 若本地有软删同名 row → 走"复活"路径(update,不 insert)。
   b. 否则:生成新 UUID;插入相应表;
      - category 的 sort_order = (同 parentKey 下 max sort_order) + 1;
      - account 无 sort_order 概念,按插入顺序自然排列;icon / color 留 null。
   c. **同事务内调 db.syncOpDao.enqueue**:
      - 分类:entity='category', entityId=新id/复活 id, op='upsert', payload=jsonEncode(category.toJson()), enqueuedAt=clock().millisecondsSinceEpoch
      - 账户:entity='account',  entityId=同上,            op='upsert', payload=jsonEncode(account.toJson()),  enqueuedAt=同上
4. 刷新 categories / accounts 缓存(把新建 / 复活的并入)。
5. 第二遍扫 csvRows 写流水(沿用 13.4 _applyCsv 后半段):categoryId / accountId / toAccountId 查 name → id(此时缓存已含新建项);流水仍**不写** sync_op。
6. 返回 BackupImportResult(categoriesCreated + accountsCreated 由步骤 3 累计)。
```

**事务原子性**:任一分类 / 账户新建失败 → 整个 transaction 回滚;不会留下"半建配置 + 已写流水"的中间状态。

### 8.3 不复用 LocalCategoryRepository.save / LocalAccountRepository.save 的理由

- 保持 import_service "故意绕开 Repository"批量化路径(与 13.3 / 13.4 一致;Repository 单条 save 嵌套 transaction 在 drift 里走 savepoint,语义虽 OK 但增加复杂度)。
- 减少跨层依赖:import_service 已经持有 AppDatabase,直接 `db.into(db.categoryTable / db.accountTable).insert(...)` + `db.syncOpDao.enqueue(...)` 即可。
- 缺点:enqueue payload 构造与 LocalCategoryRepository / LocalAccountRepository 重复一份代码——需在代码注释里明确"任何对分类 / 账户同步字段的修改必须同步修改两处"。

## 9 · 编码自动识别(csv_text_decoder.dart)

照搬 BeeCount `FileReaderService.decodeBytes`:

```
1. UTF-16 LE BOM (FF FE):跳 2 字节,每 2 字节小端组 char。
2. UTF-16 BE BOM (FE FF):跳 2 字节,每 2 字节大端组 char。
3. UTF-8 BOM (EF BB BF):跳 3 字节,utf8.decode(allowMalformed: false)。
4. 无 BOM:
   a. 尝试 utf8.decode(allowMalformed: false);若不含 U+FFFD → 用 UTF-8。
   b. 否则尝试 gbk_codec.decode;若解出文本含中文字符(U+4E00-U+9FFF)→ 用 GBK。
   c. 否则 utf8.decode(allowMalformed: true)。
   d. 兜底 latin1.decode。
```

**新依赖**:`pubspec.yaml` 加 `gbk_codec: ^0.4.0`。

**适用场景**:
- 微信 / 支付宝近年导出已用 UTF-8 with BOM(BeeCount 验证过)。
- 支付宝旧版 Windows 导出常用 GBK——是这次加 gbk_codec 的主要原因。
- 用户手动用 Excel 另存为「CSV(逗号分隔)(*.csv)」会按 Windows-1252 / GBK 双重不确定保存——兜底路径覆盖。

## 10 · 导出 CSV(export_service.dart)

### 10.1 header

```dart
const List<String> _backupCsvHeader = [
  '账本', '日期', '类型', '金额', '币种',
  '一级分类',   // ← 新增,位于「分类」前
  '分类',
  '账户', '转入账户', '备注',
];
```

### 10.2 编码循环

```dart
for (final tx in entries) {
  final cat = tx.categoryId == null ? null : categoryMap[tx.categoryId!];
  final categoryName = cat?.name ?? '';
  final primaryCategoryName = cat == null
      ? ''
      : (parentKeyToChineseLabel(cat.parentKey) ?? '');
  // ... 其他字段同 13.1
  final row = [
    ledgerLabel, dateFmt.format(tx.occurredAt), _typeLabel(tx.type),
    amountFmt.format(tx.amount), tx.currency,
    primaryCategoryName,  // ← 新增
    categoryName,
    accountName, toAccountName, tx.tags ?? '',
  ];
  buffer.writeln(row.map(_escapeField).join(','));
}
```

**转账行**:categoryId 通常为 null,「一级分类」与「分类」两列都为空字符串。

### 10.3 parent_key_labels.dart(新公共工具)

```dart
// lib/core/util/parent_key_labels.dart
const Map<String, String> kParentKeyToLabel = {
  'income': '收入',
  'food': '饮食',
  'shopping': '购物',
  'transport': '出行',
  'education': '教育',
  'entertainment': '娱乐',
  'social': '人情',
  'housing': '住房',
  'medical': '医药',
  'investment': '投资',
  'other': '其他',
};

const Map<String, String> kLabelToParentKey = {
  '收入': 'income',
  '饮食': 'food',
  // ... 反向
};

String? parentKeyToChineseLabel(String parentKey) => kParentKeyToLabel[parentKey];
String? chineseLabelToParentKey(String label) => kLabelToParentKey[label.trim()];
```

`quick_text_parser.dart::_parentKeyLabels` 改为引用本文件的 `kParentKeyToLabel`,避免双副本飘移。

## 11 · UI 改造(import_page.dart)

### 11.1 预览卡片(CSV 路径)

新增 / 修改:
- 删除 13.4 「识别为:三方模板」相关 UI(`thirdPartyTemplateId != null` 分支)。
- 新增「识别为:`<parserDisplayName>`」一行(图标 `Icons.auto_awesome`),所有 parser 都显示(包括 Generic = 「通用 CSV」)。
- 新增「将新建 N 个二级分类 / M 个账户」橙色提示(`newCategoryCount > 0 || newAccountCount > 0` 时显示):
  - 文案:「检测到 N 个本地不存在的分类(将创建并默认归入对应一级分类,无法判断的归到「其他」)+ M 个本地不存在的账户(将以 type=其他 创建)。可在「高级映射」中跳过相应列。」
- 策略区文字:CSV 路径不再特别区分模板/非模板;统一文案「CSV 不含本 App 的 ID,会作为「全部新记录」导入;账本归入当前账本;分类与账户列若与本地已有同名则关联,否则**自动新建**(可在「高级映射」中跳过)。」

### 11.2 「高级映射」折叠区

默认收起;点开后展示:

```
列名               → 字段(下拉)
─────────────────────────────────
交易时间           → [date         ▼]
交易类型           → [category     ▼]   ← parser 已重映射的列
交易对方           → [note         ▼]
商品               → [note         ▼]   ← 多列映射到同字段,note 自动 _composeNote
收/支              → [type         ▼]
金额(元)          → [amount       ▼]
支付方式           → [account      ▼]
当前状态           → [status       ▼]
交易单号           → [(忽略)       ▼]
─────────────────────────────────
[重新预览]
```

下拉选项:
- 11 个字段 key(date / type / amount / currency / primary_category / category / account / from_account / to_account / note / status)。
- 「忽略此列」选项(对应 columnMapping 中该列被删除)。

点「重新预览」:
- 把用户调整后的 columnMapping 传回 service 的 `preview` 方法的新参数 `overrideColumnMapping`;
- service 若拿到 override 则跳过 detectBillParser,直接用 GenericBillParser.parseRow + 该 mapping 重新跑预览;
- 返回新的 BackupImportPreview(`parserId` 显示为 `'custom'`、`parserDisplayName` 显示为「自定义映射」)。

**约束**:
- date / type / amount 必须有列映射,否则禁用「重新预览」按钮并提示。
- category / account / primary_category 缺失允许,流水仍能写入(分类 / 账户为 null)。

### 11.3 文案 i18n 处理

沿用 13.4 的 `// i18n-exempt: needs refactoring for l10n` 标注;不本次提前做 i18n 抽出。

## 12 · 测试

### 12.1 删除

- `test/features/import_export/third_party_template_test.dart`(37 用例;整文件)。

### 12.2 新增

- `test/features/import_export/csv/csv_lexer_test.dart`(~6 用例):RFC 4180 引号 / 转义 / 跨行 / BOM 剥除;从原 import_service_test 抽出。
- `test/features/import_export/csv/csv_text_decoder_test.dart`(~7 用例):UTF-8 BOM / UTF-16 LE / UTF-16 BE / GBK 解码 / UTF-8 无 BOM / mixed / 兜底 latin1。
- `test/features/import_export/csv/parsers/generic_parser_test.dart`(~10 用例):
  - `_normalizeToKey` 11 个字段的中英文别名命中。
  - 顺序敏感(「二级分类」必须先于「分类」匹配)。
  - 列数一致性 header 发现(前 5 行说明 + 6-30 行表头 / 没找到回 0)。
  - parseRow 基础字段映射。
- `test/features/import_export/csv/parsers/bianbian_parser_test.dart`(~5 用例):10 列严匹配 / 旧 9 列向后兼容 / 一级分类列存在但内容非中文标签 / Excel BOM。
- `test/features/import_export/csv/parsers/wechat_parser_test.dart`(~5 用例):header 签名识别 / 「交易类型」重映射到 category / 状态过滤(退款 / 失败) / 「/」中性收支跳过 / `_composeNote` 拼接。
- `test/features/import_export/csv/parsers/alipay_parser_test.dart`(~5 用例):同上;account 固定支付宝 / 「类型」重映射 / 退款 / 关闭过滤 / 商品名进 note。
- `test/features/import_export/csv/parsers/qianji_parser_test.dart`(~5 用例):8 列格式 / 6 列格式 / 含「账本」/「币种」必须不命中(护栏) / amount.abs() / transfer 行 account1/2。
- `test/features/import_export/csv/csv_format_detector_test.dart`(~5 用例):优先级(钱迹放最后) / 微信不被钱迹抢 / 本 App 9 列不被钱迹抢 / 任意 CSV 兜底 Generic / 空 rows 返回 null。

### 12.3 修改

- `test/features/import_export/import_service_test.dart`(+~9 用例):
  - 10 列 CSV preview + 字段全部识别(parserDisplayName = '本 App')。
  - 旧 9 列 CSV preview 仍能工作(向后兼容)。
  - apply 时新建 3 个二级分类:① 「私房菜」+一级=「饮食」→ 落到 food;② 「玄学」+一级=null → 落到 other;③ 「咖啡」(已存在 food/咖啡)→ 复用不新建。
  - apply 后查 sync_op 表:3 - 1 = 2 条 category upsert 记录(复用的那条不写 sync_op);流水不写 sync_op。
  - apply 后 BackupImportResult.categoriesCreated == 2。
  - **新增账户用例**:apply 时含 3 个账户名:① 「招商卡(尾号8888)」(本地不存在)→ 新建 type='other';② 「现金」(已存在)→ 复用;③ 转账行的 toAccountName=「零钱通」(本地不存在)→ 新建。
  - apply 后查 sync_op 表:2 条 account upsert(复用的那条不写)。
  - apply 后 BackupImportResult.accountsCreated == 2。
  - 软删同名分类「复活」:本地有软删的「私房菜」(parentKey=food, deletedAt!=null) → 导入命中 → 复活(deletedAt=null, updatedAt 刷新),sync_op 写一条 upsert。
  - 软删同名账户「复活」:本地有软删的「招商卡(尾号8888)」→ 导入命中 → 复活;**type / icon / color 不动**(保留用户原配置)。
- `test/features/import_export/export_service_test.dart`(+~3 用例):
  - encodeBackupCsv 输出 10 列 header。
  - 流水的「一级分类」列是中文标签(食物 → 「饮食」)。
  - 转账行「一级分类」+「分类」列都为空字符串。

### 12.4 用例总账

| 项 | 数量 |
| :-- | --: |
| 删除(third_party_template_test) | -37 |
| 新增 csv/* 与 parsers/* | +48 |
| 修改 import_service_test | +9 |
| 修改 export_service_test | +3 |
| **净变化** | **+23** |

全量回归预期:**当前 14.x 基线**(14.1 时为 591;14.2+ 数量以实测为准) + **本次净变化 +23**(+48 新建 csv 测试 + 9 改 import_service_test + 3 改 export_service_test - 37 删 third_party_template_test)。最终数字以 `flutter test` 实测为准。

**重要**:`flutter test`(全量回归)应通过,Phase 14.x 的锁屏 / 生物识别 / 加密测试不受本次重构影响。

## 13 · 文档更新

### 13.1 `memory-bank/architecture.md`

- 顶部时间戳:`Phase 14.2 · ... 完成后` → `Phase 13.5 · CSV 导入重构完成后(基线为 14.2)`。
- `lib/features/import_export/` 目录树:
  - 移除 `templates/third_party_template.dart` 行。
  - 新增 `csv/` 子目录及其内 8 个文件。
- `lib/core/util/` 目录树:新增 `parent_key_labels.dart`。
- `test/features/import_export/` 目录树:对齐新增 / 删除测试文件。
- 新增「Phase 13.5 架构决策(2026-05-16)」段落:14 条决策、数据流图(CSV → detect → parser → preview → apply → sync_op)、单元测试策略、与 13.3 / 13.4 / 14.x 的关系、故意不做的事。

### 13.2 `memory-bank/progress.md`

- 新增 `### ✅ Step 13.5 CSV 导入重构 - BeeCount 同构(2026-05-16)` 章节,沿用 13.4 文档结构:
  - **改动**(7 大块)。
  - **验证**(`flutter analyze` / `flutter test` 套件 / 用户端到端 5 项)。
  - **给后续开发者的备忘**(关键 trade-off 与红线)。

## 14 · 故意不做的事

- **不支持 XLSX 导入**:BeeCount 用 `xlsxConverter` 注入,本 App 用户极少有 XLSX 账单;若有可手动另存为 CSV。
- **不支持 PDF 账单**:OCR 复杂度远高于价值;沿用 13.4 决策。
- **不实现「分类映射」UI**:用户可在导入后到分类管理页手动改名 / 挪 parent_key;BeeCount 的两步映射 UI 在本 App 简化为「字段映射 + 自动建分类」即可。
- **不实现流式进度回调**:本 App 用户的 CSV 都 < 10 MB,内存读够用;BeeCount 的进度 callback 仅在 Web 端的大文件场景有意义。
- **不支持「忽略整文件」**:CSV 解析失败抛 `BackupImportException` 由 UI 提示,用户决策。
- **不在 13.5 加 i18n 抽出**:文案沿用 13.4 的 `// i18n-exempt` 标注;Phase 16.x 集中做。
- **不删除 BeeCount 目录**:它是参考源码,不在 src tree;保留以备后续比对。

## 15 · 已知风险与权衡

### 15.1 微信账单「分类爆炸」与「账户爆炸」

- **分类**:微信「交易类型」列噪音化,一份 200 行的微信账单可能产生 10-30 个新二级分类,全部挂到 `other` 一级下。
- **账户**:微信「支付方式」列粒度细(零钱 / 零钱通 / 建设银行卡(7234) / 招商信用卡(...) / ...),同样会建出多个新账户。支付宝路径相对干净(account 固定为「支付宝」),钱迹路径取决于用户原有账户配置。
- **用户的明确选择**:完全废弃关键词映射;接受这两个 trade-off。
- **缓解措施**:
  - 预览页显示「将新建 N 个二级分类 + M 个账户」橙色提示,让用户知情。
  - 高级映射的「忽略此列」选项允许用户主动跳过 category / account / from_account / to_account 任一列的导入(对应字段全部归 null,流水仍写入)。
  - 文档明确告知用户:导入后到「分类管理 → 其他」/「账户管理」批量改名 / 删除 / 合并。

### 15.2 现有 13.4 用户的迁移

- **现象**:13.4 用户依赖关键词映射,升级到 13.5 后微信账单导入体验显著变化:不再有「智能归类」,改为「全部归到 other」。
- **告知路径**:Phase 13.5 完成后的版本日志 / 升级提示弹窗(由 Phase 17.x 版本管理决定)说明这个变化。
- **回退路径**:无;13.5 是单向重构。若用户反馈不满,可考虑在 13.6 把关键词映射作为「可选增强层」加回(在 GenericBillParser 之上),但**不在 13.5 范围**。

### 15.3 跨设备同步 + CSV 导入的边界

- **现象**:用户 A 在 A 设备导入 100 行带 5 个新分类 + 3 个新账户的微信账单:
  - A 设备:5 条 category + 3 条 account 进 sync_op;100 条流水**不进** sync_op。
  - 同步触发:5 个分类 + 3 个账户 push 到云端 / pull 到 B 设备。
  - B 设备:看到 5 个新分类 + 3 个新账户,但**看不到 100 条流水**(因为流水不进 sync_op)。
  - 用户在 B 设备看「其他」一级下多出 5 个空分类 / 账户列表多出 3 个零余额账户,可能困惑。
- **沿用 13.3 决策**:流水不进 sync_op;若用户希望跨设备完整数据,需用 backup 文件转移(导出 `.bbbak` → 跨设备恢复)或等下一次「整盘 push」(Phase 18.x 完整云端备份机制)。
- **不在 13.5 范围**;但需在用户文档 / FAQ 说明。

### 15.4 同名分类复用 vs 新建的语义模糊

- **现象**:CSV 行 `primaryCategoryName='教育' + categoryName='早餐'`,本地已有 `parent_key='food'` 的「早餐」→ **复用本地 food/早餐**(不新建 education/早餐)。
- **trade-off**:违反 CSV 来源的"父子关系",但避免本地"同名分类"混乱。
- **缓解**:在 architecture.md 与 progress.md 明确写出此策略;用户若坚持归到「教育」需手动改本地分类。

## 16 · 与 Phase 14.x / 后续 Phase 的衔接

### 14.x(已完成 / 进行中)

- **14.1 应用锁 PIN**:不受影响——锁屏拦截在 router 层,与 CSV 导入逻辑无交集。
- **14.2 生物识别**:同上。
- **14.3 / 14.4 字段加密 / TOTP**(未实施):若涉及笔记加密,与 import_service 的 `noteEncrypted` 字段写入路径无关——本次重构不动 note 字段编码。

### Phase 15.x(预计:统计页改版 / 月度账本回顾)

- 不阻塞;Phase 15 消费的 `transaction_entry` / `category` 表结构不变。

### Phase 16.x(预计:国际化抽取)

- 13.5 的 `// i18n-exempt` 标注由 16.x 一并处理。

### Phase 17.x(版本管理 / 升级提示)

- 13.5 升级提示文案("微信账单导入策略变化")由 17.x 实施。

### Phase 18.x(完整云端备份)

- 流水不进 sync_op 的 trade-off 由 18.x 解决——届时实现"整盘 push / pull"机制后,CSV 导入的流水也能跨设备转移。

## 17 · 实施顺序提示(给 writing-plans 用)

建议拆分子步骤(每步独立可测、有可回退点):

1. **csv_text_decoder + csv_lexer**(基础设施):抽出 + GBK 解码 + UTF-16 识别;独立单测先过。
2. **bill_parser + generic_parser**(核心抽象):接口定义 + GenericBillParser._normalizeToKey 全量字段;独立单测先过。
3. **5 个具体 parser**(并行可写):bianbian / wechat / alipay / qianji;独立单测各自通过。
4. **csv_format_detector**(集成):注册表 + 优先级测试。
5. **parent_key_labels.dart**(公共常量):抽 + quick_text_parser 改引用。
6. **import_service 改造**:`_previewCsvBytes` 改用 detect;`_applyCsv` 加自动建分类 + sync_op enqueue。
7. **export_service 改造**:10 列 header。
8. **import_page UI 改造**:高级映射折叠区(可放在最后,前 7 步完成后再改)。
9. **删除 templates/third_party_template.dart + 测试**。
10. **文档同步**:architecture.md + progress.md。

每步完成后跑相应测试套件;最后跑全量回归。
