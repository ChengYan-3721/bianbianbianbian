# CSV 导入重构(BeeCount 同构) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把本 App CSV 导入路径架构对齐 BeeCount(`BillParser` 抽象 + 5 具体 parser + 列名一致性识别);导出 CSV 9→10 列(新增「一级分类」中文标签列);导入时本地不存在的二级分类 / 账户自动新建并进 sync_op 队列;完全废弃 13.4 的关键词→分类映射。

**Architecture:** 抽出 `lib/features/import_export/csv/` 子目录承载抽象 + 5 具体 parser + 文本解码 + lexer + format detector;`import_service._previewCsvBytes` 改用 detector,`_applyCsv` 在 `db.transaction` 内做"第一遍收集 → 新建分类/账户(含 sync_op enqueue) → 第二遍写流水"三步;`export_service.encodeBackupCsv` 新增「一级分类」列(中文标签,位于「分类」前);删除 `templates/third_party_template.dart` 整个文件。

**Tech Stack:** Flutter 3.x / Dart 3.11.5 / Drift / Riverpod 2.x / `gbk_codec` 0.4.x(新增依赖,纯 Dart GBK 文本解码) / `intl` / `uuid`

**前置文档:** `docs/superpowers/specs/2026-05-16-csv-import-refactor-design.md`(本计划随时引用)

---

## Phase 1 · 基础设施与公共常量

### Task 1: 添加 `gbk_codec` 依赖

**Files:**
- Modify: `pubspec.yaml:67-68`(在 `mime: ^2.0.0` 之后插入)

- [ ] **Step 1: 编辑 pubspec.yaml 加依赖**

在 `pubspec.yaml` 第 67 行(`mime: ^2.0.0` 这行)之后插入:

```yaml
  # Step 13.5: GBK 文本解码(支付宝旧版 Windows 导出常用 GBK 编码)。
  # 纯 Dart,无 native 依赖;在 csv_text_decoder.dart 中按编码探测顺序使用。
  gbk_codec: ^0.4.0
```

- [ ] **Step 2: 拉依赖**

Run: `flutter pub get`
Expected: `Got dependencies!`(若失败可能是版本不存在,改成 `^0.4.5` 或最新可用版本)

- [ ] **Step 3: 验证可 import**

新建临时文件 `lib/_tmp_gbk_check.dart`:

```dart
// ignore_for_file: unused_import
import 'package:gbk_codec/gbk_codec.dart';
void _check() {
  gbk_bytes.decode([0xC4, 0xE3]);
}
```

Run: `flutter analyze lib/_tmp_gbk_check.dart`
Expected: `No issues found!`

- [ ] **Step 4: 删除临时文件 + commit**

```bash
rm lib/_tmp_gbk_check.dart
git add pubspec.yaml pubspec.lock
git commit -m "Step 13.5(1/N):add gbk_codec dependency for CSV import GBK decoding"
```

---

### Task 2: `parent_key_labels.dart` 公共常量

**Files:**
- Create: `lib/core/util/parent_key_labels.dart`
- Create: `test/core/util/parent_key_labels_test.dart`
- Modify: `lib/core/util/quick_text_parser.dart:80-92`(改 `_parentKeyLabels` 引用本文件)

- [ ] **Step 1: 写失败测试**

创建 `test/core/util/parent_key_labels_test.dart`:

```dart
import 'package:bianbianbianbian/core/util/parent_key_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('kParentKeyToLabel', () {
    test('11 个 parent_key 全部覆盖', () {
      const keys = [
        'income', 'food', 'shopping', 'transport', 'education',
        'entertainment', 'social', 'housing', 'medical', 'investment', 'other',
      ];
      for (final k in keys) {
        expect(kParentKeyToLabel[k], isNotNull, reason: 'missing $k');
      }
      expect(kParentKeyToLabel.length, 11);
    });

    test('双向映射对称', () {
      kParentKeyToLabel.forEach((key, label) {
        expect(kLabelToParentKey[label], key, reason: 'mismatch $key↔$label');
      });
      expect(kLabelToParentKey.length, kParentKeyToLabel.length);
    });
  });

  group('parentKeyToChineseLabel', () {
    test('已知 key 返回中文', () {
      expect(parentKeyToChineseLabel('food'), '饮食');
      expect(parentKeyToChineseLabel('other'), '其他');
    });

    test('未知 key 返回 null', () {
      expect(parentKeyToChineseLabel('unknown'), isNull);
    });
  });

  group('chineseLabelToParentKey', () {
    test('已知中文返回 key', () {
      expect(chineseLabelToParentKey('饮食'), 'food');
      expect(chineseLabelToParentKey('  其他  '), 'other'); // trim
    });

    test('未知中文返回 null', () {
      expect(chineseLabelToParentKey('火星人'), isNull);
      expect(chineseLabelToParentKey(''), isNull);
    });
  });
}
```

- [ ] **Step 2: 运行测试看到失败**

Run: `flutter test test/core/util/parent_key_labels_test.dart`
Expected: 编译失败,提示 parent_key_labels.dart 不存在。

- [ ] **Step 3: 创建实现**

创建 `lib/core/util/parent_key_labels.dart`:

