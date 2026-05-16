import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:bianbianbianbian/domain/entity/account.dart';
import 'package:bianbianbianbian/domain/entity/budget.dart';
import 'package:bianbianbianbian/domain/entity/category.dart';
import 'package:bianbianbianbian/domain/entity/ledger.dart';
import 'package:bianbianbianbian/domain/entity/transaction_entry.dart';
import 'package:bianbianbianbian/features/sync/snapshot_serializer.dart';
import 'package:bianbianbianbian/features/import_export/export_service.dart';

// ──────────────────────────────────────────────────────────────────────────
// 数据构造 helper：单元测试里的样本快照只需要 minimal 字段；不可空字段一律填默认值。
// ──────────────────────────────────────────────────────────────────────────

Ledger _ledger({
  required String id,
  required String name,
  String? cover,
}) =>
    Ledger(
      id: id,
      name: name,
      coverEmoji: cover,
      createdAt: DateTime.utc(2026, 4, 1),
      updatedAt: DateTime.utc(2026, 4, 1),
      deviceId: 'dev-1',
    );

Category _cat(String id, String name) => Category(
      id: id,
      name: name,
      parentKey: 'food',
      updatedAt: DateTime.utc(2026, 4, 1),
      deviceId: 'dev-1',
    );

Account _acc(String id, String name) => Account(
      id: id,
      name: name,
      type: 'cash',
      updatedAt: DateTime.utc(2026, 4, 1),
      deviceId: 'dev-1',
    );

