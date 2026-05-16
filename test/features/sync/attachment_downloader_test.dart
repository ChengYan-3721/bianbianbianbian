import 'dart:io';
import 'dart:typed_data';

import 'package:bianbianbianbian/domain/entity/attachment_meta.dart';
import 'package:bianbianbianbian/features/sync/attachment/attachment_downloader.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// In-memory mock CloudStorageService —— 记录 download 调用次数，便于断言。
class _MockStorage implements CloudStorageService {
  final Map<String, Uint8List> store = {};
  final List<String> downloadCalls = [];

  /// 注入：调用 downloadBinary 时延迟 [downloadDelay]，用于并发测试。
  Duration downloadDelay = Duration.zero;

  /// 注入：调用 downloadBinary 时强制抛 [throwOnDownload]（模拟网络错误）。
  bool throwOnDownload = false;

  @override
  Future<Uint8List?> downloadBinary({required String path}) async {
    downloadCalls.add(path);
    if (downloadDelay > Duration.zero) {
      await Future.delayed(downloadDelay);
    }
    if (throwOnDownload) {
      throw CloudStorageException('mock network error');
    }
    return store[path];
  }

  // 不消费的方法
  @override
  Future<void> upload({
    required String path,
    required String data,
    Map<String, String>? metadata,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<String?> download({required String path}) async => null;

  @override
  Future<void> uploadBinary({
    required String path,
    required Uint8List bytes,
    String? contentType,
    Map<String, String>? metadata,
  }) async {
    store[path] = bytes;
  }

  @override
  Future<void> delete({required String path}) async {
    store.remove(path);
  }

  @override
  Future<bool> exists({required String path}) async =>
      store.containsKey(path);

  @override
  Future<List<CloudFile>> list({required String path}) async => const [];

  @override
  Future<List<CloudFile>> listBinary({required String prefix}) async =>
      const [];

  @override
  Future<CloudFile?> getMetadata({required String path}) async => null;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('att_dl_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AttachmentDownloader.ensureLocal', () {
    test('localPath 已存在时直接返回 File，不调 storage', () async {
      // 准备一个真实存在的文件
      final f = File(p.join(tempDir.path, 'cat.jpg'));
      await f.writeAsBytes([1, 2, 3]);

      final storage = _MockStorage();
      final downloader = AttachmentDownloader(
        storage: storage,
        cacheRoot: Directory(p.join(tempDir.path, 'cache')),
      );

      final meta = AttachmentMeta(
        size: 3,
        originalName: 'cat.jpg',
        mime: 'image/jpeg',
        localPath: f.path,
      );
      final result = await downloader.ensureLocal(meta, txId: 'tx-1');

      expect(result, isNotNull);
      expect(result!.path, f.path);
      expect(storage.downloadCalls, isEmpty);
    });

    test('remoteKey == null 且 localPath == null 时直接返回 null', () async {
      final storage = _MockStorage();
      final downloader = AttachmentDownloader(
        storage: storage,
        cacheRoot: Directory(p.join(tempDir.path, 'cache')),
      );

      const meta = AttachmentMeta(
        size: 0,
        originalName: 'lost.jpg',
        mime: 'image/jpeg',
        missing: true,
      );
      final result = await downloader.ensureLocal(meta, txId: 'tx-1');

      expect(result, isNull);
      expect(storage.downloadCalls, isEmpty);
    });

    test('localPath 不存在但 remoteKey 在时下载到 cache 并返回 File', () async {
      final storage = _MockStorage();
      const remoteKey = 'users/u/attachments/tx-1/abc.jpg';
      final bytes = Uint8List.fromList([10, 20, 30, 40]);
      storage.store[remoteKey] = bytes;

      final cacheRoot = Directory(p.join(tempDir.path, 'cache'));
      final downloader = AttachmentDownloader(
        storage: storage,
        cacheRoot: cacheRoot,
      );

      final meta = AttachmentMeta(
        remoteKey: remoteKey,
        sha256: 'abc',
        size: 4,
        originalName: 'photo.jpg',
        mime: 'image/jpeg',
        // 故意指向不存在的本地路径——validates 走下载分支
        localPath: '/nonexistent/dir/does_not_exist.jpg',
      );
      final result = await downloader.ensureLocal(meta, txId: 'tx-1');

      expect(result, isNotNull);
      expect(await result!.readAsBytes(), bytes);
      expect(result.path,
          p.join(cacheRoot.path, 'tx-1', 'abc.jpg'));
      expect(storage.downloadCalls, [remoteKey]);
    });

    test('storage 抛异常时返回 null（不抛异常给 UI）', () async {
      final storage = _MockStorage()..throwOnDownload = true;
      final downloader = AttachmentDownloader(
        storage: storage,
        cacheRoot: Directory(p.join(tempDir.path, 'cache')),
      );

      const meta = AttachmentMeta(
        remoteKey: 'users/u/attachments/tx-1/abc.jpg',
        sha256: 'abc',
        size: 1,
        originalName: 'x.jpg',
        mime: 'image/jpeg',
      );
      final result = await downloader.ensureLocal(meta, txId: 'tx-1');

      expect(result, isNull);
      expect(storage.downloadCalls, hasLength(1));
    });

    test('远端返回 null（404）时返回 null', () async {
      final storage = _MockStorage(); // store 空 → downloadBinary 返回 null
      final downloader = AttachmentDownloader(
        storage: storage,
        cacheRoot: Directory(p.join(tempDir.path, 'cache')),
      );

      const meta = AttachmentMeta(
        remoteKey: 'users/u/attachments/tx-1/missing.jpg',
        sha256: 'mm',
        size: 1,
        originalName: 'missing.jpg',
        mime: 'image/jpeg',
      );
      final result = await downloader.ensureLocal(meta, txId: 'tx-1');

      expect(result, isNull);
      expect(storage.downloadCalls, hasLength(1));
    });

    test('writeback 在下载成功后被调用并接到正确参数', () async {
      final storage = _MockStorage();
      const remoteKey = 'users/u/attachments/tx-1/wb.png';
      final bytes = Uint8List.fromList([1, 2, 3]);
      storage.store[remoteKey] = bytes;

      String? wbTxId;
      String? wbSha256;
      String? wbLocalPath;
      final downloader = AttachmentDownloader(
        storage: storage,
        cacheRoot: Directory(p.join(tempDir.path, 'cache')),
        writeback: ({
          required txId,
          required sha256,
          required localPath,
        }) async {
          wbTxId = txId;
          wbSha256 = sha256;
          wbLocalPath = localPath;
        },
      );

      const meta = AttachmentMeta(
        remoteKey: remoteKey,
        sha256: 'wb',
        size: 3,
        originalName: 'pic.png',
        mime: 'image/png',
      );
      final result = await downloader.ensureLocal(meta, txId: 'tx-1');

      expect(result, isNotNull);
      expect(wbTxId, 'tx-1');
      expect(wbSha256, 'wb');
      expect(wbLocalPath, isNotNull);
      expect(File(wbLocalPath!).existsSync(), isTrue);
    });

    test('writeback 抛异常不影响 ensureLocal 返回 File', () async {
      final storage = _MockStorage();
      const remoteKey = 'users/u/attachments/tx-1/wb.jpg';
      storage.store[remoteKey] = Uint8List.fromList([1, 2, 3]);

      final downloader = AttachmentDownloader(
        storage: storage,
        cacheRoot: Directory(p.join(tempDir.path, 'cache')),
        writeback: ({
          required txId,
          required sha256,
          required localPath,
        }) async {
          throw StateError('mock writeback failure');
        },
      );

      const meta = AttachmentMeta(
        remoteKey: remoteKey,
        sha256: 'wb',
        size: 3,
        originalName: 'x.jpg',
        mime: 'image/jpeg',
      );
      final result = await downloader.ensureLocal(meta, txId: 'tx-1');

      expect(result, isNotNull); // 返回 File，writeback 失败被吞掉
    });

    test('同 (txId, sha256) 第二次调用走内存缓存，不再调 storage', () async {
      final storage = _MockStorage();
      const remoteKey = 'users/u/attachments/tx-1/dup.jpg';
      storage.store[remoteKey] = Uint8List.fromList([7, 8, 9]);

      final downloader = AttachmentDownloader(
        storage: storage,
        cacheRoot: Directory(p.join(tempDir.path, 'cache')),
      );

      const meta = AttachmentMeta(
        remoteKey: remoteKey,
        sha256: 'dup',
        size: 3,
        originalName: 'a.jpg',
        mime: 'image/jpeg',
      );

      final r1 = await downloader.ensureLocal(meta, txId: 'tx-1');
      final r2 = await downloader.ensureLocal(meta, txId: 'tx-1');
      expect(r1!.path, r2!.path);
      // 仅一次实际 download 调用——第二次走 in-memory index
      expect(storage.downloadCalls, hasLength(1));
    });

    test('两个相同 meta 并发 ensureLocal 仅触发一次 download（inflight 复用）', () async {
      final storage = _MockStorage()
        ..downloadDelay = const Duration(milliseconds: 80);
      const remoteKey = 'users/u/attachments/tx-1/concurrent.jpg';
      storage.store[remoteKey] = Uint8List.fromList([1]);

      final downloader = AttachmentDownloader(
        storage: storage,
        cacheRoot: Directory(p.join(tempDir.path, 'cache')),
      );

      const meta = AttachmentMeta(
        remoteKey: remoteKey,
        sha256: 'c',
        size: 1,
        originalName: 'x.jpg',
        mime: 'image/jpeg',
      );
      final futures = await Future.wait([
        downloader.ensureLocal(meta, txId: 'tx-1'),
        downloader.ensureLocal(meta, txId: 'tx-1'),
        downloader.ensureLocal(meta, txId: 'tx-1'),
      ]);

      expect(futures.where((f) => f != null), hasLength(3));
      expect(storage.downloadCalls, hasLength(1));
    });

    test('并发限流：>3 个不同 meta 同时下载时 storage 同时进行的最多 3 个', () async {
      // 注入足够长的下载延时，确保前 3 个还在跑时第 4 个才开始排队。
      final storage = _MockStorage()
        ..downloadDelay = const Duration(milliseconds: 100);
      for (var i = 0; i < 5; i++) {
        storage.store['users/u/attachments/tx-$i/h$i.jpg'] =
            Uint8List.fromList([i]);
      }

      // 用一个观察 wrapper 来记录 in-flight 高水位。
      final probe = _ProbingStorage(storage);
      final downloader = AttachmentDownloader(
        storage: probe,
        cacheRoot: Directory(p.join(tempDir.path, 'cache')),
        maxConcurrent: 3,
      );

      final futures = <Future<File?>>[];
      for (var i = 0; i < 5; i++) {
        futures.add(downloader.ensureLocal(
          AttachmentMeta(
            remoteKey: 'users/u/attachments/tx-$i/h$i.jpg',
            sha256: 'h$i',
            size: 1,
            originalName: 'x.jpg',
            mime: 'image/jpeg',
          ),
          txId: 'tx-$i',
        ));
      }
      await Future.wait(futures);

      expect(probe.maxInFlight, lessThanOrEqualTo(3));
      // 5 个不同 meta 都被下载——只是限流到 3 路并发
      expect(storage.downloadCalls, hasLength(5));
    });
  });
}

/// 包装 _MockStorage 以记录在跑中的 downloadBinary 数量峰值——验证限流。
class _ProbingStorage implements CloudStorageService {
  _ProbingStorage(this._inner);
  final _MockStorage _inner;
  int _running = 0;
  int maxInFlight = 0;

  @override
  Future<Uint8List?> downloadBinary({required String path}) async {
    _running++;
    if (_running > maxInFlight) maxInFlight = _running;
    try {
      return await _inner.downloadBinary(path: path);
    } finally {
      _running--;
    }
  }

  // 透传其他方法（本测试不消费）
  @override
  Future<void> upload({
    required String path,
    required String data,
    Map<String, String>? metadata,
  }) =>
      _inner.upload(path: path, data: data, metadata: metadata);

  @override
  Future<String?> download({required String path}) =>
      _inner.download(path: path);

  @override
  Future<void> uploadBinary({
    required String path,
    required Uint8List bytes,
    String? contentType,
    Map<String, String>? metadata,
  }) =>
      _inner.uploadBinary(
        path: path,
        bytes: bytes,
        contentType: contentType,
        metadata: metadata,
      );

  @override
  Future<void> delete({required String path}) => _inner.delete(path: path);

  @override
  Future<bool> exists({required String path}) => _inner.exists(path: path);

  @override
  Future<List<CloudFile>> list({required String path}) =>
      _inner.list(path: path);

  @override
  Future<List<CloudFile>> listBinary({required String prefix}) =>
      _inner.listBinary(prefix: prefix);

  @override
  Future<CloudFile?> getMetadata({required String path}) =>
      _inner.getMetadata(path: path);
}