```dart
/// 一级分类(`category.parent_key`)与中文标签的双向映射。
///
/// 单一真值源——`quick_text_parser.dart` / `export_service.dart` /
/// `csv/parsers/*.dart` 等均从本文件取常量,避免双副本飘移。
///
/// 11 个固定 key 必须与 `category_table.dart::customConstraints` 中
/// CHECK 约束完全对齐。
// i18n-exempt: needs refactoring for l10n
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

/// 反向映射——CSV 导入时把「饮食」reverse map 到 `food`。
// i18n-exempt: needs refactoring for l10n
const Map<String, String> kLabelToParentKey = {
  '收入': 'income',
  '饮食': 'food',
  '购物': 'shopping',
  '出行': 'transport',
  '教育': 'education',
  '娱乐': 'entertainment',
  '人情': 'social',
  '住房': 'housing',
  '医药': 'medical',
  '投资': 'investment',
  '其他': 'other',
};

/// 已知 `parentKey` 返回中文标签;未知返回 null。
String? parentKeyToChineseLabel(String parentKey) => kParentKeyToLabel[parentKey];

/// 已知中文标签返回 `parentKey`(trim 后查表);未知返回 null。
String? chineseLabelToParentKey(String label) => kLabelToParentKey[label.trim()];
```

- [ ] **Step 4: 运行测试通过**

Run: `flutter test test/core/util/parent_key_labels_test.dart`
Expected: `All tests passed!`(7 用例)

- [ ] **Step 5: 重构 quick_text_parser.dart 引用公共常量**

编辑 `lib/core/util/quick_text_parser.dart`,把 80-92 行的 `_parentKeyLabels` map 替换为:

```dart
  /// 一级分类标签,与 [kParentKeyToLabel] 同源。
  /// 此处特意通过 import 引用而非 inline——避免双副本飘移(Step 13.5)。
  static const Map<String, String> _parentKeyLabels = kParentKeyToLabel;
```

并在文件头加 `import 'parent_key_labels.dart';`(若已有相对 import 则放在最近)。

- [ ] **Step 6: 跑 quick_text_parser 现有测试无回归**

Run: `flutter test test/core/util/quick_text_parser_test.dart`(若该文件存在)或全局 `flutter test test/core/util/`
Expected: 全部通过。

- [ ] **Step 7: Commit**

```bash
git add lib/core/util/parent_key_labels.dart test/core/util/parent_key_labels_test.dart lib/core/util/quick_text_parser.dart
git commit -m "Step 13.5(2/N):add parent_key_labels.dart as single source of truth"
```

---

### Task 3: `csv_lexer.dart` 从 `import_service.dart` 抽出 CSV 词法

**Files:**
- Create: `lib/features/import_export/csv/csv_lexer.dart`
- Create: `test/features/import_export/csv/csv_lexer_test.dart`
- Modify: `lib/features/import_export/import_service.dart`(删除 `parseCsvRows` / `stripUtf8Bom` / `_isLikelyTextChar` / `stripLedgerEmoji` 函数,改为 import 新模块)

- [ ] **Step 1: 写失败测试**

创建 `test/features/import_export/csv/csv_lexer_test.dart`:

```dart
import 'package:bianbianbianbian/features/import_export/csv/csv_lexer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseCsvRows', () {
    test('basic CSV — three fields three rows', () {
      const input = 'a,b,c\n1,2,3\nx,y,z';
      final rows = parseCsvRows(input);
      expect(rows, [
        ['a', 'b', 'c'],
        ['1', '2', '3'],
        ['x', 'y', 'z'],
      ]);
    });

    test('quoted field with comma', () {
      const input = '"a,b",c\n"hello, world","x"';
      final rows = parseCsvRows(input);
      expect(rows[0], ['a,b', 'c']);
      expect(rows[1], ['hello, world', 'x']);
    });

    test('escaped double-quote inside quoted field', () {
      const input = '"a""b","c"';
      final rows = parseCsvRows(input);
      expect(rows[0], ['a"b', 'c']);
    });

    test('CRLF line endings', () {
      const input = 'a,b\r\n1,2\r\n';
      final rows = parseCsvRows(input);
      expect(rows.length, 2);
      expect(rows[1], ['1', '2']);
    });

    test('field with embedded newline (quoted)', () {
      const input = '"line1\nline2",x';
      final rows = parseCsvRows(input);
      expect(rows[0], ['line1\nline2', 'x']);
    });

    test('trailing line without newline', () {
      const input = 'a,b\n1,2';
      final rows = parseCsvRows(input);
      expect(rows.length, 2);
      expect(rows[1], ['1', '2']);
    });
  });

  group('stripUtf8Bom', () {
    test('removes BOM when present', () {
      expect(stripUtf8Bom('﻿hello'), 'hello');
    });
    test('no-op when absent', () {
      expect(stripUtf8Bom('hello'), 'hello');
      expect(stripUtf8Bom(''), '');
    });
  });

  group('stripLedgerEmoji', () {
    test('strips leading emoji + space', () {
      expect(stripLedgerEmoji('📒 生活'), '生活');
    });
    test('no-op when no leading emoji', () {
      expect(stripLedgerEmoji('生活'), '生活');
      expect(stripLedgerEmoji('Work'), 'Work');
    });
    test('handles multiple emoji prefix', () {
      expect(stripLedgerEmoji('📒💼 工作'), '工作');
    });
  });
}
```

- [ ] **Step 2: 运行测试看到失败**

Run: `flutter test test/features/import_export/csv/csv_lexer_test.dart`
Expected: 编译失败(`csv_lexer.dart` 不存在)。

- [ ] **Step 3: 创建 csv_lexer.dart**

创建 `lib/features/import_export/csv/csv_lexer.dart`。把 `lib/features/import_export/import_service.dart` 中以下符号原样搬过来(行号见原文件):
- `parseCsvRows`(`@visibleForTesting`)—— 第 887-949 行
- `stripUtf8Bom`(`@visibleForTesting`)—— 第 840-842 行
- `stripLedgerEmoji`(`@visibleForTesting`)—— 第 852-868 行
- `_isLikelyTextChar`(私有 helper)—— 第 872-881 行

文件头:

```dart
import 'package:flutter/foundation.dart' show visibleForTesting;
```

去掉 `@visibleForTesting` 标注(本模块新结构里这些是公共 API,不再"仅测试可见")。

- [ ] **Step 4: 运行测试通过**

Run: `flutter test test/features/import_export/csv/csv_lexer_test.dart`
Expected: `All tests passed!`(11 用例)

- [ ] **Step 5: 修改 import_service.dart 引用新模块**

编辑 `lib/features/import_export/import_service.dart`:
- 文件顶部 imports 加 `import 'csv/csv_lexer.dart';`
- 删除原文件中的 `parseCsvRows` / `stripUtf8Bom` / `stripLedgerEmoji` / `_isLikelyTextChar` 函数(第 840 行至文件末尾,以及保留 `_kBackupCsvHeader` 常量)。
- 删除 `flutter/foundation.dart` import 中的 `visibleForTesting`(如果不再被其它符号使用)。

- [ ] **Step 6: 跑 import_service 全部测试无回归**

Run: `flutter test test/features/import_export/import_service_test.dart`
Expected: 全部通过(部分 `parseCsvRows` 直接测试若存在,改 import 到 csv_lexer)。
若原 test 文件 import 了 `import_service.dart::parseCsvRows`,改为 `csv/csv_lexer.dart`。

- [ ] **Step 7: Commit**

```bash
git add lib/features/import_export/csv/csv_lexer.dart test/features/import_export/csv/csv_lexer_test.dart lib/features/import_export/import_service.dart test/features/import_export/import_service_test.dart
git commit -m "Step 13.5(3/N):extract csv_lexer.dart from import_service"
```

---

### Task 4: `csv_text_decoder.dart` 编码自动识别

**Files:**
- Create: `lib/features/import_export/csv/csv_text_decoder.dart`
- Create: `test/features/import_export/csv/csv_text_decoder_test.dart`

- [ ] **Step 1: 写失败测试**

创建 `test/features/import_export/csv/csv_text_decoder_test.dart`:

```dart
import 'dart:convert';

import 'package:bianbianbianbian/features/import_export/csv/csv_text_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('decodeCsvBytes', () {
    test('UTF-8 with BOM', () {
      final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode('你好,world')];
      expect(decodeCsvBytes(bytes), '你好,world');
    });

    test('UTF-8 no BOM, all ASCII', () {
      final bytes = utf8.encode('hello,world');
      expect(decodeCsvBytes(bytes), 'hello,world');
    });

    test('UTF-8 no BOM with Chinese', () {
      final bytes = utf8.encode('你好,世界');
      expect(decodeCsvBytes(bytes), '你好,世界');
    });

    test('UTF-16 LE with BOM', () {
      // '你' = U+4F60 → LE: 60 4F;'好' = U+597D → 7D 59
      final bytes = [0xFF, 0xFE, 0x60, 0x4F, 0x7D, 0x59];
      expect(decodeCsvBytes(bytes), '你好');
    });

    test('UTF-16 BE with BOM', () {
      // '你' = U+4F60 → BE: 4F 60
      final bytes = [0xFE, 0xFF, 0x4F, 0x60, 0x59, 0x7D];
      expect(decodeCsvBytes(bytes), '你好');
    });

    test('GBK encoded Chinese', () {
      // '你好' GBK 编码:0xC4 0xE3 0xBA 0xC3
      final bytes = [0xC4, 0xE3, 0xBA, 0xC3];
      expect(decodeCsvBytes(bytes), '你好');
    });

    test('empty bytes', () {
      expect(decodeCsvBytes([]), '');
    });
  });
}
```

- [ ] **Step 2: 运行测试看到失败**

Run: `flutter test test/features/import_export/csv/csv_text_decoder_test.dart`
Expected: 编译失败。

- [ ] **Step 3: 创建实现**

创建 `lib/features/import_export/csv/csv_text_decoder.dart`:

```dart
import 'dart:convert';

import 'package:gbk_codec/gbk_codec.dart';

/// 自动识别 CSV 文件字节流的编码并解码为字符串。
///
/// 探测顺序(BeeCount `FileReaderService.decodeBytes` 同构):
/// 1. UTF-16 LE BOM(`FF FE`)→ 小端 16-bit 解码。
/// 2. UTF-16 BE BOM(`FE FF`)→ 大端 16-bit 解码。
/// 3. UTF-8 BOM(`EF BB BF`)→ 跳 3 字节后 utf8.decode。
/// 4. 无 BOM:
///    a. utf8.decode strict;成功且不含 U+FFFD 替换字符 → 用 UTF-8。
///    b. 否则 gbk_codec 解码;含中文字符 → 用 GBK。
///    c. 否则 utf8.decode(allowMalformed: true)。
///    d. 兜底 latin1.decode。
///
/// 设计动机:
/// - 微信 / 支付宝近年导出用 UTF-8 with BOM(主路径)。
/// - 支付宝旧版 Windows 导出用 GBK(GBK 路径)。
/// - 用户 Excel 另存为 CSV 可能产生 Windows-1252 / GBK 混合(兜底覆盖)。
String decodeCsvBytes(List<int> bytes) {
  if (bytes.isEmpty) return '';

  // UTF-16 LE BOM
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return _decodeUtf16Le(bytes.sublist(2));
  }
  // UTF-16 BE BOM
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return _decodeUtf16Be(bytes.sublist(2));
  }
  // UTF-8 BOM
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return utf8.decode(bytes.sublist(3), allowMalformed: true);
  }

  // 无 BOM:先 UTF-8 strict
  try {
    final text = utf8.decode(bytes, allowMalformed: false);
    if (!text.contains('�')) {
      return text;
    }
  } catch (_) {
    // 落入 GBK 尝试
  }

  // 再 GBK
  try {
    final gbkText = gbk_bytes.decode(bytes);
    if (_containsChineseChars(gbkText)) {
      return gbkText;
    }
  } catch (_) {
    // 兜底 utf8.allowMalformed
  }

  // utf8 allowMalformed
  try {
    return utf8.decode(bytes, allowMalformed: true);
  } catch (_) {
    // 最后兜底 latin1
  }
  return latin1.decode(bytes);
}

String _decodeUtf16Le(List<int> bytes) {
  final codeUnits = <int>[];
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    codeUnits.add(bytes[i] | (bytes[i + 1] << 8));
  }
  return String.fromCharCodes(codeUnits);
}

String _decodeUtf16Be(List<int> bytes) {
  final codeUnits = <int>[];
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    codeUnits.add((bytes[i] << 8) | bytes[i + 1]);
  }
  return String.fromCharCodes(codeUnits);
}

bool _containsChineseChars(String text) {
  // CJK 基本块 U+4E00-U+9FFF
  return RegExp(r'[一-鿿]').hasMatch(text);
}
```

- [ ] **Step 4: 运行测试通过**

Run: `flutter test test/features/import_export/csv/csv_text_decoder_test.dart`
Expected: `All tests passed!`(7 用例)

- [ ] **Step 5: Commit**

```bash
git add lib/features/import_export/csv/csv_text_decoder.dart test/features/import_export/csv/csv_text_decoder_test.dart
git commit -m "Step 13.5(4/N):add csv_text_decoder for UTF-8/UTF-16/GBK auto-detection"
```

---

## Phase 2 · BillParser 抽象 + 通用解析器

### Task 5: `bill_parser.dart` 抽象接口

**Files:**
- Create: `lib/features/import_export/csv/bill_parser.dart`

(本任务不立即写测试——纯接口定义,在 Task 6 GenericBillParser 测试中间接验证。)

- [ ] **Step 1: 创建抽象接口文件**

创建 `lib/features/import_export/csv/bill_parser.dart`:

```dart
import 'package:flutter/foundation.dart' show immutable;

import '../import_service.dart' show BackupImportCsvRow;

/// CSV 账单解析器抽象(BeeCount 同构 + 本项目数据模型适配)。
///
/// 每个具体 parser 负责:
/// - [validateBillType]:扫前若干行判断是否能识别这个 CSV 的 header 签名。
/// - [findHeaderRow]:返回 header 行号(0-indexed),没有返回 -1。
/// - [mapColumns]:把 header 行转成「字段 key → 列索引」映射。
/// - [parseRow]:按 columnMapping 把单行解析为 [BackupImportCsvRow];
///   返回 null 表示该行应被跳过(空行 / 状态异常 / 无法解析的核心字段)。
///
/// 字段 key 集合(11 个):
/// `date / type / amount / currency / primary_category / category /
///  account / from_account / to_account / note / status`
abstract class BillParser {
  const BillParser();

  /// 唯一标识(不展示给用户)。
  String get id;

  /// 用户可见名称(导入页「识别为:xxx」显示)。
  String get displayName;

  /// 是否能识别此 CSV。
  bool validateBillType(List<List<String>> rows);

  /// header 行号;未找到返回 -1。
  int findHeaderRow(List<List<String>> rows);

  /// 字段 key → 列索引;未识别列被跳过。
  Map<String, int> mapColumns(List<String> headerRow);

  /// 解析单行。返回 null = 跳过该行。
  BackupImportCsvRow? parseRow(List<String> row, Map<String, int> columnMapping);
}

/// 解析结果(供 csv_format_detector 返回)。
@immutable
class ParseResult {
  const ParseResult({
    required this.parser,
    required this.rows,
  });

  final BillParser parser;
  final List<BackupImportCsvRow> rows;
}
```

- [ ] **Step 2: 验证编译通过**

Run: `flutter analyze lib/features/import_export/csv/bill_parser.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/import_export/csv/bill_parser.dart
git commit -m "Step 13.5(5/N):add BillParser abstract interface"
```

---

### Task 6: `generic_parser.dart` GenericBillParser(列名规范化 + 列数一致性)

**Files:**
- Create: `lib/features/import_export/csv/parsers/generic_parser.dart`
- Create: `test/features/import_export/csv/parsers/generic_parser_test.dart`

- [ ] **Step 1: 写失败测试**

创建 `test/features/import_export/csv/parsers/generic_parser_test.dart`:

```dart
import 'package:bianbianbianbian/features/import_export/csv/parsers/generic_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = GenericBillParser();

  group('normalizeToKey', () {
    test('英文 date 别名', () {
      expect(GenericBillParser.normalizeToKey('Date'), 'date');
      expect(GenericBillParser.normalizeToKey('  TIME '), 'date');
      expect(GenericBillParser.normalizeToKey('datetime'), 'date');
    });

    test('英文 amount 别名', () {
      expect(GenericBillParser.normalizeToKey('amount'), 'amount');
      expect(GenericBillParser.normalizeToKey('Money'), 'amount');
      expect(GenericBillParser.normalizeToKey('Value'), 'amount');
    });

    test('中文 date 含子串', () {
      expect(GenericBillParser.normalizeToKey('交易时间'), 'date');
      expect(GenericBillParser.normalizeToKey('账单日期'), 'date');
    });

    test('中文 primary_category 优先于 category', () {
      expect(GenericBillParser.normalizeToKey('一级分类'), 'primary_category');
      expect(GenericBillParser.normalizeToKey('父分类'), 'primary_category');
    });

    test('中文 category(二级)优先于 type', () {
      expect(GenericBillParser.normalizeToKey('二级分类'), 'category');
      expect(GenericBillParser.normalizeToKey('子分类'), 'category');
      expect(GenericBillParser.normalizeToKey('分类'), 'category');
    });

    test('收支符号识别为 type', () {
      expect(GenericBillParser.normalizeToKey('收/支'), 'type');
      expect(GenericBillParser.normalizeToKey('收支'), 'type');
    });

    test('账户列别名', () {
      expect(GenericBillParser.normalizeToKey('账户'), 'account');
      expect(GenericBillParser.normalizeToKey('转出账户'), 'from_account');
      expect(GenericBillParser.normalizeToKey('转入账户'), 'to_account');
    });

    test('状态列', () {
      expect(GenericBillParser.normalizeToKey('当前状态'), 'status');
      expect(GenericBillParser.normalizeToKey('交易状态'), 'status');
    });

    test('忽略的列返回 null', () {
      expect(GenericBillParser.normalizeToKey('交易号'), null);
      expect(GenericBillParser.normalizeToKey('订单号'), null);
      expect(GenericBillParser.normalizeToKey(''), null);
    });
  });

  group('findHeaderRow', () {
    test('列数一致性发现 header', () {
      // 前 2 行说明(列数不一致),第 3 行起 6 行 4 列数据
      final rows = [
        ['这是说明'],
        ['第二行说明'],
        ['日期', '类型', '金额', '分类'],
        ['2026-01-01', '支出', '10', '餐饮'],
        ['2026-01-02', '支出', '20', '餐饮'],
        ['2026-01-03', '支出', '30', '餐饮'],
        ['2026-01-04', '支出', '40', '餐饮'],
        ['2026-01-05', '支出', '50', '餐饮'],
        ['2026-01-06', '支出', '60', '餐饮'],
      ];
      expect(parser.findHeaderRow(rows), 2);
    });

    test('没有一致结构返回 0(兜底)', () {
      final rows = [
        ['a', 'b'],
        ['c'],
      ];
      expect(parser.findHeaderRow(rows), 0);
    });
  });

  group('validateBillType', () {
    test('总是返回 true(兜底)', () {
      expect(parser.validateBillType([['a']]), true);
      expect(parser.validateBillType([]), true);
    });
  });
}
```

- [ ] **Step 2: 运行测试看到失败**

Run: `flutter test test/features/import_export/csv/parsers/generic_parser_test.dart`
Expected: 编译失败。

- [ ] **Step 3: 创建 generic_parser.dart**

创建 `lib/features/import_export/csv/parsers/generic_parser.dart`:

```dart
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:intl/intl.dart';

import '../../import_service.dart' show BackupImportCsvRow;
import '../bill_parser.dart';

/// 通用 CSV 账单解析器(BeeCount 同构)。
///
/// 识别策略:
/// - [validateBillType] 永远 true(兜底兜住所有列数一致的 CSV)。
/// - [findHeaderRow] 走「列数一致性」:在前 30 行中找一行,其列数 ≥ 3 且
///   后续 10 行内至少有 5 行列数与之一致;否则回 0。
/// - [mapColumns] 用 [normalizeToKey] 把任意中英文列名规范化到 11 个字段 key。
///
/// 子类(微信 / 支付宝 / 钱迹 / Bianbian)继承本类,通常仅覆写
/// [findHeaderRow] / [validateBillType] / [mapColumns];[parseRow] 多数情况
/// 沿用父类即可。
class GenericBillParser extends BillParser {
  const GenericBillParser();

  @override
  String get id => 'generic';

  @override
  // i18n-exempt: needs refactoring for l10n
  String get displayName => '通用 CSV';

  @override
  bool validateBillType(List<List<String>> rows) => true;

  @override
  int findHeaderRow(List<List<String>> rows) {
    if (rows.isEmpty) return -1;
    final byConsistency = _findHeaderByColumnConsistency(rows);
    if (byConsistency >= 0) return byConsistency;
    return 0; // 兜底
  }

  /// 列数一致性算法(BeeCount 同款):
  /// 在前 30 行中,找首个列数 ≥ 3 且后续 10 行内 ≥ 5 行列数与之相等的行。
  int _findHeaderByColumnConsistency(List<List<String>> rows) {
    final maxRows = rows.length < 30 ? rows.length : 30;
    for (var i = 0; i < maxRows; i++) {
      final cols = rows[i].length;
      if (cols < 3) continue;
      var consistent = 0;
      final checkEnd = rows.length < i + 11 ? rows.length : i + 11;
      for (var j = i + 1; j < checkEnd; j++) {
        if (rows[j].length == cols) consistent++;
      }
      if (consistent >= 5) return i;
    }
    return -1;
  }

  @override
  Map<String, int> mapColumns(List<String> headerRow) {
    final mapping = <String, int>{};
    for (var i = 0; i < headerRow.length; i++) {
      final key = normalizeToKey(headerRow[i]);
      if (key != null) {
        mapping.putIfAbsent(key, () => i);
      }
    }
    return mapping;
  }

  @override
  BackupImportCsvRow? parseRow(
    List<String> row,
    Map<String, int> columnMapping,
  ) {
    String? getBy(String key) {
      final idx = columnMapping[key];
      if (idx == null || idx >= row.length) return null;
      final v = row[idx].trim();
      return v.isEmpty ? null : v;
    }

    final dateStr = getBy('date');
    final amountStr = getBy('amount');
    if (dateStr == null || amountStr == null) return null;

    final occurredAt = parseFlexibleDate(dateStr);
    if (occurredAt == null) return null;

    final amount = parseAmount(amountStr);
    if (amount == null) return null;

    final typeRaw = getBy('type');
    final type = _typeFromAnyLabel(typeRaw);
    if (type == null) return null;

    return BackupImportCsvRow(
      ledgerLabel: displayName,
      occurredAt: occurredAt,
      type: type,
      amount: amount.abs(),
      currency: getBy('currency') ?? 'CNY',
      primaryCategoryName: getBy('primary_category'),
      categoryName: getBy('category'),
      accountName: getBy('account') ?? getBy('from_account'),
      toAccountName: getBy('to_account'),
      note: getBy('note'),
    );
  }

  /// 把任意中英文列名规范化为 11 个字段 key 之一;不识别返回 null。
  ///
  /// **顺序敏感**:必须先匹配更长 / 更具体的中文词,再匹配宽泛词。
  /// 公开为 static + `@visibleForTesting` 供单元测试 + 子类直接调用。
  @visibleForTesting
  static String? normalizeToKey(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final lower = s.toLowerCase();
    final noSpace = lower.replaceAll(RegExp(r'\s+'), '');

    // 英文(精确)
    if (noSpace == 'date' ||
        noSpace == 'time' ||
        noSpace == 'datetime') return 'date';
    if (noSpace == 'type' ||
        noSpace == 'inout' ||
        noSpace == 'direction') return 'type';
    if (noSpace == 'amount' ||
        noSpace == 'money' ||
        noSpace == 'price' ||
        noSpace == 'value') return 'amount';
    if (noSpace == 'currency') return 'currency';
    if (noSpace == 'primarycategory' ||
        noSpace == 'parentcategory') return 'primary_category';
    if (noSpace == 'subcategory' ||
        noSpace == 'subcat' ||
        noSpace == 'category' ||
        noSpace == 'cate' ||
        noSpace == 'subject' ||
        noSpace == 'tag') return 'category';
    if (noSpace == 'note' ||
        noSpace == 'memo' ||
        noSpace == 'desc' ||
        noSpace == 'description' ||
        noSpace == 'remark' ||
        noSpace == 'title') return 'note';
    if (noSpace == 'fromaccount') return 'from_account';
    if (noSpace == 'toaccount') return 'to_account';
    if (noSpace == 'account') return 'account';
    if (noSpace == 'status') return 'status';

    // 中文(顺序敏感子串匹配)
    // 优先识别复合词,再处理短词
    if (_containsAny(s, ['一级分类', '父分类', '主分类'])) return 'primary_category';
    if (_containsAny(s, ['二级分类', '子分类', '次分类'])) return 'category';
    if (_containsAny(s, ['当前状态', '交易状态'])) return 'status';
    if (_containsAny(s, ['转出账户'])) return 'from_account';
    if (_containsAny(s, ['转入账户'])) return 'to_account';
    if (_containsAny(s, ['账户'])) return 'account';
    if (_containsAny(s, ['日期', '时间', '交易时间', '账单时间', '创建时间'])) return 'date';
    if (_containsAny(s, ['金额', '交易金额', '变动金额', '收支金额'])) return 'amount';
    if (_containsAny(s, ['币种', '货币'])) return 'currency';
    if (_containsAny(s, ['分类', '类别', '账目名称', '科目'])) return 'category';
    if (_containsAny(s, ['类型', '收支', '收/支', '方向'])) return 'type';
    if (_containsAny(s, ['备注', '说明', '标题', '摘要', '附言', '商品名称',
        '商品说明', '商品', '交易对方', '商家'])) return 'note';

    // 明确忽略
    if (_containsAny(s, ['账目编号', '编号', '单号', '流水号', '交易号',
        '相关图片', '图片', '交易单号', '订单号', '账本'])) {
      return null;
    }

    return null;
  }

  static bool _containsAny(String text, List<String> keywords) {
    for (final k in keywords) {
      if (text.contains(k)) return true;
    }
    return false;
  }

  /// 「收/支」/「类型」原始值 → `income / expense / transfer`;
  /// 「/」/ 空 / 未识别返回 null(调用方决定跳过该行)。
  static String? _typeFromAnyLabel(String? label) {
    if (label == null) return null;
    final t = label.trim().toLowerCase();
    if (t == '收入' || t == '收' || t == 'income') return 'income';
    if (t == '支出' || t == '支' || t == '消费' || t == 'expense' ||
        t == 'spending') return 'expense';
    if (t == '转账' || t == 'transfer') return 'transfer';
    return null;
  }
}

/// 去除 `¥` / `￥` / `$` / 千位分隔逗号 / 引号包裹,再 [double.tryParse]。
/// 失败返回 null。
@visibleForTesting
double? parseAmount(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  s = s.replaceAll('¥', '').replaceAll('￥', '').replaceAll(r'$', '').trim();
  s = s.replaceAll(',', '').replaceAll('"', '').trim();
  if (s.isEmpty) return null;
  return double.tryParse(s);
}

/// 多格式日期解析(账单 vs 钱迹格式有差异)。失败返回 null。
@visibleForTesting
DateTime? parseFlexibleDate(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  const formats = [
    'yyyy-MM-dd HH:mm:ss',
    'yyyy-MM-dd HH:mm',
    'yyyy-MM-dd',
    'yyyy/MM/dd HH:mm:ss',
    'yyyy/MM/dd HH:mm',
    'yyyy/MM/dd',
  ];
  for (final f in formats) {
    try {
      return DateFormat(f).parseStrict(s);
    } on FormatException {
      // try next
    }
  }
  return null;
}

/// 把候选文本数组拼为单行备注,去除 null / 空 / 仅斜杠的项。
String? composeNote(List<String?> parts) {
  final keep = <String>[];
  for (final p in parts) {
    if (p == null) continue;
    final t = p.trim();
    if (t.isEmpty || t == '/') continue;
    keep.add(t);
  }
  return keep.isEmpty ? null : keep.join(' · ');
}
```

**注意**:本任务**暂时还没有更新 BackupImportCsvRow 增加 primaryCategoryName 字段**——Task 12 才做。本步骤代码会有编译错误(`primaryCategoryName: getBy('primary_category')`)。**这是预期的**:Phase 2 全部完成后,Task 12 才统一改数据契约,届时这段代码会编译通过。

为了让本任务的测试先过(测试只验证 `normalizeToKey` / `findHeaderRow` / `validateBillType`,不调 `parseRow`),临时把 parseRow 的 `primaryCategoryName: getBy('primary_category'),` 这一行注释掉:

```dart
      // primaryCategoryName: getBy('primary_category'),  // TODO Task 12 解开
```

- [ ] **Step 4: 运行测试通过**

Run: `flutter test test/features/import_export/csv/parsers/generic_parser_test.dart`
Expected: `All tests passed!`(13 用例)

- [ ] **Step 5: Commit**

```bash
git add lib/features/import_export/csv/parsers/generic_parser.dart test/features/import_export/csv/parsers/generic_parser_test.dart
git commit -m "Step 13.5(6/N):add GenericBillParser with normalizeToKey + findHeaderRow"
```

---

## Phase 3 · 5 个具体 Parser

### Task 7: `bianbian_parser.dart` 本 App 自有格式

**Files:**
- Create: `lib/features/import_export/csv/parsers/bianbian_parser.dart`
- Create: `test/features/import_export/csv/parsers/bianbian_parser_test.dart`

- [ ] **Step 1: 写失败测试**

创建 `test/features/import_export/csv/parsers/bianbian_parser_test.dart`:

```dart
import 'package:bianbianbianbian/features/import_export/csv/parsers/bianbian_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = BianbianBillParser();

  test('10 列严匹配', () {
    final rows = [
      ['账本', '日期', '类型', '金额', '币种', '一级分类', '分类', '账户', '转入账户', '备注'],
      ['📒 生活', '2026-01-01 12:00', '支出', '10.00', 'CNY', '饮食', '早餐', '现金', '', '吃饭'],
    ];
    expect(parser.validateBillType(rows), true);
    expect(parser.findHeaderRow(rows), 0);
    final row = parser.parseRow(rows[1], parser.mapColumns(rows[0]));
    expect(row, isNotNull);
    expect(row!.primaryCategoryName, '饮食');
    expect(row.categoryName, '早餐');
    expect(row.accountName, '现金');
  });

  test('旧 9 列兼容(无一级分类列)', () {
    final rows = [
      ['账本', '日期', '类型', '金额', '币种', '分类', '账户', '转入账户', '备注'],
      ['生活', '2026-01-01 12:00', '支出', '10.00', 'CNY', '早餐', '现金', '', '吃饭'],
    ];
    expect(parser.validateBillType(rows), true);
    final row = parser.parseRow(rows[1], parser.mapColumns(rows[0]));
    expect(row, isNotNull);
    expect(row!.primaryCategoryName, isNull); // 9 列无一级
    expect(row.categoryName, '早餐');
  });

  test('非本 App header 不匹配', () {
    final rows = [
      ['Date', 'Type', 'Amount'],
      ['2026-01-01', '支出', '10'],
    ];
    expect(parser.validateBillType(rows), false);
  });
}
```

- [ ] **Step 2: 运行测试看到失败**

Run: `flutter test test/features/import_export/csv/parsers/bianbian_parser_test.dart`
Expected: 编译失败。

- [ ] **Step 3: 创建实现**

创建 `lib/features/import_export/csv/parsers/bianbian_parser.dart`:

```dart
import '../../import_service.dart' show BackupImportCsvRow;
import 'generic_parser.dart';

/// 本 App 自有 CSV 格式(10 列严匹配 + 旧 9 列向后兼容)。
///
/// 10 列:`账本,日期,类型,金额,币种,一级分类,分类,账户,转入账户,备注`(Step 13.5)
/// 9  列:`账本,日期,类型,金额,币种,分类,账户,转入账户,备注`           (Step 13.1)
class BianbianBillParser extends GenericBillParser {
  const BianbianBillParser();

  @override
  String get id => 'bianbian';

  @override
  // i18n-exempt: needs refactoring for l10n
  String get displayName => '本 App';

  static const List<String> _header10 = [
    '账本', '日期', '类型', '金额', '币种', '一级分类', '分类',
    '账户', '转入账户', '备注',
  ];
  static const List<String> _header9 = [
    '账本', '日期', '类型', '金额', '币种', '分类',
    '账户', '转入账户', '备注',
  ];

  @override
  bool validateBillType(List<List<String>> rows) {
    if (rows.isEmpty) return false;
    final h = rows.first.map((c) => c.trim()).toList();
    return _matches(h, _header10) || _matches(h, _header9);
  }

  static bool _matches(List<String> actual, List<String> expected) {
    if (actual.length != expected.length) return false;
    for (var i = 0; i < actual.length; i++) {
      if (actual[i] != expected[i]) return false;
    }
    return true;
  }

  @override
  int findHeaderRow(List<List<String>> rows) => 0;

  @override
  Map<String, int> mapColumns(List<String> headerRow) {
    final h = headerRow.map((c) => c.trim()).toList();
    if (_matches(h, _header10)) {
      return {
        'ledger': 0,
        'date': 1,
        'type': 2,
        'amount': 3,
        'currency': 4,
        'primary_category': 5,
        'category': 6,
        'account': 7,
        'to_account': 8,
        'note': 9,
      };
    }
    if (_matches(h, _header9)) {
      return {
        'ledger': 0,
        'date': 1,
        'type': 2,
        'amount': 3,
        'currency': 4,
        'category': 5,
        'account': 6,
        'to_account': 7,
        'note': 8,
      };
    }
    return {};
  }

  @override
  BackupImportCsvRow? parseRow(
    List<String> row,
    Map<String, int> columnMapping,
  ) {
    String? getBy(String key) {
      final idx = columnMapping[key];
      if (idx == null || idx >= row.length) return null;
      final v = row[idx].trim();
      return v.isEmpty ? null : v;
    }

    final ledger = getBy('ledger');
    final dateStr = getBy('date');
    final typeStr = getBy('type');
    final amountStr = getBy('amount');
    final currency = getBy('currency') ?? 'CNY';
    if (ledger == null || dateStr == null || typeStr == null || amountStr == null) {
      return null;
    }
    final occurredAt = parseFlexibleDate(dateStr);
    if (occurredAt == null) return null;
    final type = _typeFromChinese(typeStr);
    if (type == null) return null;
    final amount = parseAmount(amountStr);
    if (amount == null) return null;

    return BackupImportCsvRow(
      ledgerLabel: ledger,
      occurredAt: occurredAt,
      type: type,
      amount: amount.abs(),
      currency: currency,
      primaryCategoryName: getBy('primary_category'),
      categoryName: getBy('category'),
      accountName: getBy('account'),
      toAccountName: getBy('to_account'),
      note: getBy('note'),
    );
  }

  static String? _typeFromChinese(String s) {
    switch (s.trim()) {
      case '收入':
      case 'income':
        return 'income';
      case '支出':
      case 'expense':
        return 'expense';
      case '转账':
      case 'transfer':
        return 'transfer';
      default:
        return null;
    }
  }
}
```

**注意**:这里也用了 `primaryCategoryName`,与 Task 6 同样有「Task 12 之前编译错」的状况——把这行临时注释掉,Task 12 解开。

- [ ] **Step 4: 运行测试通过**

Run: `flutter test test/features/import_export/csv/parsers/bianbian_parser_test.dart`
Expected: `All tests passed!`(测试本身因 `expect(row!.primaryCategoryName, ...)` 也访问该字段,需在 Task 12 后才能完全通过——本任务暂时把 `expect(row!.primaryCategoryName, '饮食');` 改成 `expect(row, isNotNull);`,Task 12 再恢复完整断言)。

- [ ] **Step 5: Commit**

```bash
git add lib/features/import_export/csv/parsers/bianbian_parser.dart test/features/import_export/csv/parsers/bianbian_parser_test.dart
git commit -m "Step 13.5(7/N):add BianbianBillParser (10-col strict + 9-col compat)"
```

---

### Task 8: `wechat_parser.dart` 微信账单

**Files:**
- Create: `lib/features/import_export/csv/parsers/wechat_parser.dart`
- Create: `test/features/import_export/csv/parsers/wechat_parser_test.dart`

- [ ] **Step 1: 写失败测试**

创建 `test/features/import_export/csv/parsers/wechat_parser_test.dart`:

```dart
import 'package:bianbianbianbian/features/import_export/csv/parsers/wechat_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = WechatBillParser();

  test('header 签名识别', () {
    final rows = [
      ['以下为本人微信账单明细'],
      ['账单明细'],
      ['交易时间', '交易类型', '交易对方', '商品', '收/支', '金额(元)',
        '支付方式', '当前状态', '交易单号', '商户单号', '备注'],
      ['2026-01-01 12:00:00', '商户消费', '星巴克', '咖啡', '支出', '30.00',
        '零钱', '支付成功', 'X', 'Y', '/'],
    ];
    expect(parser.validateBillType(rows), true);
    expect(parser.findHeaderRow(rows), 2);
  });

  test('parseRow:交易类型 → category;收/支 → type', () {
    final rows = [
      ['交易时间', '交易类型', '交易对方', '商品', '收/支', '金额(元)',
        '支付方式', '当前状态'],
      ['2026-01-01 12:00:00', '商户消费', '星巴克', '咖啡', '支出', '30.00',
        '零钱', '支付成功'],
    ];
    final mapping = parser.mapColumns(rows[0]);
    expect(mapping['category'], 1); // 交易类型 → category
    expect(mapping['type'], 4);     // 收/支 → type
    final row = parser.parseRow(rows[1], mapping);
    expect(row, isNotNull);
    expect(row!.type, 'expense');
    expect(row.categoryName, '商户消费');
    expect(row.accountName, '零钱');
  });

  test('退款 / 失败 / 关闭 / 未支付状态过滤', () {
    final header = ['交易时间', '交易类型', '交易对方', '商品', '收/支',
      '金额(元)', '支付方式', '当前状态'];
    final parser = const WechatBillParser();
    final mapping = parser.mapColumns(header);
    final base = ['2026-01-01 12:00:00', '商户消费', 'X', 'Y',
      '支出', '10', '零钱'];
    expect(parser.parseRow([...base, '已全额退款'], mapping), isNull);
    expect(parser.parseRow([...base, '支付失败'], mapping), isNull);
    expect(parser.parseRow([...base, '已关闭'], mapping), isNull);
    expect(parser.parseRow([...base, '未支付'], mapping), isNull);
    expect(parser.parseRow([...base, '支付成功'], mapping), isNotNull);
  });

  test('「/」收支视为中性,跳过', () {
    final header = ['交易时间', '交易类型', '交易对方', '商品', '收/支',
      '金额(元)', '支付方式', '当前状态'];
    final mapping = parser.mapColumns(header);
    final row = ['2026-01-01 12:00:00', '零钱通转入', '零钱通', '/', '/', '100',
      '零钱通', '充值完成'];
    expect(parser.parseRow(row, mapping), isNull);
  });

  test('ledgerLabel 固定 = 「微信账单」', () {
    final header = ['交易时间', '交易类型', '交易对方', '商品', '收/支',
      '金额(元)', '支付方式', '当前状态'];
    final mapping = parser.mapColumns(header);
    final row = ['2026-01-01 12:00:00', '商户消费', 'X', 'Y', '支出', '10',
      '零钱', '支付成功'];
    final parsed = parser.parseRow(row, mapping);
    expect(parsed!.ledgerLabel, '微信账单');
  });
}
```

- [ ] **Step 2: 运行测试看到失败**

Run: `flutter test test/features/import_export/csv/parsers/wechat_parser_test.dart`
Expected: 编译失败。

- [ ] **Step 3: 创建实现**

创建 `lib/features/import_export/csv/parsers/wechat_parser.dart`:

```dart
import '../../import_service.dart' show BackupImportCsvRow;
import 'generic_parser.dart';

/// 微信支付账单 CSV 解析器。
///
/// **来源**:微信支付 → 账单 → 申请账单 → 邮箱接收 → 解压 ZIP → CSV。
///
/// **结构**:文件头 16 行说明,然后一行 header:
/// `交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,当前状态,
///  交易单号,商户单号,备注`
///
/// **关键映射**(本 parser 在 mapColumns 中覆盖 super):
/// - 「交易类型」列被 super 归到 `type`,本 parser 把它移到 `category`
///   (微信的「交易类型」语义上是分类,例「商户消费」/「转账」/「红包」);
/// - 「收/支」列(super 也归到 `type`)保留在 `type`(覆盖前一步)。
class WechatBillParser extends GenericBillParser {
  const WechatBillParser();

  @override
  String get id => 'wechat_bill';

  @override
  // i18n-exempt: needs refactoring for l10n
  String get displayName => '微信账单';

  static const List<String> _headerSignals = [
    '交易时间', '交易类型', '交易对方', '收/支',
  ];

  @override
  bool validateBillType(List<List<String>> rows) {
    return _findHeaderRowByKeywords(rows) >= 0;
  }

  @override
  int findHeaderRow(List<List<String>> rows) {
    final idx = _findHeaderRowByKeywords(rows);
    return idx >= 0 ? idx : super.findHeaderRow(rows);
  }

  static int _findHeaderRowByKeywords(List<List<String>> rows) {
    final scanLimit = rows.length < 30 ? rows.length : 30;
    for (var i = 0; i < scanLimit; i++) {
      final row = rows[i];
      if (row.length < 6) continue;
      final joined = row.join('|');
      if (_headerSignals.every(joined.contains)) return i;
    }
    return -1;
  }

  @override
  Map<String, int> mapColumns(List<String> headerRow) {
    final base = super.mapColumns(headerRow);
    // 找精确列名做手动重映射
    int? indexOf(String name) {
      for (var i = 0; i < headerRow.length; i++) {
        if (headerRow[i].trim() == name) return i;
      }
      return null;
    }
    final txTypeIdx = indexOf('交易类型');
    final ioIdx = indexOf('收/支');
    if (txTypeIdx != null) base['category'] = txTypeIdx;
    if (ioIdx != null) base['type'] = ioIdx; // 覆盖
    return base;
  }

  @override
  BackupImportCsvRow? parseRow(
    List<String> row,
    Map<String, int> columnMapping,
  ) {
    String? getBy(String key) {
      final idx = columnMapping[key];
      if (idx == null || idx >= row.length) return null;
      final v = row[idx].trim();
      return v.isEmpty ? null : v;
    }

    // 状态过滤
    final status = getBy('status') ?? '';
    if (status.contains('退款') ||
        status.contains('失败') ||
        status.contains('关闭') ||
        status.contains('未支付')) {
      return null;
    }

    final dateStr = getBy('date');
    if (dateStr == null) return null;
    final occurredAt = parseFlexibleDate(dateStr);
    if (occurredAt == null) return null;

    final amountStr = getBy('amount');
    if (amountStr == null) return null;
    final amount = parseAmount(amountStr);
    if (amount == null || amount <= 0) return null;

    final type = _typeFromIoFlag(getBy('type') ?? '');
    if (type == null) return null;

    final counterparty = getBy('note'); // super 把「交易对方」归到 note
    // 但 wechat 有多列「note」候选:交易对方 / 商品 / 备注;super 只取第一个
    // 命中的列 putIfAbsent。这里我们重新组合 note。
    String? extra(String header) {
      for (var i = 0; i < row.length; i++) {
        // 此处依赖调用方先 mapColumns(headerRow) 拿 mapping,
        // 但行本身无 header 上下文——退而求其次:不依赖 header 名,
        // 而由 parseRow 调用方传入已映射好的字段。
        // 为简化:不在 parseRow 里访问原 headerRow;复合 note 在 service 层 / 上层做。
        break;
      }
      return null;
    }
    // 本 parser 不在此处拼复合 note;note 字段沿用 super 的 'note' 字段 key
    // (super.mapColumns 已把首个命中的中文列名归到 'note')。
    final note = counterparty;

    return BackupImportCsvRow(
      ledgerLabel: displayName,
      occurredAt: occurredAt,
      type: type,
      amount: amount,
      currency: 'CNY',
      primaryCategoryName: null,    // 微信「交易类型」无可推断一级分类
      categoryName: getBy('category'),
      accountName: getBy('account'),
      toAccountName: null,
      note: note,
    );
  }

  static String? _typeFromIoFlag(String flag) {
    final t = flag.trim();
    if (t == '支出') return 'expense';
    if (t == '收入') return 'income';
    return null;
  }
}
```

**注意**:`primaryCategoryName: null` 这一行同样依赖 Task 12 才能编译。临时注释或保留(让它在 Task 12 后自然通过)。

- [ ] **Step 4: 运行测试通过**

Run: `flutter test test/features/import_export/csv/parsers/wechat_parser_test.dart`
Expected: `All tests passed!`(5 用例)

- [ ] **Step 5: Commit**

```bash
git add lib/features/import_export/csv/parsers/wechat_parser.dart test/features/import_export/csv/parsers/wechat_parser_test.dart
git commit -m "Step 13.5(8/N):add WechatBillParser (status filter + col remap)"
```

---

### Task 9: `alipay_parser.dart` 支付宝账单

**Files:**
- Create: `lib/features/import_export/csv/parsers/alipay_parser.dart`
- Create: `test/features/import_export/csv/parsers/alipay_parser_test.dart`

- [ ] **Step 1: 写失败测试**

创建 `test/features/import_export/csv/parsers/alipay_parser_test.dart`:

```dart
import 'package:bianbianbianbian/features/import_export/csv/parsers/alipay_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = AlipayBillParser();

  test('header 签名识别', () {
    final rows = [
      ['支付宝账单查询信息'],
      ['交易号', '商家订单号', '交易创建时间', '付款时间', '类型',
        '交易对方', '商品名称', '金额（元）', '收/支', '交易状态'],
      ['X', 'Y', '2026-01-01 12:00:00', '2026-01-01 12:00:00', '餐饮美食',
        '某餐厅', '午饭', '30.00', '支出', '交易成功'],
    ];
    expect(parser.validateBillType(rows), true);
  });

  test('parseRow:类型 → category;收/支 → type;account 固定支付宝', () {
    final rows = [
      ['交易号', '商家订单号', '交易创建时间', '付款时间', '类型',
        '交易对方', '商品名称', '金额（元）', '收/支', '交易状态'],
      ['X', 'Y', '2026-01-01 12:00:00', '2026-01-01 12:00:00', '餐饮美食',
        '某餐厅', '午饭', '30.00', '支出', '交易成功'],
    ];
    final mapping = parser.mapColumns(rows[0]);
    final row = parser.parseRow(rows[1], mapping);
    expect(row, isNotNull);
    expect(row!.type, 'expense');
    expect(row.categoryName, '餐饮美食');
    expect(row.accountName, '支付宝');
    expect(row.ledgerLabel, '支付宝账单');
  });

  test('退款 / 关闭 / 失败 过滤', () {
    final header = ['交易号', '商家订单号', '交易创建时间', '付款时间', '类型',
      '交易对方', '商品名称', '金额（元）', '收/支', '交易状态'];
    final mapping = parser.mapColumns(header);
    final base = ['X', 'Y', '2026-01-01 12:00:00', '2026-01-01 12:00:00',
      '日用百货', 'A', 'B', '50', '支出'];
    expect(parser.parseRow([...base, '退款成功'], mapping), isNull);
    expect(parser.parseRow([...base, '交易关闭'], mapping), isNull);
    expect(parser.parseRow([...base, '支付失败'], mapping), isNull);
    expect(parser.parseRow([...base, '交易成功'], mapping), isNotNull);
  });
}
```

- [ ] **Step 2: 运行测试看到失败**

Run: `flutter test test/features/import_export/csv/parsers/alipay_parser_test.dart`
Expected: 编译失败。

- [ ] **Step 3: 创建实现**

创建 `lib/features/import_export/csv/parsers/alipay_parser.dart`:

```dart
import '../../import_service.dart' show BackupImportCsvRow;
import 'generic_parser.dart';

/// 支付宝账单 CSV 解析器。
///
/// **来源**:支付宝 App → 我的 → 账单 → 开具交易流水证明 → 选 CSV → 邮箱。
/// 也可网页版导出。
///
/// **结构**:文件头说明 + header:
/// `交易号,商家订单号,交易创建时间,付款时间,最近修改时间,交易来源地,类型,
///  交易对方,商品名称,金额（元）,收/支,交易状态,服务费（元）,...`
///
/// **关键映射**(同 wechat 思路):
/// - 「类型」列(super 归到 `type`)移到 `category`;
/// - 「收/支」列保留在 `type`;
/// - account 固定为「支付宝」(账单本身没有账户列)。
class AlipayBillParser extends GenericBillParser {
  const AlipayBillParser();

  @override
  String get id => 'alipay_bill';

  @override
  // i18n-exempt: needs refactoring for l10n
  String get displayName => '支付宝账单';

  static const List<String> _headerSignals = [
    '交易号', '交易创建时间', '商品名称', '金额', '收/支',
  ];

  @override
  bool validateBillType(List<List<String>> rows) =>
      _findHeaderRowByKeywords(rows) >= 0;

  @override
  int findHeaderRow(List<List<String>> rows) {
    final idx = _findHeaderRowByKeywords(rows);
    return idx >= 0 ? idx : super.findHeaderRow(rows);
  }

  static int _findHeaderRowByKeywords(List<List<String>> rows) {
    final scanLimit = rows.length < 30 ? rows.length : 30;
    for (var i = 0; i < scanLimit; i++) {
      final row = rows[i];
      if (row.length < 8) continue;
      final joined = row.join('|');
      if (_headerSignals.every(joined.contains)) return i;
    }
    return -1;
  }

  @override
  Map<String, int> mapColumns(List<String> headerRow) {
    final base = super.mapColumns(headerRow);
    int? indexOf(String name) {
      for (var i = 0; i < headerRow.length; i++) {
        if (headerRow[i].trim() == name) return i;
      }
      return null;
    }
    final typeColIdx = indexOf('类型');
    final ioIdx = indexOf('收/支');
    if (typeColIdx != null) base['category'] = typeColIdx;
    if (ioIdx != null) base['type'] = ioIdx;
    return base;
  }

  @override
  BackupImportCsvRow? parseRow(
    List<String> row,
    Map<String, int> columnMapping,
  ) {
    String? getBy(String key) {
      final idx = columnMapping[key];
      if (idx == null || idx >= row.length) return null;
      final v = row[idx].trim();
      return v.isEmpty ? null : v;
    }

    final status = getBy('status') ?? '';
    if (status.contains('退款') ||
        status.contains('关闭') ||
        status.contains('失败')) {
      return null;
    }

    final dateStr = getBy('date');
    if (dateStr == null) return null;
    final occurredAt = parseFlexibleDate(dateStr);
    if (occurredAt == null) return null;

    final amountStr = getBy('amount');
    if (amountStr == null) return null;
    final amount = parseAmount(amountStr);
    if (amount == null || amount <= 0) return null;

    final type = _typeFromIoFlag(getBy('type') ?? '');
    if (type == null) return null;

    return BackupImportCsvRow(
      ledgerLabel: displayName,
      occurredAt: occurredAt,
      type: type,
      amount: amount,
      currency: 'CNY',
      primaryCategoryName: null,
      categoryName: getBy('category'),
      accountName: '支付宝',
      toAccountName: null,
      note: getBy('note'),
    );
  }

  static String? _typeFromIoFlag(String flag) {
    final t = flag.trim();
    if (t == '支出') return 'expense';
    if (t == '收入') return 'income';
    return null;
  }
}
```

- [ ] **Step 4: 运行测试通过**

Run: `flutter test test/features/import_export/csv/parsers/alipay_parser_test.dart`
Expected: `All tests passed!`(3 用例)

- [ ] **Step 5: Commit**

```bash
git add lib/features/import_export/csv/parsers/alipay_parser.dart test/features/import_export/csv/parsers/alipay_parser_test.dart
git commit -m "Step 13.5(9/N):add AlipayBillParser"
```

---

### Task 10: `qianji_parser.dart` 钱迹

**Files:**
- Create: `lib/features/import_export/csv/parsers/qianji_parser.dart`
- Create: `test/features/import_export/csv/parsers/qianji_parser_test.dart`

- [ ] **Step 1: 写失败测试**

创建 `test/features/import_export/csv/parsers/qianji_parser_test.dart`:

```dart
import 'package:bianbianbianbian/features/import_export/csv/parsers/qianji_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = QianjiBillParser();

  test('8 列格式识别', () {
    final rows = [
      ['时间', '类型', '金额', '一级分类', '二级分类', '账户1', '账户2', '备注'],
      ['2026-01-01 12:00', '支出', '30', '饮食', '午餐', '现金', '', '吃饭'],
    ];
    expect(parser.validateBillType(rows), true);
  });

  test('6 列格式识别', () {
    final rows = [
      ['日期', '分类', '子分类', '账户', '金额', '备注'],
      ['2026-01-01', '饮食', '午餐', '现金', '30', '吃饭'],
    ];
    expect(parser.validateBillType(rows), true);
  });

  test('含「账本」/「币种」必须不命中(护栏)', () {
    final rows = [
      ['账本', '日期', '类型', '金额', '币种', '分类', '账户', '转入账户', '备注'],
      ['生活', '2026-01-01', '支出', '30', 'CNY', '午餐', '现金', '', ''],
    ];
    expect(parser.validateBillType(rows), false);
  });

  test('parseRow 8 列:一级 + 二级直接取值', () {
    final rows = [
      ['时间', '类型', '金额', '一级分类', '二级分类', '账户1', '账户2', '备注'],
      ['2026-01-01 12:00', '支出', '30', '饮食', '午餐', '现金', '', '吃饭'],
    ];
    final mapping = parser.mapColumns(rows[0]);
    final row = parser.parseRow(rows[1], mapping);
    expect(row, isNotNull);
    expect(row!.primaryCategoryName, '饮食');
    expect(row.categoryName, '午餐');
    expect(row.accountName, '现金');
    expect(row.ledgerLabel, '钱迹');
  });

  test('amount 永远 abs()', () {
    final rows = [
      ['时间', '类型', '金额', '一级分类', '二级分类', '账户1', '账户2', '备注'],
      ['2026-01-01 12:00', '支出', '-30', '饮食', '午餐', '现金', '', ''],
    ];
    final mapping = parser.mapColumns(rows[0]);
    final row = parser.parseRow(rows[1], mapping);
    expect(row!.amount, 30.0);
  });

  test('转账行:类型=转账,账户1→from,账户2→to', () {
    final rows = [
      ['时间', '类型', '金额', '一级分类', '二级分类', '账户1', '账户2', '备注'],
      ['2026-01-01 12:00', '转账', '100', '', '', '现金', '银行卡', ''],
    ];
    final mapping = parser.mapColumns(rows[0]);
    final row = parser.parseRow(rows[1], mapping);
    expect(row!.type, 'transfer');
    expect(row.accountName, '现金');
    expect(row.toAccountName, '银行卡');
  });
}
```

- [ ] **Step 2: 运行测试看到失败**

Run: `flutter test test/features/import_export/csv/parsers/qianji_parser_test.dart`
Expected: 编译失败。

- [ ] **Step 3: 创建实现**

创建 `lib/features/import_export/csv/parsers/qianji_parser.dart`:

```dart
import '../../import_service.dart' show BackupImportCsvRow;
import 'generic_parser.dart';

/// 钱迹 (Qianji) 账单 CSV 解析器。
///
/// **来源**:钱迹 App → 我的 → 备份 → 导出 CSV。
///
/// **支持两种格式**:
/// 1. 8 列:`时间, 类型, 金额, 一级分类, 二级分类, 账户1, 账户2, 备注`
/// 2. 6 列:`日期, 分类, 子分类, 账户, 金额, 备注`
///
/// **关键护栏**:[validateBillType] 必须排除「账本」/「币种」列——本 App 9/10 列
/// CSV 含这两列,否则会被钱迹弱签名抢占。
class QianjiBillParser extends GenericBillParser {
  const QianjiBillParser();

  @override
  String get id => 'qianji';

  @override
  // i18n-exempt: needs refactoring for l10n
  String get displayName => '钱迹';

  @override
  bool validateBillType(List<List<String>> rows) =>
      _findHeaderRowByKeywords(rows) >= 0;

  @override
  int findHeaderRow(List<List<String>> rows) {
    final idx = _findHeaderRowByKeywords(rows);
    return idx >= 0 ? idx : super.findHeaderRow(rows);
  }

  static int _findHeaderRowByKeywords(List<List<String>> rows) {
    final scanLimit = rows.length < 10 ? rows.length : 10;
    for (var i = 0; i < scanLimit; i++) {
      final row = rows[i];
      if (row.length < 4) continue;
      final cols = row.map((c) => c.trim()).toList();
      final joined = cols.join('|');
      final hasAmount = joined.contains('金额');
      final hasCat = joined.contains('分类') || joined.contains('类别');
      final hasDate = joined.contains('时间') || joined.contains('日期');
      if (!(hasAmount && hasCat && hasDate)) continue;
      // 排除本 App 9/10 列 CSV
      if (cols.contains('账本') || cols.contains('币种')) continue;
      return i;
    }
    return -1;
  }

  @override
  BackupImportCsvRow? parseRow(
    List<String> row,
    Map<String, int> columnMapping,
  ) {
    String? getBy(String key) {
      final idx = columnMapping[key];
      if (idx == null || idx >= row.length) return null;
      final v = row[idx].trim();
      return v.isEmpty ? null : v;
    }

    final dateStr = getBy('date');
    if (dateStr == null) return null;
    final occurredAt = parseFlexibleDate(dateStr);
    if (occurredAt == null) return null;

    final amountStr = getBy('amount');
    if (amountStr == null) return null;
    final amount = parseAmount(amountStr);
    if (amount == null) return null;

    String? type;
    final typeLabel = getBy('type');
    if (typeLabel != null) {
      type = _typeFromQianjiLabel(typeLabel);
    }
    type ??= 'expense'; // 6 列格式无独立类型列,兜底支出
    // 但若 amount 为 0 或负且无 type 列,跳过
    if (amount == 0) return null;

    // 一级 / 二级分类:8 列格式直接走 super 的「一级分类」/「二级分类」字段;
    // 6 列格式只有「分类」+「子分类」,super 把「分类」归到 category(级别模糊)。
    // 钱迹 6 列「分类」实际是一级,「子分类」是二级——本 parser 覆盖一次:
    final primary = getBy('primary_category');
    final category = getBy('category');
    // 优先使用 super 已识别的字段(8 列格式精确);
    // 6 列格式需要额外手工识别:在 mapColumns 之外做不到——保持当前粗粒度即可。

    final accountFrom = getBy('account') ?? getBy('from_account');
    final accountTo = getBy('to_account');

    return BackupImportCsvRow(
      ledgerLabel: displayName,
      occurredAt: occurredAt,
      type: type,
      amount: amount.abs(),
      currency: 'CNY',
      primaryCategoryName: primary,
      categoryName: category,
      accountName: accountFrom,
      toAccountName: type == 'transfer' ? accountTo : null,
      note: getBy('note'),
    );
  }

  @override
  Map<String, int> mapColumns(List<String> headerRow) {
    final base = super.mapColumns(headerRow);
    // 钱迹 8 列:账户1 → account;账户2 → to_account
    int? indexOf(String name) {
      for (var i = 0; i < headerRow.length; i++) {
        if (headerRow[i].trim() == name) return i;
      }
      return null;
    }
    final a1 = indexOf('账户1');
    final a2 = indexOf('账户2');
    if (a1 != null) base['account'] = a1;
    if (a2 != null) base['to_account'] = a2;
    return base;
  }

  static String? _typeFromQianjiLabel(String label) {
    final t = label.trim();
    if (t == '支出') return 'expense';
    if (t == '收入') return 'income';
    if (t == '转账') return 'transfer';
    return null;
  }
}
```

- [ ] **Step 4: 运行测试通过**

Run: `flutter test test/features/import_export/csv/parsers/qianji_parser_test.dart`
Expected: `All tests passed!`(6 用例)

- [ ] **Step 5: Commit**

```bash
git add lib/features/import_export/csv/parsers/qianji_parser.dart test/features/import_export/csv/parsers/qianji_parser_test.dart
git commit -m "Step 13.5(10/N):add QianjiBillParser (8-col + 6-col with ledger/currency guard)"
```

---

### Task 11: `csv_format_detector.dart` 注册表入口

**Files:**
- Create: `lib/features/import_export/csv/csv_format_detector.dart`
- Create: `test/features/import_export/csv/csv_format_detector_test.dart`

- [ ] **Step 1: 写失败测试**

创建 `test/features/import_export/csv/csv_format_detector_test.dart`:

```dart
import 'package:bianbianbianbian/features/import_export/csv/csv_format_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('detectBillParser', () {
    test('本 App 10 列 CSV → BianbianBillParser', () {
      final rows = [
        ['账本', '日期', '类型', '金额', '币种', '一级分类', '分类',
          '账户', '转入账户', '备注'],
        ['生活', '2026-01-01 12:00', '支出', '10', 'CNY', '饮食', '早餐',
          '现金', '', ''],
      ];
      final p = detectBillParser(rows);
      expect(p?.id, 'bianbian');
    });

    test('微信账单 → WechatBillParser', () {
      final rows = [
        ['说明'],
        ['交易时间', '交易类型', '交易对方', '商品', '收/支', '金额(元)',
          '支付方式', '当前状态'],
        ['2026-01-01 12:00:00', '商户消费', 'X', 'Y', '支出', '10', '零钱',
          '支付成功'],
      ];
      expect(detectBillParser(rows)?.id, 'wechat_bill');
    });

    test('钱迹 CSV → QianjiBillParser', () {
      final rows = [
        ['时间', '类型', '金额', '一级分类', '二级分类', '账户1', '账户2', '备注'],
        ['2026-01-01 12:00', '支出', '30', '饮食', '午餐', '现金', '', ''],
      ];
      expect(detectBillParser(rows)?.id, 'qianji');
    });

    test('本 App 9 列(无一级分类) → BianbianBillParser(向后兼容)', () {
      final rows = [
        ['账本', '日期', '类型', '金额', '币种', '分类', '账户', '转入账户', '备注'],
        ['生活', '2026-01-01', '支出', '10', 'CNY', '早餐', '现金', '', ''],
      ];
      expect(detectBillParser(rows)?.id, 'bianbian');
    });

    test('任意 3 列 CSV → GenericBillParser 兜底', () {
      final rows = [
        ['date', 'amount', 'note'],
        ['2026-01-01', '10', 'X'],
        ['2026-01-02', '20', 'Y'],
        ['2026-01-03', '30', 'Z'],
        ['2026-01-04', '40', 'W'],
        ['2026-01-05', '50', 'V'],
        ['2026-01-06', '60', 'U'],
      ];
      expect(detectBillParser(rows)?.id, 'generic');
    });

    test('空 rows → null', () {
      expect(detectBillParser([]), isNull);
    });
  });
}
```

- [ ] **Step 2: 运行测试看到失败**

Run: `flutter test test/features/import_export/csv/csv_format_detector_test.dart`
Expected: 编译失败。

- [ ] **Step 3: 创建实现**

创建 `lib/features/import_export/csv/csv_format_detector.dart`:

```dart
import 'bill_parser.dart';
import 'parsers/alipay_parser.dart';
import 'parsers/bianbian_parser.dart';
import 'parsers/generic_parser.dart';
import 'parsers/qianji_parser.dart';
import 'parsers/wechat_parser.dart';

/// CSV 格式探测注册表——按顺序逐一 [BillParser.validateBillType],命中第一个返回。
///
/// 顺序敏感:
/// - **Bianbian 最前**:本 App 自有 9/10 列严匹配最具体,避免被 Generic 抢走解析权。
/// - **Wechat / Alipay 接着**:header 关键字签名强,放在钱迹之前免被钱迹弱签名误命中。
/// - **Qianji 倒数第二**:弱签名(金额+分类+时间),放后面。
/// - **Generic 兜底**:总是返回 true,接受所有列数一致的 CSV。
const List<BillParser> kAllParsers = [
  BianbianBillParser(),
  WechatBillParser(),
  AlipayBillParser(),
  QianjiBillParser(),
  GenericBillParser(),
];

/// 探测主入口。空 rows 返回 null。
BillParser? detectBillParser(List<List<String>> rows) {
  if (rows.isEmpty) return null;
  for (final p in kAllParsers) {
    if (p.validateBillType(rows)) return p;
  }
  return null; // 不会发生,Generic 兜底永真
}
```

- [ ] **Step 4: 运行测试通过**

Run: `flutter test test/features/import_export/csv/csv_format_detector_test.dart`
Expected: `All tests passed!`(6 用例)

- [ ] **Step 5: 跑 csv/* 全部测试无回归**

Run: `flutter test test/features/import_export/csv/`
Expected: 全部通过(约 40 用例,含 csv_lexer / csv_text_decoder / generic / bianbian / wechat / alipay / qianji / format_detector)。

- [ ] **Step 6: Commit**

```bash
git add lib/features/import_export/csv/csv_format_detector.dart test/features/import_export/csv/csv_format_detector_test.dart
git commit -m "Step 13.5(11/N):add csv_format_detector with priority registry"
```

---

## Phase 4 · import_service 数据契约 + apply 改造

### Task 12: 数据契约更新(`BackupImportCsvRow / BackupImportPreview / BackupImportResult`)

**Files:**
- Modify: `lib/features/import_export/import_service.dart:62-198`(数据类区段)

- [ ] **Step 1: 修改 BackupImportCsvRow 加 `primaryCategoryName`**

编辑 `lib/features/import_export/import_service.dart` 中 `BackupImportCsvRow` 类(约第 62 行起):

```dart
@immutable
class BackupImportCsvRow {
  const BackupImportCsvRow({
    required this.ledgerLabel,
    required this.occurredAt,
    required this.type,
    required this.amount,
    required this.currency,
    this.primaryCategoryName,   // ← 新增
    this.categoryName,
    this.accountName,
    this.toAccountName,
    this.note,
  });

  final String ledgerLabel;
  final DateTime occurredAt;
  final String type;
  final double amount;
  final String currency;
  /// 一级分类中文标签(如「饮食」);Step 13.5 引入。
  /// 仅本 App 10 列 / 钱迹 8 列 / Generic 命中「一级分类|父分类|主分类」列时非 null。
  /// 微信 / 支付宝 / 旧 9 列 = null,apply 时挂到 `parent_key='other'`。
  final String? primaryCategoryName;
  final String? categoryName;
  final String? accountName;
  final String? toAccountName;
  final String? note;
}
```

- [ ] **Step 2: 修改 BackupImportPreview 字段重组**

在同文件 `BackupImportPreview` 类(约第 128 行):
- **删除**:`thirdPartyTemplateId` / `thirdPartyTemplateName` / `unmappedCategoryCount`。
- **新增**:`parserId / parserDisplayName / newCategoryCount / newAccountCount / columnMapping / csvHeader`。

完整新版:

```dart
@immutable
class BackupImportPreview {
  const BackupImportPreview({
    required this.fileType,
    required this.ledgerCount,
    required this.transactionCount,
    required this.sampleRows,
    this.snapshot,
    this.csvRows,
    this.exportedAt,
    this.sourceDeviceId,
    this.parserId,
    this.parserDisplayName,
    this.newCategoryCount = 0,
    this.newAccountCount = 0,
    this.columnMapping,
    this.csvHeader,
  });

  final BackupImportFileType fileType;
  final int ledgerCount;
  final int transactionCount;
  final List<BackupImportPreviewRow> sampleRows;
  final MultiLedgerSnapshot? snapshot;
  final List<BackupImportCsvRow>? csvRows;
  final DateTime? exportedAt;
  final String? sourceDeviceId;

  /// 命中 parser 的 id(`'bianbian' / 'wechat_bill' / 'alipay_bill' / 'qianji' /
  /// 'generic' / 'custom'`);null = JSON / .bbbak 路径。
  final String? parserId;

  /// 命中 parser 的用户可见名称(如「微信账单」)。
  final String? parserDisplayName;

  /// 本次 apply 将新建的二级分类数(去重 by name 后)。
  final int newCategoryCount;

  /// 本次 apply 将新建的账户数(去重 by name 后)。
  final int newAccountCount;

  /// 命中 parser 输出的列名 → 列索引映射;UI 「高级映射」用。
  final Map<String, int>? columnMapping;

  /// 原始 CSV header 行;UI 「高级映射」展示列名用。
  final List<String>? csvHeader;
}
```

- [ ] **Step 3: 修改 BackupImportResult 加 categoriesCreated / accountsCreated**

在同文件 `BackupImportResult` 类(约第 178 行):

```dart
@immutable
class BackupImportResult {
  const BackupImportResult({
    this.ledgersWritten = 0,
    this.categoriesWritten = 0,
    this.accountsWritten = 0,
    this.transactionsWritten = 0,
    this.transactionsSkipped = 0,
    this.budgetsWritten = 0,
    this.categoriesCreated = 0,   // ← 新增
    this.accountsCreated = 0,     // ← 新增
    this.unresolvedLedgerLabels = const <String>{},
  });

  final int ledgersWritten;
  final int categoriesWritten;
  final int accountsWritten;
  final int transactionsWritten;
  final int transactionsSkipped;
  final int budgetsWritten;
  /// CSV 路径下,本次 apply 新建的二级分类数(Step 13.5)。
  final int categoriesCreated;
  /// CSV 路径下,本次 apply 新建的账户数(Step 13.5)。
  final int accountsCreated;
  final Set<String> unresolvedLedgerLabels;
}
```

- [ ] **Step 4: 解开 Phase 2 / Phase 3 暂时注释的 primaryCategoryName 字段**

在以下文件中把 `// primaryCategoryName: ...  // TODO Task 12` 注释解开:
- `lib/features/import_export/csv/parsers/generic_parser.dart`
- `lib/features/import_export/csv/parsers/bianbian_parser.dart`
- `lib/features/import_export/csv/parsers/wechat_parser.dart`
- `lib/features/import_export/csv/parsers/alipay_parser.dart`
- `lib/features/import_export/csv/parsers/qianji_parser.dart`

测试文件 `bianbian_parser_test.dart` 同样恢复完整断言 `expect(row!.primaryCategoryName, '饮食');`。

- [ ] **Step 5: 跑 csv/* + import_service_test 编译通过**

Run: `flutter analyze lib/features/import_export/ test/features/import_export/`
Expected: `No issues found!`

Run: `flutter test test/features/import_export/csv/`
Expected: 全部通过,parsers 测试现在 `primaryCategoryName` 断言生效。

- [ ] **Step 6: Commit**

```bash
git add lib/features/import_export/import_service.dart lib/features/import_export/csv/parsers/ test/features/import_export/csv/parsers/
git commit -m "Step 13.5(12/N):update import data contract (primaryCategoryName, parser fields, created counts)"
```

---

### Task 13: `_previewCsvBytes` 改用 detector

**Files:**
- Modify: `lib/features/import_export/import_service.dart:536-646`(`_previewCsvBytes` + `_previewFromThirdPartyMatch`)

- [ ] **Step 1: 删除旧的三方模板分支**

在 `_previewCsvBytes` 中(约第 536 行):
- 删除 `final thirdPartyMatch = detectThirdPartyTemplate(rows); if (thirdPartyMatch != null) return _previewFromThirdPartyMatch(thirdPartyMatch);` 块(约 549-554 行)。
- 删除 `_previewFromThirdPartyMatch` 整个方法(约第 612-646 行)。
- 删除文件顶部 `import 'templates/third_party_template.dart';`(约第 16 行)。

- [ ] **Step 2: 改写为基于 detector 的预览**

把 `_previewCsvBytes` 完整替换为以下版本:

```dart
  // i18n-exempt: needs refactoring for l10n
  BackupImportPreview _previewCsvBytes(Uint8List bytes) {
    final text = decodeCsvBytes(bytes);  // ← Task 4 新模块
    final stripped = stripUtf8Bom(text);
    final rows = parseCsvRows(stripped);
    if (rows.isEmpty) {
      throw const BackupImportException('CSV 文件为空');
    }

    final parser = detectBillParser(rows);
    if (parser == null) {
      throw const BackupImportException('无法识别的 CSV 格式');
    }
    final headerRowIdx = parser.findHeaderRow(rows);
    if (headerRowIdx < 0) {
      throw BackupImportException('${parser.displayName}:未找到表头行');
    }
    final header = rows[headerRowIdx];
    final columnMapping = parser.mapColumns(header);

    final csvRows = <BackupImportCsvRow>[];
    for (var i = headerRowIdx + 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length == 1 && row[0].isEmpty) continue;
      try {
        final parsed = parser.parseRow(row, columnMapping);
        if (parsed != null) csvRows.add(parsed);
      } catch (_) {
        // 单行解析异常忽略,继续下一行
      }
    }

    // 统计 CSV 内出现的 unique 分类 / 账户 name 上限
    // (实际新建数 = unique - 本地已有同名;在 apply 阶段精确得到 BackupImportResult.categoriesCreated)
    final uniqueCategoryNames = <String>{
      for (final r in csvRows)
        if (r.categoryName != null && r.categoryName!.isNotEmpty) r.categoryName!,
    };
    final uniqueAccountNames = <String>{
      for (final r in csvRows) ...[
        if (r.accountName != null && r.accountName!.isNotEmpty) r.accountName!,
        if (r.toAccountName != null && r.toAccountName!.isNotEmpty) r.toAccountName!,
      ],
    };

    // 准备预览样本(最多 20 行)
    final amountFmt = NumberFormat('0.00');
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    final samples = <BackupImportPreviewRow>[];
    for (final r in csvRows.take(20)) {
      samples.add(BackupImportPreviewRow(
        ledgerLabel: r.ledgerLabel,
        date: dateFmt.format(r.occurredAt),
        type: _typeLabel(r.type),
        amount: amountFmt.format(r.amount),
        currency: r.currency,
        category: r.categoryName,
        account: r.accountName,
        toAccount: r.toAccountName,
        note: r.note,
      ));
    }

    final ledgerLabels = <String>{for (final r in csvRows) r.ledgerLabel};
    return BackupImportPreview(
      fileType: BackupImportFileType.csv,
      ledgerCount: ledgerLabels.length,
      transactionCount: csvRows.length,
      sampleRows: List.unmodifiable(samples),
      csvRows: List.unmodifiable(csvRows),
      parserId: parser.id,
      parserDisplayName: parser.displayName,
      newCategoryCount: uniqueCategoryNames.length,
      newAccountCount: uniqueAccountNames.length,
      columnMapping: Map.unmodifiable(columnMapping),
      csvHeader: List.unmodifiable(header),
    );
  }
```

**关键设计点**:
- preview 阶段**不查 DB**(BackupImportService 在 preview 路径不持有 db handle),因此 `newCategoryCount` / `newAccountCount` 上报的是 **CSV 内 unique name 上限**(实际复用 / 复活会让真值更小)。Apply 完成后由 `BackupImportResult.categoriesCreated / accountsCreated` 提供准确值。
- 单行 parseRow 异常吞掉(允许文件中有少量坏行);header 完全找不到才抛 `BackupImportException`。

- [ ] **Step 3: 添加 csv 模块 imports**

文件顶部:

```dart
import 'csv/csv_format_detector.dart';
import 'csv/csv_lexer.dart';
import 'csv/csv_text_decoder.dart';
```

并删除已经无用的旧 `csv/csv_lexer.dart` 重复导入(Task 3 已加)。

- [ ] **Step 4: 编译通过**

Run: `flutter analyze lib/features/import_export/import_service.dart`
Expected: `No issues found!`

- [ ] **Step 5: 跑 import_service_test 看现状**

Run: `flutter test test/features/import_export/import_service_test.dart`
Expected: 部分 13.4 的「三方模板」测试会失败(因为它们 `expect(preview.thirdPartyTemplateId, ...)` 等)——这些字段已删。**接受失败**,留待 Task 16 集成测试改写。

- [ ] **Step 6: Commit**

```bash
git add lib/features/import_export/import_service.dart
git commit -m "Step 13.5(13/N):wire _previewCsvBytes to csv_format_detector"
```

---

### Task 14: `_applyCsv` 改造:第一遍收集 + 第二遍写流水(含分类自动新建 + sync_op)

**Files:**
- Modify: `lib/features/import_export/import_service.dart:648-717`(`_applyCsv` 方法)

- [ ] **Step 1: 写新 `_applyCsv` 整体框架(分类新建 + 账户新建 + sync_op enqueue)**

把 `_applyCsv` 完全替换为以下版本:

```dart
  Future<BackupImportResult> _applyCsv({
    required List<BackupImportCsvRow> rows,
    required AppDatabase db,
    required String currentDeviceId,
    required String fallbackLedgerId,
  }) async {
    final ledgers = await db.ledgerDao.listActive();
    // 预拉 categories / accounts 含软删行(复活路径需要)
    final allCategoriesRows = await db.select(db.categoryTable).get();
    final allAccountsRows   = await db.select(db.accountTable).get();
    final categoryByName = <String, CategoryEntry>{
      for (final c in allCategoriesRows) c.name: c,
    };
    final accountByName = <String, AccountEntry>{
      for (final a in allAccountsRows) a.name: a,
    };

    // ── 第一遍:收集需要新建 / 复活的分类 / 账户 ───────────────────────
    final newCategorySpecs = <_NewCategorySpec>{};
    final newAccountSpecs  = <_NewAccountSpec>{};
    final categorySeen = <String>{};
    final accountSeen = <String>{};
    for (final r in rows) {
      final cat = r.categoryName;
      if (cat != null && cat.isNotEmpty && !categorySeen.contains(cat)) {
        categorySeen.add(cat);
        final existing = categoryByName[cat];
        if (existing == null || existing.deletedAt != null) {
          final parentKey = _resolveParentKeyFromLabel(r.primaryCategoryName);
          newCategorySpecs.add(_NewCategorySpec(
            name: cat,
            parentKey: parentKey,
            existing: existing,        // null = 全新建;非 null = 复活
          ));
        }
      }
      for (final acc in [r.accountName, r.toAccountName]) {
        if (acc == null || acc.isEmpty || accountSeen.contains(acc)) continue;
        accountSeen.add(acc);
        final existing = accountByName[acc];
        if (existing == null || existing.deletedAt != null) {
          newAccountSpecs.add(_NewAccountSpec(
            name: acc,
            existing: existing,
          ));
        }
      }
    }

    final unresolvedLabels = <String>{};
    var transactionsWritten = 0;
    var categoriesCreated = 0;
    var accountsCreated   = 0;
    final nowMs = _clock().millisecondsSinceEpoch;

    await db.transaction(() async {
      // ── 新建 / 复活分类 ───────────────────────────────────────────
      for (final spec in newCategorySpecs) {
        if (spec.existing != null) {
          // 复活:deletedAt 清空,parentKey 重置,updatedAt / deviceId 刷新
          await (db.update(db.categoryTable)
                ..where((t) => t.id.equals(spec.existing!.id)))
              .write(CategoryTableCompanion(
            parentKey: Value(spec.parentKey),
            deletedAt: const Value(null),
            updatedAt: Value(nowMs),
            deviceId: Value(currentDeviceId),
          ));
          final updated = (await (db.select(db.categoryTable)
                    ..where((t) => t.id.equals(spec.existing!.id)))
                  .getSingle())
              .toCategoryEntity();
          await db.syncOpDao.enqueue(
            entity: 'category',
            entityId: spec.existing!.id,
            op: 'upsert',
            payload: jsonEncode(updated.toJson()),
            enqueuedAt: nowMs,
          );
          categoryByName[spec.name] = (await (db.select(db.categoryTable)
                    ..where((t) => t.id.equals(spec.existing!.id)))
                  .getSingle());
        } else {
          // 新建
          final maxOrder = await _maxSortOrder(db, spec.parentKey);
          final newId = _uuid.v4();
          final companion = CategoryTableCompanion.insert(
            id: newId,
            name: spec.name,
            parentKey: spec.parentKey,
            sortOrder: Value(maxOrder + 1),
            updatedAt: nowMs,
            deviceId: currentDeviceId,
          );
          await db.into(db.categoryTable).insert(companion);
          final inserted = await (db.select(db.categoryTable)
                ..where((t) => t.id.equals(newId)))
              .getSingle();
          await db.syncOpDao.enqueue(
            entity: 'category',
            entityId: newId,
            op: 'upsert',
            payload: jsonEncode(inserted.toCategoryEntity().toJson()),
            enqueuedAt: nowMs,
          );
          categoryByName[spec.name] = inserted;
        }
        categoriesCreated++;
      }

      // ── 新建 / 复活账户 ───────────────────────────────────────────
      for (final spec in newAccountSpecs) {
        if (spec.existing != null) {
          await (db.update(db.accountTable)
                ..where((t) => t.id.equals(spec.existing!.id)))
              .write(AccountTableCompanion(
            deletedAt: const Value(null),
            updatedAt: Value(nowMs),
            deviceId: Value(currentDeviceId),
            // type / icon / color 不动,保留用户原配置
          ));
          final updated = await (db.select(db.accountTable)
                ..where((t) => t.id.equals(spec.existing!.id)))
              .getSingle();
          await db.syncOpDao.enqueue(
            entity: 'account',
            entityId: spec.existing!.id,
            op: 'upsert',
            payload: jsonEncode(updated.toAccountEntity().toJson()),
            enqueuedAt: nowMs,
          );
          accountByName[spec.name] = updated;
        } else {
          final newId = _uuid.v4();
          final companion = AccountTableCompanion.insert(
            id: newId,
            name: spec.name,
            type: 'other',
            updatedAt: nowMs,
            deviceId: currentDeviceId,
          );
          await db.into(db.accountTable).insert(companion);
          final inserted = await (db.select(db.accountTable)
                ..where((t) => t.id.equals(newId)))
              .getSingle();
          await db.syncOpDao.enqueue(
            entity: 'account',
            entityId: newId,
            op: 'upsert',
            payload: jsonEncode(inserted.toAccountEntity().toJson()),
            enqueuedAt: nowMs,
          );
          accountByName[spec.name] = inserted;
        }
        accountsCreated++;
      }

      // ── 第二遍:写流水(用刷新后的缓存 resolve id)──────────────────
      String? resolveLedgerId(String label) {
        final name = stripLedgerEmoji(label);
        for (final l in ledgers) {
          if (l.name == name) return l.id;
        }
        return null;
      }

      for (final row in rows) {
        var ledgerId = resolveLedgerId(row.ledgerLabel);
        if (ledgerId == null) {
          ledgerId = fallbackLedgerId;
          unresolvedLabels.add(row.ledgerLabel);
        }
        String? categoryId;
        if (row.categoryName != null) {
          categoryId = categoryByName[row.categoryName!]?.id;
        }
        String? accountId;
        if (row.accountName != null) {
          accountId = accountByName[row.accountName!]?.id;
        }
        String? toAccountId;
        if (row.toAccountName != null) {
          toAccountId = accountByName[row.toAccountName!]?.id;
        }

        final tx = TransactionEntry(
          id: _uuid.v4(),
          ledgerId: ledgerId,
          type: row.type,
          amount: row.amount,
          currency: row.currency,
          categoryId: categoryId,
          accountId: accountId,
          toAccountId: toAccountId,
          occurredAt: row.occurredAt,
          tags: (row.note != null && row.note!.isNotEmpty) ? row.note : null,
          updatedAt: _clock(),
          deviceId: currentDeviceId,
        );
        await db.into(db.transactionEntryTable).insert(
              transactionEntryToCompanion(tx),
              mode: InsertMode.insertOrAbort,
            );
        transactionsWritten++;
      }
    });
    return BackupImportResult(
      transactionsWritten: transactionsWritten,
      categoriesCreated: categoriesCreated,
      accountsCreated: accountsCreated,
      unresolvedLedgerLabels: unresolvedLabels,
    );
  }

  /// 同 parentKey 下当前最大 sort_order;空表返回 -1(新分类即 0)。
  Future<int> _maxSortOrder(AppDatabase db, String parentKey) async {
    final rows = await (db.select(db.categoryTable)
          ..where((t) => t.parentKey.equals(parentKey)))
        .get();
    var max = -1;
    for (final r in rows) {
      if (r.sortOrder > max) max = r.sortOrder;
    }
    return max;
  }

  String _resolveParentKeyFromLabel(String? label) {
    if (label == null) return 'other';
    return chineseLabelToParentKey(label) ?? 'other';
  }
}

class _NewCategorySpec {
  _NewCategorySpec({
    required this.name,
    required this.parentKey,
    this.existing,
  });
  final String name;
  final String parentKey;
  final CategoryEntry? existing;

  @override
  bool operator ==(Object other) =>
      other is _NewCategorySpec && other.name == name;
  @override
  int get hashCode => name.hashCode;
}

class _NewAccountSpec {
  _NewAccountSpec({required this.name, this.existing});
  final String name;
  final AccountEntry? existing;

  @override
  bool operator ==(Object other) =>
      other is _NewAccountSpec && other.name == name;
  @override
  int get hashCode => name.hashCode;
}
```

- [ ] **Step 2: 添加必需 imports**

`lib/features/import_export/import_service.dart` 顶部:

```dart
import '../../core/util/parent_key_labels.dart';
```

- [ ] **Step 3: 添加 entity mapper helpers**

检查 `lib/data/repository/entity_mappers.dart` 是否有 `CategoryEntry.toCategoryEntity()` 与 `AccountEntry.toAccountEntity()`(把 drift 行转 domain entity)。如果没有,在该文件追加:

```dart
extension CategoryRowToEntity on CategoryEntry {
  Category toCategoryEntity() => Category(
        id: id,
        name: name,
        icon: icon,
        color: color,
        parentKey: parentKey,
        sortOrder: sortOrder,
        isFavorite: isFavorite == 1,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
        deletedAt: deletedAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(deletedAt!),
        deviceId: deviceId,
      );
}

extension AccountRowToEntity on AccountEntry {
  Account toAccountEntity() => Account(
        id: id,
        name: name,
        type: type,
        icon: icon,
        color: color,
        initialBalance: initialBalance ?? 0,
        includeInTotal: (includeInTotal ?? 1) == 1,
        currency: currency ?? 'CNY',
        billingDay: billingDay,
        repaymentDay: repaymentDay,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
        deletedAt: deletedAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(deletedAt!),
        deviceId: deviceId,
      );
}
```

(如果项目已有等价的转换函数 `rowToCategory(row)` / `rowToAccount(row)`,优先使用现有的,不要重复定义——只把那些函数引入 `import_service.dart` 即可。)

- [ ] **Step 4: 编译通过**

Run: `flutter analyze lib/features/import_export/import_service.dart`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/import_export/import_service.dart lib/data/repository/entity_mappers.dart
git commit -m "Step 13.5(14/N):rewrite _applyCsv with auto-create categories & accounts + sync_op enqueue"
```

---

### Task 15: 补集成测试(import_service)

**Files:**
- Modify: `test/features/import_export/import_service_test.dart`(新增测试用例 + 删除依赖已删字段的旧测试)

- [ ] **Step 1: 删除依赖已删 13.4 字段的旧测试**

打开 `test/features/import_export/import_service_test.dart`,搜索:
- `thirdPartyTemplateId`
- `thirdPartyTemplateName`
- `unmappedCategoryCount`
- `detectThirdPartyTemplate`(若存在,Task 22 后整个 templates 文件已删,这些 test 必死)

把这些测试用例完整删除(或改写为新数据契约的等价用例)。

- [ ] **Step 2: 写新失败测试 — 10 列 CSV preview**

在 `import_service_test.dart` 新增 group:

```dart
group('CSV 10-col preview (Step 13.5)', () {
  test('本 App 10 列 CSV → parserId=bianbian', () async {
    final csv = utf8.encode('﻿账本,日期,类型,金额,币种,一级分类,分类,'
        '账户,转入账户,备注\n'
        '生活,2026-01-01 12:00,支出,10.00,CNY,饮食,早餐,现金,,午饭\n');
    final service = BackupImportService();
    final preview = await service.preview(
      bytes: Uint8List.fromList(csv),
      fileType: BackupImportFileType.csv,
    );
    expect(preview.parserId, 'bianbian');
    expect(preview.parserDisplayName, '本 App');
    expect(preview.transactionCount, 1);
    expect(preview.csvRows!.first.primaryCategoryName, '饮食');
    expect(preview.csvHeader, isNotNull);
    expect(preview.columnMapping, isNotNull);
  });

  test('旧 9 列 CSV → 仍走 bianbian(向后兼容)', () async {
    final csv = utf8.encode('账本,日期,类型,金额,币种,分类,'
        '账户,转入账户,备注\n'
        '生活,2026-01-01 12:00,支出,10.00,CNY,早餐,现金,,午饭\n');
    final service = BackupImportService();
    final preview = await service.preview(
      bytes: Uint8List.fromList(csv),
      fileType: BackupImportFileType.csv,
    );
    expect(preview.parserId, 'bianbian');
    expect(preview.csvRows!.first.primaryCategoryName, isNull);
  });
});
```

- [ ] **Step 3: 写新测试 — apply 自动新建分类(in-memory drift)**

(本步使用项目已有的 in-memory drift fixture。若已有 `_buildInMemoryDb()` helper,复用之;若无,参考其它 *_test.dart 同款 setUp。)

```dart
group('CSV apply — auto-create categories (Step 13.5)', () {
  test('新建分类 + 复用 + 复活', () async {
    final db = await _buildInMemoryDb();   // 含 seed 默认分类
    final service = BackupImportService(
      uuid: const Uuid(),
      clock: () => DateTime(2026, 5, 16, 10),
    );
    final csv = utf8.encode(
      '账本,日期,类型,金额,币种,一级分类,分类,账户,转入账户,备注\n'
      '生活,2026-01-01,支出,10,CNY,饮食,私房菜,现金,,A\n'   // 全新 → food
      '生活,2026-01-01,支出,20,CNY,,玄学,现金,,B\n'         // 无一级 → other
      '生活,2026-01-01,支出,30,CNY,饮食,午餐,现金,,C\n',     // 已存在 → 复用
    );
    final preview = await service.preview(
      bytes: Uint8List.fromList(csv),
      fileType: BackupImportFileType.csv,
    );
    final result = await service.apply(
      preview: preview,
      strategy: BackupDedupeStrategy.asNew,
      db: db,
      currentDeviceId: 'test-device',
      fallbackLedgerId: 'fallback-ledger',
    );
    expect(result.transactionsWritten, 3);
    expect(result.categoriesCreated, 2);   // 私房菜 + 玄学
    // 验证 DB 状态
    final cats = await db.select(db.categoryTable).get();
    expect(cats.where((c) => c.name == '私房菜').first.parentKey, 'food');
    expect(cats.where((c) => c.name == '玄学').first.parentKey, 'other');
    // sync_op:2 条 category upsert
    final ops = await db.syncOpDao.listAll();
    final catOps = ops.where((o) => o.entity == 'category').toList();
    expect(catOps.length, 2);
    expect(catOps.every((o) => o.op == 'upsert'), true);
    // 流水不进 sync_op
    expect(ops.where((o) => o.entity == 'transaction'), isEmpty);
  });
});
```

- [ ] **Step 4: 写新测试 — apply 自动新建账户**

```dart
group('CSV apply — auto-create accounts (Step 13.5)', () {
  test('新建账户 + 复用', () async {
    final db = await _buildInMemoryDb();  // 含 seed 5 个默认账户
    final service = BackupImportService(clock: () => DateTime(2026, 5, 16));
    final csv = utf8.encode(
      '账本,日期,类型,金额,币种,一级分类,分类,账户,转入账户,备注\n'
      '生活,2026-01-01,支出,10,CNY,饮食,早餐,招商卡(尾号8888),,A\n'
      '生活,2026-01-01,支出,20,CNY,饮食,早餐,现金,,B\n'
      '生活,2026-01-01,转账,30,CNY,,,招商卡(尾号8888),零钱通,C\n',
    );
    final preview = await service.preview(
      bytes: Uint8List.fromList(csv),
      fileType: BackupImportFileType.csv,
    );
    final result = await service.apply(
      preview: preview,
      strategy: BackupDedupeStrategy.asNew,
      db: db,
      currentDeviceId: 'test-device',
      fallbackLedgerId: 'fallback-ledger',
    );
    expect(result.accountsCreated, 2);  // 招商卡(尾号8888) + 零钱通
    final accounts = await db.select(db.accountTable).get();
    final names = accounts.map((a) => a.name).toSet();
    expect(names.contains('招商卡(尾号8888)'), true);
    expect(names.contains('零钱通'), true);
    expect(names.contains('现金'), true);   // 复用
    // sync_op:2 条 account upsert
    final ops = await db.syncOpDao.listAll();
    final accOps = ops.where((o) => o.entity == 'account').toList();
    expect(accOps.length, 2);
    // 新账户 type='other'
    final newAcc = accounts.firstWhere((a) => a.name == '零钱通');
    expect(newAcc.type, 'other');
  });
});
```

- [ ] **Step 5: 运行测试**

Run: `flutter test test/features/import_export/import_service_test.dart`
Expected: 新 3 个测试全部通过;旧 13.3 / 13.4 测试中已删字段的用例此前已删,其它沿用通过。

- [ ] **Step 6: Commit**

```bash
git add test/features/import_export/import_service_test.dart
git commit -m "Step 13.5(15/N):add integration tests for auto-create categories & accounts"
```

---

## Phase 5 · export_service 10 列

### Task 16: `encodeBackupCsv` 9 → 10 列

**Files:**
- Modify: `lib/features/import_export/export_service.dart:103-115`(`_backupCsvHeader`)
- Modify: `lib/features/import_export/export_service.dart:168-224`(`encodeBackupCsv`)
- Modify: `test/features/import_export/export_service_test.dart`

- [ ] **Step 1: 写失败测试**

在 `test/features/import_export/export_service_test.dart` 加测试:

```dart
group('encodeBackupCsv 10-col (Step 13.5)', () {
  test('header 10 列含一级分类', () {
    final csv = encodeBackupCsv(snapshots: []);
    final firstLine = csv.split('\n')[1]; // 跳 BOM
    expect(firstLine, contains('一级分类'));
    final cols = firstLine.split(',');
    expect(cols.length, 10);
    expect(cols[5], '一级分类');
    expect(cols[6], '分类');
  });

  test('一级分类列为中文标签', () {
    final snap = LedgerSnapshot(
      version: 1,
      exportedAt: DateTime(2026, 5, 16),
      deviceId: 'd',
      ledger: Ledger(/*...*/ name: '生活', /*...*/),
      categories: [
        Category(id: 'c1', name: '早餐', parentKey: 'food', /*...*/),
      ],
      accounts: [],
      transactions: [
        TransactionEntry(
          id: 't1', ledgerId: 'l1', type: 'expense', amount: 10,
          currency: 'CNY', categoryId: 'c1', accountId: null, toAccountId: null,
          occurredAt: DateTime(2026, 1, 1, 12), /*...*/
        ),
      ],
      budgets: [],
    );
    final csv = encodeBackupCsv(snapshots: [snap]);
    // 数据行应在第 3 行(BOM, header, data)
    final dataLine = csv.split('\n')[2];
    expect(dataLine.contains('饮食'), true); // food → 饮食
  });

  test('转账行一级分类列为空', () {
    final snap = LedgerSnapshot(
      /*...*/
      transactions: [
        TransactionEntry(
          id: 't1', type: 'transfer', categoryId: null,
          /*...*/
        ),
      ],
      /*...*/
    );
    final csv = encodeBackupCsv(snapshots: [snap]);
    final dataLine = csv.split('\n')[2];
    final cols = dataLine.split(',');
    expect(cols[5], ''); // 一级分类空
    expect(cols[6], ''); // 二级分类空
  });
});
```

(测试 helper 构造 Ledger / Category / TransactionEntry 等实体可能需要补全字段——参照该文件已有的 fixture 风格。)

- [ ] **Step 2: 运行测试看到失败**

Run: `flutter test test/features/import_export/export_service_test.dart`
Expected: 新测试失败(header 仍是 9 列)。

- [ ] **Step 3: 修改 `_backupCsvHeader`**

```dart
const List<String> _backupCsvHeader = <String>[
  '账本',
  '日期',
  '类型',
  '金额',
  '币种',
  '一级分类',   // ← 新增
  '分类',
  '账户',
  '转入账户',
  '备注',
];
```

- [ ] **Step 4: 修改 `encodeBackupCsv` 编码循环**

在 `encodeBackupCsv` 中,流水编码的 `final row = <String>[...]` 改为:

```dart
import '../../core/util/parent_key_labels.dart';  // 加 import

