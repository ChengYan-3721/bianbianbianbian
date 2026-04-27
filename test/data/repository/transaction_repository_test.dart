import 'dart:convert';

import 'package:bianbianbianbian/data/local/app_database.dart';
import 'package:bianbianbianbian/data/repository/transaction_repository.dart';
import 'package:bianbianbianbian/domain/entity/transaction_entry.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Step 2.2 验证：TransactionRepository 的 create / update / delete 流程，
/// 重点断言 sync_op 队列变化与返回实体的纯 Dart 类型。
void main() {
  late AppDatabase db;
  late TransactionRepository repo;

  const fixedTs = 1714000000000;
  DateTime fixedClock() => DateTime.fromMillisecondsSinceEpoch(fixedTs);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = LocalTransactionRepository(
      db: db,
      deviceId: 'device-test',
      clock: fixedClock,
    );
    // 种子一个父 ledger
    await db.into(db.ledgerTable).insert(
          LedgerTableCompanion.insert(
            id: 'ledger-1',
            name: '生活',
            createdAt: fixedTs,
            updatedAt: fixedTs,
            deviceId: 'device-seed',
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  test('create → sync_op 入队 upsert', () async {
    final tx = TransactionEntry(
      id: 'tx-1',
      ledgerId: 'ledger-1',
      type: 'expense',
      amount: 42.5,
      currency: 'CNY',
      occurredAt: DateTime.fromMillisecondsSinceEpoch(fixedTs),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0), // 会被 repo 覆写
      deviceId: 'wrong-device', // 会被 repo 覆写
    );

    final saved = await repo.save(tx);

    // 返回实体的 updated_at / device_id 被 repo 覆写
    expect(saved.updatedAt.millisecondsSinceEpoch, fixedTs);
    expect(saved.deviceId, 'device-test');
    expect(saved.amount, 42.5);

    // sync_op 队列应有 1 条 upsert
    final ops = await db.syncOpDao.listAll();
    expect(ops, hasLength(1));
    expect(ops.first.entity, 'transaction');
    expect(ops.first.entityId, 'tx-1');
    expect(ops.first.op, 'upsert');

    final payload = jsonDecode(ops.first.payload) as Map<String, dynamic>;
    expect(payload['id'], 'tx-1');
    expect(payload['amount'], 42.5);
    expect(payload['device_id'], 'device-test');
  });

  test('update → updated_at 变化且 sync_op 再入队一条 upsert', () async {
    var tick = 0;
    DateTime steppedClock() =>
        DateTime.fromMillisecondsSinceEpoch(fixedTs + (tick++));

    final steppedRepo = LocalTransactionRepository(
      db: db,
      deviceId: 'device-test',
      clock: steppedClock,
    );

    final tx1 = TransactionEntry(
      id: 'tx-2',
      ledgerId: 'ledger-1',
      type: 'income',
      amount: 100.0,
      currency: 'CNY',
      occurredAt: DateTime.fromMillisecondsSinceEpoch(fixedTs),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      deviceId: 'wrong-device',
    );
    final saved1 = await steppedRepo.save(tx1);

    // 修改金额后再 save
    final tx2 = tx1.copyWith(amount: 200.0);
    final saved2 = await steppedRepo.save(tx2);

    // 第二次保存 updated_at 必须大于第一次
    expect(saved2.updatedAt.isAfter(saved1.updatedAt), isTrue);

    // sync_op 应有 2 条（都是 upsert，同一 entity_id）
    final ops = await db.syncOpDao.listAll();
    expect(ops, hasLength(2));
    expect(ops.map((o) => o.op), ['upsert', 'upsert']);
    expect(ops.map((o) => o.entityId), ['tx-2', 'tx-2']);

    final payload2 = jsonDecode(ops.last.payload) as Map<String, dynamic>;
    expect(payload2['amount'], 200.0);
    expect(payload2['updated_at'], saved2.updatedAt.toIso8601String());
    expect(payload2['device_id'], 'device-test');
  });

  test('softDeleteById → 首页不可见且库内 deleted_at 非空，并入队 delete', () async {
    final tx = TransactionEntry(
      id: 'tx-3',
      ledgerId: 'ledger-1',
      type: 'expense',
      amount: 30.0,
      currency: 'CNY',
      occurredAt: DateTime.fromMillisecondsSinceEpoch(fixedTs),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(fixedTs),
      deviceId: 'device-test',
    );
    await repo.save(tx);

    await repo.softDeleteById('tx-3');

    // listActive 应查不到（对应首页列表不再展示）
    final active = await repo.listActiveByLedger('ledger-1');
    expect(active, isEmpty);

    // 但库内物理行仍在，且 deleted_at 非空（软删除）
    final row = await (db.select(
      db.transactionEntryTable,
    )..where((t) => t.id.equals('tx-3'))).getSingle();
    expect(row.deletedAt, isNotNull);

    // sync_op 应有 2 条：1 upsert + 1 delete
    final ops = await db.syncOpDao.listAll();
    expect(ops, hasLength(2));
    expect(ops.last.op, 'delete');
    expect(ops.last.entityId, 'tx-3');

    final payload = jsonDecode(ops.last.payload) as Map<String, dynamic>;
    expect(payload['deleted_at'], isNotNull);
    expect(payload['device_id'], 'device-test');
  });

  test('返回实体是纯 Dart 类型（不含 drift 专属类型）', () async {
    final tx = TransactionEntry(
      id: 'tx-4',
      ledgerId: 'ledger-1',
      type: 'transfer',
      accountId: 'acc-out',
      toAccountId: 'acc-in',
      amount: 500.0,
      currency: 'USD',
      fxRate: 7.2,
      occurredAt: DateTime.fromMillisecondsSinceEpoch(fixedTs),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(fixedTs),
      deviceId: 'device-test',
    );

    final saved = await repo.save(tx);

    // 断言类型是领域实体，不是 drift 生成的 Row
    expect(saved, isA<TransactionEntry>());
    expect(saved.runtimeType.toString(), 'TransactionEntry');

    final list = await repo.listActiveByLedger('ledger-1');
    expect(list.first, isA<TransactionEntry>());
  });
}