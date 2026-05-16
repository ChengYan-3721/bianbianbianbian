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
