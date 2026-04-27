import 'package:bianbianbianbian/data/local/app_database.dart';
import 'package:bianbianbianbian/data/local/seeder.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Step 1.7 验证：`DefaultSeeder.seedIfEmpty()` 的三条路径。
///
/// 覆盖实施计划的三条验收要求：
/// ① 首次启动后账本 1 个、分类按固定一级分类键生成、账户 5 个，字段齐全
///    （device_id、updated_at、created_at、颜色循环、收藏默认值）；
/// ② 第二次调用不重复插入（存在性判断保证幂等）；
/// ③ 用户已有账本的情况下整体跳过（不越权补齐）。
void main() {
  late AppDatabase db;
  const fixedInstant = 1714000000000; // 2024-04-24T21:46:40Z

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  DefaultSeeder makeSeeder({int counterStart = 0}) {
    var counter = counterStart;
    return DefaultSeeder(
      db: db,
      deviceId: 'device-a',
      clock: () =>
          DateTime.fromMillisecondsSinceEpoch(fixedInstant, isUtc: true),
      // 确定性 UUID 工厂：'uuid-0001', 'uuid-0002', ... 让断言可精确到 id
      uuidFactory: () => 'uuid-${(++counter).toString().padLeft(4, '0')}',
    );
  }

  group('DefaultSeeder.seedIfEmpty', () {
    test('空库 → 插入 1 账本 + 默认分类 + 5 账户，字段齐全', () async {
      await makeSeeder().seedIfEmpty();

      // 账本
      final ledgers = await db.select(db.ledgerTable).get();
      expect(ledgers, hasLength(1));
      final ledger = ledgers.single;
      expect(ledger.id, 'uuid-0001');
      expect(ledger.name, '生活');
      expect(ledger.coverEmoji, '📒');
      expect(ledger.defaultCurrency, 'CNY');
      expect(ledger.archived, 0);
      expect(ledger.createdAt, fixedInstant);
      expect(ledger.updatedAt, fixedInstant);
      expect(ledger.deletedAt, isNull);
      expect(ledger.deviceId, 'device-a');

      // 分类
      final categories = await db.select(db.categoryTable).get();
      const expectedCategoryCount = 60; // 11 个一级，收入 10 个，其余 10 类各 5 个
      expect(categories, hasLength(expectedCategoryCount));

      final food = categories.where((c) => c.parentKey == 'food').toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      expect(food, hasLength(5));
      expect(food.first.name, '早餐');
      expect(food.first.icon, '🥣');
      expect(food.first.color, DefaultSeeder.palette[0]); // 奶油黄
      expect(food.first.sortOrder, 0);
      expect(food.first.isFavorite, 0);
      expect(food.first.updatedAt, fixedInstant);
      expect(food.first.deviceId, 'device-a');
      expect(food.first.deletedAt, isNull);

      final income = categories.where((c) => c.parentKey == 'income').toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      expect(income, hasLength(10));
      expect(income.first.name, '工资');
      expect(income.first.icon, '💰');
      expect(income.first.sortOrder, 0);
      expect(income.last.name, '其他收入');
      expect(income.last.sortOrder, 9);

      // 账户
      final accounts = await db.select(db.accountTable).get();
      expect(accounts, hasLength(5));
      final byName = {for (final a in accounts) a.name: a};
      expect(byName.keys, containsAll(['现金', '工商银行卡', '招商信用卡', '支付宝', '微信']));
      expect(byName['现金']!.type, 'cash');
      expect(byName['工商银行卡']!.type, 'debit');
      expect(byName['招商信用卡']!.type, 'credit');
      expect(byName['支付宝']!.type, 'third_party');
      expect(byName['微信']!.type, 'third_party');
      for (final acc in accounts) {
        expect(acc.includeInTotal, 1);
        expect(acc.currency, 'CNY');
        expect(acc.initialBalance, 0.0);
        expect(acc.deviceId, 'device-a');
        expect(acc.updatedAt, fixedInstant);
        expect(acc.deletedAt, isNull);
      }
    });

    test('第二次调用不重复插入（幂等）', () async {
      await makeSeeder().seedIfEmpty();
      final ledgersAfterFirst = await db.select(db.ledgerTable).get();
      final catsAfterFirst = await db.select(db.categoryTable).get();
      final accsAfterFirst = await db.select(db.accountTable).get();

      // 第二个 seeder 实例:若幂等失效会复用新 UUID 覆盖,我们以 id 集合来比对
      await makeSeeder(counterStart: 1000).seedIfEmpty();

      final ledgersAfterSecond = await db.select(db.ledgerTable).get();
      final catsAfterSecond = await db.select(db.categoryTable).get();
      final accsAfterSecond = await db.select(db.accountTable).get();

      expect(ledgersAfterSecond.map((l) => l.id).toSet(),
          ledgersAfterFirst.map((l) => l.id).toSet());
      expect(catsAfterSecond.map((c) => c.id).toSet(),
          catsAfterFirst.map((c) => c.id).toSet());
      expect(accsAfterSecond.map((a) => a.id).toSet(),
          accsAfterFirst.map((a) => a.id).toSet());
    });

    test('已存在账本时整体跳过（不补齐分类/账户）', () async {
      // 预置一个用户自建的账本,seeder 应完全不动
      await db.into(db.ledgerTable).insert(
            LedgerTableCompanion.insert(
              id: 'user-ledger-1',
              name: '工作',
              createdAt: 1700000000000,
              updatedAt: 1700000000000,
              deviceId: 'device-other',
            ),
          );

      await makeSeeder().seedIfEmpty();

      final ledgers = await db.select(db.ledgerTable).get();
      expect(ledgers, hasLength(1));
      expect(ledgers.single.id, 'user-ledger-1');
      expect(ledgers.single.name, '工作');

      // 不新增分类或账户
      expect(await db.select(db.categoryTable).get(), isEmpty);
      expect(await db.select(db.accountTable).get(), isEmpty);
    });
  });
}
