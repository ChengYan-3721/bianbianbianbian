import 'package:bianbianbianbian/data/local/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Step 1.4 验证：5 张业务表 DAO 的 4 类方法。
///
/// 每个 DAO 按 `list (active [by ledger]) / upsert / softDeleteById /
/// hardDeleteById` 顺序覆盖；特别验证：
/// ① soft-delete 后 `listActive...` 查不到，
/// ② 但 [hardDeleteById] 仍能把物理行移除（软删只写 `deleted_at`，
///    行本身没走硬删；这是垃圾桶定时任务的必要前提）。
void main() {
  late AppDatabase db;
  const insertTs = 1700000000000;
  const updateTs = 1700000010000;
  const deleteTs = 1700000020000;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedLedger(String id) async {
    await db.into(db.ledgerTable).insert(
          LedgerTableCompanion.insert(
            id: id,
            name: id,
            createdAt: insertTs,
            updatedAt: insertTs,
            deviceId: 'device-a',
          ),
        );
  }

  group('LedgerDao', () {
    test('listActive / upsert / softDeleteById / hardDeleteById', () async {
      final dao = db.ledgerDao;

      // upsert × 2 作为 insert 使用
      await dao.upsert(
        LedgerTableCompanion.insert(
          id: 'ledger-1',
          name: '生活',
          createdAt: insertTs,
          updatedAt: insertTs,
          deviceId: 'device-a',
        ),
      );
      await dao.upsert(
        LedgerTableCompanion.insert(
          id: 'ledger-2',
          name: '工作',
          createdAt: insertTs,
          updatedAt: insertTs,
          deviceId: 'device-a',
        ),
      );

      // upsert 同 id:改名 + 刷 updated_at
      await dao.upsert(
        const LedgerTableCompanion(
          id: Value('ledger-1'),
          name: Value('生活账本'),
          createdAt: Value(insertTs),
          updatedAt: Value(updateTs),
          deviceId: Value('device-a'),
        ),
      );

      var rows = await dao.listActive();
      expect(rows.map((r) => r.id), unorderedEquals(['ledger-1', 'ledger-2']));
      expect(rows.firstWhere((r) => r.id == 'ledger-1').name, '生活账本');

      // softDelete:deleted_at + updated_at 双写,list 立即排除
      final softAffected = await dao.softDeleteById(
        'ledger-1',
        deletedAt: deleteTs,
        updatedAt: deleteTs,
      );
      expect(softAffected, 1);

      rows = await dao.listActive();
      expect(rows.map((r) => r.id), ['ledger-2']);

      // 物理行仍在——验证 hardDelete 能命中"软删后的行"
      final stillThere = await (db.select(db.ledgerTable)
            ..where((t) => t.id.equals('ledger-1')))
          .get();
      expect(stillThere, hasLength(1));
      expect(stillThere.first.deletedAt, deleteTs);
      expect(stillThere.first.updatedAt, deleteTs);

      final hardAffected = await dao.hardDeleteById('ledger-1');
      expect(hardAffected, 1);

      final rawAfterHard = await (db.select(db.ledgerTable)
            ..where((t) => t.id.equals('ledger-1')))
          .get();
      expect(rawAfterHard, isEmpty);
    });
  });

  group('CategoryDao', () {
    test('listActiveByParentKey / upsert / softDeleteById / hardDeleteById',
        () async {
      final dao = db.categoryDao;

      await dao.upsert(
        CategoryTableCompanion.insert(
          id: 'cat-1',
          parentKey: 'food',
          name: '餐饮',
          sortOrder: const Value(1),
          updatedAt: insertTs,
          deviceId: 'device-a',
        ),
      );
      await dao.upsert(
        CategoryTableCompanion.insert(
          id: 'cat-2',
          parentKey: 'food',
          name: '交通',
          sortOrder: const Value(0),
          updatedAt: insertTs,
          deviceId: 'device-a',
        ),
      );
      // 另一一级分类——不应出现在 food 的 list 里
      await dao.upsert(
        CategoryTableCompanion.insert(
          id: 'cat-3',
          parentKey: 'education',
          name: '办公',
          updatedAt: insertTs,
          deviceId: 'device-a',
        ),
      );

      // upsert 覆盖:改名 + 更新 sortOrder
      await dao.upsert(
        const CategoryTableCompanion(
          id: Value('cat-1'),
          parentKey: Value('food'),
          name: Value('吃喝'),
          sortOrder: Value(2),
          updatedAt: Value(updateTs),
          deviceId: Value('device-a'),
        ),
      );

      var rows = await dao.listActiveByParentKey('food');
      expect(rows.map((r) => r.id), ['cat-2', 'cat-1']); // sort_order 升序
      expect(rows.last.name, '吃喝');

      await dao.softDeleteById(
        'cat-2',
        deletedAt: deleteTs,
        updatedAt: deleteTs,
      );
      rows = await dao.listActiveByParentKey('food');
      expect(rows.map((r) => r.id), ['cat-1']);

      final hardAffected = await dao.hardDeleteById('cat-2');
      expect(hardAffected, 1);

      final remaining = await db.select(db.categoryTable).get();
      expect(remaining.map((r) => r.id), unorderedEquals(['cat-1', 'cat-3']));
    });
  });

  group('AccountDao', () {
    test('listActive / upsert / softDeleteById / hardDeleteById', () async {
      final dao = db.accountDao;

      await dao.upsert(
        AccountTableCompanion.insert(
          id: 'acc-1',
          name: '现金',
          type: 'cash',
          updatedAt: insertTs,
          deviceId: 'device-a',
        ),
      );
      await dao.upsert(
        AccountTableCompanion.insert(
          id: 'acc-2',
          name: '招行信用卡',
          type: 'credit',
          initialBalance: const Value(-1200.0),
          updatedAt: insertTs,
          deviceId: 'device-a',
        ),
      );

      // upsert 覆盖:改余额 + 刷 updated_at
      await dao.upsert(
        const AccountTableCompanion(
          id: Value('acc-2'),
          name: Value('招行信用卡'),
          type: Value('credit'),
          initialBalance: Value(-800.0),
          updatedAt: Value(updateTs),
          deviceId: Value('device-a'),
        ),
      );

      var rows = await dao.listActive();
      expect(rows.map((r) => r.id), unorderedEquals(['acc-1', 'acc-2']));
      expect(
        rows.firstWhere((r) => r.id == 'acc-2').initialBalance,
        -800.0,
      );

      await dao.softDeleteById(
        'acc-1',
        deletedAt: deleteTs,
        updatedAt: deleteTs,
      );
      rows = await dao.listActive();
      expect(rows.map((r) => r.id), ['acc-2']);

      final hardAffected = await dao.hardDeleteById('acc-1');
      expect(hardAffected, 1);

      final remaining = await db.select(db.accountTable).get();
      expect(remaining.map((r) => r.id), ['acc-2']);
    });
  });

  group('TransactionEntryDao', () {
    test('listActiveByLedger / upsert / softDeleteById / hardDeleteById',
        () async {
      await seedLedger('ledger-1');
      await seedLedger('ledger-2');
      final dao = db.transactionEntryDao;

      // 两条属于 ledger-1(不同 occurred_at),一条属于 ledger-2
      await dao.upsert(
        TransactionEntryTableCompanion.insert(
          id: 'tx-1',
          ledgerId: 'ledger-1',
          type: 'expense',
          amount: 42.5,
          currency: 'CNY',
          occurredAt: insertTs,
          updatedAt: insertTs,
          deviceId: 'device-a',
        ),
      );
      await dao.upsert(
        TransactionEntryTableCompanion.insert(
          id: 'tx-2',
          ledgerId: 'ledger-1',
          type: 'expense',
          amount: 15.0,
          currency: 'CNY',
          occurredAt: insertTs + 86400000, // 晚一天
          updatedAt: insertTs,
          deviceId: 'device-a',
        ),
      );
      await dao.upsert(
        TransactionEntryTableCompanion.insert(
          id: 'tx-3',
          ledgerId: 'ledger-2',
          type: 'income',
          amount: 10000.0,
          currency: 'CNY',
          occurredAt: insertTs,
          updatedAt: insertTs,
          deviceId: 'device-a',
        ),
      );

      // upsert 覆盖 tx-1:改金额
      await dao.upsert(
        const TransactionEntryTableCompanion(
          id: Value('tx-1'),
          ledgerId: Value('ledger-1'),
          type: Value('expense'),
          amount: Value(50.0),
          currency: Value('CNY'),
          occurredAt: Value(insertTs),
          updatedAt: Value(updateTs),
          deviceId: Value('device-a'),
        ),
      );

      var rows = await dao.listActiveByLedger('ledger-1');
      expect(rows.map((r) => r.id), ['tx-2', 'tx-1']); // occurred_at DESC
      expect(rows.last.amount, 50.0);

      await dao.softDeleteById(
        'tx-2',
        deletedAt: deleteTs,
        updatedAt: deleteTs,
      );
      rows = await dao.listActiveByLedger('ledger-1');
      expect(rows.map((r) => r.id), ['tx-1']);

      final hardAffected = await dao.hardDeleteById('tx-2');
      expect(hardAffected, 1);

      final remaining = await db.select(db.transactionEntryTable).get();
      expect(remaining.map((r) => r.id), unorderedEquals(['tx-1', 'tx-3']));
    });
  });

  group('BudgetDao', () {
    test('listActiveByLedger / upsert / softDeleteById / hardDeleteById',
        () async {
      await seedLedger('ledger-1');
      await seedLedger('ledger-2');
      final dao = db.budgetDao;

      // ledger-1 总预算 + 餐饮分类预算;ledger-2 一条总预算
      await dao.upsert(
        BudgetTableCompanion.insert(
          id: 'bgt-1',
          ledgerId: 'ledger-1',
          period: 'monthly',
          amount: 3000.0,
          startDate: insertTs,
          updatedAt: insertTs,
          deviceId: 'device-a',
        ),
      );
      await dao.upsert(
        BudgetTableCompanion.insert(
          id: 'bgt-2',
          ledgerId: 'ledger-1',
          period: 'monthly',
          categoryId: const Value('cat-food'),
          amount: 1200.0,
          startDate: insertTs,
          updatedAt: insertTs,
          deviceId: 'device-a',
        ),
      );
      await dao.upsert(
        BudgetTableCompanion.insert(
          id: 'bgt-3',
          ledgerId: 'ledger-2',
          period: 'yearly',
          amount: 50000.0,
          startDate: insertTs,
          updatedAt: insertTs,
          deviceId: 'device-a',
        ),
      );

      // upsert 覆盖 bgt-1:改金额 + 开启 carry_over
      await dao.upsert(
        const BudgetTableCompanion(
          id: Value('bgt-1'),
          ledgerId: Value('ledger-1'),
          period: Value('monthly'),
          amount: Value(3500.0),
          carryOver: Value(1),
          startDate: Value(insertTs),
          updatedAt: Value(updateTs),
          deviceId: Value('device-a'),
        ),
      );

      var rows = await dao.listActiveByLedger('ledger-1');
      expect(rows.map((r) => r.id), unorderedEquals(['bgt-1', 'bgt-2']));
      expect(
        rows.firstWhere((r) => r.id == 'bgt-1').amount,
        3500.0,
      );

      await dao.softDeleteById(
        'bgt-2',
        deletedAt: deleteTs,
        updatedAt: deleteTs,
      );
      rows = await dao.listActiveByLedger('ledger-1');
      expect(rows.map((r) => r.id), ['bgt-1']);

      final hardAffected = await dao.hardDeleteById('bgt-2');
      expect(hardAffected, 1);

      final remaining = await db.select(db.budgetTable).get();
      expect(remaining.map((r) => r.id), unorderedEquals(['bgt-1', 'bgt-3']));
    });
  });
}
