import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_cloud_sync_supabase/flutter_cloud_sync_supabase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/providers.dart' as local;
import '../../data/repository/providers.dart' as repo;
import 'incremental_sync_service.dart';
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

/// 当前 sync service:按 backend 类型分发。
///
/// - 未配置或初始化失败 → [LocalOnlySyncService];
/// - **Supabase**(Step 17 / 云同步 V2):[IncrementalSyncService] —— 按行
///   增量同步整库(5 张云端表),走 `sync_op` 队列 + LWW;
/// - 其它后端(S3 / WebDAV / iCloud / BeeCount-Cloud):[SnapshotSyncService]
///   —— V1 整库 JSON 快照,按账本上传/下载。
///
/// 三个 service 实现共存的理由:Supabase 有真鉴权 + RLS + Postgres,适合做
/// 增量;其它后端只有对象存储,做不了 per-row LWW(每个 column 当 key 显然
/// 不现实),保留 V1 快照模型最稳。
///
/// 依赖 5 个 repository provider + appDatabase + deviceId——这些都是
/// `keepAlive: true`,所以重建 sync service 不会导致重复打开 DB。Supabase
/// 路径不读 repo provider(增量 service 直接走 db),仅 V1 分支需要。
final syncServiceProvider = FutureProvider<SyncService>((ref) async {
  final cloudProv = await ref.watch(cloudProviderInstanceProvider.future);
  if (cloudProv == null) {
    return const LocalOnlySyncService();
  }

  final config = await ref.watch(activeCloudConfigProvider.future);
  final db = ref.watch(local.appDatabaseProvider);
  final deviceId = await ref.watch(local.deviceIdProvider.future);

  // Step 17(云同步 V2):Supabase 走增量同步。
  if (config.type == CloudBackendType.supabase) {
    final dbSvc =
        (cloudProv as SupabaseProvider).databaseService
            as SupabaseDatabaseService?;
    if (dbSvc == null) {
      // 理论上 cloudProviderInstanceProvider 初始化成功就一定有 databaseService;
      // 兜底走 local-only 避免 UI 抛异常。
      return const LocalOnlySyncService();
    }
    return IncrementalSyncService(
      gateway: SupabaseIncrementalGateway(dbSvc),
      db: db,
      deviceId: deviceId,
    );
  }

  // V1 快照路径:S3 / WebDAV / iCloud / BeeCount-Cloud。
  final ledgerRepo = await ref.watch(repo.ledgerRepositoryProvider.future);
  final categoryRepo = await ref.watch(repo.categoryRepositoryProvider.future);
  final accountRepo = await ref.watch(repo.accountRepositoryProvider.future);
  final transactionRepo =
      await ref.watch(repo.transactionRepositoryProvider.future);
  final budgetRepo = await ref.watch(repo.budgetRepositoryProvider.future);

  final manager = CloudSyncManager<MultiLedgerSnapshot>(
    provider: cloudProv,
    serializer: const MultiLedgerSnapshotSerializer(),
  );

  return SnapshotSyncService(
    manager: manager,
    db: db,
    deviceId: deviceId,
    backendType: config.type,
    ledgerRepo: ledgerRepo,
    categoryRepo: categoryRepo,
    accountRepo: accountRepo,
    transactionRepo: transactionRepo,
    budgetRepo: budgetRepo,
  );
});