// ...

      final cat = tx.categoryId == null ? null : categoryMap[tx.categoryId!];
      final categoryName = cat?.name ?? '';
      final primaryCategoryName = cat == null
          ? ''
          : (parentKeyToChineseLabel(cat.parentKey) ?? '');
      final accountName = tx.accountId == null
          ? ''
          : (accountMap[tx.accountId!]?.name ?? '');
      final toAccountName = tx.toAccountId == null
          ? ''
          : (accountMap[tx.toAccountId!]?.name ?? '');

      final row = <String>[
        ledgerLabel,
        dateFmt.format(tx.occurredAt),
        _typeLabel(tx.type),
        amountFmt.format(tx.amount),
        tx.currency,
        primaryCategoryName,  // ← 新列
        categoryName,
        accountName,
        toAccountName,
        tx.tags ?? '',
      ];
```

- [ ] **Step 5: 运行测试通过**

Run: `flutter test test/features/import_export/export_service_test.dart`
Expected: 全部通过。

- [ ] **Step 6: Commit**

```bash
git add lib/features/import_export/export_service.dart test/features/import_export/export_service_test.dart
git commit -m "Step 13.5(16/N):export CSV 9→10 cols (add 一级分类 before 分类)"
```

---

## Phase 6 · UI 改造

### Task 17: `import_page.dart` 预览卡片文案更新

**Files:**
- Modify: `lib/features/import_export/import_page.dart`(预览卡片渲染部分)

- [ ] **Step 1: 找到 `_buildPreview` 方法**

打开 `lib/features/import_export/import_page.dart`,定位到 `_buildPreview(BuildContext context)` 方法。13.4 期间会有引用 `thirdPartyTemplateName` / `unmappedCategoryCount` 的代码块。

- [ ] **Step 2: 替换为新文案**

把所有 `if (preview.thirdPartyTemplateId != null)` / `preview.thirdPartyTemplateName` / `preview.unmappedCategoryCount` 引用改为基于 `parserId / parserDisplayName / newCategoryCount / newAccountCount`:

```dart
// 「识别为:xxx」一行(CSV 路径,所有 parser 都显示)
if (preview.fileType == BackupImportFileType.csv &&
    preview.parserDisplayName != null) ...[
  Row(
    children: [
      const Icon(Icons.auto_awesome, size: 18),
      const SizedBox(width: 6),
      Text('识别为:${preview.parserDisplayName}'),
    ],
  ),
  const SizedBox(height: 8),
],

