import 'package:flutter_test/flutter_test.dart';

import 'package:bianbianbianbian/domain/entity/account.dart';
import 'package:bianbianbianbian/domain/entity/category.dart';
import 'package:bianbianbianbian/domain/entity/transaction_entry.dart';
import 'package:bianbianbianbian/features/stats/stats_export_service.dart';
import 'package:bianbianbianbian/features/stats/stats_range_providers.dart';

TransactionEntry _tx({
  required String id,
  required String type,
  required double amount,
  required DateTime occurredAt,
  String? categoryId,
  String? accountId,
  String? toAccountId,
  String? tags,
}) {
  return TransactionEntry(
    id: id,
    ledgerId: 'ledger-1',
    type: type,
    amount: amount,
    currency: 'CNY',
    categoryId: categoryId,
    accountId: accountId,
    toAccountId: toAccountId,
    occurredAt: occurredAt,
    tags: tags,
    updatedAt: occurredAt,
    deviceId: 'dev-1',
  );
}

Category _cat(String id, String name) => Category(
      id: id,
      name: name,
      parentKey: 'food',
      updatedAt: DateTime(2026, 4, 1),
      deviceId: 'dev-1',
    );

Account _acc(String id, String name) => Account(
      id: id,
      name: name,
      type: 'cash',
      updatedAt: DateTime(2026, 4, 1),
      deviceId: 'dev-1',
    );

