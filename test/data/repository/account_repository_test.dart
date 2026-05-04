import 'dart:convert';

import 'package:bianbianbianbian/data/local/app_database.dart';
import 'package:bianbianbianbian/data/repository/account_repository.dart';
import 'package:bianbianbianbian/domain/entity/account.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Step 7.2 验证：AccountRepository 的 CRUD（getById / save / softDeleteById）
/// 与 sync_op 队列契约。
void main() {
  late AppDatabase db;
  late AccountRepository repo;

  const fixedTs = 1714000000000;
  DateTime fixedClock() => DateTime.fromMillisecondsSinceEpoch(fixedTs);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = LocalAccountRepository(
      db: db,
      deviceId: 'device-test',
      clock: fixedClock,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Account makeAccount({
    String id = 'acc-1',
    String name = '现金',
    String type = 'cash',
    double initialBalance = 0,
    bool includeInTotal = true,
    String? icon,
    int? billingDay,
    int? repaymentDay,
  }) {
    return Account(
      id: id,
      name: name,
      type: type,
      icon: icon,
      initialBalance: initialBalance,
      includeInTotal: includeInTotal,
      currency: 'CNY',
      billingDay: billingDay,
      repaymentDay: repaymentDay,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0), // 会被 repo 覆写
      deviceId: 'wrong-device', // 会被 repo 覆写
    );
  }

  test('save → 写入并入队 sync_op upsert，updated_at/device_id 被覆写', () async {
    final acc = makeAccount(id: 'acc-1', name: '工商卡', type: 'debit');
    final saved = await repo.save(acc);

    expect(saved.id, 'acc-1');
    expect(saved.name, '工商卡');
    expect(saved.deviceId, 'device-test');
    expect(saved.updatedAt.millisecondsSinceEpoch, fixedTs);

    final ops = await db.syncOpDao.listAll();
    expect(ops, hasLength(1));
    expect(ops.first.entity, 'account');
    expect(ops.first.entityId, 'acc-1');
    expect(ops.first.op, 'upsert');

    final payload = jsonDecode(ops.first.payload) as Map<String, dynamic>;
    expect(payload['name'], '工商卡');
    expect(payload['type'], 'debit');
    expect(payload['device_id'], 'device-test');
  });

  test('getById 命中活跃账户', () async {
    await repo.save(makeAccount(id: 'acc-1', name: '现金', type: 'cash'));
    final got = await repo.getById('acc-1');
    expect(got, isNotNull);
    expect(got!.name, '现金');
    expect(got.deletedAt, isNull);
  });

  test('getById 不存在的 id 返回 null', () async {
    final got = await repo.getById('does-not-exist');
    expect(got, isNull);
  });

  test('softDeleteById → listActive 不可见，但 getById 仍能查到（含 deletedAt）',
      () async {
    await repo.save(makeAccount(id: 'acc-1', name: '现金'));

    await repo.softDeleteById('acc-1');

    // listActive 看不到（流水详情 fallback 不依赖 listActive，依赖 getById）。
    final active = await repo.listActive();
    expect(active, isEmpty);

    // 但 getById 能查到——这正是 Step 7.2 流水详情兜底的实现路径。
    final got = await repo.getById('acc-1');
    expect(got, isNotNull);
    expect(got!.deletedAt, isNotNull);
    expect(got.name, '现金'); // 名称仍保留，UI 选择展示"（已删账户）"占位

    // sync_op 应有 1 upsert + 1 delete
    final ops = await db.syncOpDao.listAll();
    expect(ops, hasLength(2));
    expect(ops.last.op, 'delete');
    expect(ops.last.entityId, 'acc-1');
    final payload = jsonDecode(ops.last.payload) as Map<String, dynamic>;
    expect(payload['deleted_at'], isNotNull);
    expect(payload['device_id'], 'device-test');
  });

  test('softDeleteById 不存在的 id 静默跳过（不入队）', () async {
    await repo.softDeleteById('ghost-account');
    final ops = await db.syncOpDao.listAll();
    expect(ops, isEmpty);
  });

  test('save (update) 同 id 二次保存视为更新（id 列只一行）', () async {
    var tick = 0;
    DateTime steppedClock() =>
        DateTime.fromMillisecondsSinceEpoch(fixedTs + (tick++));
    final steppedRepo = LocalAccountRepository(
      db: db,
      deviceId: 'device-test',
      clock: steppedClock,
    );

    final saved1 = await steppedRepo.save(
      makeAccount(id: 'acc-1', name: '现金', initialBalance: 0),
    );
    final saved2 = await steppedRepo.save(
      saved1.copyWith(initialBalance: 1234.5),
    );

    expect(saved2.updatedAt.isAfter(saved1.updatedAt), isTrue);
    expect(saved2.initialBalance, 1234.5);

    // 数据库内只有一行
    final all = await steppedRepo.listActive();
    expect(all, hasLength(1));
    expect(all.first.initialBalance, 1234.5);

    // sync_op 应有 2 条 upsert（同一 entity_id）
    final ops = await db.syncOpDao.listAll();
    expect(ops, hasLength(2));
    expect(ops.map((o) => o.op), ['upsert', 'upsert']);
    expect(ops.map((o) => o.entityId), ['acc-1', 'acc-1']);
  });

  test('返回实体是纯 Dart 类型（不含 drift 专属类型）', () async {
    final acc = makeAccount(id: 'acc-1');
    final saved = await repo.save(acc);
    expect(saved, isA<Account>());
    expect(saved.runtimeType.toString(), 'Account');

    final got = await repo.getById('acc-1');
    expect(got, isA<Account>());
  });

  test('Step 7.3：信用卡 billingDay/repaymentDay 持久化并可读回', () async {
    final card = makeAccount(
      id: 'acc-card',
      name: '招商信用卡',
      type: 'credit',
      initialBalance: -1500,
      billingDay: 5,
      repaymentDay: 22,
    );
    await repo.save(card);

    final got = await repo.getById('acc-card');
    expect(got, isNotNull);
    expect(got!.type, 'credit');
    expect(got.billingDay, 5);
    expect(got.repaymentDay, 22);

    // sync_op payload 也应携带新字段
    final ops = await db.syncOpDao.listAll();
    expect(ops, hasLength(1));
    final payload = jsonDecode(ops.first.payload) as Map<String, dynamic>;
    expect(payload['billing_day'], 5);
    expect(payload['repayment_day'], 22);
  });

  test('Step 7.3：非信用卡保存时 billingDay/repaymentDay 为 null（即使被传入）',
      () async {
    // UI 层会按 type 清空字段并写 null，仓库不做强制；这里覆盖"按规范写入 null"的路径。
    final cash = makeAccount(
      id: 'acc-cash',
      name: '现金',
      type: 'cash',
    );
    await repo.save(cash);
    final got = await repo.getById('acc-cash');
    expect(got, isNotNull);
    expect(got!.billingDay, isNull);
    expect(got.repaymentDay, isNull);
  });
}