// 新建分类 / 账户提示
if (preview.newCategoryCount > 0 || preview.newAccountCount > 0)
  Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.orange.withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      '检测到 ${preview.newCategoryCount} 个本地不存在的分类 + '
      '${preview.newAccountCount} 个本地不存在的账户,导入时会自动创建。'
      '分类按「一级分类」列归类,无法判断的归到「其他」;账户以 type=其他 创建。',
      style: const TextStyle(color: Colors.deepOrange),
    ),
  ),
```

- [ ] **Step 3: 修改 idle 卡片提示文案**

定位 `_buildIdle(BuildContext context)`,把 13.4 的「自动识别钱迹/微信/支付宝」文案改为:

```
导入 CSV / JSON / .bbbak 备份。本 App 自有 CSV(10 列)、微信账单、
支付宝账单、钱迹账单、任意带中文表头的 CSV 都能识别;不存在的分类 /
账户会自动创建。
```

- [ ] **Step 4: 修改策略区文案(CSV 路径)**

定位策略区,把 CSV 路径文案改为:

```
CSV 不含本 App 的 ID,作为「全部新记录」导入;账本归入当前账本;
分类与账户列若与本地已有同名则关联,否则自动新建(可在「高级映射」中跳过)。
```

(若「高级映射」按钮在 Task 18 才加,文案先这样写,Task 18 加按钮。)

- [ ] **Step 5: 编译 + 运行现有 widget 测试**

Run: `flutter test test/features/import_export/import_page_test.dart`(若存在)
Expected: 通过;若有测试断言旧文案,改成新文案。

- [ ] **Step 6: Commit**

```bash
git add lib/features/import_export/import_page.dart
git commit -m "Step 13.5(17/N):update import page preview/idle text for new parser model"
```

---

### Task 18: `import_page.dart` 「高级映射」折叠区

**Files:**
- Modify: `lib/features/import_export/import_page.dart`(`_buildPreview` 加 ExpansionTile)
- Modify: `lib/features/import_export/import_service.dart`(`preview` 增可选 `overrideColumnMapping` 入参)

- [ ] **Step 1: BackupImportService.preview 加 `overrideColumnMapping` 参数**

修改 `lib/features/import_export/import_service.dart`:

```dart
Future<BackupImportPreview> preview({
  required Uint8List bytes,
  required BackupImportFileType fileType,
  String? password,
  int? bbbakIterations,
  Map<String, int>? overrideColumnMapping,   // ← 新增
}) async {
  // ...
  case BackupImportFileType.csv:
    return _previewCsvBytes(bytes, override: overrideColumnMapping);
  // ...
}
```

`_previewCsvBytes` 改签名:

```dart
BackupImportPreview _previewCsvBytes(Uint8List bytes, {Map<String, int>? override}) {
  // ... 解码 / parseCsvRows / detectBillParser 全同前 ...

  BillParser effectiveParser;
  Map<String, int> effectiveMapping;
  int headerRowIdx;

  if (override != null) {
    // 用户在高级映射调整后重新预览
    effectiveParser = const GenericBillParser();
    effectiveMapping = override;
    headerRowIdx = 0;  // 自定义模式:把第一行视为 header
  } else {
    final detected = detectBillParser(rows);
    if (detected == null) {
      throw const BackupImportException('无法识别的 CSV 格式');
    }
    effectiveParser = detected;
    headerRowIdx = detected.findHeaderRow(rows);
    if (headerRowIdx < 0) {
      throw BackupImportException('${detected.displayName}:未找到表头行');
    }
    effectiveMapping = detected.mapColumns(rows[headerRowIdx]);
  }

  // ... 后面 csvRows 循环用 effectiveParser.parseRow ...
  // BackupImportPreview 构造时:
  //   parserId: override != null ? 'custom' : effectiveParser.id
  //   parserDisplayName: override != null ? '自定义映射' : effectiveParser.displayName
}
```

- [ ] **Step 2: 在 `import_page.dart` `_buildPreview` 加 ExpansionTile**

```dart
// 高级映射折叠区(仅 CSV 路径显示)
if (preview.fileType == BackupImportFileType.csv && preview.csvHeader != null)
  ExpansionTile(
    title: const Text('高级映射(调整列 → 字段)'),
    children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            for (var i = 0; i < preview.csvHeader!.length; i++)
              Row(
                children: [
                  Expanded(child: Text(preview.csvHeader![i])),
                  const Text(' → '),
                  Expanded(
                    child: DropdownButton<String?>(
                      value: _currentMappingFor(preview, i),
                      items: _fieldKeyOptions(),
                      onChanged: (key) {
                        setState(() {
                          _userMapping ??= Map.of(preview.columnMapping!);
                          // 移除原映射到 i 的 key
                          _userMapping!.removeWhere((_, idx) => idx == i);
                          if (key != null) _userMapping![key] = i;
                        });
                      },
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _userMapping == null ? null : _rePreview,
              child: const Text('重新预览'),
            ),
          ],
        ),
      ),
    ],
  ),
