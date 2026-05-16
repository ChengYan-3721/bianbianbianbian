import 'dart:typed_data';

import 'package:bianbianbianbian/domain/entity/attachment_meta.dart';
import 'package:bianbianbianbian/features/sync/attachment/attachment_uploader.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory mock —— 记录所有 uploadBinary 调用 + exists 查询，便于断言。
class _MockStorage implements CloudStorageService {
  final Map<String, Uint8List> store = {};
  final List<String> uploadCalls = [];
  final List<String> existsCalls = [];

  /// 注入「单条上传强制失败一次」的开关——验证错误隔离。
  String? failOnPath;

  @override
  Future<void> uploadBinary({
    required String path,
    required Uint8List bytes,
    String? contentType,
    Map<String, String>? metadata,
  }) async {
    uploadCalls.add(path);
    if (path == failOnPath) {
      throw CloudStorageException('mock failure');
    }
    store[path] = bytes;
  }

  @override
  Future<bool> exists({required String path}) async {
    existsCalls.add(path);
    return store.containsKey(path);
  }

  // 以下方法本测试不调用，简单实现即可。
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
  Future<Uint8List?> downloadBinary({required String path}) async =>
      store[path];

  @override
  Future<void> delete({required String path}) async {
    store.remove(path);
  }

  @override
  Future<List<CloudFile>> list({required String path}) async => const [];

  @override
  Future<List<CloudFile>> listBinary({required String prefix}) async => const [];

  @override
  Future<CloudFile?> getMetadata({required String path}) async => null;
}

void main() {
  group('AttachmentUploader.uploadPending', () {
    test('remoteKey 已填的 meta 原样透传，不调 uploadBinary', () async {
      final storage = _MockStorage();
      final uploader = AttachmentUploader(
        storage: storage,
        readBytes: (_) async => Uint8List.fromList([1, 2, 3]),
      );

      final meta = AttachmentMeta(
        remoteKey: 'users/u/attachments/t/h.jpg',
        sha256: 'a' * 64,
        size: 3,
        originalName: 'h.jpg',
        mime: 'image/jpeg',
        localPath: '/local/h.jpg',
      );
      final result = await uploader.uploadPending(
        [meta],
        txId: 'tx-1',
        uid: 'u',
      );
      expect(result, [meta]);
      expect(storage.uploadCalls, isEmpty);
    });

    test('多个相同内容（同 sha256）的文件去重——同 path 命中 exists 后只上传一次', () async {
      final storage = _MockStorage();
      // 两个 meta 指向相同字节内容，sha256 相同 → path 相同
      final bytes = Uint8List.fromList([1, 2, 3]);
      final uploader = AttachmentUploader(
        storage: storage,
        readBytes: (_) async => bytes,
      );

      const m1 = AttachmentMeta(
        size: 3,
        originalName: 'a.jpg',
        mime: 'image/jpeg',
        localPath: '/local/a.jpg',
      );
      const m2 = AttachmentMeta(
        size: 3,
        originalName: 'b.jpg',
        mime: 'image/jpeg',
        localPath: '/local/b.jpg',
      );

      final result = await uploader.uploadPending(
        const [m1, m2],
        txId: 'tx-1',
        uid: 'u',
      );

      expect(result, hasLength(2));
      // 两个都有同一 remoteKey（同 sha256）
      expect(result[0].remoteKey, isNotNull);
      expect(result[1].remoteKey, isNotNull);
      expect(result[0].remoteKey, result[1].remoteKey);
      expect(result[0].sha256, result[1].sha256);
      // 第一次 uploadBinary，第二次因 exists 命中跳过
      expect(storage.uploadCalls, hasLength(1));
      expect(storage.existsCalls, hasLength(2));
    });

    test('单条失败不影响其他——失败的 meta remoteKey 仍 null', () async {
      final storage = _MockStorage();

      // 注入「第二条失败」——通过精准失败 path 控制。
      // 我们事先不知道 hash 的 path，所以让 storage 总是失败，单测两条 meta
      // 一条用注入失败 path，一条无：用两个 mock 更易控制。
      final byteMap = {
        '/local/a.jpg': Uint8List.fromList([1, 2, 3]),
        '/local/b.jpg': Uint8List.fromList([4, 5, 6]),
      };
      // 计算 b 的 sha256 来做失败匹配。
      final uploader = AttachmentUploader(
        storage: storage,
        readBytes: (path) async => byteMap[path]!,
      );

      // Phase 1: 先跑一次拿到 b 的真实 path，然后清状态注入失败再跑。
      const m1 = AttachmentMeta(
        size: 3,
        originalName: 'a.jpg',
        mime: 'image/jpeg',
        localPath: '/local/a.jpg',
      );
      const m2 = AttachmentMeta(
        size: 3,
        originalName: 'b.jpg',
        mime: 'image/jpeg',
        localPath: '/local/b.jpg',
      );

      final probe = await uploader.uploadPending(
        const [m2],
        txId: 'tx-1',
        uid: 'u',
      );
      final bPath = probe.first.remoteKey;
      expect(bPath, isNotNull);

      // 重置 storage 并注入 b 失败。
      final storage2 = _MockStorage()..failOnPath = bPath;
      final uploader2 = AttachmentUploader(
        storage: storage2,
        readBytes: (path) async => byteMap[path]!,
      );

      final result = await uploader2.uploadPending(
        const [m1, m2],
        txId: 'tx-1',
        uid: 'u',
      );

      expect(result, hasLength(2));
      // a 成功
      expect(result[0].remoteKey, isNotNull);
      expect(result[0].sha256, isNotNull);
      // b 失败 → 原样返回
      expect(result[1].remoteKey, isNull);
      expect(result[1].sha256, isNull);
      // 两次都尝试上传过（exists 不命中）
      expect(storage2.uploadCalls, hasLength(2));
    });

    test('localPath 为 null 时跳过上传，原样返回', () async {
      final storage = _MockStorage();
      final uploader = AttachmentUploader(
        storage: storage,
        readBytes: (_) async => Uint8List(0),
      );
      const meta = AttachmentMeta(
        size: 0,
        originalName: 'lost.jpg',
        mime: 'image/jpeg',
        missing: true,
      );
      final result = await uploader.uploadPending(
        const [meta],
        txId: 'tx-1',
        uid: 'u',
      );
      expect(result, [meta]);
      expect(storage.uploadCalls, isEmpty);
    });

    test('远端路径模式：users/<uid>/attachments/<txId>/<sha256><ext>', () async {
      final storage = _MockStorage();
      final uploader = AttachmentUploader(
        storage: storage,
        readBytes: (_) async => Uint8List.fromList([1, 2, 3]),
      );
      const meta = AttachmentMeta(
        size: 3,
        originalName: 'photo.png',
        mime: 'image/png',
        localPath: '/local/photo.png',
      );
      final result = await uploader.uploadPending(
        const [meta],
        txId: 'tx-abc',
        uid: 'user-xyz',
      );
      final remoteKey = result.first.remoteKey!;
      expect(remoteKey, startsWith('users/user-xyz/attachments/tx-abc/'));
      expect(remoteKey, endsWith('.png'));
    });
  });
}
