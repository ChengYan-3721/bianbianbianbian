import 'dart:convert';

import 'package:bianbianbianbian/data/local/app_database.dart';
import 'package:bianbianbianbian/domain/entity/account.dart';
import 'package:bianbianbianbian/features/account/account_save_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late AccountSaveService service;

  final fixedNow = DateTime(2026, 5, 24, 10, 30);

  Account account({
    String id = 'acc-1',
    String name = 'Cash',
    String currency = 'CNY',
  }) {
    return Account(
      id: id,
      name: name,
      type: 'cash',
      currency: currency,
      updatedAt: DateTime(2000),
      deviceId: 'wrong-device',
    );
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = AccountSaveService(
      db: db,
      deviceId: 'device-test',
      clock: () => fixedNow,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'saving account without balance change does not create transaction',
    () async {
      final saved = await service.save(
        account: account(),
        ledgerId: 'ledger-1',
        oldBalance: 0,
        newBalance: 0,
        adjustmentNote: '余额调整',
      );

      expect(saved.deviceId, 'device-test');
      expect(saved.updatedAt, fixedNow);
      expect(await db.select(db.accountTable).get(), hasLength(1));
      expect(await db.select(db.transactionEntryTable).get(), isEmpty);

      final ops = await db.syncOpDao.listAll();
      expect(ops, hasLength(1));
      expect(ops.single.entity, 'account');
    },
  );

  test('increasing balance creates uncategorized income adjustment', () async {
    await service.save(
      account: account(currency: 'USD'),
      ledgerId: 'ledger-1',
      oldBalance: 100,
      newBalance: 150,
      adjustmentNote: '余额调整',
    );

    final tx = (await db.select(db.transactionEntryTable).get()).single;
    expect(tx.ledgerId, 'ledger-1');
    expect(tx.type, 'income');
    expect(tx.amount, 50);
    expect(tx.currency, 'USD');
    expect(tx.accountId, 'acc-1');
    expect(tx.categoryId, isNull);
    expect(tx.toAccountId, isNull);
    expect(tx.tags, '余额调整');

    final ops = await db.syncOpDao.listAll();
    expect(ops.map((o) => o.entity).toList(), ['account', 'transaction']);
    final txPayload = jsonDecode(ops.last.payload) as Map<String, dynamic>;
    expect(txPayload['type'], 'income');
    expect(txPayload['category_id'], isNull);
    expect(txPayload['tags'], '余额调整');
  });

  test('decreasing balance creates uncategorized expense adjustment', () async {
    await service.save(
      account: account(),
      ledgerId: 'ledger-1',
      oldBalance: 100,
      newBalance: 80,
      adjustmentNote: '余额调整',
    );

    final tx = (await db.select(db.transactionEntryTable).get()).single;
    expect(tx.type, 'expense');
    expect(tx.amount, 20);
    expect(tx.categoryId, isNull);
    expect(tx.tags, '余额调整');
  });

  test('new negative balance creates expense from zero baseline', () async {
    await service.save(
      account: account(id: 'acc-card'),
      ledgerId: 'ledger-1',
      oldBalance: 0,
      newBalance: -300,
      adjustmentNote: '余额调整',
    );

    final tx = (await db.select(db.transactionEntryTable).get()).single;
    expect(tx.type, 'expense');
    expect(tx.amount, 300);
    expect(tx.accountId, 'acc-card');
  });
}
