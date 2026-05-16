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
