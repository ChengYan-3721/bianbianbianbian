import 'dart:convert';
import 'dart:typed_data';

import 'package:bianbianbianbian/data/local/app_database.dart';
import 'package:bianbianbianbian/data/repository/entity_mappers.dart';
import 'package:bianbianbianbian/domain/entity/account.dart';
import 'package:bianbianbianbian/domain/entity/budget.dart';
import 'package:bianbianbianbian/domain/entity/category.dart';
import 'package:bianbianbianbian/domain/entity/ledger.dart';
import 'package:bianbianbianbian/domain/entity/transaction_entry.dart';
import 'package:bianbianbianbian/features/import_export/bbbak_codec.dart';
import 'package:bianbianbianbian/features/import_export/csv/csv_lexer.dart';
import 'package:bianbianbianbian/features/import_export/import_service.dart';
import 'package:bianbianbianbian/features/sync/snapshot_serializer.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

/// Step 13.3 验证：BackupImportService 解析 / 应用三类备份的端到端行为。
///
/// 单测覆盖：
/// - detectFileType（按扩展名识别）
/// - parseCsvRows（RFC 4180：双引号 / 转义 / 字段内换行）
/// - stripUtf8Bom / stripLedgerEmoji 工具函数
/// - JSON 路径：preview 计数 + 三种 strategy 各自的写入数 / 跳过数
/// - CSV 路径：header 校验 / 行解析 / fallback ledger 落地
/// - `.bbbak` 路径：与 BbbakCodec 串联完整 round-trip
///
/// 所有 DB 测试都用 `NativeDatabase.memory()` —— 与 dao_test.dart 同模式。

const _devId = 'test-dev';

/// 直接构造内存 DB；调用方负责 close。
AppDatabase _createDb() => AppDatabase.forTesting(NativeDatabase.memory());

/// 直接灌入一个 ledger / 一组 categories / accounts；测试用最简种子。
Future<void> _seedDb(AppDatabase db, {
  required List<Ledger> ledgers,
  required List<Category> categories,
  required List<Account> accounts,
}) async {
  for (final l in ledgers) {
    await db.into(db.ledgerTable).insert(ledgerToCompanion(l));
  }
  for (final c in categories) {
    await db.into(db.categoryTable).insert(categoryToCompanion(c));
  }
  for (final a in accounts) {
    await db.into(db.accountTable).insert(accountToCompanion(a));
  }
}

Ledger _ledger(String id, String name, {String? cover}) => Ledger(
      id: id,
      name: name,
      coverEmoji: cover,
      createdAt: DateTime.utc(2026, 4, 1),
      updatedAt: DateTime.utc(2026, 4, 1),
      deviceId: _devId,
    );

Category _cat(String id, String name, {String parentKey = 'food'}) => Category(
      id: id,
      name: name,
      parentKey: parentKey,
      updatedAt: DateTime.utc(2026, 4, 1),
      deviceId: _devId,
    );

Account _acc(String id, String name, {String type = 'cash'}) => Account(
      id: id,
      name: name,
      type: type,
      updatedAt: DateTime.utc(2026, 4, 1),
      deviceId: _devId,
    );

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
  String currency = 'CNY',
  String deviceId = _devId,
}) =>
    TransactionEntry(
      id: id,
      ledgerId: ledgerId,
      type: type,
      amount: amount,
      currency: currency,
      categoryId: categoryId,
      accountId: accountId,
      toAccountId: toAccountId,
      occurredAt: occurredAt,
      tags: tags,
      updatedAt: occurredAt,
      deviceId: deviceId,
    );

LedgerSnapshot _snap(
  Ledger ledger, {
  List<Category> categories = const [],
  List<Account> accounts = const [],
  List<TransactionEntry> transactions = const [],
  List<Budget> budgets = const [],
}) =>
    LedgerSnapshot(
      version: LedgerSnapshot.kVersion,
      exportedAt: DateTime.utc(2026, 5, 4, 12),
      deviceId: _devId,
      ledger: ledger,
      categories: categories,
      accounts: accounts,
      transactions: transactions,
      budgets: budgets,
    );

