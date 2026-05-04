import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/providers.dart' as local;
import '../../data/repository/providers.dart' as repo;
import 'snapshot_serializer.dart';
import 'sync_service.dart';

/// Phase 10 sync providers——本文件**不**用 `@riverpod` 代码生成，因为
/// `flutter_cloud_sync` 包对外类型（[CloudServiceConfig] 等）已经稳定，
/// 用普通 `Provider` / `FutureProvider` 写更直观，也避免再产 .g.dart。

/// 云服务配置 store——thin wrapper over SharedPreferences（包内实现）。
final cloudServiceStoreProvider = Provider<CloudServiceStore>((ref) {
  return CloudServiceStore();
});

/// 当前激活的云服务配置——同步与 UI 共享真值源。
///
/// 切换激活后端 / 保存配置后调用 `ref.invalidate(activeCloudConfigProvider)`
/// 即可下游链式重建（[cloudProviderInstanceProvider] / [authServiceProvider] /
/// [syncServiceProvider]）。
final activeCloudConfigProvider =
    FutureProvider<CloudServiceConfig>((ref) async {
  final store = ref.watch(cloudServiceStoreProvider);
  return store.loadActive();
});

/// 各 backend 已保存的配置（即使未激活）——UI 配置对话框预填用。
final supabaseConfigProvider = FutureProvider<CloudServiceConfig?>((ref) async {
  return ref.watch(cloudServiceStoreProvider).loadSupabase();
});

final webdavConfigProvider = FutureProvider<CloudServiceConfig?>((ref) async {
  return ref.watch(cloudServiceStoreProvider).loadWebdav();
});

final s3ConfigProvider = FutureProvider<CloudServiceConfig?>((ref) async {
  return ref.watch(cloudServiceStoreProvider).loadS3();
});

/// 已知"上次连接测试失败"的后端集合——用于 UI 把对应卡片置灰。
/// 保存配置后需手动 `ref.invalidate(cloudFailedBackendsProvider)` 才会刷新，
/// 见 `cloud_service_page._saveConfig`。
final cloudFailedBackendsProvider =
    FutureProvider<Set<CloudBackendType>>((ref) async {
  return ref.watch(cloudServiceStoreProvider).failedBackends();
});

/// 当前激活后端的 [CloudProvider] 实例。
///
/// `local` 或配置无效时返回 null。初始化失败（如 iCloud 未登录）也返回
/// null，让上层走 [LocalOnlySyncService] 兜底——避免抛异常打断 UI。
/// `ref.onDispose` 在 provider 失活时调 `provider.dispose()` 清理连接。
final cloudProviderInstanceProvider =
    FutureProvider<CloudProvider?>((ref) async {
  final config = await ref.watch(activeCloudConfigProvider.future);
  if (!config.valid || config.type == CloudBackendType.local) {
    return null;
  }
  try {
    final services = await createCloudServices(config);
    final provider = services.provider;
    if (provider != null) {
      ref.onDispose(provider.dispose);
    }
    return provider;
  } catch (_) {
    return null;
  }
});

/// 当前 auth service。未激活云服务时返回 [NoopAuthService]。
final authServiceProvider = FutureProvider<CloudAuthService>((ref) async {
  final provider = await ref.watch(cloudProviderInstanceProvider.future);
  return provider?.auth ?? NoopAuthService();
});

/// 当前 sync service：未配置则 [LocalOnlySyncService]，已激活则
/// [SnapshotSyncService]（V1 快照模型）。
///
/// 依赖 5 个 repository provider + appDatabase + deviceId——这些都是
/// `keepAlive: true`，所以重建 sync service 不会导致重复打开 DB。
final syncServiceProvider = FutureProvider<SyncService>((ref) async {
  final cloudProv = await ref.watch(cloudProviderInstanceProvider.future);
  if (cloudProv == null) {
    return const LocalOnlySyncService();
  }

  final db = ref.watch(local.appDatabaseProvider);
  final deviceId = await ref.watch(local.deviceIdProvider.future);
  final ledgerRepo = await ref.watch(repo.ledgerRepositoryProvider.future);
  final categoryRepo = await ref.watch(repo.categoryRepositoryProvider.future);
  final accountRepo = await ref.watch(repo.accountRepositoryProvider.future);
  final transactionRepo =
      await ref.watch(repo.transactionRepositoryProvider.future);
  final budgetRepo = await ref.watch(repo.budgetRepositoryProvider.future);

  final manager = CloudSyncManager<LedgerSnapshot>(
    provider: cloudProv,
    serializer: const LedgerSnapshotSerializer(),
  );

  return SnapshotSyncService(
    manager: manager,
    db: db,
    deviceId: deviceId,
    ledgerRepo: ledgerRepo,
    categoryRepo: categoryRepo,
    accountRepo: accountRepo,
    transactionRepo: transactionRepo,
    budgetRepo: budgetRepo,
  );
});
