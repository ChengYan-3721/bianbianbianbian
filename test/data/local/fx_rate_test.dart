import 'package:bianbianbianbian/core/util/currencies.dart';
import 'package:bianbianbianbian/data/local/app_database.dart';
import 'package:bianbianbianbian/data/local/seeder.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Step 8.1 验证：fx_rate DAO + 种子化 + 内置常量。
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('FxRateDao', () {
    test('upsert + listAll 按 code 升序返回', () async {
      await db.fxRateDao.upsert(
        FxRateTableCompanion.insert(
          code: 'USD',
          rateToCny: 7.20,
          updatedAt: 1714000000000,
        ),
      );
      await db.fxRateDao.upsert(
        FxRateTableCompanion.insert(
          code: 'EUR',
          rateToCny: 7.85,
          updatedAt: 1714000000000,
        ),
      );

      final rows = await db.fxRateDao.listAll();
      expect(rows, hasLength(2));
      expect(rows[0].code, 'EUR');
      expect(rows[0].rateToCny, 7.85);
      expect(rows[1].code, 'USD');
      expect(rows[1].rateToCny, 7.20);
      // Step 8.3：默认 is_manual=0
      expect(rows.every((r) => r.isManual == 0), true);
    });

    test('upsert 同 code 二次写入视为更新', () async {
      await db.fxRateDao.upsert(
        FxRateTableCompanion.insert(
          code: 'USD',
          rateToCny: 7.20,
          updatedAt: 1714000000000,
        ),
      );
      await db.fxRateDao.upsert(
        FxRateTableCompanion.insert(
          code: 'USD',
          rateToCny: 7.30,
          updatedAt: 1714999999999,
        ),
      );

      final all = await db.fxRateDao.listAll();
      expect(all, hasLength(1));
      expect(all.single.rateToCny, 7.30);
      expect(all.single.updatedAt, 1714999999999);
    });

    test('getByCode 命中 / 未命中', () async {
      await db.fxRateDao.upsert(
        FxRateTableCompanion.insert(
          code: 'JPY',
          rateToCny: 0.048,
          updatedAt: 1714000000000,
        ),
      );

      final hit = await db.fxRateDao.getByCode('JPY');
      expect(hit, isNotNull);
      expect(hit!.rateToCny, 0.048);

      final miss = await db.fxRateDao.getByCode('XXX');
      expect(miss, isNull);
    });

    test('Step 8.3：setAutoRate 在新行上插入并默认 is_manual=0', () async {
      final affected = await db.fxRateDao.setAutoRate(
        code: 'USD',
        rateToCny: 7.30,
        updatedAt: 1714000000000,
      );
      expect(affected, 1);
      final usd = await db.fxRateDao.getByCode('USD');
      expect(usd!.isManual, 0);
      expect(usd.rateToCny, 7.30);
    });

    test('Step 8.3：setAutoRate 跳过 is_manual=1 的行', () async {
      await db.fxRateDao.setManualRate(
        code: 'USD',
        rateToCny: 6.50,
        updatedAt: 1700000000000,
      );

      final affected = await db.fxRateDao.setAutoRate(
        code: 'USD',
        rateToCny: 7.30,
        updatedAt: 1714000000000,
      );
      expect(affected, 0, reason: '手动行被跳过');

      final usd = await db.fxRateDao.getByCode('USD');
      expect(usd!.rateToCny, 6.50);
      expect(usd.isManual, 1);
      expect(usd.updatedAt, 1700000000000);
    });

    test('Step 8.3：setManualRate 写入并标 is_manual=1', () async {
      await db.fxRateDao.setManualRate(
        code: 'USD',
        rateToCny: 6.50,
        updatedAt: 1714000000000,
      );
      final usd = await db.fxRateDao.getByCode('USD');
      expect(usd!.isManual, 1);
      expect(usd.rateToCny, 6.50);
    });

    test('Step 8.3：clearManualFlag 清标记但保留 rate', () async {
      await db.fxRateDao.setManualRate(
        code: 'USD',
        rateToCny: 6.50,
        updatedAt: 1714000000000,
      );
      await db.fxRateDao.clearManualFlag('USD');
      final usd = await db.fxRateDao.getByCode('USD');
      expect(usd!.isManual, 0);
      expect(usd.rateToCny, 6.50, reason: 'rate 不动，等下次自动刷新覆盖');
    });

    test('Step 8.3：clearManualFlag 对不存在的 code 返回 0', () async {
      final affected = await db.fxRateDao.clearManualFlag('XXX');
      expect(affected, 0);
    });
  });

  group('DefaultSeeder fx_rate 路径', () {
    const fixedInstant = 1714000000000;

    DefaultSeeder makeSeeder() {
      var counter = 0;
      return DefaultSeeder(
        db: db,
        deviceId: 'device-a',
        clock: () => DateTime.fromMillisecondsSinceEpoch(
          fixedInstant,
          isUtc: true,
        ),
        uuidFactory: () =>
            'uuid-${(++counter).toString().padLeft(4, '0')}',
      );
    }

    test('空库 → 写入 [kFxRateSnapshot] 全集', () async {
      await makeSeeder().seedIfEmpty();

      final rows = await db.fxRateDao.listAll();
      expect(rows.length, kFxRateSnapshot.length);
      for (final entry in kFxRateSnapshot.entries) {
        final row = rows.firstWhere((r) => r.code == entry.key);
        expect(row.rateToCny, entry.value);
        expect(row.updatedAt, fixedInstant);
      }
    });

    test('CNY 基准为 1.0 且 11 种内置币种全部覆盖', () async {
      await makeSeeder().seedIfEmpty();

      final rows = await db.fxRateDao.listAll();
      // 内置 11 种币种与 [kBuiltInCurrencies] 一致。
      expect(
        rows.map((r) => r.code).toSet(),
        kBuiltInCurrencies.map((c) => c.code).toSet(),
      );
      final cny = rows.firstWhere((r) => r.code == 'CNY');
      expect(cny.rateToCny, 1.0);
    });

    test('已有 fx_rate 时不被覆盖（独立判空）', () async {
      // 用户/Step 8.3 已经手动覆盖了 USD 汇率
      await db.fxRateDao.upsert(
        FxRateTableCompanion.insert(
          code: 'USD',
          rateToCny: 6.50,
          updatedAt: 1700000000000,
        ),
      );

      await makeSeeder().seedIfEmpty();

      // USD 仍是用户值，不是 7.20
      final usd = await db.fxRateDao.getByCode('USD');
      expect(usd, isNotNull);
      expect(usd!.rateToCny, 6.50);
      expect(usd.updatedAt, 1700000000000);

      // 但不应反过来阻止其它币种被种子化——fx_rate 整体判空已有数据 → 整体跳过
      // 这是当前实现选择：避免逐 code 增量逻辑（与 ledger seeding 同语义）。
      final all = await db.fxRateDao.listAll();
      expect(all, hasLength(1));
    });

    test('ledger 已存在但 fx_rate 为空 → 仅种子化 fx_rate', () async {
      // 模拟 v6 schema 升级后的首次冷启动：用户已有 ledger（来自 v5 数据），
      // 但 fx_rate 是新表，初始为空。seeder 应只补齐 fx_rate 而不重建账本/分类。
      await db.into(db.ledgerTable).insert(
            LedgerTableCompanion.insert(
              id: 'user-ledger',
              name: '工作',
              createdAt: 1700000000000,
              updatedAt: 1700000000000,
              deviceId: 'device-other',
            ),
          );
      expect(await db.fxRateDao.listAll(), isEmpty);

      await makeSeeder().seedIfEmpty();

      final ledgers = await db.select(db.ledgerTable).get();
      expect(ledgers, hasLength(1));
      expect(ledgers.single.id, 'user-ledger');
      // 分类/账户保持空——seeder 不补齐
      expect(await db.select(db.categoryTable).get(), isEmpty);
      expect(await db.select(db.accountTable).get(), isEmpty);
      // fx_rate 被独立种子化
      expect(await db.fxRateDao.listAll(), hasLength(kFxRateSnapshot.length));
    });
  });

  group('内置币种常量', () {
    test('kBuiltInCurrencies 含 CNY/USD/EUR/JPY/KRW/HKD/TWD/GBP/SGD/CAD/AUD',
        () async {
      final codes = kBuiltInCurrencies.map((c) => c.code).toList();
      expect(codes, [
        'CNY', 'USD', 'EUR', 'JPY', 'KRW',
        'HKD', 'TWD', 'GBP', 'SGD', 'CAD', 'AUD',
      ]);
    });

    test('kFxRateSnapshot 与 kBuiltInCurrencies 同集', () async {
      expect(
        kFxRateSnapshot.keys.toSet(),
        kBuiltInCurrencies.map((c) => c.code).toSet(),
      );
    });

    test('kFxRateSnapshot 中 CNY 自身汇率为 1.0', () async {
      expect(kFxRateSnapshot['CNY'], 1.0);
    });

    test('每种币种有非空 symbol 与中文 name', () async {
      for (final c in kBuiltInCurrencies) {
        expect(c.symbol, isNotEmpty, reason: '${c.code} 缺少 symbol');
        expect(c.name, isNotEmpty, reason: '${c.code} 缺少 name');
      }
    });
  });
}
