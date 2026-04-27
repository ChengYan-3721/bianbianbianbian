// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appDatabaseHash() => r'59cce38d45eeaba199eddd097d8e149d66f9f3e1';

/// 本地 drift 数据库的 Riverpod 唯一实例。
///
/// `keepAlive: true` 保证数据库在应用生命周期内只开一次；当 ProviderContainer 被
/// dispose 时（测试结束 / 热重启 / 错误兜底分支）通过 `ref.onDispose` 关闭 DB
/// 连接，释放 isolate + 文件句柄。生产入口（`main.dart`）走 `container.read` 触发
/// 首次构建，间接驱动 [AppDatabase] 的 [LazyDatabase] 打开、SQLCipher `PRAGMA key`
/// 注入与 `PRAGMA cipher_version` 断言——这些在首次真实 SQL 查询（目前由
/// [deviceIdProvider] 内部 `select(userPrefTable)` 触发）之前不会实际发生。
///
/// Copied from [appDatabase].
@ProviderFor(appDatabase)
final appDatabaseProvider = Provider<AppDatabase>.internal(
  appDatabase,
  name: r'appDatabaseProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$appDatabaseHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AppDatabaseRef = ProviderRef<AppDatabase>;
String _$deviceIdHash() => r'aaf273fa0b84390e0e486000903300b00dfecc2a';

/// 当前设备的 `device_id`（UUID v4 字符串）。
///
/// `Future<String>` 而非同步 String，是因为 [LocalDeviceIdStore.loadOrCreate] 涉及
/// `flutter_secure_storage` + drift 查询；首屏布线上应在 `main.dart` 的
/// bootstrap 阶段 `await container.read(deviceIdProvider.future)`，确保 runApp
/// 之前 DB 已打开、device_id 已固定。UI 层日后可直接 `ref.watch(deviceIdProvider)`
/// 得到 `AsyncValue<String>`（`keepAlive: true` 保证值只算一次）。
///
/// Copied from [deviceId].
@ProviderFor(deviceId)
final deviceIdProvider = FutureProvider<String>.internal(
  deviceId,
  name: r'deviceIdProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$deviceIdHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DeviceIdRef = FutureProviderRef<String>;
String _$defaultSeedHash() => r'6b00efb4d088993c794e94552b66e3ba9380039a';

/// 首次启动种子化 gate——链式依赖 [appDatabaseProvider] 打开 DB 与
/// [deviceIdProvider] 初始化 device_id，然后调 [DefaultSeeder.seedIfEmpty]。
///
/// bootstrap 只需 `await container.read(defaultSeedProvider.future)` 一次，
/// 就保证了"DB 已开 → device_id 已固定 → 默认数据已到位（或已检测非空跳过）"
/// 这条完整链。`keepAlive: true` + 只构建一次的幂等实现让后续任何 `watch`
/// 都是 cache hit。
///
/// Copied from [defaultSeed].
@ProviderFor(defaultSeed)
final defaultSeedProvider = FutureProvider<void>.internal(
  defaultSeed,
  name: r'defaultSeedProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$defaultSeedHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DefaultSeedRef = FutureProviderRef<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
