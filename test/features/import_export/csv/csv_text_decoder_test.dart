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