```

加 helpers:

```dart
Map<String, int>? _userMapping;

String? _currentMappingFor(BackupImportPreview p, int colIdx) {
  final m = _userMapping ?? p.columnMapping ?? {};
  for (final entry in m.entries) {
    if (entry.value == colIdx) return entry.key;
  }
  return null; // 「忽略」
}

List<DropdownMenuItem<String?>> _fieldKeyOptions() {
  const fieldKeys = [
    'date', 'type', 'amount', 'currency',
    'primary_category', 'category',
    'account', 'from_account', 'to_account',
    'note', 'status',
  ];
  return [
    const DropdownMenuItem<String?>(value: null, child: Text('(忽略)')),
    for (final k in fieldKeys)
      DropdownMenuItem<String?>(value: k, child: Text(k)),
  ];
}

Future<void> _rePreview() async {
  if (_bytes == null || _userMapping == null) return;
  final service = BackupImportService();
  final newPreview = await service.preview(
    bytes: _bytes!,
    fileType: BackupImportFileType.csv,
    overrideColumnMapping: _userMapping,
  );
  setState(() {
    _preview = newPreview;
    _userMapping = null;
  });
}
```

- [ ] **Step 3: 编译通过**

Run: `flutter analyze lib/features/import_export/`
Expected: `No issues found!`

- [ ] **Step 4: 手工测试(可选,subagent 可跳过)**

Run: `flutter run` → 选 CSV 文件 → 验证「高级映射」可展开 / 下拉可选 / 重新预览。

- [ ] **Step 5: Commit**

```bash
git add lib/features/import_export/import_service.dart lib/features/import_export/import_page.dart
git commit -m "Step 13.5(18/N):add advanced column mapping UI + overrideColumnMapping API"
```

---

## Phase 7 · 清理 + 文档

### Task 19: 删除 `templates/third_party_template.dart` + 旧测试

**Files:**
- Delete: `lib/features/import_export/templates/third_party_template.dart`
- Delete: `test/features/import_export/third_party_template_test.dart`
- Verify: 全工程无引用残留

- [ ] **Step 1: 搜索残留引用**

Run: `grep -r "third_party_template\|detectThirdPartyTemplate\|ThirdPartyMatch\|ThirdPartyTemplate\|kKeywordToCategory\|kFallbackCategoryName\|mapKeywordToCategory" lib/ test/`
Expected: 仅 `templates/third_party_template.dart` 与 `third_party_template_test.dart` 自身命中。

如果还有其它文件引用,先移除引用(应该在 Task 13 已删除 import,确认一次)。

- [ ] **Step 2: 删除文件**

```bash
rm lib/features/import_export/templates/third_party_template.dart
rm -r lib/features/import_export/templates  # 若目录已空
rm test/features/import_export/third_party_template_test.dart
```

- [ ] **Step 3: 全量 analyze 通过**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add -A lib/features/import_export/templates test/features/import_export/third_party_template_test.dart
git commit -m "Step 13.5(19/N):remove templates/third_party_template.dart (replaced by csv/ parsers)"
```

