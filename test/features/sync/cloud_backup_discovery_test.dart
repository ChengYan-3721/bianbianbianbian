import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bianbianbianbian/domain/entity/account.dart';
import 'package:bianbianbianbian/domain/entity/category.dart';
import 'package:bianbianbianbian/domain/entity/ledger.dart';
import 'package:bianbianbianbian/features/sync/cloud_backup_discovery.dart';
import 'package:bianbianbianbian/features/sync/snapshot_serializer.dart';

/// 覆盖 `discoverBackups`:云端备份枚举与解析。
///
/// 走 `_FakeStorage` 不触达任何真实 backend——目的是验证算法逻辑:
/// - 鉴权后端只扫 `users/<uid>/snapshot.json`(RLS 隔离);
/// - 非鉴权后端先列 `users/` 再逐个找 `snapshot.json`(找回老 deviceId);
/// - 损坏 JSON 跳过不阻塞整体;
/// - 按 snapshot.exportedAt 降序排;
/// - 过滤非 snapshot.json 文件。
void main() {
  group('discoverBackups (auth backend)', () {
    test('单个 snapshot.json 解析为一条 RemoteBackup', () async {
      final exportedAt = DateTime.utc(2026, 5, 1, 12);
      final snap = _multiSnapshot(
        ledgerId: 'L1',
        ledgerName: '生活',
        sourceDeviceId: 'dev-old',
        exportedAt: exportedAt,
      );
      final storage = _FakeStorage(
        listings: {
          'users/uid-A/': [
            _file('users/uid-A/snapshot.json',
                size: 1024, lastModified: exportedAt),
          ],
        },
        downloads: {
          'users/uid-A/snapshot.json':
              await const MultiLedgerSnapshotSerializer().serialize(snap),
        },
      );

      final result = await discoverBackups(storage: storage, authUid: 'uid-A');

      expect(result, hasLength(1));
      final b = result.single;
      expect(b.ledgerId, 'L1');
      expect(b.ledgerName, '生活');
      expect(b.sourceDeviceId, 'dev-old');
      expect(b.cloudPath, 'users/uid-A/snapshot.json');
      expect(b.exportedAt, exportedAt);
      expect(b.transactionCount, 0);
      expect(b.accountCount, 1);
      expect(b.categoryCount, 1);
      expect(b.sizeBytes, 1024);
    });

    test('JSON 解析失败的备份被跳过,不影响其他', () async {
      final t1 = DateTime.utc(2026, 5, 1, 12);
      final t2 = DateTime.utc(2026, 5, 2, 12);
      final goodSnap = _multiSnapshot(ledgerId: 'L1', exportedAt: t1);
      final goodPayload =
          await const MultiLedgerSnapshotSerializer().serialize(goodSnap);
      final storage = _FakeStorage(
        listings: {
          'users/uid-A/': [
            _file('users/uid-A/broken.json',
                size: 10, lastModified: t2),
            _file('users/uid-A/snapshot.json',
                size: 1024, lastModified: t1),
          ],
        },
        downloads: {
          'users/uid-A/broken.json': '{not valid json',
          'users/uid-A/snapshot.json': goodPayload,
        },
      );

      final result = await discoverBackups(storage: storage, authUid: 'uid-A');

      expect(result.map((e) => e.ledgerId), ['L1']);
    });

    test('非 snapshot.json 文件被忽略(下载不会被触发)', () async {
      final exportedAt = DateTime.utc(2026, 5, 1, 12);
      final snap = _multiSnapshot(ledgerId: 'L1', exportedAt: exportedAt);
      final storage = _FakeStorage(
        listings: {
          'users/uid-A/': [
            _file('users/uid-A/.DS_Store', size: 6),
            _file('users/uid-A/snapshot.json',
                size: 1024, lastModified: exportedAt),
          ],
        },
        downloads: {
          'users/uid-A/snapshot.json':
              await const MultiLedgerSnapshotSerializer().serialize(snap),
        },
      );

      final result = await discoverBackups(storage: storage, authUid: 'uid-A');

      expect(result, hasLength(1));
      expect(result.single.cloudPath, 'users/uid-A/snapshot.json');
    });
  });

  group('discoverBackups (非鉴权后端)', () {
    test('先列 users/ 再下钻每个子目录,跨设备前缀全收集', () async {
      final t1 = DateTime.utc(2026, 5, 1, 12);
      final t2 = DateTime.utc(2026, 5, 2, 12);
      final t3 = DateTime.utc(2026, 5, 3, 12);

      final snapA = _multiSnapshot(
        ledgerId: 'L-old',
        ledgerName: '老账本',
        sourceDeviceId: 'dev-A',
        exportedAt: t1,
      );
      final snapB = MultiLedgerSnapshot(
        version: MultiLedgerSnapshot.kVersion,
        exportedAt: t3,
        deviceId: 'dev-B',
        ledgers: [
          _ledgerSnapshot(
            ledgerId: 'L-new1',
            ledgerName: '工作',
            sourceDeviceId: 'dev-B',
            exportedAt: t3,
          ),
          _ledgerSnapshot(
            ledgerId: 'L-new2',
            ledgerName: '副业',
            sourceDeviceId: 'dev-B',
            exportedAt: t2,
          ),
        ],
      );
      final ser = const MultiLedgerSnapshotSerializer();
      final storage = _FakeStorage(
        listings: {
          'users/': [
            _file('users/dev-A/'),
            _file('users/dev-B/'),
          ],
          'users/dev-A/': [
            _file('users/dev-A/snapshot.json',
                size: 100, lastModified: t1),
          ],
          'users/dev-B/': [
            _file('users/dev-B/snapshot.json',
                size: 200, lastModified: t3),
          ],
        },
        downloads: {
          'users/dev-A/snapshot.json': await ser.serialize(snapA),
          'users/dev-B/snapshot.json': await ser.serialize(snapB),
        },
      );

      final result = await discoverBackups(storage: storage, authUid: null);

      // 按 exportedAt 降序:t3 → t1
      expect(result, hasLength(2));
      expect(result[0].sourceDeviceId, 'dev-B');
      expect(result[1].sourceDeviceId, 'dev-A');
      // dev-B 的备份包含 2 个账本
      expect(result[0].ledgers.length, 2);
      expect(result[0].ledgers.map((l) => l.ledgerId).toList(),
          ['L-new1', 'L-new2']);
    });

    test('users/ 下若有 attachments/ 这种非备份子目录,不抛异常', () async {
      final storage = _FakeStorage(
        listings: {
          'users/': [
            _file('users/dev-A/'),
          ],
        },
        downloads: const {},
      );

      final result = await discoverBackups(storage: storage, authUid: null);

      expect(result, isEmpty);
    });

    test('S3 扁平 key:list(users/) 直接返回 snapshot.json 文件,无需二次下钻', () async {
      final t1 = DateTime.utc(2026, 5, 1, 12);
      final t2 = DateTime.utc(2026, 5, 2, 12);
      final snap1 = _multiSnapshot(
        ledgerId: 'L1',
        ledgerName: '生活',
        sourceDeviceId: 'dev-old',
        exportedAt: t1,
      );
      final snap2 = _multiSnapshot(
        ledgerId: 'L2',
        ledgerName: '工作',
        sourceDeviceId: 'dev-old',
        exportedAt: t2,
      );
      final ser = const MultiLedgerSnapshotSerializer();
      final storage = _FakeStorage(
        listings: {
          'users/': [
            _file('users/MyCustom/snapshot.json', size: 111, lastModified: t1),
            _file('users/Other/snapshot.json', size: 222, lastModified: t2),
          ],
        },
        downloads: {
          'users/MyCustom/snapshot.json': await ser.serialize(snap1),
          'users/Other/snapshot.json': await ser.serialize(snap2),
        },
      );

      final result = await discoverBackups(storage: storage, authUid: null);

      expect(result, hasLength(2));
      // 按 exportedAt 降序:t2 → t1
      expect(result.map((e) => e.ledgerId).toList(), ['L2', 'L1']);
      expect(result[0].cloudPath, 'users/Other/snapshot.json');
      expect(result[1].cloudPath, 'users/MyCustom/snapshot.json');
    });

    test('混合形态:list(users/) 同时返回伪目录条目与扁平 snapshot.json key', () async {
      final t1 = DateTime.utc(2026, 5, 1, 12);
      final t2 = DateTime.utc(2026, 5, 2, 12);
      final snap1 = _multiSnapshot(ledgerId: 'L-flat', exportedAt: t1);
      final snap2 = _multiSnapshot(ledgerId: 'L-dir', exportedAt: t2);
      final ser = const MultiLedgerSnapshotSerializer();
      final storage = _FakeStorage(
        listings: {
          'users/': [
            _file('users/flat/snapshot.json', size: 100, lastModified: t1),
            _file('users/dir/'),
          ],
          'users/dir/': [
            _file('users/dir/snapshot.json', size: 200, lastModified: t2),
          ],
        },
        downloads: {
          'users/flat/snapshot.json': await ser.serialize(snap1),
          'users/dir/snapshot.json': await ser.serialize(snap2),
        },
      );

      final result = await discoverBackups(storage: storage, authUid: null);

      expect(result.map((e) => e.ledgerId).toSet(), {'L-flat', 'L-dir'});
    });

    test('顶层 list(users/) 失败时往外抛,不返回空列表', () async {
      final storage = _FakeStorage(
        listings: const {},
        downloads: const {},
      );

      expect(
        () => discoverBackups(storage: storage, authUid: null),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('鉴权后端目录 list 失败时往外抛,不返回空列表', () async {
      final storage = _FakeStorage(
        listings: const {},
        downloads: const {},
      );

      expect(
        () => discoverBackups(storage: storage, authUid: 'uid-A'),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });
}

// ---- 测试夹具 ----------------------------------------------------------------

const _testDeviceId = 'dev-old';

Ledger _ledger({required String id, required String name, required String deviceId}) =>
    Ledger(
      id: id,
      name: name,
      coverEmoji: '📒',
      createdAt: DateTime.utc(2026, 5, 1),
      updatedAt: DateTime.utc(2026, 5, 1),
      deviceId: deviceId,
    );

Category _category(String deviceId) => Category(
      id: 'C1',
      name: '餐饮',
      parentKey: 'food',
      icon: '🍚',
      updatedAt: DateTime.utc(2026, 5, 1),
      deviceId: deviceId,
    );

Account _account(String deviceId) => Account(
      id: 'A1',
      name: '现金',
      type: 'cash',
      icon: '💵',
      updatedAt: DateTime.utc(2026, 5, 1),
      deviceId: deviceId,
    );

LedgerSnapshot _ledgerSnapshot({
  String ledgerId = 'L1',
  String ledgerName = '生活',
  String sourceDeviceId = _testDeviceId,
  required DateTime exportedAt,
}) {
  return LedgerSnapshot(
    version: LedgerSnapshot.kVersion,
    exportedAt: exportedAt,
    deviceId: sourceDeviceId,
    ledger: _ledger(id: ledgerId, name: ledgerName, deviceId: sourceDeviceId),
    categories: [_category(sourceDeviceId)],
    accounts: [_account(sourceDeviceId)],
    transactions: const [],
    budgets: const [],
  );
}

MultiLedgerSnapshot _multiSnapshot({
  String ledgerId = 'L1',
  String ledgerName = '生活',
  String sourceDeviceId = _testDeviceId,
  required DateTime exportedAt,
}) {
  return MultiLedgerSnapshot(
    version: MultiLedgerSnapshot.kVersion,
    exportedAt: exportedAt,
    deviceId: sourceDeviceId,
    ledgers: [
      _ledgerSnapshot(
        ledgerId: ledgerId,
        ledgerName: ledgerName,
        sourceDeviceId: sourceDeviceId,
        exportedAt: exportedAt,
      ),
    ],
  );
}

CloudFile _file(String path,
    {int? size, DateTime? lastModified}) {
  final name = path.split('/').last;
  return CloudFile(
    name: name,
    path: path,
    size: size,
    lastModified: lastModified,
  );
}

/// 只实现 list / download:其它接口在本测试不触达,统一抛 [UnimplementedError]。
class _FakeStorage implements CloudStorageService {
  _FakeStorage({
    required this.listings,
    required this.downloads,
  });

  /// path → 该目录返回的 CloudFile 列表。未配置的 path 抛
  /// [UnimplementedError]——避免无声返回空集合掩盖测试错配。
  final Map<String, List<CloudFile>> listings;

  /// path → JSON 文本。下载未配置 path 时返回 null(对应"云端无此文件")。
  final Map<String, String> downloads;

  @override
  Future<List<CloudFile>> list({required String path}) async {
    final hit = listings[path];
    if (hit == null) {
      throw UnimplementedError('Fake _FakeStorage.list: $path not configured');
    }
    return List.unmodifiable(hit);
  }

  @override
  Future<String?> download({required String path}) async {
    return downloads[path];
  }

  // 下面这些方法本测试用不到——抛 UnimplementedError 是 fail-fast,
  // 让任何意外调用立刻报错。
  @override
  Future<void> upload({
    required String path,
    required String data,
    Map<String, String>? metadata,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> delete({required String path}) async => throw UnimplementedError();

  @override
  Future<bool> exists({required String path}) async => throw UnimplementedError();

  @override
  Future<CloudFile?> getMetadata({required String path}) async =>
      throw UnimplementedError();

  @override
  Future<void> uploadBinary({
    required String path,
    required Uint8List bytes,
    String? contentType,
    Map<String, String>? metadata,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Uint8List?> downloadBinary({required String path}) async =>
      throw UnimplementedError();

  @override
  Future<List<CloudFile>> listBinary({required String prefix}) async =>
      throw UnimplementedError();
}

// `dart:convert` 仅为可能的未来测试预留——保留 import 避免 lint 漂移。
// ignore: unused_element
void _silenceUnusedConvertImport() => jsonEncode(const <String, dynamic>{});