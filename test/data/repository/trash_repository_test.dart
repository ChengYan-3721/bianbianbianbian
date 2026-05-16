import 'package:bianbianbianbian/data/local/app_database.dart';
import 'package:bianbianbianbian/data/repository/account_repository.dart';
import 'package:bianbianbianbian/data/repository/category_repository.dart';
import 'package:bianbianbianbian/data/repository/ledger_repository.dart';
import 'package:bianbianbianbian/data/repository/transaction_repository.dart';
import 'package:bianbianbianbian/domain/entity/account.dart';
import 'package:bianbianbianbian/domain/entity/category.dart';
import 'package:bianbianbianbian/domain/entity/ledger.dart';
import 'package:bianbianbianbian/domain/entity/transaction_entry.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 12 Step 12.1 + 12.2 + 12.3：垃圾桶相关仓库方法的端到端覆盖。
///
/// 关键不变量：
/// 1. listDeleted 仅返回软删行，按 deleted_at 倒序；
/// 2. restoreById 清 deleted_at + 刷新 updated_at；不存在静默；
/// 3. purgeById 物理删除；不写 sync_op（快照模型走整体覆盖）；
/// 4. purgeAllDeleted 不影响活跃行；
/// 5. listExpired(cutoff) 仅返回 deleted_at <= cutoff；
/// 6. **Ledger 级联恢复**：restoreById 同步把同一时间戳软删的子流水/预算
///    一并恢复，但不误恢复 deletedAt 不同的单独软删项。
/// 7. **Ledger 级联硬删**：purgeById 把该 ledger 下全部流水/预算物理删除。
void main() {
  late AppDatabase db;
  late TransactionRepository txRepo;
  late CategoryRepository catRepo;
  late AccountRepository accRepo;
  late LocalLedgerRepository ledgerRepo;

  // 注入可步进的 clock，让 updated_at 在 restore 后真的发生变化。
  late int currentTs;
  DateTime clock() => DateTime.fromMillisecondsSinceEpoch(currentTs);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    currentTs = 1714000000000;
    txRepo = LocalTransactionRepository(
      db: db,
      deviceId: 'device-test',
      clock: clock,
    );
    catRepo = LocalCategoryRepository(
      db: db,
      deviceId: 'device-test',
      clock: clock,
    );
    accRepo = LocalAccountRepository(
      db: db,
      deviceId: 'device-test',
      clock: clock,
    );
    ledgerRepo = LocalLedgerRepository(
      db: db,
      deviceId: 'device-test',
      clock: clock,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedLedger(String id) async {
    await ledgerRepo.save(Ledger(
      id: id,
      name: '生活$id',
      createdAt: clock(),
      updatedAt: clock(),
      deviceId: 'device-test',
    ));
  }

  Future<TransactionEntry> seedTx(String id, String ledgerId, {double amount = 10}) async {
    return txRepo.save(TransactionEntry(
      id: id,
      ledgerId: ledgerId,
      type: 'expense',
      amount: amount,
      currency: 'CNY',
      occurredAt: clock(),
      updatedAt: clock(),
      deviceId: 'device-test',
    ));
  }

  group('TransactionRepository.listDeleted / restore / purge', () {
    test('listDeleted 仅返回软删行，按 deleted_at 倒序', () async {
      await seedLedger('L1');
      await seedTx('tx-active', 'L1');

      currentTs += 1000;
      await seedTx('tx-old-soft', 'L1');
      currentTs += 1000;
      await seedTx('tx-new-soft', 'L1');

      currentTs += 5000;
      await txRepo.softDeleteById('tx-old-soft');
      currentTs += 1000;
      await txRepo.softDeleteById('tx-new-soft');

      final deleted = await txRepo.listDeleted();
      expect(deleted.map((t) => t.id).toList(), [
        'tx-new-soft',
        'tx-old-soft',
      ]);
    });

    test('restoreById：清 deleted_at + 刷新 updated_at', () async {
      await seedLedger('L1');
      final tx = await seedTx('tx-1', 'L1');
      currentTs += 5000;
      await txRepo.softDeleteById('tx-1');

      final beforeUpdated = (await txRepo.listDeleted()).first.updatedAt;
      currentTs += 7000;
      await txRepo.restoreById('tx-1');

      // listDeleted 不再含它
      expect(await txRepo.listDeleted(), isEmpty);
      // listActiveByLedger 重新可见
      final active = await txRepo.listActiveByLedger('L1');
      expect(active.length, 1);
      expect(active.first.id, 'tx-1');
      expect(active.first.deletedAt, isNull);
      // updated_at 已刷新（更晚于软删时刻）
      expect(active.first.updatedAt.isAfter(beforeUpdated), isTrue);
      // 体积不重要，但 amount 等业务字段保留
      expect(active.first.amount, tx.amount);
    });

    test('restoreById 不存在的 id：静默', () async {
      // await 让 restoreById 完成再让 setUp/tearDown 推进——`returnsNormally`
      // 只看"调用瞬间不抛"，会让 future 在 tearDown 后才触达已关闭的 db。
      await expectLater(txRepo.restoreById('missing'), completes);
    });

    test('purgeById：物理删除（listDeleted 不再返回）', () async {
      await seedLedger('L1');
      await seedTx('tx-1', 'L1');
      await txRepo.softDeleteById('tx-1');

      final affected = await txRepo.purgeById('tx-1');
      expect(affected, 1);
      expect(await txRepo.listDeleted(), isEmpty);
      // 直查表也没了
      final raw = await db.select(db.transactionEntryTable).get();
      expect(raw, isEmpty);
    });

    test('purgeAllDeleted 不影响活跃流水', () async {
      await seedLedger('L1');
      await seedTx('tx-active', 'L1');
      await seedTx('tx-soft-1', 'L1');
      await seedTx('tx-soft-2', 'L1');
      await txRepo.softDeleteById('tx-soft-1');
      await txRepo.softDeleteById('tx-soft-2');

      final affected = await txRepo.purgeAllDeleted();
      expect(affected, 2);
      expect(await txRepo.listDeleted(), isEmpty);
      final active = await txRepo.listActiveByLedger('L1');
      expect(active.length, 1);
      expect(active.first.id, 'tx-active');
    });

    test('listExpired 仅返回 deleted_at <= cutoff', () async {
      await seedLedger('L1');
      await seedTx('old-tx', 'L1');
      await seedTx('new-tx', 'L1');

      // old-tx 在 t=2000 删；new-tx 在 t=10000 删
      currentTs = 2000;
      await txRepo.softDeleteById('old-tx');
      currentTs = 10000;
      await txRepo.softDeleteById('new-tx');

      final cutoff = DateTime.fromMillisecondsSinceEpoch(5000);
      final expired = await txRepo.listExpired(cutoff);
      expect(expired.map((t) => t.id), ['old-tx']);
    });
  });

  group('CategoryRepository / AccountRepository: 基础 trash 路径', () {
    test('Category restoreById 后 listActiveAll 可见', () async {
      final c = await catRepo.save(Category(
        id: 'cat-1',
        parentKey: 'food',
        name: '午餐',
        sortOrder: 0,
        isFavorite: false,
        updatedAt: clock(),
        deviceId: 'device-test',
      ));
      await catRepo.softDeleteById(c.id);
      expect(await catRepo.listActiveAll(), isEmpty);
      expect((await catRepo.listDeleted()).length, 1);

      currentTs += 1000;
      await catRepo.restoreById(c.id);
      expect(await catRepo.listDeleted(), isEmpty);
      expect((await catRepo.listActiveAll()).length, 1);
    });

    test('Account purgeById 物理删除', () async {
      final a = await accRepo.save(Account(
        id: 'acc-1',
        name: '现金',
        type: 'cash',
        initialBalance: 0,
        includeInTotal: true,
        currency: 'CNY',
        updatedAt: clock(),
        deviceId: 'device-test',
      ));
      await accRepo.softDeleteById(a.id);
      final affected = await accRepo.purgeById(a.id);
      expect(affected, 1);
      expect(await accRepo.getById(a.id), isNull);
    });
  });

  group('LedgerRepository: 级联恢复 / 级联硬删', () {
    setUp(() async {
      // 准备两个账本，每个账本下两条流水。
      await seedLedger('L1');
      await seedLedger('L2');

      currentTs += 1000;
      await seedTx('tx-l1-a', 'L1');
      await seedTx('tx-l1-b', 'L1');
      await seedTx('tx-l2-a', 'L2');
    });

    test('级联恢复：账本恢复时仅同时间戳级联软删的子项一起复活', () async {
      // 用户单独软删 tx-l1-a
      currentTs = 5000;
      await txRepo.softDeleteById('tx-l1-a');

      // 之后用户级联软删账本 L1（自身 + tx-l1-b 同时间戳）
      currentTs = 10000;
      await ledgerRepo.softDeleteById('L1');

      // 软删后：L1 的 deleted_at = 10000；tx-l1-a 的 deleted_at = 5000；
      // tx-l1-b 的 deleted_at = 10000。
      var trashedTx = await txRepo.listDeleted();
      expect(trashedTx.map((t) => t.id).toSet(),
          {'tx-l1-a', 'tx-l1-b'});

      // 现在恢复 L1：应该把 tx-l1-b（同时间戳）一起复活，但 tx-l1-a 不动。
      currentTs = 20000;
      await ledgerRepo.restoreById('L1');

      // L1 重新活跃
      final ledgers = await ledgerRepo.listActive();
      expect(ledgers.map((l) => l.id), contains('L1'));
      // tx-l1-b 重新活跃
      final l1Active =
          (await txRepo.listActiveByLedger('L1')).map((t) => t.id).toSet();
      expect(l1Active, {'tx-l1-b'});
      // tx-l1-a 仍在垃圾桶（用户单独删的没被误恢复）
      trashedTx = await txRepo.listDeleted();
      expect(trashedTx.map((t) => t.id), ['tx-l1-a']);
    });

    test('级联硬删：purgeById 物理移除该账本下全部流水/预算（含活跃）', () async {
      // L1 下：tx-l1-a 软删 / tx-l1-b 活跃；L2 下流水不动
      await txRepo.softDeleteById('tx-l1-a');
      // 软删账本本身（这才有资格 purgeById；但 purgeById 不要求 ledger 已软删——
      // 实际 UI 流程总是先软删再永久删，所以这里也走一次）。
      currentTs += 1000;
      await ledgerRepo.softDeleteById('L1');

      currentTs += 5000;
      final affected = await ledgerRepo.purgeById('L1');
      expect(affected, 1);

      // L1 行物理消失
      expect(await ledgerRepo.getById('L1'), isNull);
      // L1 下的所有流水（含已软删 + 级联软删）都被硬删
      final allRows = await db.select(db.transactionEntryTable).get();
      expect(allRows.where((r) => r.ledgerId == 'L1'), isEmpty);
      // L2 下流水保持不变
      final l2 = allRows.where((r) => r.ledgerId == 'L2').toList();
      expect(l2.length, 1);
    });
  });
}
