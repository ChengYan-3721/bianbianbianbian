import 'package:uuid/uuid.dart';

import 'app_database.dart';
import 'db_cipher_key_store.dart';

/// `LocalDeviceIdStore` 依赖的 UUID 生成注入点。
/// 生产路径默认走 `const Uuid().v4()`；测试注入确定性工厂以产出可重现结果。
typedef UuidFactory = String Function();

/// 本机设备 ID（UUID v4）的加载/初始化器。
///
/// **优先级**：`flutter_secure_storage` > `user_pref.device_id` > 生成新 UUID。
/// 取到值之后，主动把它**同步写回另一侧**——这是"冗余防丢"（实施计划 Step 1.5 原话）
/// 落地的关键：两侧任一生还即可恢复同一个 device_id，避免同步数据被误判为"新设备"
/// 而产生冗余行或错误的冲突副本。
///
/// 生命周期（按真实重装/清数据场景拆开）：
/// - 🆕 **全新安装**：两侧均空 → 生成新 UUID v4 → 双写 → 返回。
/// - 🔄 **冷启动（正常）**：secure 有合法值 → 直接返回；如果 user_pref 缺失（罕见，
///   多半是测试或损坏场景）就顺手补写。
/// - 🍎 **iOS 重装**：DB 清空但 Keychain 保留 → secure 有值、user_pref 无 →
///   返回 secure 值并写回 user_pref（让同步 push 出去的新库 id 与老设备一致）。
/// - 🤖 **Android 重装 / 清除应用数据**：secure + user_pref 同时空 → 回落到 🆕 生成。
///
/// 密钥命名空间：`local_device_id`，**与 `DbCipherKeyStore.storageKey`
/// (`local_db_cipher_key`) 完全独立**——前者可以被同步/恢复，后者丢失即
/// 本机 DB 永久不可读。两者不要复用。
class LocalDeviceIdStore {
  LocalDeviceIdStore({
    required AppDatabase db,
    SecureKeyValueStore? storage,
    UuidFactory? uuidFactory,
  })  : _db = db,
        _storage = storage ?? const FlutterSecureKeyValueStore(),
        _uuidFactory = uuidFactory ?? _defaultUuid;

  final AppDatabase _db;
  final SecureKeyValueStore _storage;
  final UuidFactory _uuidFactory;

  /// `flutter_secure_storage` 中的条目名，与实施计划 Step 1.5 约定一致。
  static const String storageKey = 'local_device_id';

  /// 8-4-4-4-12 hex 串——大小写均可（`uuid` 包默认输出小写，测试可能注入大写字面量）。
  /// 故意不强制 version=4 / variant 位，因为"从 user_pref 老库恢复"的场景下，
  /// 值可能来自早期实现。只要 256 bit 熵 hex 合法即放行，避免误判导致不必要的重置。
  static final RegExp _uuidLike = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static String _defaultUuid() => const Uuid().v4();

  /// 读取或初始化 device_id。详见类文档的优先级说明。
  Future<String> loadOrCreate() async {
    final fromSecure = await _storage.read(storageKey);
    if (fromSecure != null && _uuidLike.hasMatch(fromSecure)) {
      await _ensureUserPref(fromSecure);
      return fromSecure;
    }

    final fromPref = await _readUserPrefDeviceId();
    if (fromPref != null && _uuidLike.hasMatch(fromPref)) {
      await _storage.write(storageKey, fromPref);
      return fromPref;
    }

    final generated = _uuidFactory();
    await _storage.write(storageKey, generated);
    await _ensureUserPref(generated);
    return generated;
  }

  Future<String?> _readUserPrefDeviceId() async {
    final row = await (_db.select(_db.userPrefTable)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    return row?.deviceId;
  }

  Future<void> _ensureUserPref(String deviceId) async {
    // `insertOnConflictUpdate` 的 UPSERT 路径与 user_pref 的 `CHECK(id=1)` 不兼容：
    // 第二次调用时 INSERT 因 PK 冲突退到 DO UPDATE，但 SQLite 在这条路径上会重新
    // 评估 CHECK——本机已验证会抛 `CHECK constraint failed: id = 1`（哪怕 UPDATE
    // 没动 id 列）。改为显式的"读一次 → 决定 INSERT 还是 UPDATE"，绕开 UPSERT 语法，
    // 同时把 device_id 已一致时的写入也省掉。
    //
    // 单行表 + id 默认 1：`UserPrefTableCompanion.insert(deviceId: ...)` 的 SQL
    // 是 `INSERT INTO user_pref (device_id) VALUES (?)`——SQLite 填 DEFAULT 1、
    // 命中 CHECK(id=1)=true，首次插入合法。
    final existing = await (_db.select(_db.userPrefTable)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    if (existing == null) {
      await _db.into(_db.userPrefTable).insert(
            UserPrefTableCompanion.insert(deviceId: deviceId),
          );
    } else if (existing.deviceId != deviceId) {
      await (_db.update(_db.userPrefTable)..where((t) => t.id.equals(1)))
          .write(UserPrefTableCompanion(deviceId: Value(deviceId)));
    }
  }
}
