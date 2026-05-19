import 'dart:typed_data';

import 'package:bianbianbianbian/data/local/app_database.dart';
import 'package:bianbianbianbian/domain/entity/account.dart';
import 'package:bianbianbianbian/domain/entity/category.dart';
import 'package:bianbianbianbian/domain/entity/ledger.dart';
import 'package:bianbianbianbian/domain/entity/transaction_entry.dart';
import 'package:bianbianbianbian/features/sync/cloud_backup_discovery.dart';
import 'package:bianbianbianbian/features/sync/snapshot_serializer.dart';
import 'package:drift/native.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';

/// 覆盖 [restoreBackupAsNew]:把 [RemoteBackup] 拉回云端 JSON 并以新 ledger
/// 形式落到本地 DB,确保 wiring 正确——download → deserialize → 调
/// [importLedgerSnapshotAsNew]。
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('正常路径:下载 → 导入为新账本,返回新 ledgerId', () async {
    final t = DateTime.utc(2026, 5, 1, 12);
    final snap = LedgerSnapshot(
      version: LedgerSnapshot.kVersion,
      exportedAt: t,
      deviceId: 'dev-old',
      ledger: Ledger(
        id: 'cloud-L',
        name: '云端账本',
        createdAt: t,
        updatedAt: t,
        deviceId: 'dev-old',
      ),
      categories: [
        Category(
          id: 'food',
          name: '餐饮',
          parentKey: 'food',
          updatedAt: t,
          deviceId: 'dev-old',
        ),
      ],
      accounts: [
        Account(
          id: 'cash',
          name: '现金',
          type: 'cash',
          updatedAt: t,
          deviceId: 'dev-old',
        ),
      ],
      transactions: [
        TransactionEntry(
          id: 'cloud-tx',
          ledgerId: 'cloud-L',
          type: 'expense',
          amount: 10,
          currency: 'CNY',
          occurredAt: t,
          updatedAt: t,
          deviceId: 'dev-old',
        ),
      ],
      budgets: const [],
    );
    final serialized = await const LedgerSnapshotSerializer().serialize(snap);
    final storage = _FakeStorage(downloads: {
      'users/dev-old/ledgers/cloud-L.json': serialized,
    });
    final backup = RemoteBackup(
      ledgerId: 'cloud-L',
      ledgerName: '云端账本',
      sourceDeviceId: 'dev-old',
      cloudPath: 'users/dev-old/ledgers/cloud-L.json',
      exportedAt: t,
      transactionCount: 1,
      accountCount: 1,
      categoryCount: 1,
      sizeBytes: 100,
    );

    // 无冲突 → 保留原始 ledgerId 'cloud-L',tx 需要新 UUID
    final newId = await restoreBackupAsNew(
      storage: storage,
      backup: backup,
      db: db,
      uuidFactory: _seq(['new-tx']).next,
      conflictStrategy: null,
    );

    expect(newId, 'cloud-L');
    final txs = await db.select(db.transactionEntryTable).get();
    expect(txs.single.ledgerId, 'cloud-L');
    expect(txs.single.id, 'new-tx');
  });

  test('云端文件已不存在(download 返回 null)抛 StateError', () async {
    final storage = _FakeStorage(downloads: const {});
    final backup = RemoteBackup(
      ledgerId: 'L',
      ledgerName: '账本',
      sourceDeviceId: 'd',
      cloudPath: 'users/d/ledgers/L.json',
      exportedAt: DateTime.utc(2026, 5, 1),
      transactionCount: 0,
      accountCount: 0,
      categoryCount: 0,
    );

    expect(
      () => restoreBackupAsNew(storage: storage, backup: backup, db: db),
      throwsA(isA<StateError>()),
    );
  });
}

class _Seq {
  _Seq(this._values);
  final List<String> _values;
  int _i = 0;
  String next() => _values[_i++];
}

_Seq _seq(List<String> v) => _Seq(v);

class _FakeStorage implements CloudStorageService {
  _FakeStorage({required this.downloads});
  final Map<String, String> downloads;

  @override
  Future<String?> download({required String path}) async => downloads[path];

  // unused but required by interface
  @override
  Future<List<CloudFile>> list({required String path}) async =>
      throw UnimplementedError();

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