---

### Task 20: `architecture.md` 更新

**Files:**
- Modify: `memory-bank/architecture.md`

- [ ] **Step 1: 更新顶部时间戳**

把文件顶部「Phase XX · ... 完成后」改为:
```
Phase 13.5 · CSV 导入重构完成后(基线 = Phase 14.x 当前)
```

- [ ] **Step 2: 更新 `lib/features/import_export/` 目录树**

把该子树替换为:

```
lib/features/import_export/
├─ csv/                                ← Step 13.5 新增
│   ├─ csv_lexer.dart                  ← parseCsvRows / stripUtf8Bom / stripLedgerEmoji
│   ├─ csv_text_decoder.dart           ← UTF-8 BOM / UTF-16 LE/BE / GBK 自动识别
│   ├─ bill_parser.dart                ← 抽象 BillParser + ParseResult
│   ├─ csv_format_detector.dart        ← detectBillParser(注册表入口)
│   └─ parsers/
│       ├─ generic_parser.dart         ← 列数一致性 + normalizeToKey 11 字段
│       ├─ bianbian_parser.dart        ← 本 App 10 列 + 旧 9 列兼容
│       ├─ wechat_parser.dart          ← 状态过滤 + 列重映射
│       ├─ alipay_parser.dart          ← 同上;account 固定支付宝
│       └─ qianji_parser.dart          ← 8 列 / 6 列;护栏排除本 App
├─ import_service.dart                 ← _previewCsvBytes / _applyCsv 改造(13.5)
├─ export_service.dart                 ← 10 列 header(13.5)
├─ import_page.dart                    ← 高级映射 UI(13.5)
└─ ...
```

