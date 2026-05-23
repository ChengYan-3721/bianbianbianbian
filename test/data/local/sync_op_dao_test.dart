import 'package:bianbianbianbian/data/local/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Step 17（云同步 V2）：SyncOpDao 消费侧 API 单元测试。
///
/// 不验 enqueue / listAll 的契约——那些在 repository 测试里已经覆盖；
/// 本文件聚焦 push 路径新增的 [SyncOpDao.listPendingBatch] /
/// [SyncOpDao.markPushed] / [SyncOpDao.incrementTried] /
/// [SyncOpDao.coalesceByEntity]。
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> seedOp({
    required String entity,
    required String entityId,
    String op = 'upsert',
    String payload = '{}',
    int enqueuedAt = 1700000000000,
  }) {
    return db.syncOpDao.enqueue(
      entity: entity,
      entityId: entityId,
      op: op,
      payload: payload,
      enqueuedAt: enqueuedAt,
    );
  }

  group('listPendingBatch', () {
    test('按 id 升序返回（= enqueue 顺序）', () async {
      final id1 = await seedOp(entity: 'ledger', entityId: 'l-1');
      final id2 = await seedOp(entity: 'transaction', entityId: 't-1');
      final id3 = await seedOp(entity: 'category', entityId: 'c-1');

      final batch = await db.syncOpDao.listPendingBatch();
      expect(batch.map((e) => e.id), [id1, id2, id3]);
    });

    test('limit 参数生效', () async {
      for (var i = 0; i < 5; i++) {
        await seedOp(entity: 'transaction', entityId: 't-$i');
      }
      final batch = await db.syncOpDao.listPendingBatch(limit: 3);
      expect(batch, hasLength(3));
    });

    test('过滤 tried >= maxTried（毒丸不阻塞队列）', () async {
      final id1 = await seedOp(entity: 'ledger', entityId: 'l-1');
      final id2 = await seedOp(entity: 'ledger', entityId: 'l-2');
      final id3 = await seedOp(entity: 'ledger', entityId: 'l-3');

      // id2 失败 5 次（达到默认 maxTried=5），应被过滤
      for (var i = 0; i < 5; i++) {
        await db.syncOpDao.incrementTried(id2, 'boom');
      }

      final batch = await db.syncOpDao.listPendingBatch();
      expect(batch.map((e) => e.id), [id1, id3]);
    });

    test('maxTried 可调（自定义阈值）', () async {
      final id1 = await seedOp(entity: 'ledger', entityId: 'l-1');
      await db.syncOpDao.incrementTried(id1, 'err');
      await db.syncOpDao.incrementTried(id1, 'err');

      // 默认 maxTried=5，id1 tried=2 应被取到
      expect(await db.syncOpDao.listPendingBatch(), isNotEmpty);
      // 调成 2 后被过滤
      expect(await db.syncOpDao.listPendingBatch(maxTried: 2), isEmpty);
    });

    test('tried 为 NULL 的历史行也被纳入', () async {
      // enqueue 默认 tried=0;直接 customStatement 模拟"老数据"NULL
      final id = await seedOp(entity: 'ledger', entityId: 'l-1');
      await db.customStatement(
        'UPDATE sync_op SET tried = NULL WHERE id = ?',
        [id],
      );

      final batch = await db.syncOpDao.listPendingBatch();
      expect(batch.map((e) => e.id), [id]);
    });
  });

  group('markPushed', () {
    test('批量删除指定 id', () async {
      final id1 = await seedOp(entity: 'ledger', entityId: 'l-1');
      final id2 = await seedOp(entity: 'ledger', entityId: 'l-2');
      final id3 = await seedOp(entity: 'ledger', entityId: 'l-3');

      await db.syncOpDao.markPushed([id1, id3]);

      final remaining = await db.syncOpDao.listAll();
      expect(remaining.map((e) => e.id), [id2]);
    });

    test('空 list 是 no-op，不报错', () async {
      await seedOp(entity: 'ledger', entityId: 'l-1');
      await db.syncOpDao.markPushed([]);
      expect(await db.syncOpDao.listAll(), hasLength(1));
    });

    test('不存在的 id 不报错', () async {
      await seedOp(entity: 'ledger', entityId: 'l-1');
      await db.syncOpDao.markPushed([9999, 8888]);
      expect(await db.syncOpDao.listAll(), hasLength(1));
    });
  });

  group('incrementTried', () {
    test('tried 累加 + 写入 last_error', () async {
      final id = await seedOp(entity: 'ledger', entityId: 'l-1');

      await db.syncOpDao.incrementTried(id, 'network down');

      final rows = await db.syncOpDao.listAll();
      expect(rows.single.tried, 1);
      expect(rows.single.lastError, 'network down');

      await db.syncOpDao.incrementTried(id, '500 server');
      final rows2 = await db.syncOpDao.listAll();
      expect(rows2.single.tried, 2);
      expect(rows2.single.lastError, '500 server');
    });

    test('NULL tried 自动当 0 处理', () async {
      final id = await seedOp(entity: 'ledger', entityId: 'l-1');
      await db.customStatement(
        'UPDATE sync_op SET tried = NULL WHERE id = ?',
        [id],
      );

      await db.syncOpDao.incrementTried(id, 'err');
      final rows = await db.syncOpDao.listAll();
      expect(rows.single.tried, 1);
    });

    test('error 可传 null（清错误）', () async {
      final id = await seedOp(entity: 'ledger', entityId: 'l-1');
      await db.syncOpDao.incrementTried(id, 'err');
      await db.syncOpDao.incrementTried(id, null);

      final rows = await db.syncOpDao.listAll();
      expect(rows.single.tried, 2);
      expect(rows.single.lastError, isNull);
    });
  });

  group('coalesceByEntity', () {
    test('空列表返回空', () {
      expect(db.syncOpDao.coalesceByEntity(const []), isEmpty);
    });

    test('单条原样返回', () async {
      final id = await seedOp(entity: 'ledger', entityId: 'l-1');
      final raw = await db.syncOpDao.listAll();
      final coalesced = db.syncOpDao.coalesceByEntity(raw);
      expect(coalesced.map((e) => e.id), [id]);
    });

    test('同 (entity, entityId) 多 op 取 id 最大的（最终态）', () async {
      // 用户连续编辑同一笔流水 3 次：3 条 upsert 应只保留最后一条
      await seedOp(entity: 'transaction', entityId: 't-1', payload: '{"v":1}');
      await seedOp(entity: 'transaction', entityId: 't-1', payload: '{"v":2}');
      final lastId =
          await seedOp(entity: 'transaction', entityId: 't-1', payload: '{"v":3}');

      final raw = await db.syncOpDao.listAll();
      final coalesced = db.syncOpDao.coalesceByEntity(raw);
      expect(coalesced, hasLength(1));
      expect(coalesced.single.id, lastId);
      expect(coalesced.single.payload, '{"v":3}');
    });

    test('先 upsert 后 delete：取 delete（最终是删除）', () async {
      await seedOp(
        entity: 'transaction',
        entityId: 't-1',
        op: 'upsert',
        payload: '{"deleted_at":null}',
      );
      final deleteId = await seedOp(
        entity: 'transaction',
        entityId: 't-1',
        op: 'delete',
        payload: '{"deleted_at":12345}',
      );

      final raw = await db.syncOpDao.listAll();
      final coalesced = db.syncOpDao.coalesceByEntity(raw);
      expect(coalesced, hasLength(1));
      expect(coalesced.single.id, deleteId);
      expect(coalesced.single.op, 'delete');
    });

    test('先 delete 后 upsert：取 upsert（即恢复，最终态是存活）', () async {
      await seedOp(
        entity: 'transaction',
        entityId: 't-1',
        op: 'delete',
        payload: '{"deleted_at":12345}',
      );
      final restoreId = await seedOp(
        entity: 'transaction',
        entityId: 't-1',
        op: 'upsert',
        payload: '{"deleted_at":null}',
      );

      final raw = await db.syncOpDao.listAll();
      final coalesced = db.syncOpDao.coalesceByEntity(raw);
      expect(coalesced, hasLength(1));
      expect(coalesced.single.id, restoreId);
      expect(coalesced.single.op, 'upsert');
    });

    test('不同 entityId 互不干扰', () async {
      final id1 = await seedOp(entity: 'transaction', entityId: 't-1');
      final id2 = await seedOp(entity: 'transaction', entityId: 't-2');
      final id3 = await seedOp(entity: 'transaction', entityId: 't-3');

      final raw = await db.syncOpDao.listAll();
      final coalesced = db.syncOpDao.coalesceByEntity(raw);
      expect(coalesced.map((e) => e.id), [id1, id2, id3]);
    });

    test('不同 entity 同 entityId 互不干扰（极少见，验稳健性）', () async {
      // 不同 entity 的 entityId 理论上来自不同 UUID 空间，但本契约要求严格按
      // (entity, entityId) 分组，不能误合并。
      final id1 = await seedOp(entity: 'ledger', entityId: 'same-id');
      final id2 = await seedOp(entity: 'category', entityId: 'same-id');

      final raw = await db.syncOpDao.listAll();
      final coalesced = db.syncOpDao.coalesceByEntity(raw);
      expect(coalesced.map((e) => e.id), [id1, id2]);
    });

    test('输入顺序无关，输出按 id 升序', () async {
      await seedOp(entity: 'ledger', entityId: 'l-1');
      await seedOp(entity: 'ledger', entityId: 'l-2');
      await seedOp(entity: 'ledger', entityId: 'l-3');

      final raw = await db.syncOpDao.listAll();
      // 故意打乱
      final shuffled = [raw[2], raw[0], raw[1]];
      final coalesced = db.syncOpDao.coalesceByEntity(shuffled);
      expect(coalesced.map((e) => e.id), [raw[0].id, raw[1].id, raw[2].id]);
    });

    test('混合：3 entity 各自折叠到最新态', () async {
      // ledger l-1: 2 条 upsert,最终保留第 2 条
      await seedOp(entity: 'ledger', entityId: 'l-1', payload: '{"v":1}');
      final ledgerLast =
          await seedOp(entity: 'ledger', entityId: 'l-1', payload: '{"v":2}');
      // transaction t-1: 1 条
      final txOnly = await seedOp(entity: 'transaction', entityId: 't-1');
      // category c-1: 3 条,最终保留第 3 条
      await seedOp(entity: 'category', entityId: 'c-1');
      await seedOp(entity: 'category', entityId: 'c-1');
      final categoryLast = await seedOp(entity: 'category', entityId: 'c-1');

      final raw = await db.syncOpDao.listAll();
      expect(raw, hasLength(6));

      final coalesced = db.syncOpDao.coalesceByEntity(raw);
      expect(coalesced.map((e) => e.id),
          [ledgerLast, txOnly, categoryLast]..sort());
    });
  });
}