TransactionEntry _tx({
  required String id,
  required String ledgerId,
  required String type,
  required double amount,
  required DateTime occurredAt,
  String? categoryId,
  String? accountId,
  String? toAccountId,
  String? tags,
}) =>
    TransactionEntry(
      id: id,
      ledgerId: ledgerId,
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

LedgerSnapshot _snap({
  required Ledger ledger,
  List<Category> categories = const [],
  List<Account> accounts = const [],
  List<TransactionEntry> transactions = const [],
  List<Budget> budgets = const [],
}) =>
    LedgerSnapshot(
      version: LedgerSnapshot.kVersion,
      exportedAt: DateTime.utc(2026, 4, 30, 12),
      deviceId: 'dev-1',
      ledger: ledger,
      categories: categories,
      accounts: accounts,
      transactions: transactions,
      budgets: budgets,
    );

void main() {
  group('BackupDateRange', () {
    test('unbounded contains every timestamp', () {
      const r = BackupDateRange.unbounded;
      expect(r.isBounded, isFalse);
      expect(r.contains(DateTime.utc(1900)), isTrue);
      expect(r.contains(DateTime.utc(2200)), isTrue);
    });

    test('start-only excludes timestamps before start', () {
      final r = BackupDateRange(start: DateTime.utc(2026, 4, 10));
      expect(r.contains(DateTime.utc(2026, 4, 9, 23, 59)), isFalse);
      expect(r.contains(DateTime.utc(2026, 4, 10)), isTrue);
      expect(r.contains(DateTime.utc(2030)), isTrue);
    });

    test('end-only excludes timestamps after end', () {
      final r = BackupDateRange(end: DateTime.utc(2026, 4, 30, 23, 59, 59));
      expect(r.contains(DateTime.utc(2026, 4, 30)), isTrue);
      expect(r.contains(DateTime.utc(2026, 5)), isFalse);
    });

    test('bounded includes both endpoints', () {
      final r = BackupDateRange(
        start: DateTime.utc(2026, 4, 10),
        end: DateTime.utc(2026, 4, 30, 23, 59, 59),
      );
      expect(r.contains(DateTime.utc(2026, 4, 10)), isTrue);
      expect(r.contains(DateTime.utc(2026, 4, 30, 23, 59, 59)), isTrue);
      expect(r.contains(DateTime.utc(2026, 4, 9, 23, 59)), isFalse);
      expect(r.contains(DateTime.utc(2026, 5)), isFalse);
    });
  });

  group('filterSnapshotByRange', () {
    test('returns identical instance when range is unbounded', () {
      final snap = _snap(
        ledger: _ledger(id: 'L1', name: '生活'),
        transactions: [
          _tx(
            id: 't1',
            ledgerId: 'L1',
            type: 'expense',
            amount: 1,
            occurredAt: DateTime.utc(1900),
          ),
        ],
      );
      final filtered = filterSnapshotByRange(snap, BackupDateRange.unbounded);
      expect(identical(filtered, snap), isTrue);
    });

    test('drops transactions outside range, keeps other fields intact', () {
      final ledger = _ledger(id: 'L1', name: '生活');
      final categories = [_cat('cat-food', '餐饮')];
      final accounts = [_acc('acc-cash', '现金')];
      final budgets = <Budget>[];
      final snap = _snap(
        ledger: ledger,
        categories: categories,
        accounts: accounts,
        budgets: budgets,
        transactions: [
          _tx(
            id: 'before',
            ledgerId: 'L1',
            type: 'expense',
            amount: 1,
            occurredAt: DateTime.utc(2026, 3, 31, 23, 59),
          ),
          _tx(
            id: 'in',
            ledgerId: 'L1',
            type: 'expense',
            amount: 99,
            occurredAt: DateTime.utc(2026, 4, 15, 12),
          ),
          _tx(
            id: 'after',
            ledgerId: 'L1',
            type: 'expense',
            amount: 1,
            occurredAt: DateTime.utc(2026, 5, 1),
          ),
        ],
      );
      final range = BackupDateRange(
        start: DateTime.utc(2026, 4, 1),
        end: DateTime.utc(2026, 4, 30, 23, 59, 59),
      );
      final filtered = filterSnapshotByRange(snap, range);
      expect(filtered.transactions.map((t) => t.id), ['in']);
      // 其余字段引用未变
      expect(identical(filtered.ledger, ledger), isTrue);
      expect(identical(filtered.categories, categories), isTrue);
      expect(identical(filtered.accounts, accounts), isTrue);
      expect(identical(filtered.budgets, budgets), isTrue);
    });
  });

  group('encodeBackupCsv', () {
    test('emits UTF-8 BOM and 9-column Chinese header', () {
      final csv = encodeBackupCsv(snapshots: const []);
      expect(csv.startsWith('\uFEFF'), isTrue);
      final header = csv.split('\n').first;
      expect(header,
          '\uFEFF账本,日期,类型,金额,币种,分类,账户,转入账户,备注');
    });

    test('writes ledger label with cover emoji + name', () {
      final csv = encodeBackupCsv(snapshots: [
        _snap(
          ledger: _ledger(id: 'L1', name: '生活', cover: '📒'),
          categories: [_cat('cat-food', '餐饮')],
          accounts: [_acc('acc-cash', '现金')],
          transactions: [
            _tx(
              id: 't1',
              ledgerId: 'L1',
              type: 'expense',
              amount: 12.5,
              occurredAt: DateTime.utc(2026, 4, 25, 10),
              categoryId: 'cat-food',
              accountId: 'acc-cash',
              tags: '午餐',
            ),
          ],
        ),
      ]);
      final lines = const LineSplitter().convert(csv);
      expect(lines.length, 2);
      expect(
        lines[1],
        '📒 生活,2026-04-25 10:00,支出,12.50,CNY,餐饮,现金,,午餐',
      );
    });

    test('falls back to plain ledger name when cover emoji is missing', () {
      final csv = encodeBackupCsv(snapshots: [
        _snap(
          ledger: _ledger(id: 'L1', name: '工作', cover: null),
          accounts: [_acc('acc-bank', '工行卡')],
          transactions: [
            _tx(
              id: 't1',
              ledgerId: 'L1',
              type: 'income',
              amount: 5000,
              occurredAt: DateTime.utc(2026, 4, 5, 9, 30),
              accountId: 'acc-bank',
              tags: '工资',
            ),
          ],
        ),
      ]);
      final lines = const LineSplitter().convert(csv);
      expect(
        lines[1],
        '工作,2026-04-05 09:30,收入,5000.00,CNY,,工行卡,,工资',
      );
    });

    test('keeps transfer rows with toAccount column populated', () {
      final csv = encodeBackupCsv(snapshots: [
        _snap(
          ledger: _ledger(id: 'L1', name: '生活', cover: '📒'),
          accounts: [
            _acc('acc-cash', '现金'),
            _acc('acc-bank', '工行卡'),
          ],
          transactions: [
            _tx(
              id: 'transfer',
              ledgerId: 'L1',
              type: 'transfer',
              amount: 200,
              occurredAt: DateTime.utc(2026, 4, 10, 12),
              accountId: 'acc-cash',
              toAccountId: 'acc-bank',
            ),
          ],
        ),
      ]);
      final lines = const LineSplitter().convert(csv);
      expect(
        lines[1],
        '📒 生活,2026-04-10 12:00,转账,200.00,CNY,,现金,工行卡,',
      );
    });

    test('escapes commas, quotes and newlines per RFC 4180', () {
      final csv = encodeBackupCsv(snapshots: [
        _snap(
          ledger: _ledger(id: 'L1', name: '生活', cover: '📒'),
          categories: [_cat('c', '杂,项')],
          accounts: [_acc('a', '钱"包')],
          transactions: [
            _tx(
              id: 't',
              ledgerId: 'L1',
              type: 'expense',
              amount: 9.99,
              occurredAt: DateTime.utc(2026, 4, 12, 8),
              categoryId: 'c',
              accountId: 'a',
              tags: 'hello, "world"\n第二行',
            ),
          ],
        ),
      ]);
      expect(csv, contains('"杂,项"'));
      expect(csv, contains('"钱""包"'));
      expect(csv, contains('"hello, ""world""'));
    });

    test('orders transactions ascending by occurredAt within each snapshot', () {
      final csv = encodeBackupCsv(snapshots: [
        _snap(
          ledger: _ledger(id: 'L1', name: '生活', cover: '📒'),
          accounts: [_acc('a', '钱包')],
          transactions: [
            _tx(
              id: 'b',
              ledgerId: 'L1',
              type: 'expense',
              amount: 2,
              occurredAt: DateTime.utc(2026, 4, 25, 10),
              accountId: 'a',
            ),
            _tx(
              id: 'a',
              ledgerId: 'L1',
              type: 'expense',
              amount: 1,
              occurredAt: DateTime.utc(2026, 4, 5, 10),
              accountId: 'a',
            ),
          ],
        ),
      ]);
      final lines = const LineSplitter().convert(csv);
      expect(lines[1], contains('1.00'));
      expect(lines[2], contains('2.00'));
    });

    test('writes multiple ledgers in given order with their own labels', () {
      final csv = encodeBackupCsv(snapshots: [
        _snap(
          ledger: _ledger(id: 'L1', name: '生活', cover: '📒'),
          accounts: [_acc('a1', '现金')],
          transactions: [
            _tx(
              id: 't1',
              ledgerId: 'L1',
              type: 'expense',
              amount: 1,
              occurredAt: DateTime.utc(2026, 4, 1),
              accountId: 'a1',
            ),
          ],
        ),
        _snap(
          ledger: _ledger(id: 'L2', name: '工作', cover: '💼'),
          accounts: [_acc('a2', '工行卡')],
          transactions: [
            _tx(
              id: 't2',
              ledgerId: 'L2',
              type: 'income',
              amount: 1000,
              occurredAt: DateTime.utc(2026, 4, 2),
              accountId: 'a2',
            ),
          ],
        ),
      ]);
      final lines = const LineSplitter().convert(csv);
      expect(lines.length, 3);
      expect(lines[1], startsWith('📒 生活,'));
      expect(lines[2], startsWith('💼 工作,'));
    });

    test('renders empty cells when category/account references are stale', () {
      final csv = encodeBackupCsv(snapshots: [
        _snap(
          ledger: _ledger(id: 'L1', name: '生活', cover: '📒'),
          transactions: [
            _tx(
              id: 't',
              ledgerId: 'L1',
              type: 'expense',
              amount: 3.5,
              occurredAt: DateTime.utc(2026, 4, 1),
              categoryId: 'missing-cat',
              accountId: 'missing-acc',
            ),
          ],
        ),
      ]);
      final lines = const LineSplitter().convert(csv);
      expect(lines[1], '📒 生活,2026-04-01 00:00,支出,3.50,CNY,,,,');
    });
  });

  group('encodeBackupJson + MultiLedgerSnapshot.fromJson', () {
    test('round-trips through toJson/fromJson', () {
      final snap = _snap(
        ledger: _ledger(id: 'L1', name: '生活', cover: '📒'),
        categories: [_cat('cat-food', '餐饮')],
        accounts: [_acc('acc-cash', '现金')],
        transactions: [
          _tx(
            id: 't1',
            ledgerId: 'L1',
            type: 'expense',
            amount: 12.5,
            occurredAt: DateTime.utc(2026, 4, 25, 10),
            categoryId: 'cat-food',
            accountId: 'acc-cash',
            tags: '午餐',
          ),
        ],
      );
      final multi = MultiLedgerSnapshot(
        version: MultiLedgerSnapshot.kVersion,
        exportedAt: DateTime.utc(2026, 5, 4, 12),
        deviceId: 'dev-1',
        ledgers: [snap],
      );
      final str = encodeBackupJson(multi);
      final decoded = MultiLedgerSnapshot.fromJson(
        jsonDecode(str) as Map<String, dynamic>,
      );
      expect(decoded.version, MultiLedgerSnapshot.kVersion);
      expect(decoded.deviceId, 'dev-1');
      expect(decoded.ledgers.length, 1);
      final ls = decoded.ledgers.first;
      expect(ls.ledger.id, 'L1');
      expect(ls.ledger.coverEmoji, '📒');
      expect(ls.transactions.first.id, 't1');
      expect(ls.transactions.first.amount, 12.5);
      expect(ls.transactions.first.tags, '午餐');
    });

    test('throws FormatException when version is newer than supported', () {
      final json = {
        'version': MultiLedgerSnapshot.kVersion + 1,
        'exported_at': DateTime.utc(2026, 5, 4).toIso8601String(),
        'device_id': 'dev-1',
        'ledgers': <Map<String, dynamic>>[],
      };
      expect(
        () => MultiLedgerSnapshot.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('treats absent version as v1 (forward-compat reading)', () {
      final json = {
        'exported_at': DateTime.utc(2026, 5, 4).toIso8601String(),
        'device_id': 'dev-1',
        'ledgers': <Map<String, dynamic>>[],
      };
      final ms = MultiLedgerSnapshot.fromJson(json);
      expect(ms.version, 1);
      expect(ms.ledgers, isEmpty);
    });
  });

  group('buildBackupFileName', () {
    test('omits range segments when range is unbounded', () {
      final name = buildBackupFileName(
        prefix: 'bianbian_backup',
        extension: 'csv',
        now: DateTime(2026, 5, 4, 14, 5, 8),
        scope: BackupScope.currentLedger,
        range: BackupDateRange.unbounded,
      );
      expect(name, 'bianbian_backup_current_20260504_140508.csv');
    });

    test('includes range start/end when bounded', () {
      final name = buildBackupFileName(
        prefix: 'bianbian_backup',
        extension: 'json',
        now: DateTime(2026, 5, 4, 14, 5, 8),
        scope: BackupScope.allLedgers,
        range: BackupDateRange(
          start: DateTime(2026, 4, 1),
          end: DateTime(2026, 4, 30, 23, 59, 59),
        ),
      );
      expect(name, 'bianbian_backup_all_20260401_20260430_20260504_140508.json');
    });

    test('renders min/max placeholders for half-open ranges', () {
      final startOnly = buildBackupFileName(
        prefix: 'bianbian_backup',
        extension: 'csv',
        now: DateTime(2026, 5, 4, 14, 5, 8),
        scope: BackupScope.currentLedger,
        range: BackupDateRange(start: DateTime(2026, 4, 1)),
      );
      expect(startOnly,
          'bianbian_backup_current_20260401_max_20260504_140508.csv');

      final endOnly = buildBackupFileName(
        prefix: 'bianbian_backup',
        extension: 'csv',
        now: DateTime(2026, 5, 4, 14, 5, 8),
        scope: BackupScope.currentLedger,
        range: BackupDateRange(end: DateTime(2026, 4, 30, 23, 59, 59)),
      );
      expect(endOnly,
          'bianbian_backup_current_min_20260430_20260504_140508.csv');
    });
  });
}

/// Minimal LineSplitter clone（与 stats_export_service_test 同形态）：只按 \n / \r\n 切。
class LineSplitter {
  const LineSplitter();
  List<String> convert(String input) {
    final lines = <String>[];
    var start = 0;
    for (var i = 0; i < input.length; i++) {
      final ch = input.codeUnitAt(i);
      if (ch == 0x0A) {
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
