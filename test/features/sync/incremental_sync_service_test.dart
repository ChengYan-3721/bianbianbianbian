import 'package:bianbianbianbian/data/local/app_database.dart';
import 'package:bianbianbianbian/data/repository/account_repository.dart';
import 'package:bianbianbianbian/data/repository/category_repository.dart';
import 'package:bianbianbianbian/data/repository/ledger_repository.dart';
import 'package:bianbianbianbian/data/repository/transaction_repository.dart';
import 'package:bianbianbianbian/domain/entity/account.dart';
import 'package:bianbianbianbian/domain/entity/category.dart';
import 'package:bianbianbianbian/domain/entity/ledger.dart';
import 'package:bianbianbianbian/domain/entity/transaction_entry.dart';
import 'package:bianbianbianbian/features/sync/incremental_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';

/// Step 17(云同步 V2):IncrementalSyncService 集成测试。
///
/// 测试范围:
/// 1. push: 空云端 + 本地数据 / coalesce / 失败 tried++ / 不阻塞队列;
/// 2. pull: 空本地 + 云端数据 / LWW(三种结局) / 分页;
/// 3. fullPull: 重置游标后再拉一次;
/// 4. 软删传播;
/// 5. getStatus 三态;
/// 6. 不支持的接口方法抛 UnsupportedError。
void main() {
  late AppDatabase db;
  late _FakeGateway gateway;
  late IncrementalSyncService service;
  late TransactionRepository txRepo;
  late LedgerRepository ledgerRepo;
  late CategoryRepository catRepo;
  late AccountRepository accRepo;

  late int currentTs;
  DateTime clock() => DateTime.fromMillisecondsSinceEpoch(currentTs);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    currentTs = 1700000000000;
    gateway = _FakeGateway();
    txRepo = LocalTransactionRepository(
      db: db,
      deviceId: 'device-self',
      clock: clock,
    );
    ledgerRepo = LocalLedgerRepository(
      db: db,
      deviceId: 'device-self',
      clock: clock,
    );
    catRepo = LocalCategoryRepository(
      db: db,
      deviceId: 'device-self',
      clock: clock,
    );
    accRepo = LocalAccountRepository(
      db: db,
      deviceId: 'device-self',
      clock: clock,
    );
    // 必须 seed 一行 user_pref(id=1),才能 update 游标。
    await db.into(db.userPrefTable).insert(
          UserPrefTableCompanion.insert(deviceId: 'device-self'),
        );
    service = IncrementalSyncService(
      gateway: gateway,
      db: db,
      deviceId: 'device-self',
      clock: clock,
    );
  });

  tearDown(() async {
    await db.close();
  });

  // ────────── 测试 helper ──────────

  Future<Ledger> seedLedger(String id, {String name = '默认账本'}) {
    return ledgerRepo.save(Ledger(
      id: id,
      name: name,
      createdAt: clock(),
      updatedAt: clock(),
      deviceId: 'device-self',
    ));
  }

  Future<TransactionEntry> seedTx(
    String id,
    String ledgerId, {
    double amount = 10,
  }) {
    return txRepo.save(TransactionEntry(
      id: id,
      ledgerId: ledgerId,
      type: 'expense',
      amount: amount,
      currency: 'CNY',
      occurredAt: clock(),
      updatedAt: clock(),
      deviceId: 'device-self',
    ));
  }

  /// 构造一行云端 ledger row(bigint timestamps + boolean archived + user_id 字段)。
  Map<String, dynamic> remoteLedger({
    required String id,
    required int updatedAt,
    String name = '云端账本',
    String deviceId = 'device-remote',
    int? deletedAt,
  }) {
    return {
      'id': id,
      'user_id': 'user-self',
      'name': name,
      'cover_emoji': null,
      'cover_svg': null,
      'default_currency': 'CNY',
      'archived': false,
      'created_at': updatedAt,
      'updated_at': updatedAt,
      'deleted_at': deletedAt,
      'device_id': deviceId,
    };
  }

  Map<String, dynamic> remoteTx({
    required String id,
    required String ledgerId,
    required int updatedAt,
    String deviceId = 'device-remote',
    double amount = 99.0,
    int? deletedAt,
  }) {
    return {
      'id': id,
      'user_id': 'user-self',
      'ledger_id': ledgerId,
      'type': 'expense',
      'amount': amount,
      'currency': 'CNY',
      'fx_rate': 1.0,
      'category_id': null,
      'account_id': null,
      'to_account_id': null,
      'occurred_at': updatedAt,
      'note_encrypted': null,
      'attachments_encrypted': null,
      'tags': null,
      'content_hash': null,
      'updated_at': updatedAt,
      'deleted_at': deletedAt,
      'device_id': deviceId,
    };
  }

  // ════════════════════════ push ════════════════════════

  group('push: 队列 → 云端', () {
    test('空云端 + 本地数据 → push 全部', () async {
      await seedLedger('L1', name: '生活');
      currentTs += 1000;
      await seedTx('tx-1', 'L1');

      await service.pushOnly();

      // 云端两张表各 1 行
      expect(gateway.tables['ledger'], hasLength(1));
      expect(gateway.tables['ledger']!.single['id'], 'L1');
      expect(gateway.tables['ledger']!.single['name'], '生活');
      expect(gateway.tables['transaction_entry'], hasLength(1));
      expect(gateway.tables['transaction_entry']!.single['id'], 'tx-1');
      // 日期字段已转 bigint
      expect(gateway.tables['ledger']!.single['updated_at'], isA<int>());
      // 队列清空
      expect(await db.syncOpDao.listAll(), isEmpty);
    });

    test('coalesce:同一行改 3 次 → 仅 push 最新版本', () async {
      final v1 = await seedLedger('L1', name: 'v1');
      currentTs += 100;
      await ledgerRepo.save(v1.copyWith(name: 'v2'));
      currentTs += 100;
      await ledgerRepo.save(v1.copyWith(name: 'v3'));
      expect(await db.syncOpDao.listAll(), hasLength(3));

      await service.pushOnly();

      // upsertBatch 被调用 1 次,内含 1 条最新版本
      final ledgerCalls = gateway.upsertCalls
          .where((c) => c.table == 'ledger')
          .toList();
      expect(ledgerCalls, hasLength(1));
      expect(ledgerCalls.single.data, hasLength(1));
      expect(ledgerCalls.single.data.single['name'], 'v3');
      // 队列彻底清空(3 条 raw 全标 pushed)
      expect(await db.syncOpDao.listAll(), isEmpty);
    });

    test('多 entity 各自分组 upsertBatch', () async {
      await seedLedger('L1');
      currentTs += 10;
      await seedTx('tx-1', 'L1');
      currentTs += 10;
      await catRepo.save(Category(
        id: 'cat-1',
        name: '午餐',
        parentKey: 'food',
        sortOrder: 0,
        isFavorite: false,
        updatedAt: clock(),
        deviceId: 'device-self',
      ));

      await service.pushOnly();

      final byTable = <String, int>{};
      for (final c in gateway.upsertCalls) {
        byTable[c.table] = (byTable[c.table] ?? 0) + 1;
      }
      expect(byTable['ledger'], 1);
      expect(byTable['transaction_entry'], 1);
      expect(byTable['category'], 1);
    });

    test('push 失败 → tried++ 不阻塞其它 entity 队列', () async {
      await seedLedger('L1');
      currentTs += 10;
      await seedTx('tx-1', 'L1');
      gateway.failOnTable = 'ledger';

      // pushOnly 现在会抛出第一个失败的错误，让调用方感知
      await expectLater(
        () => service.pushOnly(),
        throwsA(isA<_FakeCloudException>()),
      );

      // ledger 那条 tried 累加
      final ops = await db.syncOpDao.listAll();
      final ledgerOp = ops.firstWhere((o) => o.entity == 'ledger');
      expect(ledgerOp.tried, 1);
      expect(ledgerOp.lastError, contains('fake fail'));
      // transaction 那条已成功推送 + 清队列
      expect(ops.where((o) => o.entity == 'transaction'), isEmpty);
      expect(gateway.tables['transaction_entry'], hasLength(1));
      expect(gateway.tables['ledger'] ?? const [], isEmpty);
    });

    test('push 失败累计达 maxTried 后, listPendingBatch 自动过滤', () async {
      await seedLedger('L1');
      gateway.failOnTable = 'ledger';

      // 前 5 轮每轮 tried++ 并抛异常；第 6 轮 op 已达 maxTried 被过滤，
      // listPendingBatch 返回空 → pushOnly 不抛异常。
      for (var i = 0; i < 5; i++) {
        await expectLater(
          () => service.pushOnly(),
          throwsA(isA<_FakeCloudException>()),
        );
      }
      // 第 6 轮：op 已被过滤，队列为空，不抛异常
      await service.pushOnly();

      final ops = await db.syncOpDao.listAll();
      // op 仍存在但 tried 达上限,listPendingBatch 不再返回它
      expect(ops, hasLength(1));
      expect(ops.single.tried, greaterThanOrEqualTo(5));
      // 下次 push 不再尝试调用 ledger upsert
      gateway.upsertCalls.clear();
      await service.pushOnly();
      expect(gateway.upsertCalls.where((c) => c.table == 'ledger'), isEmpty);
    });
  });

  // ════════════════════════ pull ════════════════════════

  group('pull: 云端 → 本地', () {
    test('空本地 + 云端有数据 → pull 全部', () async {
      gateway.tables['ledger'] = [remoteLedger(id: 'L1', updatedAt: 1000)];
      gateway.tables['transaction_entry'] = [
        remoteTx(id: 'tx-1', ledgerId: 'L1', updatedAt: 1500),
      ];

      await service.pullThenPush();

      final ledgers = await db.select(db.ledgerTable).get();
      expect(ledgers, hasLength(1));
      expect(ledgers.first.id, 'L1');
      expect(ledgers.first.updatedAt, 1000);
      expect(ledgers.first.deviceId, 'device-remote');
      final txs = await db.select(db.transactionEntryTable).get();
      expect(txs, hasLength(1));
      expect(txs.first.amount, 99.0);
    });

    test('LWW: 本地较新 → 云端旧版不覆盖', () async {
      // 本地 L1, repo 写时 updated_at = currentTs = 1700000000000
      await seedLedger('L1', name: '本地新');
      // 云端 L1, 较老的 updated_at = 1000
      gateway.tables['ledger'] = [
        remoteLedger(id: 'L1', updatedAt: 1000, name: '云端旧'),
      ];

      await service.pullThenPush();

      // 本地保留本地版本
      final local = await db.select(db.ledgerTable).getSingle();
      expect(local.name, '本地新');
      // push 后云端最终也是本地版本(LWW 双向一致)
      expect(gateway.tables['ledger']!.single['name'], '本地新');
    });

    test('LWW: 云端较新 → 覆盖本地', () async {
      await seedLedger('L1', name: '本地旧');
      // 云端 updated_at 设得比 currentTs 大
      gateway.tables['ledger'] = [
        remoteLedger(
          id: 'L1',
          updatedAt: currentTs + 1000,
          name: '云端新',
        ),
      ];

      await service.pullThenPush();

      final local = await db.select(db.ledgerTable).getSingle();
      expect(local.name, '云端新');
      expect(local.deviceId, 'device-remote');
    });

    test('LWW 平手: device_id 字典序大者胜', () async {
      // 本地: device-self (s < z),updated_at = currentTs
      await seedLedger('L1', name: '本地');
      final localUpdatedAt =
          (await db.select(db.ledgerTable).getSingle()).updatedAt;
      // 云端: device-zzz 平手 updated_at,字典序大 → 应覆盖本地
      gateway.tables['ledger'] = [
        remoteLedger(
          id: 'L1',
          updatedAt: localUpdatedAt,
          name: '云端覆盖',
          deviceId: 'device-zzz',
        ),
      ];

      await service.pullThenPush();
      final local = await db.select(db.ledgerTable).getSingle();
      expect(local.name, '云端覆盖');
    });

    test('分页: 云端 1500 行 → 至少跑 2 轮 query', () async {
      // 先 seed 一个本地 ledger 让 transaction.ledgerId 有引用(尽管 V2 无 FK)
      gateway.tables['ledger'] = [remoteLedger(id: 'L1', updatedAt: 1)];
      gateway.tables['transaction_entry'] = List.generate(
        1500,
        (i) => remoteTx(
          id: 'tx-$i',
          ledgerId: 'L1',
          updatedAt: 1000 + i,
        ),
      );

      await service.pullThenPush();

      // transaction_entry 表至少被 query 了 2 次(分页)
      final txQueries = gateway.queryCalls
          .where((c) => c.table == 'transaction_entry')
          .toList();
      expect(txQueries.length, greaterThanOrEqualTo(2));
      // 本地 1500 行全部到位
      expect(
        await db.select(db.transactionEntryTable).get(),
        hasLength(1500),
      );
    });

    test('分页: 云端 2500 行共享同一 updated_at → 仍能拉全(回归 CSV 批量导入卡死 bug)',
        () async {
      // CSV 批量导入场景:同一个 _clock() 毫秒,全部 4000+ 行共用同一 updated_at。
      // 旧实现 pageSince = batchMax + 严格 > 过滤会卡在第一页之后,只拉到 1000。
      gateway.tables['ledger'] = [remoteLedger(id: 'L1', updatedAt: 1)];
      gateway.tables['transaction_entry'] = List.generate(
        2500,
        (i) => remoteTx(
          id: 'tx-${i.toString().padLeft(5, '0')}',
          ledgerId: 'L1',
          updatedAt: 1000, // 全部相同!
        ),
      );

      await service.pullThenPush();

      // 全部 2500 行都到本地
      expect(
        await db.select(db.transactionEntryTable).get(),
        hasLength(2500),
      );
      // 至少 3 次 query(2500 / 1000 = 3 页)
      final txQueries = gateway.queryCalls
          .where((c) => c.table == 'transaction_entry')
          .toList();
      expect(txQueries.length, greaterThanOrEqualTo(3));
      // 验证 offset 单调递增(0 → 1000 → 2000)
      expect(txQueries.map((c) => c.offset).toList(), [0, 1000, 2000]);
    });

    test('游标推进: 第二次 pull 只拉新增', () async {
      // 第一轮: 拉 2 条
      gateway.tables['ledger'] = [
        remoteLedger(id: 'L1', updatedAt: 1000),
        remoteLedger(id: 'L2', updatedAt: 2000),
      ];
      await service.pullThenPush();
      expect(await db.select(db.ledgerTable).get(), hasLength(2));

      // 云端再来一条 updated_at=5000
      gateway.tables['ledger']!.add(remoteLedger(id: 'L3', updatedAt: 5000));
      gateway.queryCalls.clear();

      await service.pullThenPush();

      // ledger 的 query 应该用上次游标 2000 过滤
      final ledgerQueries =
          gateway.queryCalls.where((c) => c.table == 'ledger').toList();
      expect(ledgerQueries, isNotEmpty);
      expect(ledgerQueries.first.updatedAtGt, 2000);
      // 本地拿到 L3
      expect(
        (await db.select(db.ledgerTable).get()).map((r) => r.id).toSet(),
        {'L1', 'L2', 'L3'},
      );
    });
  });

  // ════════════════════════ fullPull ════════════════════════

  group('fullPull', () {
    test('重置游标后再次拉取', () async {
      gateway.tables['ledger'] = [remoteLedger(id: 'L1', updatedAt: 5000)];
      await service.pullThenPush();
      // 第一次 pull 后游标 = 5000
      gateway.queryCalls.clear();

      await service.fullPull();

      // 游标重置 → 用 0 重新 query 一遍
      final ledgerQueries =
          gateway.queryCalls.where((c) => c.table == 'ledger').toList();
      expect(ledgerQueries, isNotEmpty);
      expect(ledgerQueries.first.updatedAtGt, 0);
    });

    test('fullPull 不推进 lastSyncedAt(留给 pullThenPush)', () async {
      gateway.tables['ledger'] = [remoteLedger(id: 'L1', updatedAt: 1000)];
      await service.fullPull();
      final pref = await (db.select(db.userPrefTable)
            ..where((t) => t.id.equals(1)))
          .getSingle();
      expect(pref.lastSyncAt, isNull);
    });
  });

  // ════════════════════════ 软删传播 ════════════════════════

  group('soft delete 传播', () {
    test('本地 softDelete → push 后云端 deleted_at 非 null', () async {
      await seedLedger('L1');
      currentTs += 10;
      await seedTx('tx-1', 'L1');
      await service.pushOnly();
      gateway.upsertCalls.clear();

      currentTs += 1000;
      await txRepo.softDeleteById('tx-1');
      await service.pushOnly();

      final cloudTx =
          gateway.tables['transaction_entry']!.firstWhere((r) => r['id'] == 'tx-1');
      expect(cloudTx['deleted_at'], isNotNull);
    });

    test('云端 deleted_at 非 null → pull 后本地软删', () async {
      // 本地 L1 活跃
      await seedLedger('L1', name: '原始名');
      // 云端 L1 较新且软删
      gateway.tables['ledger'] = [
        remoteLedger(
          id: 'L1',
          updatedAt: currentTs + 5000,
          deletedAt: currentTs + 5000,
          name: '即将删',
        ),
      ];

      await service.pullThenPush();

      final local = await (db.select(db.ledgerTable)
            ..where((t) => t.id.equals('L1')))
          .getSingle();
      expect(local.deletedAt, isNotNull);
    });

    test('restoreById → push 后云端 deleted_at = null', () async {
      await seedLedger('L1');
      await service.pushOnly();
      currentTs += 1000;
      await ledgerRepo.softDeleteById('L1');
      await service.pushOnly();
      expect(
        gateway.tables['ledger']!.single['deleted_at'],
        isNotNull,
      );

      currentTs += 1000;
      await ledgerRepo.restoreById('L1');
      await service.pushOnly();

      expect(gateway.tables['ledger']!.single['deleted_at'], isNull);
    });
  });

  // ════════════════════════ getStatus ════════════════════════

  group('getStatus', () {
    test('队列空 + 从未同步 → localOnly', () async {
      final status = await service.getStatus(ledgerId: 'L1');
      expect(status.state, SyncState.localOnly);
      expect(status.lastSyncedAt, isNull);
    });

    test('队列非空 → outOfSync(localNewer) + localCount', () async {
      await seedLedger('L1');
      currentTs += 10;
      await seedTx('tx-1', 'L1');

      final status = await service.getStatus(ledgerId: 'L1');
      expect(status.state, SyncState.outOfSync);
      expect(status.direction, SyncDirection.localNewer);
      expect(status.localCount, 2);
    });

    test('pullThenPush 完成 + 队列空 → synced + lastSyncedAt', () async {
      gateway.tables['ledger'] = [remoteLedger(id: 'L1', updatedAt: 1000)];
      await service.pullThenPush();
      final status = await service.getStatus(ledgerId: 'L1');
      expect(status.state, SyncState.synced);
      expect(status.lastSyncedAt, isNotNull);
    });
  });

  // ════════════════════════ UnsupportedError ════════════════════════

  group('增量模式不支持的接口', () {
    test('downloadAndRestore', () {
      expect(
        () => service.downloadAndRestore(ledgerId: 'x'),
        throwsA(isA<UnsupportedError>()),
      );
    });
    test('listBackups', () {
      expect(
        () => service.listBackups(),
        throwsA(isA<UnsupportedError>()),
      );
    });
    test('deleteRemote', () {
      expect(
        () => service.deleteRemote(ledgerId: 'x'),
        throwsA(isA<UnsupportedError>()),
      );
    });
    test('checkLedgerNameConflict', () {
      expect(
        () => service.checkLedgerNameConflict('x'),
        throwsA(isA<UnsupportedError>()),
      );
    });
    test('deleteBackupAt', () {
      expect(
        () => service.deleteBackupAt('x'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  // ════════════════════════ Account / Budget 走通 ════════════════════════

  group('Account/Budget 走通 push/pull', () {
    test('Account push 后云端 initial_balance/include_in_total 字段正确', () async {
      await accRepo.save(Account(
        id: 'acc-1',
        name: '现金',
        type: 'cash',
        initialBalance: 100.5,
        includeInTotal: false,
        currency: 'USD',
        updatedAt: clock(),
        deviceId: 'device-self',
      ));
      await service.pushOnly();
      final cloud = gateway.tables['account']!.single;
      expect(cloud['initial_balance'], 100.5);
      // bool 字段经 _entityJsonToCloudRow 转为 int 0/1——Supabase 业务表
      // 的实际列类型是 integer（见 docs/supabase-setup.sql §5），PostgREST
      // 不会自动 bool→int 归一化，发 JSON bool 会被拒绝。
      expect(cloud['include_in_total'], 0);
      expect(cloud['currency'], 'USD');
    });
  });
}

/// In-memory [IncrementalCloudGateway] 模拟云端 5 张表存储。
class _FakeGateway implements IncrementalCloudGateway {
  final Map<String, List<Map<String, dynamic>>> tables = {};
  final List<({String table, List<Map<String, dynamic>> data})> upsertCalls = [];
  final List<({String table, int updatedAtGt, int limit, int offset})> queryCalls = [];

  /// 注入 push 失败模拟: 调用该表的 upsertBatch 时抛异常。
  String? failOnTable;

  @override
  Future<void> upsertBatch({
    required String table,
    required List<Map<String, dynamic>> data,
  }) async {
    upsertCalls.add((table: table, data: data));
    if (table == failOnTable) {
      throw const _FakeCloudException('fake fail');
    }
    final list = tables.putIfAbsent(table, () => []);
    for (final row in data) {
      list.removeWhere((r) => r['id'] == row['id']);
      list.add(Map<String, dynamic>.from(row));
    }
    list.sort((a, b) =>
        (a['updated_at'] as int).compareTo(b['updated_at'] as int));
  }

  @override
  Future<void> deleteAll(String table) async {
    tables.remove(table);
  }

  @override
  Future<void> deleteBatch({
    required String table,
    required List<String> ids,
  }) async {
    final list = tables[table];
    if (list == null) return;
    list.removeWhere((r) => ids.contains(r['id']));
  }

  @override
  Future<List<Map<String, dynamic>>> queryUpdatedSince({
    required String table,
    required int updatedAtGt,
    required int limit,
    int offset = 0,
  }) async {
    queryCalls.add(
      (table: table, updatedAtGt: updatedAtGt, limit: limit, offset: offset),
    );
    final rows = (tables[table] ?? const [])
        .where((r) => (r['updated_at'] as int) > updatedAtGt)
        .toList()
      ..sort((a, b) {
        final cmp =
            (a['updated_at'] as int).compareTo(b['updated_at'] as int);
        if (cmp != 0) return cmp;
        return (a['id'] as String).compareTo(b['id'] as String);
      });
    return rows
        .skip(offset)
        .take(limit)
        .map((r) => Map<String, dynamic>.from(r))
        .toList(growable: false);
  }
}

class _FakeCloudException implements Exception {
  const _FakeCloudException(this.message);
  final String message;
  @override
  String toString() => 'FakeCloudException: $message';
}
