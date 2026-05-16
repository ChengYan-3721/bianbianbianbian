import 'dart:io';

import 'package:bianbianbianbian/features/sync/attachment/attachment_cache_pruner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 在 [dir] 内建一个 `<txId>/<name>` 文件，写入 [size] 字节，并显式把 mtime
/// 调到 [mtime]。返回写入的 [File] 句柄供进一步断言。
Future<File> _seedFile(
  Directory dir, {
  required String txId,
  required String name,
  required int size,
  required DateTime mtime,
}) async {
  final sub = Directory(p.join(dir.path, txId));
  if (!await sub.exists()) await sub.create(recursive: true);
  final f = File(p.join(sub.path, name));
  await f.writeAsBytes(List<int>.filled(size, 0xAB));
  await f.setLastModified(mtime);
  return f;
}

void main() {
  late Directory tempDir;
  late Directory cacheRoot;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('att_prune_test_');
    cacheRoot = Directory(p.join(tempDir.path, 'attachments'));
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AttachmentCachePruner.currentSize', () {
    test('目录不存在时返回 0', () async {
      final pruner = AttachmentCachePruner(cacheRoot: cacheRoot);
      expect(await pruner.currentSize(), 0);
    });

    test('累加所有子文件大小', () async {
      await cacheRoot.create(recursive: true);
      await _seedFile(
        cacheRoot,
        txId: 'tx-1',
        name: 'a.jpg',
        size: 100,
        mtime: DateTime(2026, 1, 1),
      );
      await _seedFile(
        cacheRoot,
        txId: 'tx-2',
        name: 'b.jpg',
        size: 250,
        mtime: DateTime(2026, 1, 2),
      );
      final pruner = AttachmentCachePruner(cacheRoot: cacheRoot);
      expect(await pruner.currentSize(), 350);
    });
  });

  group('AttachmentCachePruner.prune', () {
    test('未超限时返回 0、不删除文件', () async {
      await cacheRoot.create(recursive: true);
      await _seedFile(
        cacheRoot,
        txId: 'tx-1',
        name: 'a.jpg',
        size: 100,
        mtime: DateTime(2026, 1, 1),
      );
      final pruner = AttachmentCachePruner(
        cacheRoot: cacheRoot,
        limitBytes: 1000,
      );
      final removed = await pruner.prune();
      expect(removed, 0);
      expect(await pruner.currentSize(), 100);
    });

    test('超限时按 mtime 升序淘汰直到回到限额内', () async {
      await cacheRoot.create(recursive: true);
      // 三个文件，总 600 bytes；limit = 250。
      // 应该删除最老的两个（a + b = 400 bytes）保留最新的 c（200 bytes）→ 200 ≤ 250。
      // 但因为 minRetention=7d 守护，所有文件都得在 cutoff 之前才能删——这里用
      // 旧 mtime（now - 30 days）确保都可删。
      final now = DateTime(2026, 5, 1, 12);
      await _seedFile(
        cacheRoot,
        txId: 'tx-old',
        name: 'a.jpg',
        size: 200,
        mtime: now.subtract(const Duration(days: 30)),
      );
      await _seedFile(
        cacheRoot,
        txId: 'tx-mid',
        name: 'b.jpg',
        size: 200,
        mtime: now.subtract(const Duration(days: 20)),
      );
      final newest = await _seedFile(
        cacheRoot,
        txId: 'tx-new',
        name: 'c.jpg',
        size: 200,
        mtime: now.subtract(const Duration(days: 10)),
      );

      final pruner = AttachmentCachePruner(
        cacheRoot: cacheRoot,
        limitBytes: 250,
      );
      final removed = await pruner.prune(now: now);

      expect(removed, 400);
      expect(await pruner.currentSize(), 200);
      expect(await newest.exists(), isTrue);
    });

    test('保留最近 7 天的文件——即便仍超上限也不删', () async {
      await cacheRoot.create(recursive: true);
      final now = DateTime(2026, 5, 1, 12);
      // 三个文件全部在最近 7 天内 → 都受保留期保护；总量 600 bytes、limit=100。
      final f1 = await _seedFile(
        cacheRoot,
        txId: 'tx-1',
        name: 'a.jpg',
        size: 200,
        mtime: now.subtract(const Duration(days: 6)),
      );
      final f2 = await _seedFile(
        cacheRoot,
        txId: 'tx-2',
        name: 'b.jpg',
        size: 200,
        mtime: now.subtract(const Duration(days: 3)),
      );
      final f3 = await _seedFile(
        cacheRoot,
        txId: 'tx-3',
        name: 'c.jpg',
        size: 200,
        mtime: now.subtract(const Duration(days: 1)),
      );

      final pruner = AttachmentCachePruner(
        cacheRoot: cacheRoot,
        limitBytes: 100,
      );
      final removed = await pruner.prune(now: now);

      expect(removed, 0); // 全部受保护
      expect(await f1.exists(), isTrue);
      expect(await f2.exists(), isTrue);
      expect(await f3.exists(), isTrue);
    });

    test('保留期 + 超限混合：只删过期的，保留期内就停手', () async {
      await cacheRoot.create(recursive: true);
      final now = DateTime(2026, 5, 1, 12);
      // 旧的 1 个超期 + 1 个新的；total=400, limit=100。
      // 应该删旧的（300）→ 总量降到 100；不去碰最新的（即便仍 = limit）。
      await _seedFile(
        cacheRoot,
        txId: 'tx-old',
        name: 'a.jpg',
        size: 300,
        mtime: now.subtract(const Duration(days: 30)),
      );
      final newer = await _seedFile(
        cacheRoot,
        txId: 'tx-new',
        name: 'b.jpg',
        size: 100,
        mtime: now.subtract(const Duration(days: 1)),
      );

      final pruner = AttachmentCachePruner(
        cacheRoot: cacheRoot,
        limitBytes: 100,
      );
      final removed = await pruner.prune(now: now);

      expect(removed, 300);
      expect(await newer.exists(), isTrue);
    });
  });

  group('AttachmentCachePruner.clear', () {
    test('整个 cache 目录被删除', () async {
      await cacheRoot.create(recursive: true);
      await _seedFile(
        cacheRoot,
        txId: 'tx-1',
        name: 'a.jpg',
        size: 100,
        mtime: DateTime(2026, 1, 1),
      );
      final pruner = AttachmentCachePruner(cacheRoot: cacheRoot);
      final removed = await pruner.clear();
      expect(removed, 100);
      expect(await cacheRoot.exists(), isFalse);
    });

    test('目录不存在时返回 0', () async {
      final pruner = AttachmentCachePruner(cacheRoot: cacheRoot);
      final removed = await pruner.clear();
      expect(removed, 0);
    });
  });
}
