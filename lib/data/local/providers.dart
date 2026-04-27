import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_database.dart';
import 'device_id_store.dart';
import 'seeder.dart';

part 'providers.g.dart';

/// 本地 drift 数据库的 Riverpod 唯一实例。
///
/// `keepAlive: true` 保证数据库在应用生命周期内只开一次；当 ProviderContainer 被
/// dispose 时（测试结束 / 热重启 / 错误兜底分支）通过 `ref.onDispose` 关闭 DB
/// 连接，释放 isolate + 文件句柄。生产入口（`main.dart`）走 `container.read` 触发
/// 首次构建，间接驱动 [AppDatabase] 的 [LazyDatabase] 打开、SQLCipher `PRAGMA key`
/// 注入与 `PRAGMA cipher_version` 断言——这些在首次真实 SQL 查询（目前由
/// [deviceIdProvider] 内部 `select(userPrefTable)` 触发）之前不会实际发生。
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}

/// 当前设备的 `device_id`（UUID v4 字符串）。
///
/// `Future<String>` 而非同步 String，是因为 [LocalDeviceIdStore.loadOrCreate] 涉及
/// `flutter_secure_storage` + drift 查询；首屏布线上应在 `main.dart` 的
/// bootstrap 阶段 `await container.read(deviceIdProvider.future)`，确保 runApp
/// 之前 DB 已打开、device_id 已固定。UI 层日后可直接 `ref.watch(deviceIdProvider)`
/// 得到 `AsyncValue<String>`（`keepAlive: true` 保证值只算一次）。
@Riverpod(keepAlive: true)
Future<String> deviceId(Ref ref) async {
  final db = ref.watch(appDatabaseProvider);
  final store = LocalDeviceIdStore(db: db);
  return store.loadOrCreate();
}

/// 首次启动种子化 gate——链式依赖 [appDatabaseProvider] 打开 DB 与
/// [deviceIdProvider] 初始化 device_id，然后调 [DefaultSeeder.seedIfEmpty]。
///
/// bootstrap 只需 `await container.read(defaultSeedProvider.future)` 一次，
/// 就保证了"DB 已开 → device_id 已固定 → 默认数据已到位（或已检测非空跳过）"
/// 这条完整链。`keepAlive: true` + 只构建一次的幂等实现让后续任何 `watch`
/// 都是 cache hit。
@Riverpod(keepAlive: true)
Future<void> defaultSeed(Ref ref) async {
  final db = ref.watch(appDatabaseProvider);
  final deviceId = await ref.watch(deviceIdProvider.future);
  final seeder = DefaultSeeder(db: db, deviceId: deviceId);
  await seeder.seedIfEmpty();
}