MultiLedgerSnapshot _multi(List<LedgerSnapshot> ledgers) => MultiLedgerSnapshot(
      version: MultiLedgerSnapshot.kVersion,
      exportedAt: DateTime.utc(2026, 5, 4, 12),
      deviceId: _devId,
      ledgers: ledgers,
    );

Uint8List _jsonBytes(MultiLedgerSnapshot multi) =>
    Uint8List.fromList(utf8.encode(jsonEncode(multi.toJson())));

void main() {
  group('BackupImportService.detectFileType', () {
    test('识别 .json / .csv / .bbbak（大小写不敏感）', () {
      expect(BackupImportService.detectFileType('a.json'),
          BackupImportFileType.json);
      expect(BackupImportService.detectFileType('a.JSON'),
          BackupImportFileType.json);
      expect(BackupImportService.detectFileType('bianbian_backup_x.csv'),
          BackupImportFileType.csv);
      expect(BackupImportService.detectFileType('a.bbbak'),
          BackupImportFileType.bbbak);
      expect(BackupImportService.detectFileType('a.BBBAK'),
          BackupImportFileType.bbbak);
    });

    test('未知后缀抛 BackupImportException', () {
      expect(() => BackupImportService.detectFileType('a.txt'),
          throwsA(isA<BackupImportException>()));
      expect(() => BackupImportService.detectFileType('no-ext'),
          throwsA(isA<BackupImportException>()));
    });
  });

  group('parseCsvRows / stripUtf8Bom / stripLedgerEmoji', () {
    test('parseCsvRows 支持简单 3x2 行', () {
      final rows = parseCsvRows('a,b,c\n1,2,3\n');
      expect(rows.length, 2);
      expect(rows[0], ['a', 'b', 'c']);
      expect(rows[1], ['1', '2', '3']);
    });

    test('parseCsvRows 支持 \\r\\n 行尾', () {
      final rows = parseCsvRows('a,b\r\n1,2\r\n');
      expect(rows, [
        ['a', 'b'],
        ['1', '2']
      ]);
    });

    test('parseCsvRows 支持双引号包裹 + 内部逗号', () {
      final rows = parseCsvRows('"a,1",b\n"c""d",e\n');
      expect(rows[0], ['a,1', 'b']);
      // RFC 4180：内部双引号转义为两个双引号
      expect(rows[1], ['c"d', 'e']);
    });

    test('parseCsvRows 支持字段内换行', () {
      final rows = parseCsvRows('"line1\nline2",x\n');
      expect(rows.length, 1);
      expect(rows[0], ['line1\nline2', 'x']);
    });

    test('parseCsvRows 末尾无换行也保留最后一行', () {
      final rows = parseCsvRows('a,b\n1,2');
      expect(rows.length, 2);
      expect(rows[1], ['1', '2']);
    });

    test('stripUtf8Bom 删 BOM', () {
      expect(stripUtf8Bom('﻿hello'), 'hello');
      expect(stripUtf8Bom('hello'), 'hello');
      expect(stripUtf8Bom(''), '');
    });

    test('stripLedgerEmoji 把 emoji + 空格剥离', () {
      expect(stripLedgerEmoji('📒 生活'), '生活');
      expect(stripLedgerEmoji('💼 工作'), '工作');
      expect(stripLedgerEmoji('生活'), '生活'); // 没 emoji 原样返回
      expect(stripLedgerEmoji('  📒  生活  '), '生活');
      expect(stripLedgerEmoji('Workbook'), 'Workbook');
    });
  });

  group('JSON 预览', () {
    test('preview 提取账本数 / 流水数 / 前 20 行', () async {
      final txs = List.generate(
        25,
        (i) => _tx(
          id: 'tx-$i',
          ledgerId: 'L1',
          type: 'expense',
          amount: i + 1.0,
          occurredAt: DateTime.utc(2026, 4, 1).add(Duration(days: i)),
          categoryId: 'cat-1',
          accountId: 'acc-1',
        ),
      );
      final multi = _multi([
        _snap(
          _ledger('L1', '生活', cover: '📒'),
          categories: [_cat('cat-1', '餐饮')],
          accounts: [_acc('acc-1', '现金')],
          transactions: txs,
        ),
      ]);
      final svc = BackupImportService();
      final preview = await svc.preview(
        bytes: _jsonBytes(multi),
        fileType: BackupImportFileType.json,
      );
      expect(preview.fileType, BackupImportFileType.json);
      expect(preview.ledgerCount, 1);
      expect(preview.transactionCount, 25);
      expect(preview.sampleRows.length, 20);
      expect(preview.sampleRows.first.ledgerLabel, '📒 生活');
      expect(preview.sampleRows.first.category, '餐饮');
      expect(preview.sampleRows.first.account, '现金');
      expect(preview.exportedAt, DateTime.utc(2026, 5, 4, 12));
      expect(preview.sourceDeviceId, _devId);
    });

    test('preview 拒绝非 UTF-8 字节', () async {
      final svc = BackupImportService();
      final invalid = Uint8List.fromList([0xFF, 0xFE, 0xFD]);
      await expectLater(
        svc.preview(bytes: invalid, fileType: BackupImportFileType.json),
        throwsA(isA<BackupImportException>()),
      );
    });

    test('preview 拒绝合法 JSON 但顶层是 List', () async {
      final svc = BackupImportService();
      final bytes = Uint8List.fromList(utf8.encode('[]'));
      await expectLater(
        svc.preview(bytes: bytes, fileType: BackupImportFileType.json),
        throwsA(isA<BackupImportException>()),
      );
    });

    test('preview 拒绝版本号超前', () async {
      final svc = BackupImportService();
      final json = jsonEncode({
        'version': MultiLedgerSnapshot.kVersion + 1,
        'exported_at': DateTime.utc(2026, 5).toIso8601String(),
        'device_id': 'dev-1',
        'ledgers': const <Map<String, dynamic>>[],
      });
      await expectLater(
        svc.preview(
          bytes: Uint8List.fromList(utf8.encode(json)),
          fileType: BackupImportFileType.json,
        ),
        throwsA(isA<BackupImportException>()),
      );
    });
  });

  group('JSON 应用 — strategy', () {
    late AppDatabase db;
    setUp(() => db = _createDb());
    tearDown(() async => db.close());

    Future<MultiLedgerSnapshot> seedAndBackup() async {
      // 在 DB 中预先放一个账本 + 1 条 tx-A，再返回包含 tx-A & tx-B 的快照
      await _seedDb(
        db,
        ledgers: [_ledger('L1', '生活', cover: '📒')],
        categories: [_cat('cat-1', '餐饮')],
        accounts: [_acc('acc-1', '现金')],
      );
      // 已有 tx-A
      await db.into(db.transactionEntryTable).insert(
            transactionEntryToCompanion(_tx(
              id: 'tx-A',
              ledgerId: 'L1',
              type: 'expense',
              amount: 5,
              occurredAt: DateTime.utc(2026, 4, 1),
              categoryId: 'cat-1',
              accountId: 'acc-1',
              tags: '原值',
            )),
          );
      // 备份：含 tx-A（金额改为 99——想覆盖时区分）+ tx-B（新流水）
      return _multi([
        _snap(
          _ledger('L1', '生活', cover: '📒'),
          categories: [_cat('cat-1', '餐饮')],
          accounts: [_acc('acc-1', '现金')],
          transactions: [
            _tx(
              id: 'tx-A',
              ledgerId: 'L1',
              type: 'expense',
              amount: 99,
              occurredAt: DateTime.utc(2026, 4, 1),
              categoryId: 'cat-1',
              accountId: 'acc-1',
              tags: '备份值',
            ),
            _tx(
              id: 'tx-B',
              ledgerId: 'L1',
              type: 'expense',
              amount: 7,
              occurredAt: DateTime.utc(2026, 4, 2),
              categoryId: 'cat-1',
              accountId: 'acc-1',
            ),
          ],
        ),
      ]);
    }

    test('strategy=skip：tx-A 跳过，tx-B 写入，DB 中 tx-A 仍是原值', () async {
      final multi = await seedAndBackup();
      final svc = BackupImportService();
      final preview = await svc.preview(
        bytes: _jsonBytes(multi),
        fileType: BackupImportFileType.json,
      );
      final result = await svc.apply(
        preview: preview,
        strategy: BackupDedupeStrategy.skip,
        db: db,
        currentDeviceId: _devId,
      );
      expect(result.transactionsWritten, 1);
      expect(result.transactionsSkipped, 1);
      // DB 中 tx-A 仍是 amount=5 / tags=原值
      final rows = await db.select(db.transactionEntryTable).get();
      expect(rows.length, 2);
      final rowA = rows.firstWhere((r) => r.id == 'tx-A');
      final rowB = rows.firstWhere((r) => r.id == 'tx-B');
      expect(rowA.amount, 5);
      expect(rowA.tags, '原值');
      expect(rowB.amount, 7);
    });

    test('strategy=overwrite：tx-A 被备份值覆盖，tx-B 写入', () async {
      final multi = await seedAndBackup();
      final svc = BackupImportService();
      final preview = await svc.preview(
        bytes: _jsonBytes(multi),
        fileType: BackupImportFileType.json,
      );
      final result = await svc.apply(
        preview: preview,
        strategy: BackupDedupeStrategy.overwrite,
        db: db,
        currentDeviceId: _devId,
      );
      expect(result.transactionsWritten, 2);
      expect(result.transactionsSkipped, 0);
      final rowA = await (db.select(db.transactionEntryTable)
            ..where((t) => t.id.equals('tx-A')))
          .getSingle();
      expect(rowA.amount, 99);
      expect(rowA.tags, '备份值');
    });

    test('strategy=asNew：tx-A & tx-B 都写入新 id，原 tx-A 保留', () async {
      final multi = await seedAndBackup();
      final svc = BackupImportService(uuid: const Uuid());
      final preview = await svc.preview(
        bytes: _jsonBytes(multi),
        fileType: BackupImportFileType.json,
      );
      final result = await svc.apply(
        preview: preview,
        strategy: BackupDedupeStrategy.asNew,
        db: db,
        currentDeviceId: 'new-device',
      );
      expect(result.transactionsWritten, 2);
      expect(result.transactionsSkipped, 0);
      final rows = await db.select(db.transactionEntryTable).get();
      expect(rows.length, 3, reason: '原 tx-A + 2 条新 id 流水 = 3');
      // 原 tx-A 仍存在且未变
      final rowA = rows.firstWhere((r) => r.id == 'tx-A');
      expect(rowA.amount, 5);
      expect(rowA.deviceId, _devId);
      // 2 条新 id 都不等于 tx-A / tx-B
      final newIds =
          rows.where((r) => r.id != 'tx-A').map((r) => r.id).toList();
      expect(newIds.length, 2);
      expect(newIds.contains('tx-B'), isFalse);
      // 新流水的 deviceId 已替换为本机
      for (final id in newIds) {
        final row = rows.firstWhere((r) => r.id == id);
        expect(row.deviceId, 'new-device');
      }
    });

    test('多账本合并：L1 + L2 都被 upsert 进 DB', () async {
      // 空 DB
      final svc = BackupImportService();
      final multi = _multi([
        _snap(
          _ledger('L1', '生活', cover: '📒'),
          categories: [_cat('cat-1', '餐饮')],
          accounts: [_acc('acc-1', '现金')],
          transactions: [
            _tx(
              id: 'tx-1',
              ledgerId: 'L1',
              type: 'expense',
              amount: 1,
              occurredAt: DateTime.utc(2026, 4, 1),
              categoryId: 'cat-1',
              accountId: 'acc-1',
            ),
          ],
        ),
        _snap(
          _ledger('L2', '工作', cover: '💼'),
          categories: [_cat('cat-2', '差旅')],
          accounts: [_acc('acc-2', '工行卡')],
          transactions: [
            _tx(
              id: 'tx-2',
              ledgerId: 'L2',
              type: 'income',
              amount: 5000,
              occurredAt: DateTime.utc(2026, 4, 2),
              accountId: 'acc-2',
            ),
          ],
        ),
      ]);
      final preview = await svc.preview(
        bytes: _jsonBytes(multi),
        fileType: BackupImportFileType.json,
      );
      final result = await svc.apply(
        preview: preview,
        strategy: BackupDedupeStrategy.skip,
        db: db,
        currentDeviceId: _devId,
      );
      expect(result.ledgersWritten, 2);
      expect(result.transactionsWritten, 2);
      final ledgerRows = await db.select(db.ledgerTable).get();
      expect(ledgerRows.length, 2);
      final txRows = await db.select(db.transactionEntryTable).get();
      expect(txRows.length, 2);
    });

    test('exporter → importer round-trip：重新导入数据量一致（skip 不会重复）', () async {
      // 模拟 export → import 完整流程
      // 1. seed: 1 ledger + 5 流水
      await _seedDb(
        db,
        ledgers: [_ledger('L1', '生活', cover: '📒')],
        categories: [_cat('cat-1', '餐饮')],
        accounts: [_acc('acc-1', '现金')],
      );
      for (var i = 0; i < 5; i++) {
        await db.into(db.transactionEntryTable).insert(
              transactionEntryToCompanion(_tx(
                id: 'tx-$i',
                ledgerId: 'L1',
                type: 'expense',
                amount: 10.0 + i,
                occurredAt: DateTime.utc(2026, 4, 1).add(Duration(days: i)),
                categoryId: 'cat-1',
                accountId: 'acc-1',
              )),
            );
      }
      // 2. 模拟导出：构造 multi snapshot（直接读 DB 不走 export_service，简化）
      final ledgerRow =
          await (db.select(db.ledgerTable)..where((t) => t.id.equals('L1')))
              .getSingle();
      final txRows = await db.select(db.transactionEntryTable).get();
      final multi = _multi([
        _snap(
          rowToLedger(ledgerRow),
          categories: [_cat('cat-1', '餐饮')],
          accounts: [_acc('acc-1', '现金')],
          transactions: txRows.map(rowToTransactionEntry).toList(),
        ),
      ]);
      // 3. 第一次导入 skip：5 条都已存在，全部跳过
      final svc = BackupImportService();
      var preview = await svc.preview(
        bytes: _jsonBytes(multi),
        fileType: BackupImportFileType.json,
      );
      var r = await svc.apply(
        preview: preview,
        strategy: BackupDedupeStrategy.skip,
        db: db,
        currentDeviceId: _devId,
      );
      expect(r.transactionsSkipped, 5);
      expect(r.transactionsWritten, 0);
      expect((await db.select(db.transactionEntryTable).get()).length, 5);
      // 4. 再导一次 — 仍然 skip，DB 里仍是 5 条
      preview = await svc.preview(
        bytes: _jsonBytes(multi),
        fileType: BackupImportFileType.json,
      );
      r = await svc.apply(
        preview: preview,
        strategy: BackupDedupeStrategy.skip,
        db: db,
        currentDeviceId: _devId,
      );
      expect(r.transactionsSkipped, 5);
      expect((await db.select(db.transactionEntryTable).get()).length, 5);
    });
  });

  group('CSV 10-col preview (Step 13.5)', () {
    test('本 App 10 列 CSV → parserId=bianbian', () async {
      final csv = '﻿账本,日期,类型,金额,币种,一级分类,二级分类,账户,转入账户,备注\n'
          '生活,2026-01-01 12:00,支出,10.00,CNY,饮食,早餐,现金,,午饭\n';
      final service = BackupImportService();
      final preview = await service.preview(
        bytes: Uint8List.fromList(utf8.encode(csv)),
        fileType: BackupImportFileType.csv,
      );
      expect(preview.parserId, 'bianbian');
      expect(preview.parserDisplayName, '本 App');
      expect(preview.transactionCount, 1);
      expect(preview.csvRows!.first.primaryCategoryName, '饮食');
      expect(preview.csvHeader, isNotNull);
      expect(preview.columnMapping, isNotNull);
    });

    test('旧 9 列 CSV → 走 generic(向后兼容)', () async {
      final csv = '﻿账本,日期,类型,金额,币种,分类,账户,转入账户,备注\n'
          '生活,2026-01-01 12:00,支出,10.00,CNY,早餐,现金,,午饭\n';
      final service = BackupImportService();
      final preview = await service.preview(
        bytes: Uint8List.fromList(utf8.encode(csv)),
        fileType: BackupImportFileType.csv,
      );
      expect(preview.parserId, 'generic');
      expect(preview.csvRows!.first.primaryCategoryName, isNull);
      expect(preview.csvRows!.first.ledgerLabel, '生活');  // 账本列被正确解析
    });
  });

  group('CSV 路径', () {
    late AppDatabase db;
    setUp(() => db = _createDb());
    tearDown(() async => db.close());

    test('preview 识别 9 列 header + UTF-8 BOM', () async {
      final csv = '﻿账本,日期,类型,金额,币种,分类,账户,转入账户,备注\n'
          '📒 生活,2026-04-25 10:00,支出,12.50,CNY,餐饮,现金,,午餐\n';
      final svc = BackupImportService();
      final preview = await svc.preview(
        bytes: Uint8List.fromList(utf8.encode(csv)),
        fileType: BackupImportFileType.csv,
      );
      expect(preview.fileType, BackupImportFileType.csv);
      expect(preview.transactionCount, 1);
      expect(preview.ledgerCount, 1);
      expect(preview.csvRows!.length, 1);
      final row = preview.csvRows!.first;
      expect(row.ledgerLabel, '📒 生活');
      expect(row.occurredAt, DateTime.parse('2026-04-25T10:00:00'));
      expect(row.type, 'expense');
      expect(row.amount, 12.5);
      expect(row.currency, 'CNY');
      expect(row.categoryName, '餐饮');
      expect(row.accountName, '现金');
      expect(row.toAccountName, isNull);
      expect(row.note, '午餐');
    });

    test('apply：账本 / 分类 / 账户按名匹配；匹配不到自动创建', () async {
      await _seedDb(
        db,
        ledgers: [
          _ledger('L1', '生活'),
          _ledger('L2', '工作'),
        ],
        categories: [_cat('cat-1', '餐饮')],
        accounts: [_acc('acc-1', '现金')],
      );
      final csv = '﻿账本,日期,类型,金额,币种,一级分类,分类,账户,转入账户,备注\n'
          '生活,2026-04-25 10:00,支出,12.50,CNY,饮食,餐饮,现金,,午餐\n'
          '不存在的账本,2026-04-26 11:00,支出,8.00,CNY,,不存在的分类,不存在的账户,,\n';
      final svc = BackupImportService();
      final preview = await svc.preview(
        bytes: Uint8List.fromList(utf8.encode(csv)),
        fileType: BackupImportFileType.csv,
      );
      final result = await svc.apply(
        preview: preview,
        strategy: BackupDedupeStrategy.asNew,
        db: db,
        currentDeviceId: 'imp-dev',
        fallbackLedgerId: 'L2',
      );
      expect(result.transactionsWritten, 2);
      // 账本不存在时会自动创建，不再记录为 unresolved
      expect(result.unresolvedLedgerLabels, isEmpty);
      expect(result.ledgersWritten, 1);  // 不存在的账本 auto-created
      expect(result.categoriesCreated, 1);  // 不存在的分类 auto-created
      expect(result.accountsCreated, 1);    // 不存在的账户 auto-created
      final rows = await db.select(db.transactionEntryTable).get();
      expect(rows.length, 2);
      // 第一行落在 L1 / cat-1 / acc-1
      final r1 = rows.firstWhere((r) => r.amount == 12.5);
      expect(r1.ledgerId, 'L1');
      expect(r1.categoryId, 'cat-1');
      expect(r1.accountId, 'acc-1');
      expect(r1.deviceId, 'imp-dev');
      // 第二行落在新创建的账本 / 分类 + 账户被 auto-created
      final r2 = rows.firstWhere((r) => r.amount == 8.0);
      expect(r2.ledgerId, isNot('L2'));  // 不是 fallback，而是新创建的账本
      expect(r2.categoryId, isNotNull);  // 自动创建，非 null
      expect(r2.accountId, isNotNull);   // 自动创建，非 null
    });

    test('apply 缺少 fallbackLedgerId 抛 BackupImportException', () async {
      final csv = '﻿账本,日期,类型,金额,币种,分类,账户,转入账户,备注\n'
          '生活,2026-04-25 10:00,支出,12.50,CNY,,,,\n';
      final svc = BackupImportService();
      final preview = await svc.preview(
        bytes: Uint8List.fromList(utf8.encode(csv)),
        fileType: BackupImportFileType.csv,
      );
      await expectLater(
        svc.apply(
          preview: preview,
          strategy: BackupDedupeStrategy.asNew,
          db: db,
          currentDeviceId: _devId,
          // 不传 fallbackLedgerId
        ),
        throwsA(isA<BackupImportException>()),
      );
    });
  });

  group('CSV apply — auto-create categories (Step 13.5)', () {
    late AppDatabase db;
    setUp(() => db = _createDb());
    tearDown(() async => db.close());

    test('新建分类 + 复用 + 复活', () async {
      // seed: 一个「午餐」分类(已存在，将被复用)
      await _seedDb(
        db,
        ledgers: [_ledger('L1', '生活')],
        categories: [_cat('cat-lunch', '午餐', parentKey: 'food')],
        accounts: [_acc('acc-cash', '现金')],
      );
      final service = BackupImportService(
        uuid: const Uuid(),
        clock: () => DateTime(2026, 5, 16, 10),
      );
      final csv = utf8.encode(
        '﻿账本,日期,类型,金额,币种,一级分类,分类,账户,转入账户,备注\n'
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
        fallbackLedgerId: 'L1',
      );
      expect(result.transactionsWritten, 3);
      expect(result.categoriesCreated, 2);   // 私房菜 + 玄学
      // 验证 DB 状态
      final cats = await db.select(db.categoryTable).get();
      expect(cats.where((c) => c.name == '私房菜').first.parentKey, 'food');
      expect(cats.where((c) => c.name == '玄学').first.parentKey, 'other');
      // sync_op:2 条 category upsert + 3 条 transaction upsert
      final ops = await db.syncOpDao.listAll();
      final catOps = ops.where((o) => o.entity == 'category').toList();
      expect(catOps.length, 2);
      expect(catOps.every((o) => o.op == 'upsert'), true);
      // 流水也进 sync_op（增量同步需要推送 CSV 导入的流水）
      final txOps = ops.where((o) => o.entity == 'transaction').toList();
      expect(txOps.length, 3);
      expect(txOps.every((o) => o.op == 'upsert'), true);
    });

    test('分类复活（deletedAt 清空）', () async {
      // seed: 一个软删的「咖啡」分类
      final now = DateTime.utc(2026, 5, 16);
      await _seedDb(
        db,
        ledgers: [_ledger('L1', '生活')],
        categories: [],
        accounts: [_acc('acc-cash', '现金')],
      );
      final coffeeId = 'cat-coffee';
      await db.into(db.categoryTable).insert(
        CategoryTableCompanion(
          id: Value(coffeeId),
          name: Value('咖啡'),
          parentKey: Value('food'),
          updatedAt: Value(now.millisecondsSinceEpoch),
          deletedAt: Value(now.subtract(const Duration(days: 1)).millisecondsSinceEpoch),
          deviceId: Value(_devId),
        ),
      );

      final service = BackupImportService(
        clock: () => now,
      );
      final csv = utf8.encode(
        '﻿账本,日期,类型,金额,币种,一级分类,分类,账户,转入账户,备注\n'
        '生活,2026-01-01,支出,10,CNY,饮食,咖啡,现金,,A\n',
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
        fallbackLedgerId: 'L1',
      );
      expect(result.transactionsWritten, 1);
      expect(result.categoriesCreated, 1);  // 复活计入 created 数
      // 验证复活：deletedAt 清空
      final revived = await (db.select(db.categoryTable)
            ..where((t) => t.id.equals(coffeeId)))
          .getSingle();
      expect(revived.deletedAt, isNull);
      expect(revived.parentKey, 'food');
      // sync_op: 1 条 category upsert + 1 条 transaction upsert
      final ops = await db.syncOpDao.listAll();
      expect(ops.length, 2);
      final catOp = ops.firstWhere((o) => o.entity == 'category');
      expect(catOp.op, 'upsert');
      final txOp = ops.firstWhere((o) => o.entity == 'transaction');
      expect(txOp.op, 'upsert');
    });
  });

  group('CSV apply — auto-create accounts (Step 13.5)', () {
    late AppDatabase db;
    setUp(() => db = _createDb());
    tearDown(() async => db.close());

    test('新建账户 + 复用', () async {
      // seed: 「现金」账户已存在
      await _seedDb(
        db,
        ledgers: [_ledger('L1', '生活')],
        categories: [_cat('cat-1', '餐饮')],
        accounts: [_acc('acc-cash', '现金', type: 'cash')],
      );
      final service = BackupImportService(
        clock: () => DateTime(2026, 5, 16),
      );
      final csv = utf8.encode(
        '﻿账本,日期,类型,金额,币种,一级分类,分类,账户,转入账户,备注\n'
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
        fallbackLedgerId: 'L1',
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

  group('.bbbak 路径', () {
    test('bbbak preview 与同密码 round-trip', () async {
      final multi = _multi([
        _snap(
          _ledger('L1', '生活', cover: '📒'),
          categories: [_cat('cat-1', '餐饮')],
          accounts: [_acc('acc-1', '现金')],
          transactions: [
            _tx(
              id: 'tx-1',
              ledgerId: 'L1',
              type: 'expense',
              amount: 1,
              occurredAt: DateTime.utc(2026, 4, 1),
              categoryId: 'cat-1',
              accountId: 'acc-1',
            ),
          ],
        ),
      ]);
      final json = jsonEncode(multi.toJson());
      final encrypted = await BbbakCodec.encode(
        Uint8List.fromList(utf8.encode(json)),
        '同步密码',
        iterations: 1,
      );
      final svc = BackupImportService();
      final preview = await svc.preview(
        bytes: encrypted,
        fileType: BackupImportFileType.bbbak,
        password: '同步密码',
        bbbakIterations: 1,
      );
      expect(preview.fileType, BackupImportFileType.bbbak);
      expect(preview.transactionCount, 1);
      expect(preview.snapshot, isNotNull);
    });

    test('bbbak preview 错误密码抛 DecryptionFailure', () async {
      final encrypted = await BbbakCodec.encode(
        Uint8List.fromList(utf8.encode('{}')),
        'right',
        iterations: 1,
      );
      final svc = BackupImportService();
      await expectLater(
        svc.preview(
          bytes: encrypted,
          fileType: BackupImportFileType.bbbak,
          password: 'wrong',
          bbbakIterations: 1,
        ),
        throwsA(isA<Object>()), // 容许 DecryptionFailure 透传
      );
    });

    test('bbbak preview 空密码抛 BackupImportException', () async {
      final svc = BackupImportService();
      await expectLater(
        svc.preview(
          bytes: Uint8List(64),
          fileType: BackupImportFileType.bbbak,
          password: '',
        ),
        throwsA(isA<BackupImportException>()),
      );
    });

    test('bbbak preview null 密码抛 BackupImportException', () async {
      final svc = BackupImportService();
      await expectLater(
        svc.preview(
          bytes: Uint8List(64),
          fileType: BackupImportFileType.bbbak,
          password: null,
        ),
        throwsA(isA<BackupImportException>()),
      );
    });
  });

  group('SVG 图标 JSON round-trip（Step 13.6）', () {
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
}