- [ ] **Step 3: 更新 `lib/core/util/` 树加 `parent_key_labels.dart`**

加一行:
```
├─ parent_key_labels.dart          ← Step 13.5 新增:parent_key ↔ 中文标签双向映射
```

- [ ] **Step 4: 加「Phase 13.5 架构决策(2026-05-16)」段落**

在文件末尾追加段落,内容包括(按 13.4 同款风格):
- 14 条决策清单(BillParser 抽象、删关键词映射、新建分类 + sync_op、新建账户 + sync_op、列名规范化、状态过滤保留、列重映射策略、高级映射 UI、向后兼容 9 列、parent_key_labels 单一真值源等);
- 数据流图(`CSV bytes → decodeCsvBytes → parseCsvRows → detectBillParser → parser.findHeaderRow + mapColumns → parseRow → BackupImportCsvRow → _applyCsv 第一遍收集 + 第二遍写流水 + sync_op enqueue`);
- 单元测试策略;
- 与 13.3 / 13.4 / 14.x 的衔接;
- 故意不做的事(XLSX / PDF / 流式 / 分类映射 UI);
- 已知风险(微信分类爆炸 / 账户爆炸 / 跨设备同步流水缺失);
- 实施日期 2026-05-16。

完整内容长度参考 13.4 段落(约 50-70 行 markdown)。

