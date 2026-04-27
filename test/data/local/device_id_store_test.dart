import 'package:bianbianbianbian/data/local/app_database.dart';
import 'package:bianbianbianbian/data/local/db_cipher_key_store.dart';
import 'package:bianbianbianbian/data/local/device_id_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Step 1.5 验证：`LocalDeviceIdStore.loadOrCreate()` 的四条路径。
///
/// 覆盖实施计划的三条验收要求：
/// ① 首次启动 `user_pref.device_id` 非空（全新安装分支 + 生成后双写）；
/// ② 冷启动再次读取得到同一个值（secure 生还分支）；
/// ③ 清除应用数据后重新生成一个新值（secure + user_pref 同时空 → 回落生成）。
/// 额外第 4 条断言 secure 存的是"脏值"时不会把脏值当成合法 ID 用。
class _InMemoryStore implements SecureKeyValueStore {
  final Map<String, String> _map = {};

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String value) async {
    _map[key] = value;
  }
}

const _fixedUuidA = '11111111-2222-4333-8444-555555555555';
const _fixedUuidB = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('LocalDeviceIdStore', () {
    test('全新安装：两侧均空 → 生成 UUID 并双写 secure + user_pref', () async {
      final secure = _InMemoryStore();
      var callCount = 0;
      final store = LocalDeviceIdStore(
        db: db,
        storage: secure,
        uuidFactory: () {
          callCount++;
          return _fixedUuidA;
        },
      );

      final id = await store.loadOrCreate();

      expect(id, _fixedUuidA);
      expect(callCount, 1, reason: 'uuidFactory 只应被调用一次');
      expect(
        await secure.read(LocalDeviceIdStore.storageKey),
        _fixedUuidA,
        reason: '生成后必须写回 secure storage',
      );
      final pref = await (db.select(db.userPrefTable)
            ..where((t) => t.id.equals(1)))
          .getSingle();
      expect(pref.deviceId, _fixedUuidA,
          reason: '生成后必须同时写回 user_pref.device_id');
    });

    test('冷启动：secure 已有合法 UUID → 原样返回，不再调 uuidFactory', () async {
      final secure = _InMemoryStore();
      await secure.write(LocalDeviceIdStore.storageKey, _fixedUuidA);
      final store = LocalDeviceIdStore(
        db: db,
        storage: secure,
        uuidFactory: () => fail('已经有合法 UUID 时不应再生成'),
      );

      final first = await store.loadOrCreate();
      final second = await store.loadOrCreate();

      expect(first, _fixedUuidA);
      expect(second, _fixedUuidA);
      // user_pref 在第一次调用时被顺手补写，第二次仍读到同值
      final pref = await (db.select(db.userPrefTable)
            ..where((t) => t.id.equals(1)))
          .getSingle();
      expect(pref.deviceId, _fixedUuidA);
    });

    test('iOS 重装场景：secure 留存但 user_pref 空 → 返回 secure 值并补写 user_pref',
        () async {
      final secure = _InMemoryStore();
      await secure.write(LocalDeviceIdStore.storageKey, _fixedUuidA);
      // user_pref 空（模拟 DB 被清）
      final store = LocalDeviceIdStore(
        db: db,
        storage: secure,
        uuidFactory: () => fail('有可用 secure 值时不应再生成'),
      );

      final id = await store.loadOrCreate();

      expect(id, _fixedUuidA);
      final pref = await (db.select(db.userPrefTable)
            ..where((t) => t.id.equals(1)))
          .getSingle();
      expect(pref.deviceId, _fixedUuidA);
    });

    test('恢复分支：secure 空但 user_pref 已有合法 UUID → 使用 pref 值并回写 secure',
        () async {
      // 预置 user_pref（模拟某种异常：secure 被清但 DB 仍在）
      await db.into(db.userPrefTable).insert(
            UserPrefTableCompanion.insert(deviceId: _fixedUuidB),
          );
      final secure = _InMemoryStore();
      final store = LocalDeviceIdStore(
        db: db,
        storage: secure,
        uuidFactory: () => fail('user_pref 已有合法 UUID 时不应再生成'),
      );

      final id = await store.loadOrCreate();

      expect(id, _fixedUuidB);
      expect(
        await secure.read(LocalDeviceIdStore.storageKey),
        _fixedUuidB,
        reason: '必须把 pref 值同步回 secure，防止下次再走慢路径',
      );
    });

    test('secure 存了非法值 → 视为缺失，继续走 pref/生成 分支', () async {
      final secure = _InMemoryStore();
      await secure.write(LocalDeviceIdStore.storageKey, 'not-a-uuid');
      final store = LocalDeviceIdStore(
        db: db,
        storage: secure,
        uuidFactory: () => _fixedUuidA,
      );

      final id = await store.loadOrCreate();

      expect(id, _fixedUuidA);
      expect(
        await secure.read(LocalDeviceIdStore.storageKey),
        _fixedUuidA,
        reason: '合法新值应覆盖原脏数据',
      );
    });
  });
}
