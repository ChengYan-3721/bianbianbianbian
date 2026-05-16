/// CSV 词法工具:RFC 4180 行解析 + UTF-8 BOM 剥除 + 账本 emoji 前缀剥除。
///
/// 本模块从 [import_service.dart] 抽出,作为 csv/ 子目录下的通用 CSV 基础工具。
/// 各 BillParser 的子类 + import_service 共用本模块。
///
/// 不依赖任何外部 package(除 Flutter 自身);纯 Dart 实现。
library;

/// 去掉 UTF-8 BOM（`﻿`）。CSV 导出时显式带 BOM 让 Excel 识别中文，导入
/// 时必须先剥离否则 header 行第一列会变成 `﻿账本`。
String stripUtf8Bom(String s) =>
    s.isNotEmpty && s.codeUnitAt(0) == 0xFEFF ? s.substring(1) : s;

/// 去掉账本标签前的 emoji 前缀。
///
/// 导出时 `LedgerSnapshot.ledger.coverEmoji != null` 会拼成 `📒 生活`；导入
/// 时按"原 ledger.name"匹配 DB，故需把 emoji + 后续空格剥离。
///
/// 策略：从首字符开始向后扫，跳过所有 surrogate pair / 非 ASCII 非 CJK 字符
/// + 空白；遇到第一个 ASCII 字母数字 / CJK 字符即停。**不**做严格 emoji 表
/// 匹配——以防遗漏新 emoji；用「不是文本字符」做判定足够实用。
String stripLedgerEmoji(String label) {
  final trimmed = label.trim();
  if (trimmed.isEmpty) return trimmed;
  final runes = trimmed.runes.toList();
  var skip = 0;
  for (var i = 0; i < runes.length; i++) {
    final r = runes[i];
    if (_isLikelyTextChar(r)) {
      break;
    }
    skip++;
  }
  if (skip == 0) return trimmed;
  final remaining = String.fromCharCodes(runes.skip(skip));
  return remaining.trimLeft();
}

/// 「文本字符」判定：ASCII 字母数字 / 中文 / 常见标点。其他（emoji /
/// 私用区 / surrogate）一律视作"装饰前缀"。
bool _isLikelyTextChar(int rune) {
  if (rune >= 0x30 && rune <= 0x39) return true; // 0-9
  if (rune >= 0x41 && rune <= 0x5A) return true; // A-Z
  if (rune >= 0x61 && rune <= 0x7A) return true; // a-z
  if (rune == 0x5F || rune == 0x2D) return true; // _ -
  if (rune >= 0x4E00 && rune <= 0x9FFF) return true; // CJK 基本块
  if (rune >= 0x3400 && rune <= 0x4DBF) return true; // CJK 扩展 A
  if (rune >= 0x20000 && rune <= 0x2A6DF) return true; // CJK 扩展 B
  return false;
}

/// RFC 4180 行解析——支持双引号包裹 / 双引号转义（`""`）/ 字段内换行。
///
/// 与 Dart 标准库无关——故意不引 `csv` package，本项目只需要双向 RFC 4180，
/// 自带的 50 行实现足够覆盖。
List<List<String>> parseCsvRows(String input) {
  final rows = <List<String>>[];
  final cells = <String>[];
  final buf = StringBuffer();
  var inQuote = false;
  var i = 0;
  void endCell() {
    cells.add(buf.toString());
    buf.clear();
  }

  void endRow() {
    endCell();
    rows.add(List<String>.unmodifiable(cells));
    cells.clear();
  }

  while (i < input.length) {
    final c = input[i];
    if (inQuote) {
      if (c == '"') {
        if (i + 1 < input.length && input[i + 1] == '"') {
          buf.write('"');
          i += 2;
          continue;
        }
        inQuote = false;
        i++;
        continue;
      }
      buf.write(c);
      i++;
    } else {
      if (c == '"') {
        inQuote = true;
        i++;
      } else if (c == ',') {
        endCell();
        i++;
      } else if (c == '\r') {
        // \r\n / \r 都视为行尾
        endRow();
        if (i + 1 < input.length && input[i + 1] == '\n') {
          i += 2;
        } else {
          i++;
        }
      } else if (c == '\n') {
        endRow();
        i++;
      } else {
        buf.write(c);
        i++;
      }
    }
  }
  // 末尾未以换行结束的最后一行
  if (buf.isNotEmpty || cells.isNotEmpty) {
    endRow();
  }
  return rows;
}