- [ ] **Step 5: Commit**

```bash
git add memory-bank/architecture.md
git commit -m "Step 13.5(20/N):update architecture.md with csv refactor decisions"
```

---

### Task 21: `progress.md` 加 Step 13.5 章节

**Files:**
- Modify: `memory-bank/progress.md`

- [ ] **Step 1: 在 Step 14.x 章节之后插入新章节**

格式参考 Step 13.4 段落:

```markdown
### ✅ Step 13.5 CSV 导入重构 - BeeCount 同构(2026-05-16)

> **范围**:重构 CSV 导入路径,引入 BillParser 抽象 + 5 具体 parser;
> 导出 CSV 9→10 列(新增「一级分类」中文标签列);完全废弃 13.4 关键词→分类映射;
> 本地不存在的二级分类 / 账户自动新建并进 sync_op 队列;新增「高级映射」UI。

**改动**

#### 1. `lib/features/import_export/csv/` 新建子目录(...)

- `csv_lexer.dart`:从 import_service.dart 抽出 parseCsvRows / stripUtf8Bom / stripLedgerEmoji。
- `csv_text_decoder.dart`:UTF-8 BOM / UTF-16 LE/BE / GBK 自动识别(gbk_codec 0.4.x)。
- `bill_parser.dart`:抽象接口。
- `csv_format_detector.dart`:注册表 + detectBillParser。
- `parsers/generic_parser.dart`:列数一致性 + normalizeToKey 11 字段。
- `parsers/bianbian_parser.dart`:10 列严匹配 + 9 列向后兼容。
- `parsers/wechat_parser.dart`:状态过滤(退款/失败/关闭/未支付) + 「交易类型」→ category 重映射。
- `parsers/alipay_parser.dart`:状态过滤 + 「类型」→ category 重映射 + account 固定支付宝。
- `parsers/qianji_parser.dart`:8/6 列格式;findHeaderRow 排除「账本」「币种」(避本 App 误命中)。

#### 2. `lib/features/import_export/import_service.dart`(改造)

(详细描述 BackupImportCsvRow / BackupImportPreview / BackupImportResult 字段变更;
_previewCsvBytes 改用 detector;_applyCsv 两遍扫描 + 自动新建 + sync_op enqueue。)

#### 3. `lib/features/import_export/export_service.dart`(改造)

(10 列 header + parent_key 中文标签编码。)

#### 4. `lib/features/import_export/import_page.dart`(改造)

(预览页文案 + 「识别为」一行 + 「将新建 N 分类 + M 账户」橙色提示 +
高级映射 ExpansionTile。)

#### 5. `lib/core/util/parent_key_labels.dart`(新建)

(parent_key ↔ 中文标签双向映射;quick_text_parser 改引用本文件。)

#### 6. 测试

(列出新增 / 删除 / 修改的 test 文件;单元测试用例数。)

#### 7. 依赖

(pubspec.yaml 加 gbk_codec ^0.4.0。)

#### 8. 文档

(architecture.md / progress.md 自身。)

**验证**

- `flutter analyze` → No issues found.
- `flutter test test/features/import_export/csv/` → 全部通过(约 40 用例)。
- `flutter test test/features/import_export/` → 全部通过(总 ~80 用例)。
- `flutter test`(全量回归)→ 通过(净变化 +23,具体数字以实测为准)。
- 用户本机端到端验证(待用户执行,5 项):
  1. 微信账单 CSV → 识别为「微信账单」+ 状态过滤生效 + 大量新分类挂到 other。
  2. 支付宝账单 CSV → 识别为「支付宝账单」+ 账户=支付宝。
  3. 钱迹 CSV → 识别为「钱迹」+ 一级 / 二级分类正确归类。
  4. 本 App 10 列 CSV(再导回)→ 识别为「本 App」+ round-trip 完整。
  5. 「高级映射」展开 → 调列 → 重新预览 → 显示 parserDisplayName=「自定义映射」。

**给后续开发者的备忘**

- 微信账单「交易类型」是噪音化分类源——若用户反馈分类爆炸严重,
  可考虑在 13.6 把「忽略 category 列」作为微信 parser 的默认行为。
- 新建分类 / 账户进 sync_op 但流水不进——B 设备看到空分类 / 零余额账户
  是已知边界,等 Phase 18.x「完整云端备份」解决。
- gbk_codec 是新依赖;若未来升级到 0.5.x 注意检查 gbk_bytes 接口是否变更。
- BianbianBillParser 在注册表最前——任何新增的本 App 自有 CSV 变体
  (如未来 11 列加新字段)必须更新 BianbianBillParser._header10/11/etc 列表。
- normalizeToKey 顺序敏感——「二级分类」必须放在「分类」之前判定。改动时务必跑
  generic_parser_test 验证。
```

- [ ] **Step 2: Commit**

```bash
git add memory-bank/progress.md
git commit -m "Step 13.5(21/N):add Step 13.5 entry to progress.md"
```

---

## Phase 8 · 全量回归

### Task 22: 全量回归 + 收尾

- [ ] **Step 1: `flutter analyze` 全工程**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: `flutter test` 全量回归**

Run: `flutter test`
Expected: 全部通过。

- [ ] **Step 3: 记录实测测试数到 progress.md**

如果实测数与预期(+23)有偏差,把实际数字回填到 Step 13.5 的「验证」段。Commit:

```bash
git add memory-bank/progress.md
git commit -m "Step 13.5(22/N):record actual test count in progress.md"
```

- [ ] **Step 4: 通知用户端到端验证清单**

在最后一条 commit message 或 PR 描述中包含 5 项端到端验证清单(已在 Step 21 progress.md 中列出);告知用户:

```
代码与测试改动已完成。请按 progress.md Step 13.5 验证段执行 5 项
端到端 manual test;如有 bug 单独修复,文档已闭环。
```

---

## Self-Review Checklist(实施前自检)

- [ ] Spec § 1-17 每一节均有对应任务 / 步骤覆盖。
- [ ] 无 TBD / TODO / "类似 Task N" 占位符。
- [ ] 类型 / 方法签名前后一致(`BackupImportCsvRow.primaryCategoryName`,
      `BackupImportResult.categoriesCreated / accountsCreated`,
      `detectBillParser`,`normalizeToKey` static)。
- [ ] 每个 task 内的代码片段独立可运行(测试 + 实现 + 通过 + commit 完整闭环)。
- [ ] sync_op 写入路径在 Task 14 明确(`db.syncOpDao.enqueue`,
      字段 entity / entityId / op / payload / enqueuedAt)。
- [ ] 11 个字段 key 集合一致(date / type / amount / currency / primary_category /
      category / account / from_account / to_account / note / status)。
- [ ] 5 个 parser 各自的 header 签名 + 状态过滤策略明确(spec § 5 表格)。
- [ ] Tasks 6-11 「primaryCategoryName 临时注释」与 Task 12 「解开注释」首尾呼应。
- [ ] export_service 10 列 header 顺序与 design § 10 一致。
- [ ] UI 文案与 design § 11 一致。
- [ ] 删除 `templates/third_party_template.dart` 在 Task 19 一次性完成。