void main() {
  final range = StatsDateRange.normalize(
    DateTime(2026, 4, 1),
    DateTime(2026, 4, 30),
  );

  group('encodeStatsCsv', () {
    test('emits UTF-8 BOM and Chinese header row', () {
      final csv = encodeStatsCsv(
        entries: const [],
        categoryMap: const {},
        accountMap: const {},
        range: range,
      );
      expect(csv.startsWith('\uFEFF'), isTrue);
      final lines = const LineSplitter().convert(csv);
      expect(lines.first, '\uFEFF日期,类型,金额,币种,分类,账户,转入账户,备注');
      expect(lines.length, 1);
    });

    test('writes income/expense rows ordered by occurredAt asc', () {
      final csv = encodeStatsCsv(
        entries: [
          _tx(
            id: 't2',
            type: 'expense',
            amount: 12.5,
            occurredAt: DateTime(2026, 4, 25, 10, 0),
            categoryId: 'cat-food',
            accountId: 'acc-cash',
            tags: '午餐',
          ),
          _tx(
            id: 't1',
            type: 'income',
            amount: 5000,
            occurredAt: DateTime(2026, 4, 5, 9, 30),
            categoryId: 'cat-salary',
            accountId: 'acc-bank',
            tags: '工资',
          ),
        ],
        categoryMap: {
          'cat-food': _cat('cat-food', '餐饮'),
          'cat-salary': _cat('cat-salary', '工资'),
        },
        accountMap: {
          'acc-cash': _acc('acc-cash', '现金'),
          'acc-bank': _acc('acc-bank', '工行卡'),
        },
        range: range,
      );

      final lines = const LineSplitter().convert(csv);
      expect(lines.length, 3);
      expect(
        lines[1],
        '2026-04-05 09:30,收入,5000.00,CNY,工资,工行卡,,工资',
      );
      expect(
        lines[2],
        '2026-04-25 10:00,支出,12.50,CNY,餐饮,现金,,午餐',
      );
    });

    test('keeps transfer rows with toAccount name', () {
      final csv = encodeStatsCsv(
        entries: [
          _tx(
            id: 't',
            type: 'transfer',
            amount: 200,
            occurredAt: DateTime(2026, 4, 10, 12, 0),
            accountId: 'acc-cash',
            toAccountId: 'acc-bank',
          ),
        ],
        categoryMap: const {},
        accountMap: {
          'acc-cash': _acc('acc-cash', '现金'),
          'acc-bank': _acc('acc-bank', '工行卡'),
        },
        range: range,
      );
      final lines = const LineSplitter().convert(csv);
      expect(lines[1], '2026-04-10 12:00,转账,200.00,CNY,,现金,工行卡,');
    });

    test('escapes commas, quotes and newlines per RFC 4180', () {
      final csv = encodeStatsCsv(
        entries: [
          _tx(
            id: 't',
            type: 'expense',
            amount: 9.99,
            occurredAt: DateTime(2026, 4, 12, 8, 0),
            categoryId: 'c',
            accountId: 'a',
            tags: 'hello, "world"\n第二行',
          ),
        ],
        categoryMap: {'c': _cat('c', '杂,项')},
        accountMap: {'a': _acc('a', '钱"包')},
        range: range,
      );
      final lines = const LineSplitter().convert(csv);
      // 备注末段是 "hello, ""world""\n第二行"——含逗号/双引号/换行需整段加引号
      // 但 LineSplitter 会按物理换行切，导致备注被跨行——所以这里直接验整文件包含期望片段
      expect(csv, contains('"杂,项"'));
      expect(csv, contains('"钱""包"'));
      expect(csv, contains('"hello, ""world""'));
      // 仍然只有 1 行 header + 1 行数据物理结构（备注内嵌换行被视为 CRLF/LF 内容）
      expect(lines.length, greaterThanOrEqualTo(2));
    });

    test('drops entries outside range', () {
      final csv = encodeStatsCsv(
        entries: [
          _tx(
            id: 't1',
            type: 'expense',
            amount: 1,
            occurredAt: DateTime(2026, 3, 31, 23, 59),
          ),
          _tx(
            id: 't2',
            type: 'expense',
            amount: 1,
            occurredAt: DateTime(2026, 5, 1, 0, 0),
          ),
          _tx(
            id: 't3',
            type: 'expense',
            amount: 99,
            occurredAt: DateTime(2026, 4, 15, 12, 0),
          ),
        ],
        categoryMap: const {},
        accountMap: const {},
        range: range,
      );
      final lines = const LineSplitter().convert(csv);
      expect(lines.length, 2);
      expect(lines[1], contains('99.00'));
    });

    test('renders empty cells when category/account missing', () {
      final csv = encodeStatsCsv(
        entries: [
          _tx(
            id: 't',
            type: 'expense',
            amount: 3.5,
            occurredAt: DateTime(2026, 4, 1, 0, 0),
            categoryId: 'missing-cat',
            accountId: 'missing-acc',
          ),
        ],
        categoryMap: const {},
        accountMap: const {},
        range: range,
      );
      final lines = const LineSplitter().convert(csv);
      expect(lines[1], '2026-04-01 00:00,支出,3.50,CNY,,,,');
    });
  });

  group('buildExportFileName', () {
    test('contains range and timestamp', () {
      final name = buildExportFileName(
        prefix: 'bianbian_stats',
        extension: 'csv',
        now: DateTime(2026, 4, 29, 14, 5, 8),
        range: range,
      );
      expect(name, 'bianbian_stats_20260401_20260430_20260429_140508.csv');
    });

    test('honors extension parameter', () {
      final name = buildExportFileName(
        prefix: 'x',
        extension: 'png',
        now: DateTime(2026, 1, 2, 3, 4, 5),
        range: StatsDateRange.normalize(
          DateTime(2026, 1, 1),
          DateTime(2026, 1, 31),
        ),
      );
      expect(name.endsWith('.png'), isTrue);
      expect(name, contains('20260101_20260131'));
    });
  });
}

/// Minimal LineSplitter clone to avoid pulling `dart:convert` import noise into
/// every assertion. We only need to split on \n / \r\n.
class LineSplitter {
  const LineSplitter();
  List<String> convert(String input) {
    final lines = <String>[];
    var start = 0;
    for (var i = 0; i < input.length; i++) {
      final ch = input.codeUnitAt(i);
      if (ch == 0x0A) {
        // \n
        var end = i;
        if (end > start && input.codeUnitAt(end - 1) == 0x0D) {
          end -= 1;
        }
        lines.add(input.substring(start, end));
        start = i + 1;
      }
    }
    if (start < input.length) {
      lines.add(input.substring(start));
    }
    return lines;
  }
}
