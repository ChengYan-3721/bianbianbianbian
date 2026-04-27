import 'package:bianbianbianbian/data/local/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Step 1.3 验证：6 张业务表的 schema / CRUD 行为。
///
/// 每张实体表（ledger / category / account / transaction_entry / budget）跑
/// 同一套 roundtrip：
///   ① insert（含必填 + 验证默认值回填）
///   ② update 一个普通字段 + `updated_at` 自增
///   ③ soft-delete：写 `deleted_at` 使该行"逻辑已删"但仍物理存在
///
/// `sync_op` 不是实体表（无 updated_at/deleted_at/device_id），按队列语义改为
/// insert（含 AUTOINCREMENT id）→ tried++ → 物理 delete。
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

  group('ledger', () {
    test('insert → update(updated_at) → soft-delete(deleted_at)', () async {
      await db.into(db.ledgerTable).insert(
            LedgerTableCompanion.insert(
              id: 'ledger-1',
              name: '生活',
              coverEmoji: const Value('📒'),
              createdAt: insertTs,
              updatedAt: insertTs,
              deviceId: 'device-a',
            ),
          );

      final row = await (db.select(db.ledgerTable)
            ..where((t) => t.id.equals('ledger-1')))
          .getSingle();
      expect(row.name, '生活');
      expect(row.coverEmoji, '📒');
      expect(row.defaultCurrency, 'CNY');
      expect(row.archived, 0);
      expect(row.createdAt, insertTs);
      expect(row.updatedAt, insertTs);
      expect(row.deletedAt, isNull);
      expect(row.deviceId, 'device-a');

      await (db.update(db.ledgerTable)
            ..where((t) => t.id.equals('ledger-1')))
          .write(
        const LedgerTableCompanion(
          name: Value('工作'),
          updatedAt: Value(updateTs),
        ),
      );
      final updated = await (db.select(db.ledgerTable)
            ..where((t) => t.id.equals('ledger-1')))
          .getSingle();
      expect(updated.name, '工作');
      expect(updated.updatedAt, updateTs);
      expect(updated.deletedAt, isNull);

      await (db.update(db.ledgerTable)
            ..where((t) => t.id.equals('ledger-1')))
          .write(const LedgerTableCompanion(deletedAt: Value(deleteTs)));
      final deleted = await (db.select(db.ledgerTable)
            ..where((t) => t.id.equals('ledger-1')))
          .getSingle();
      expect(deleted.deletedAt, deleteTs);
    });
  });

  group('category', () {
    test('insert → update(updated_at) → soft-delete(deleted_at)', () async {
      await db.into(db.categoryTable).insert(
            CategoryTableCompanion.insert(
              id: 'cat-1',
              parentKey: 'food',
              name: '餐饮',
              icon: const Value('🍜'),
              color: const Value('#FFB7C5'),
              updatedAt: insertTs,
              deviceId: 'device-a',
            ),
          );

      final row = await (db.select(db.categoryTable)
            ..where((t) => t.id.equals('cat-1')))
          .getSingle();
      expect(row.parentKey, 'food');
      expect(row.name, '餐饮');
      expect(row.icon, '🍜');
      expect(row.color, '#FFB7C5');
      expect(row.sortOrder, 0);
      expect(row.isFavorite, 0);
      expect(row.deletedAt, isNull);

      await (db.update(db.categoryTable)
            ..where((t) => t.id.equals('cat-1')))
          .write(
        const CategoryTableCompanion(
          sortOrder: Value(3),
          updatedAt: Value(updateTs),
        ),
      );
      final updated = await (db.select(db.categoryTable)
            ..where((t) => t.id.equals('cat-1')))
          .getSingle();
      expect(updated.sortOrder, 3);
      expect(updated.updatedAt, updateTs);

      await (db.update(db.categoryTable)
            ..where((t) => t.id.equals('cat-1')))
          .write(const CategoryTableCompanion(deletedAt: Value(deleteTs)));
      final deleted = await (db.select(db.categoryTable)
            ..where((t) => t.id.equals('cat-1')))
          .getSingle();
      expect(deleted.deletedAt, deleteTs);
    });
  });

  group('account', () {
    test('insert → update(updated_at) → soft-delete(deleted_at)', () async {
      await db.into(db.accountTable).insert(
            AccountTableCompanion.insert(
              id: 'acc-1',
              name: '招商信用卡',
              type: 'credit',
              icon: const Value('💳'),
              initialBalance: const Value(-1200.0),
              updatedAt: insertTs,
              deviceId: 'device-a',
            ),
          );

      final row = await (db.select(db.accountTable)
            ..where((t) => t.id.equals('acc-1')))
          .getSingle();
      expect(row.name, '招商信用卡');
      expect(row.type, 'credit');
      expect(row.icon, '💳');
      expect(row.initialBalance, -1200.0);
      expect(row.includeInTotal, 1);
      expect(row.currency, 'CNY');
      expect(row.deletedAt, isNull);

      await (db.update(db.accountTable)
            ..where((t) => t.id.equals('acc-1')))
          .write(
        const AccountTableCompanion(
          initialBalance: Value(-800.0),
          updatedAt: Value(updateTs),
        ),
      );
      final updated = await (db.select(db.accountTable)
            ..where((t) => t.id.equals('acc-1')))
          .getSingle();
      expect(updated.initialBalance, -800.0);
      expect(updated.updatedAt, updateTs);

      await (db.update(db.accountTable)
            ..where((t) => t.id.equals('acc-1')))
          .write(const AccountTableCompanion(deletedAt: Value(deleteTs)));
      final deleted = await (db.select(db.accountTable)
            ..where((t) => t.id.equals('acc-1')))
          .getSingle();
      expect(deleted.deletedAt, deleteTs);
    });
  });

  group('transaction_entry', () {
    test('insert → update(updated_at) → soft-delete(deleted_at)', () async {
      await db.into(db.ledgerTable).insert(
            LedgerTableCompanion.insert(
              id: 'ledger-1',
              name: '生活',
              createdAt: insertTs,
              updatedAt: insertTs,
              deviceId: 'device-a',
            ),
          );
      await db.into(db.transactionEntryTable).insert(
            TransactionEntryTableCompanion.insert(
              id: 'tx-1',
              ledgerId: 'ledger-1',
              type: 'expense',
              amount: 42.5,
              currency: 'CNY',
              categoryId: const Value('cat-1'),
              accountId: const Value('acc-1'),
              occurredAt: insertTs,
              tags: const Value('午餐,工作日'),
              updatedAt: insertTs,
              deviceId: 'device-a',
            ),
          );

      final row = await (db.select(db.transactionEntryTable)
            ..where((t) => t.id.equals('tx-1')))
          .getSingle();
      expect(row.type, 'expense');
      expect(row.amount, 42.5);
      expect(row.currency, 'CNY');
      expect(row.fxRate, 1.0);
      expect(row.categoryId, 'cat-1');
      expect(row.accountId, 'acc-1');
      expect(row.toAccountId, isNull);
      expect(row.occurredAt, insertTs);
      expect(row.tags, '午餐,工作日');
      expect(row.noteEncrypted, isNull);
      expect(row.deletedAt, isNull);

      await (db.update(db.transactionEntryTable)
            ..where((t) => t.id.equals('tx-1')))
          .write(
        const TransactionEntryTableCompanion(
          amount: Value(50.0),
          updatedAt: Value(updateTs),
        ),
      );
      final updated = await (db.select(db.transactionEntryTable)
            ..where((t) => t.id.equals('tx-1')))
          .getSingle();
      expect(updated.amount, 50.0);
      expect(updated.updatedAt, updateTs);

      await (db.update(db.transactionEntryTable)
            ..where((t) => t.id.equals('tx-1')))
          .write(
        const TransactionEntryTableCompanion(deletedAt: Value(deleteTs)),
      );
      final deleted = await (db.select(db.transactionEntryTable)
            ..where((t) => t.id.equals('tx-1')))
          .getSingle();
      expect(deleted.deletedAt, deleteTs);
    });

    test('idx_tx_ledger_time / idx_tx_updated 两个索引已创建', () async {
      // 走 sqlite_master 直接验索引存在——这是 §7.1 显式要求的两个索引。
      final result = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'index' "
        "AND tbl_name = 'transaction_entry' AND name NOT LIKE 'sqlite_%'",
      ).get();
      final names = result.map((r) => r.read<String>('name')).toSet();
      expect(names, contains('idx_tx_ledger_time'));
      expect(names, contains('idx_tx_updated'));
    });
  });

  group('budget', () {
    test('insert → update(updated_at) → soft-delete(deleted_at)', () async {
      await db.into(db.budgetTable).insert(
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

      final row = await (db.select(db.budgetTable)
            ..where((t) => t.id.equals('bgt-1')))
          .getSingle();
      expect(row.ledgerId, 'ledger-1');
      expect(row.period, 'monthly');
      expect(row.categoryId, isNull); // null = 总预算
      expect(row.amount, 3000.0);
      expect(row.carryOver, 0);
      expect(row.startDate, insertTs);
      expect(row.deletedAt, isNull);

      await (db.update(db.budgetTable)
            ..where((t) => t.id.equals('bgt-1')))
          .write(
        const BudgetTableCompanion(
          amount: Value(3500.0),
          carryOver: Value(1),
          updatedAt: Value(updateTs),
        ),
      );
      final updated = await (db.select(db.budgetTable)
            ..where((t) => t.id.equals('bgt-1')))
          .getSingle();
      expect(updated.amount, 3500.0);
      expect(updated.carryOver, 1);
      expect(updated.updatedAt, updateTs);

      await (db.update(db.budgetTable)
            ..where((t) => t.id.equals('bgt-1')))
          .write(const BudgetTableCompanion(deletedAt: Value(deleteTs)));
      final deleted = await (db.select(db.budgetTable)
            ..where((t) => t.id.equals('bgt-1')))
          .getSingle();
      expect(deleted.deletedAt, deleteTs);
    });
  });

  group('sync_op', () {
    test('enqueue → tried++ → 物理 delete（队列语义）', () async {
      // 队列无 soft-delete：push 成功后就地物理删除。
      final insertedId = await db.into(db.syncOpTable).insert(
            SyncOpTableCompanion.insert(
              entity: 'transaction',
              entityId: 'tx-1',
              op: 'upsert',
              payload: '{"id":"tx-1","amount":42.5}',
              enqueuedAt: insertTs,
            ),
          );
      expect(insertedId, 1); // AUTOINCREMENT 从 1 起

      final row = await (db.select(db.syncOpTable)
            ..where((t) => t.id.equals(insertedId)))
          .getSingle();
      expect(row.entity, 'transaction');
      expect(row.entityId, 'tx-1');
      expect(row.op, 'upsert');
      expect(row.tried, 0);
      expect(row.lastError, isNull);

      await (db.update(db.syncOpTable)
            ..where((t) => t.id.equals(insertedId)))
          .write(
        const SyncOpTableCompanion(
          tried: Value(1),
          lastError: Value('Network unreachable'),
        ),
      );
      final updated = await (db.select(db.syncOpTable)
            ..where((t) => t.id.equals(insertedId)))
          .getSingle();
      expect(updated.tried, 1);
      expect(updated.lastError, 'Network unreachable');

      final deletedCount = await (db.delete(db.syncOpTable)
            ..where((t) => t.id.equals(insertedId)))
          .go();
      expect(deletedCount, 1);
      final after = await db.select(db.syncOpTable).get();
      expect(after, isEmpty);
    });
  });
}
