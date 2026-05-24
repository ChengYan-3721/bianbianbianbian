import 'dart:async' show unawaited;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_cloud_sync_icloud/flutter_cloud_sync_icloud.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/l10n_ext.dart';
import '../../data/local/providers.dart' as local;
import '../../data/repository/providers.dart' show currentLedgerIdProvider;
import '../account/account_providers.dart';
import '../budget/budget_providers.dart';
import '../ledger/ledger_list_page.dart';
import '../ledger/ledger_providers.dart';
import '../record/record_providers.dart';
import '../stats/stats_range_providers.dart';
import 'attachment/attachment_migration.dart';
import 'incremental_sync_service.dart';
import 'sync_provider.dart';
import 'sync_service.dart';
import 'sync_trigger.dart';

class CloudServicePage extends ConsumerStatefulWidget {
  const CloudServicePage({super.key});

  @override
  ConsumerState<CloudServicePage> createState() => _CloudServicePageState();
}

class _CloudServicePageState extends ConsumerState<CloudServicePage> {
  @override
  Widget build(BuildContext context) {
    final activeAsync = ref.watch(activeCloudConfigProvider);
    final supabaseAsync = ref.watch(supabaseConfigProvider);
    final webdavAsync = ref.watch(webdavConfigProvider);
    final s3Async = ref.watch(s3ConfigProvider);
    final failedAsync = ref.watch(cloudFailedBackendsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.syncTitle)),
      body: activeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(context.l10n.syncError(e.toString()))),
        data: (active) {
          final cloudEnabled = active.type != CloudBackendType.local;
          // failed 集合在加载未完成时取空，对应"暂时全 ready"的乐观渲染——
          // 等 provider 数据回来 ListView 会重建。
          final failed = failedAsync.maybeWhen(
            data: (s) => s,
            orElse: () => const <CloudBackendType>{},
          );
          // ready = 该后端有完整配置（config.valid）且最近一次连接测试未失败。
          // 与全局开关无关——目的是"配置好的卡片随时可点，未配置 / 失败的灰掉"，
          // 点已 ready 卡片会顺带把全局开关切到 ON。
          bool readyFor(
            CloudBackendType type,
            AsyncValue<CloudServiceConfig?> cfgAsync,
          ) {
            if (failed.contains(type)) return false;
            return cfgAsync.maybeWhen(
              data: (cfg) => cfg != null && cfg.valid,
              orElse: () => false,
            );
          }

          final supabaseReady = readyFor(
            CloudBackendType.supabase,
            supabaseAsync,
          );
          final webdavReady = readyFor(CloudBackendType.webdav, webdavAsync);
          final s3Ready = readyFor(CloudBackendType.s3, s3Async);
          final icloudReady = !kIsWeb && Platform.isIOS;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 全局开关：关闭后所有云服务卡变灰，sync 走 LocalOnly。
              // 关闭时 store 会记录当前的非 local 类型，下次打开可一键恢复；
              // 找不到上次记录时会扫描首个 ready 的后端兜底。
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  title: Text(context.l10n.syncEnable),
                  subtitle: Text(
                    cloudEnabled
                        ? context.l10n.syncCurrentBackend(active.name)
                        : context.l10n.syncDisabled,
                  ),
                  value: cloudEnabled,
                  onChanged: (on) => _toggleCloudSync(on),
                ),
              ),
              const SizedBox(height: 12),

              if (cloudEnabled) ...[
                _SyncStatusCard(active: active),
                const SizedBox(height: 12),
              ],

              // iCloud (仅 iOS)
              if (!kIsWeb && Platform.isIOS) ...[
                _buildICloudCard(context, active, isDisabled: !icloudReady),
                const SizedBox(height: 12),
              ],

              // WebDAV
              _buildServiceCard(
                context: context,
                icon: Icons.folder_shared,
                title: 'WebDAV',
                subtitle: _cardSubtitle(
                  context: context,
                  defaultText: context.l10n.syncSelfHostedWebdav,
                  cfgAsync: webdavAsync,
                  isFailed: failed.contains(CloudBackendType.webdav),
                ),
                isSelected: active.type == CloudBackendType.webdav,
                isDisabled: !webdavReady,
                onTap: () => _switchService(CloudBackendType.webdav),
                onConfigure: () => _configureService(CloudBackendType.webdav),
                onClearConfig:
                    webdavReady
                        ? () => _clearConfig(CloudBackendType.webdav)
                        : null,
              ),
              const SizedBox(height: 12),

              // S3
              _buildServiceCard(
                context: context,
                icon: Icons.storage,
                title: context.l10n.syncS3Compatible,
                subtitle: _cardSubtitle(
                  context: context,
                  defaultText: context.l10n.syncS3Desc,
                  cfgAsync: s3Async,
                  isFailed: failed.contains(CloudBackendType.s3),
                ),
                isSelected: active.type == CloudBackendType.s3,
                isDisabled: !s3Ready,
                onTap: () => _switchService(CloudBackendType.s3),
                onConfigure: () => _configureService(CloudBackendType.s3),
                onClearConfig:
                    s3Ready ? () => _clearConfig(CloudBackendType.s3) : null,
              ),
              const SizedBox(height: 12),

              // Supabase
              _buildServiceCard(
                context: context,
                icon: Icons.cloud,
                title: 'Supabase',
                subtitle: _cardSubtitle(
                  context: context,
                  defaultText: context.l10n.syncUseSupabase,
                  cfgAsync: supabaseAsync,
                  isFailed: failed.contains(CloudBackendType.supabase),
                ),
                isSelected: active.type == CloudBackendType.supabase,
                isDisabled: !supabaseReady,
                onTap: () => _switchService(CloudBackendType.supabase),
                onConfigure: () => _configureService(CloudBackendType.supabase),
                onClearConfig:
                    supabaseReady
                        ? () => _clearConfig(CloudBackendType.supabase)
                        : null,
              ),
            ],
          );
        },
      ),
    );
  }

  /// 卡片副标题：未配置 → 默认介绍；测试失败 → 红字提示重试；
  /// 已配置且未失败 → 默认介绍（不重复打印 URL，状态卡里已有）。
  String _cardSubtitle({
    required BuildContext context,
    required String defaultText,
    required AsyncValue<CloudServiceConfig?> cfgAsync,
    required bool isFailed,
  }) {
    if (isFailed) return context.l10n.syncLastTestFailed;
    return cfgAsync.maybeWhen(
      data: (cfg) => cfg == null || !cfg.valid
          ? context.l10n.syncNotConfiguredFormat(defaultText)
          : defaultText,
      orElse: () => defaultText,
    );
  }

  Widget _buildServiceCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    bool isDisabled = false,
    required VoidCallback onTap,
    VoidCallback? onConfigure,
    VoidCallback? onClearConfig,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: Card(
        elevation: isSelected ? 4 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSelected
              ? BorderSide(color: cs.primary, width: 2)
              : BorderSide.none,
        ),
        child: ListTile(
          leading: Icon(icon, size: 40),
          title: Text(title),
          subtitle: Text(subtitle),
          onTap: isDisabled ? null : onTap,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onClearConfig != null)
                IconButton(
                  tooltip: context.l10n.syncClearConfig,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onClearConfig,
                ),
              if (onConfigure != null)
                IconButton(
                  tooltip: context.l10n.a11yCloudServiceConfigure,
                  icon: const Icon(Icons.settings),
                  onPressed: onConfigure,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildICloudCard(
    BuildContext context,
    CloudServiceConfig active, {
    bool isDisabled = false,
  }) {
    final isSelected = active.type == CloudBackendType.icloud;
    return _buildServiceCard(
      context: context,
      icon: Icons.cloud,
      title: 'iCloud',
      subtitle: context.l10n.syncUseIcloud,
      isSelected: isSelected,
      isDisabled: isDisabled,
      onTap: () => _switchService(CloudBackendType.icloud),
    );
  }

  Future<void> _switchService(CloudBackendType type) async {
    final store = ref.read(cloudServiceStoreProvider);
    final active = await ref.read(activeCloudConfigProvider.future);

    if (active.type == type) return;

    if (type == CloudBackendType.icloud) {
      final icloudProvider = ICloudProvider();
      final isAvailable = await icloudProvider.isAvailable();
      if (!isAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.syncIcloudUnavailable)),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.syncSwitchConfirm),
        content: Text(context.l10n.syncSwitchHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Step 11.4：切 backend 时如果当前 backend 已上传过附件，弹"是否迁移"
    // 二次确认。选迁移 → 把所有 meta.remoteKey 清为 null（保留 localPath）→
    // 下次同步由 uploadPending 自然把附件重传到新 backend；旧 backend 上的
    // 对象 7 天宽限后由孤儿 sweep 清掉（前提是切回去再 sweep 一次——切走后
    // 不再触发旧 backend 的 sweep，所以也保留旧对象不主动删，避免误删）。
    final db = ref.read(local.appDatabaseProvider);
    final remoteAttachments = await countAttachmentsWithRemoteKey(db);
    var migrate = false;
    if (remoteAttachments > 0) {
      if (!mounted) return;
      final choice = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.syncMigrateAttachments),
          content: Text(
            context.l10n.syncMigrateAttachmentsDetail(
              remoteAttachments,
              _typeLabel(context, type),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.syncSkipMigration),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.syncMigrate),
            ),
          ],
        ),
      );
      migrate = choice == true;
    }

    try {
      // store.activate 在配置缺失 / 无效时返回 false 且不切换激活类型——必须
      // 检查返回值，否则会出现"显示已切换但实际仍是旧后端"。
      final ok = await store.activate(type);
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.syncSwitchNotConfigured(_typeLabel(context, type)),
              ),
            ),
          );
        }
        return;
      }
      // Step 11.4：activate 成功 + 用户选了迁移 → 清掉所有 meta.remoteKey，
      // 让下次 SnapshotSyncService.upload 走 uploadPending 重新上传到新 backend。
      // 失败不阻塞切换流程：附件迁移延后用户手动同步即可，最多旧附件停留旧
      // 后端，UI 显示"未同步"占位。
      var migratedRows = 0;
      if (migrate) {
        try {
          migratedRows = await clearAllRemoteAttachmentKeys(db);
        } catch (e, st) {
          debugPrint('cross-backend attachment migration failed — $e\n$st');
        }
      }
      ref.invalidate(activeCloudConfigProvider);
      ref.invalidate(authServiceProvider);
      ref.invalidate(syncServiceProvider);
      if (mounted) {
        final msg = migratedRows > 0
            ? context.l10n.syncSwitchedWithMigration(
                _typeLabel(context, type),
                migratedRows,
              )
            : context.l10n.syncSwitched(_typeLabel(context, type));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
      // 切换到 Supabase 时也触发首次同步引导——已同步过的会被 lastSyncAt
      // 跳过条件挡住，从未同步的会进入四象限分支。
      if (type == CloudBackendType.supabase && mounted) {
        await _handleInitialSync();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.syncSwitchFailed(e.toString()))),
        );
      }
    }
  }

  /// 全局开关：OFF→关闭云同步（store 记下当前类型）；ON→还原上一次激活类型，
  /// 没有可还原的就提示用户先去配置。无论结果如何，都 invalidate 让 UI/sync
  /// 链同步刷新（包括切回 LocalOnlySyncService）。
  Future<void> _toggleCloudSync(bool turnOn) async {
    final store = ref.read(cloudServiceStoreProvider);

    if (!turnOn) {
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.syncDisableConfirm),
          content: Text(context.l10n.syncDisableHint),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.close),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await store.disableCloudSync();
      ref.invalidate(activeCloudConfigProvider);
      ref.invalidate(authServiceProvider);
      ref.invalidate(syncServiceProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.syncCloudDisabled)));
      }
      return;
    }

    final restored =
        await store.reactivateLast() ?? await store.findFirstReady();
    if (restored == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.syncPleaseConfigureFirst)),
        );
      }
      return;
    }
    ref.invalidate(activeCloudConfigProvider);
    ref.invalidate(authServiceProvider);
    ref.invalidate(syncServiceProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.syncEnabledWith(_typeLabel(context, restored)),
          ),
        ),
      );
    }
  }

  String _typeLabel(BuildContext context, CloudBackendType type) {
    switch (type) {
      case CloudBackendType.local:
        return context.l10n.syncLocalStorage;
      case CloudBackendType.beecountCloud:
        return 'BeeCount Cloud';
      case CloudBackendType.supabase:
        return 'Supabase';
      case CloudBackendType.webdav:
        return 'WebDAV';
      case CloudBackendType.icloud:
        return 'iCloud';
      case CloudBackendType.s3:
        return 'S3';
    }
  }

  Future<void> _configureService(CloudBackendType type) async {
    if (type == CloudBackendType.supabase) {
      await _showSupabaseConfigDialog();
    } else if (type == CloudBackendType.webdav) {
      await _showWebdavConfigDialog();
    } else if (type == CloudBackendType.s3) {
      await _showS3ConfigDialog();
    }
  }

  Future<void> _clearConfig(CloudBackendType type) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.syncClearConfig),
        content: Text(
          context.l10n.syncClearConfigConfirm(_typeLabel(context, type)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.syncClearConfig),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final store = ref.read(cloudServiceStoreProvider);
    await store.deleteConfig(type);
    ref.invalidate(activeCloudConfigProvider);
    ref.invalidate(authServiceProvider);
    ref.invalidate(syncServiceProvider);
    ref.invalidate(supabaseConfigProvider);
    ref.invalidate(webdavConfigProvider);
    ref.invalidate(s3ConfigProvider);
    ref.invalidate(cloudFailedBackendsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.syncConfigCleared(_typeLabel(context, type)),
          ),
        ),
      );
    }
  }

  Future<void> _showSupabaseConfigDialog() async {
    final existing = await ref.read(supabaseConfigProvider.future);
    if (!mounted) return;
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (context) => _SupabaseConfigDialog(
        initialUrl: existing?.supabaseUrl ?? '',
        initialKey: existing?.supabaseAnonKey ?? '',
        initialCustomName: existing?.customName ?? '',
        initialEmail: existing?.supabaseEmail ?? '',
        initialPassword: existing?.supabasePassword ?? '',
      ),
    );
    if (result != null) {
      await _saveConfig(CloudBackendType.supabase, result);
    }
  }

  Future<void> _showWebdavConfigDialog() async {
    final existing = await ref.read(webdavConfigProvider.future);
    if (!mounted) return;
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (context) => _WebdavConfigDialog(
        initialUrl: existing?.webdavUrl ?? '',
        initialUsername: existing?.webdavUsername ?? '',
        initialPassword: existing?.webdavPassword ?? '',
        initialPath: existing?.webdavRemotePath ?? '/',
        initialCustomName: existing?.customName ?? '',
      ),
    );
    if (result != null) {
      await _saveConfig(CloudBackendType.webdav, result);
    }
  }

  Future<void> _showS3ConfigDialog() async {
    final existing = await ref.read(s3ConfigProvider.future);
    if (!mounted) return;
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => _S3ConfigDialog(
        initialEndpoint: existing?.s3Endpoint ?? '',
        initialRegion: existing?.s3Region ?? 'auto',
        initialAccessKey: existing?.s3AccessKey ?? '',
        initialSecretKey: existing?.s3SecretKey ?? '',
        initialBucket: existing?.s3Bucket ?? '',
        initialUseSSL: existing?.s3UseSSL ?? true,
        initialPort: existing?.s3Port,
        initialCustomName: existing?.customName ?? '',
      ),
    );
    if (result != null) {
      await _saveConfig(CloudBackendType.s3, result);
    }
  }

  Future<void> _saveConfig(
    CloudBackendType type,
    Map<String, dynamic> data,
  ) async {
    final store = ref.read(cloudServiceStoreProvider);
    CloudServiceConfig? cfg;

    try {
      // 通用：自定义名称——空 / 全空白视为未设置；统一存到 CloudServiceConfig.customName
      final customNameRaw = (data['customName'] as String?)?.trim();
      final customName = (customNameRaw == null || customNameRaw.isEmpty)
          ? null
          : customNameRaw;
      if (type == CloudBackendType.supabase) {
        cfg = CloudServiceConfig(
          type: CloudBackendType.supabase,
          name: 'Supabase',
          customName: customName,
          supabaseUrl: (data['url'] as String).trim(),
          supabaseAnonKey: (data['key'] as String).trim(),
          supabaseEmail: (data['email'] as String?)?.trim(),
          supabasePassword: data['password'] as String?,
        );
      } else if (type == CloudBackendType.webdav) {
        cfg = CloudServiceConfig(
          type: CloudBackendType.webdav,
          name: 'WebDAV',
          customName: customName,
          webdavUrl: (data['url'] as String).trim(),
          webdavUsername: (data['username'] as String).trim(),
          webdavPassword: data['password'] as String,
          webdavRemotePath: (data['path'] as String).trim(),
        );
      } else if (type == CloudBackendType.s3) {
        cfg = CloudServiceConfig(
          type: CloudBackendType.s3,
          name: 'S3',
          customName: customName,
          s3Endpoint: (data['endpoint'] as String).trim(),
          s3Region: (data['region'] as String).trim(),
          s3AccessKey: (data['accessKey'] as String).trim(),
          s3SecretKey: (data['secretKey'] as String).trim(),
          s3Bucket: (data['bucket'] as String).trim(),
          s3UseSSL: data['useSSL'] as bool,
          s3Port: data['port'] as int?,
        );
      }

      if (cfg != null && cfg.valid) {
        await store.saveOnly(cfg);
        // 保存后立即跑一次连接测试——createCloudServices 内部各 backend 的
        // initialize() 会做实质 I/O（如 S3 listObjects），失败时抛异常。结果
        // 持久化到 store 的 failed 集合，UI 卡片就绪态据此切换。10s 超时避免
        // 死端点卡住保存流程。
        String? testError;
        try {
          await _testConnection(cfg).timeout(const Duration(seconds: 10));
          await store.markBackendTested(type: cfg.type, success: true);
        } catch (e) {
          testError = e.toString();
          await store.markBackendTested(type: cfg.type, success: false);
        }
        ref.invalidate(activeCloudConfigProvider);
        ref.invalidate(supabaseConfigProvider);
        ref.invalidate(webdavConfigProvider);
        ref.invalidate(s3ConfigProvider);
        ref.invalidate(cloudFailedBackendsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                testError == null
                    ? context.l10n.syncConfigSavedAndTested
                    : context.l10n.syncConfigSavedTestFailed(testError),
              ),
              duration: testError == null
                  ? const Duration(seconds: 3)
                  : const Duration(seconds: 6),
            ),
          );
        }
        // Step 17(云同步 V2):Supabase 保存且测试通过 → 启动首次同步引导。
        // 关键：`store.saveOnly` 只保存配置不激活；若用户当前 active 仍是 local，
        // syncServiceProvider 会返回 LocalOnlySyncService，_handleInitialSync
        // 会因 `service is! IncrementalSyncService` 直接 return，导致 seeder
        // 默认数据永远没机会入队推送（forcePushAll 是从全表枚举入队的）。
        // 因此首次配置 Supabase（active==local 时）自动 activate 一次。
        if (testError == null && cfg.type == CloudBackendType.supabase) {
          final activeCfg = await ref.read(activeCloudConfigProvider.future);
          if (activeCfg.type == CloudBackendType.local) {
            final activated =
                await store.activate(CloudBackendType.supabase);
            if (activated) {
              ref.invalidate(activeCloudConfigProvider);
              ref.invalidate(authServiceProvider);
              ref.invalidate(syncServiceProvider);
            }
          }
          if (mounted) {
            await _handleInitialSync();
          }
        }
      } else {
        throw Exception(context.l10n.syncConfigInvalid);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.saveFailedWithError(e.toString())),
          ),
        );
      }
    }
  }

  /// 真实跑一次 provider 初始化，验证配置可用。务必 dispose 释放底层连接。
  /// 返回正常即视为通过；任何异常（含 timeout）由调用方捕获并写入 failed 集。
  Future<void> _testConnection(CloudServiceConfig cfg) async {
    final providerNullMsg = context.l10n.syncProviderInitNull;
    CloudProvider? provider;
    try {
      final services = await createCloudServices(cfg);
      provider = services.provider;
      if (provider == null) {
        throw Exception(providerNullMsg);
      }
    } finally {
      try {
        await provider?.dispose();
      } catch (_) {
        // dispose 失败不影响测试结论
      }
    }
  }

  /// Step 17（云同步 V2）：Supabase 配置保存且连接测试通过后的首次同步引导。
  ///
  /// 按"本地 × 云端"是否各有数据四象限分支：
  /// - 都空：不弹（边界情况，seeder 至少会建一个账本）；
  /// - 本地有 / 云端空：静默 `forcePushAll`，把本地（含 seeder 默认数据）全量推上去；
  /// - 本地空 / 云端有：弹"恢复云端"对话框，确定 → `forcePullAll`；取消 → 关闭云同步；
  /// - 都有：弹三选一（本地覆盖云端 / 云端覆盖本地 / 合并）；取消 → 关闭云同步。
  ///
  /// 跳过条件：`user_pref.last_sync_at != null`——已经同步过则不再弹引导，避免
  /// 用户只改了 customName 等小调整就被引导骚扰。
  Future<void> _handleInitialSync() async {
    if (!mounted) return;
    final l10n = context.l10n;
    final db = ref.read(local.appDatabaseProvider);

    // 跳过条件：之前已成功同步过。
    final pref = await (db.select(db.userPrefTable)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    if (pref?.lastSyncAt != null) return;

    final service = await ref.read(syncServiceProvider.future);
    if (service is! IncrementalSyncService) return;

    final localHas = await _localHasAnyData();
    final bool cloudHas;
    try {
      cloudHas = await service.hasAnyCloudData();
    } catch (_) {
      // 网络 / 权限失败：无法判断云端，保守不弹窗，让后续触发路径自然处理。
      return;
    }

    if (!localHas && !cloudHas) return;

    if (localHas && !cloudHas) {
      await _runInitialAction(
        action: () => service.forcePushAll(),
        runningMessage: l10n.syncInitialPushing,
        successMessage: l10n.syncInitialPushDone,
      );
      return;
    }

    if (!localHas && cloudHas) {
      if (!mounted) return;
      final ok = await _showRestoreFromCloudDialog();
      if (ok != true) {
        await _disableCloudSyncOnCancel();
        return;
      }
      await _runInitialAction(
        action: () => service.forcePullAll(),
        runningMessage: l10n.syncFullPullRunning,
        successMessage: l10n.syncFullPullDone,
      );
      return;
    }

    // 都有：三选一。
    if (!mounted) return;
    final choice = await _showInitialChoiceDialog();
    if (choice == null) {
      await _disableCloudSyncOnCancel();
      return;
    }
    switch (choice) {
      case InitialSyncChoice.merge:
        await _runInitialAction(
          action: () => service.pullThenPush(),
          runningMessage: l10n.syncInitialMerging,
          successMessage: l10n.syncInitialMergeDone,
        );
        break;
      case InitialSyncChoice.localOverwriteCloud:
        await _runInitialAction(
          action: () => service.forcePushAll(),
          runningMessage: l10n.syncInitialPushing,
          successMessage: l10n.syncForcePushDone,
        );
        break;
      case InitialSyncChoice.cloudOverwriteLocal:
        await _runInitialAction(
          action: () => service.forcePullAll(),
          runningMessage: l10n.syncFullPullRunning,
          successMessage: l10n.syncForcePullDone,
        );
        break;
    }
  }

  /// 本地任意一张同步表存在 row（含软删）即视为"本地有数据"。
  /// 用户偏好：含 seeder 默认账本/分类也算有数据——用户可能改过名称/图标，保守不丢。
  Future<bool> _localHasAnyData() async {
    final db = ref.read(local.appDatabaseProvider);
    final l = await (db.select(db.ledgerTable)..limit(1)).get();
    if (l.isNotEmpty) return true;
    final c = await (db.select(db.categoryTable)..limit(1)).get();
    if (c.isNotEmpty) return true;
    final a = await (db.select(db.accountTable)..limit(1)).get();
    if (a.isNotEmpty) return true;
    final t = await (db.select(db.transactionEntryTable)..limit(1)).get();
    return t.isNotEmpty;
  }

  Future<bool?> _showRestoreFromCloudDialog() {
    final l10n = context.l10n;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.syncInitialRestoreTitle),
        content: Text(l10n.syncInitialRestorePrompt),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.syncInitialRestoreConfirm),
          ),
        ],
      ),
    );
  }

  Future<InitialSyncChoice?> _showInitialChoiceDialog() {
    final l10n = context.l10n;
    return showDialog<InitialSyncChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.syncInitialChoiceTitle),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              l10n.syncInitialChoicePrompt,
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
          ),
          SimpleDialogOption(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            onPressed: () =>
                Navigator.of(ctx).pop(InitialSyncChoice.merge),
            child: _InitialChoiceTile(
              title: l10n.syncInitialMerge,
              subtitle: l10n.syncInitialMergeSub,
            ),
          ),
          SimpleDialogOption(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            onPressed: () =>
                Navigator.of(ctx).pop(InitialSyncChoice.localOverwriteCloud),
            child: _InitialChoiceTile(
              title: l10n.syncInitialLocalOverwrite,
              subtitle: l10n.syncInitialLocalOverwriteSub,
            ),
          ),
          SimpleDialogOption(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            onPressed: () =>
                Navigator.of(ctx).pop(InitialSyncChoice.cloudOverwriteLocal),
            child: _InitialChoiceTile(
              title: l10n.syncInitialCloudOverwrite,
              subtitle: l10n.syncInitialCloudOverwriteSub,
            ),
          ),
          const Divider(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.cancel),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runInitialAction({
    required Future<void> Function() action,
    required String runningMessage,
    required String successMessage,
  }) async {
    if (!mounted) return;
    final l10n = context.l10n;
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(runningMessage)),
          ],
        ),
      ),
    ));

    String? errorMsg;
    try {
      await action();
    } catch (e) {
      errorMsg = e.toString();
    }

    // 同步动作完成后必须 invalidate:
    // 1. 数据 provider:账本/流水/分类/账户/预算/统计——否则首次拉取后
    //    用户得新建账本或杀进程才能看到云端数据;
    // 2. syncServiceProvider:让 _SyncStatusBody 重建并重读 SyncStatus,
    //    否则状态卡片停留在 initState 时拿到的"未配置/暂无备份"。
    if (errorMsg == null) {
      _invalidateDataProviders(ref);
      ref.invalidate(syncServiceProvider);
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          errorMsg == null
              ? successMessage
              : l10n.syncInitialFailed(errorMsg),
        ),
      ),
    );
  }

  Future<void> _disableCloudSyncOnCancel() async {
    final store = ref.read(cloudServiceStoreProvider);
    await store.disableCloudSync();
    ref.invalidate(activeCloudConfigProvider);
    ref.invalidate(authServiceProvider);
    ref.invalidate(syncServiceProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.syncInitialDisabledOnCancel)),
    );
  }
}

// --- 首次同步引导 ---

/// 强制 push/pull/合并后,所有依赖 5 张同步表的 provider 都可能变化——批量
/// invalidate 让各页面(账本列表 / 流水汇总 / 统计 / 账户 / 预算)立刻拿到
/// 最新数据,而不是等用户重新切页或杀进程。
///
/// 与 `backup_list_page._invalidateDataProviders` 保持一致——两边都是
/// "云端覆盖本地"的入口。
void _invalidateDataProviders(WidgetRef ref) {
  ref.invalidate(recordMonthSummaryProvider);
  ref.invalidate(statsLinePointsProvider);
  ref.invalidate(statsPieSlicesProvider);
  ref.invalidate(statsRankItemsProvider);
  ref.invalidate(statsHeatmapCellsProvider);
  ref.invalidate(accountsListProvider);
  ref.invalidate(accountBalancesProvider);
  ref.invalidate(totalAssetsProvider);
  ref.invalidate(activeBudgetsProvider);
  ref.invalidate(budgetableCategoriesProvider);
  ref.invalidate(budgetProgressForProvider);
  ref.invalidate(ledgerTxCountsProvider);
  ref.invalidate(categoriesListProvider);
  ref.invalidate(ledgerGroupsProvider);
  ref.invalidate(currentLedgerIdProvider);
}

/// 首次同步引导对话框的三选一结果。`null` 表示取消（关闭云同步）。
enum InitialSyncChoice {
  /// 合并：双向 LWW（updated_at 较新者胜出）。
  merge,

  /// 本地覆盖云端：上传本地全部，删除云端独有行。
  localOverwriteCloud,

  /// 云端覆盖本地：下载云端全部，清空本地。
  cloudOverwriteLocal,
}

/// 三选一对话框的单个选项 tile：粗体标题 + 描述副本。
class _InitialChoiceTile extends StatelessWidget {
  const _InitialChoiceTile({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// --- 配置对话框 ---

class _SupabaseConfigDialog extends StatefulWidget {
  final String initialUrl;
  final String initialKey;
  final String initialCustomName;
  final String initialEmail;
  final String initialPassword;

  const _SupabaseConfigDialog({
    required this.initialUrl,
    required this.initialKey,
    this.initialCustomName = '',
    this.initialEmail = '',
    this.initialPassword = '',
  });

  @override
  State<_SupabaseConfigDialog> createState() => _SupabaseConfigDialogState();
}

class _SupabaseConfigDialogState extends State<_SupabaseConfigDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController _keyController;
  late final TextEditingController _customNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl);
    _keyController = TextEditingController(text: widget.initialKey);
    _customNameController = TextEditingController(
      text: widget.initialCustomName,
    );
    _emailController = TextEditingController(text: widget.initialEmail);
    _passwordController = TextEditingController(text: widget.initialPassword);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.syncConfigSupabase),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _customNameController,
              decoration: InputDecoration(
                labelText: context.l10n.syncCustomName,
                hintText: context.l10n.syncCustomNameHint,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(labelText: 'URL'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _keyController,
              decoration: const InputDecoration(labelText: 'Anon Key'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop({
              'url': _urlController.text.trim(),
              'key': _keyController.text.trim(),
              'customName': _customNameController.text.trim(),
              'email': _emailController.text.trim(),
              'password': _passwordController.text,
            });
          },
          child: Text(context.l10n.save),
        ),
      ],
    );
  }
}

class _WebdavConfigDialog extends StatefulWidget {
  final String initialUrl;
  final String initialUsername;
  final String initialPassword;
  final String initialPath;
  final String initialCustomName;

  const _WebdavConfigDialog({
    required this.initialUrl,
    required this.initialUsername,
    required this.initialPassword,
    required this.initialPath,
    this.initialCustomName = '',
  });

  @override
  State<_WebdavConfigDialog> createState() => _WebdavConfigDialogState();
}

class _WebdavConfigDialogState extends State<_WebdavConfigDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _pathController;
  late final TextEditingController _customNameController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl);
    _usernameController = TextEditingController(text: widget.initialUsername);
    _passwordController = TextEditingController(text: widget.initialPassword);
    _pathController = TextEditingController(text: widget.initialPath);
    _customNameController = TextEditingController(
      text: widget.initialCustomName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.syncConfigWebdav),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _customNameController,
              decoration: InputDecoration(
                labelText: context.l10n.syncCustomName,
                hintText: context.l10n.syncCustomNameHint,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(labelText: 'URL'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: context.l10n.syncWebdavUsername,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: context.l10n.syncWebdavPassword,
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pathController,
              decoration: InputDecoration(
                labelText: context.l10n.syncWebdavRemotePath,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop({
              'url': _urlController.text,
              'username': _usernameController.text,
              'password': _passwordController.text,
              'path': _pathController.text,
              'customName': _customNameController.text,
            });
          },
          child: Text(context.l10n.save),
        ),
      ],
    );
  }
}

class _S3ConfigDialog extends StatefulWidget {
  final String initialEndpoint;
  final String initialRegion;
  final String initialAccessKey;
  final String initialSecretKey;
  final String initialBucket;
  final bool initialUseSSL;
  final int? initialPort;
  final String initialCustomName;

  const _S3ConfigDialog({
    required this.initialEndpoint,
    required this.initialRegion,
    required this.initialAccessKey,
    required this.initialSecretKey,
    required this.initialBucket,
    required this.initialUseSSL,
    this.initialPort,
    this.initialCustomName = '',
  });

  @override
  State<_S3ConfigDialog> createState() => _S3ConfigDialogState();
}

class _S3ConfigDialogState extends State<_S3ConfigDialog> {
  late final TextEditingController _endpointController;
  late final TextEditingController _regionController;
  late final TextEditingController _accessKeyController;
  late final TextEditingController _secretKeyController;
  late final TextEditingController _bucketController;
  late final TextEditingController _portController;
  late final TextEditingController _customNameController;
  late bool _useSSL;

  @override
  void initState() {
    super.initState();
    _endpointController = TextEditingController(text: widget.initialEndpoint);
    _regionController = TextEditingController(text: widget.initialRegion);
    _accessKeyController = TextEditingController(text: widget.initialAccessKey);
    _secretKeyController = TextEditingController(text: widget.initialSecretKey);
    _bucketController = TextEditingController(text: widget.initialBucket);
    _portController = TextEditingController(
      text: widget.initialPort?.toString() ?? '',
    );
    _customNameController = TextEditingController(
      text: widget.initialCustomName,
    );
    _useSSL = widget.initialUseSSL;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.syncConfigS3),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _customNameController,
              decoration: InputDecoration(
                labelText: context.l10n.syncCustomName,
                hintText: context.l10n.syncS3CustomNameHint,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _endpointController,
              decoration: const InputDecoration(
                labelText: 'Endpoint (Without https://)',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _regionController,
              decoration: const InputDecoration(labelText: 'Region'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _accessKeyController,
              decoration: const InputDecoration(labelText: 'Access Key'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _secretKeyController,
              decoration: const InputDecoration(labelText: 'Secret Key'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bucketController,
              decoration: const InputDecoration(labelText: 'Bucket'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _portController,
              decoration: InputDecoration(
                labelText: 'Port (${context.l10n.optional})',
              ),
              keyboardType: TextInputType.number,
            ),
            SwitchListTile(
              title: const Text('Use SSL'),
              value: _useSSL,
              onChanged: (value) => setState(() => _useSSL = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop({
              'endpoint': _endpointController.text,
              'region': _regionController.text,
              'accessKey': _accessKeyController.text,
              'secretKey': _secretKeyController.text,
              'bucket': _bucketController.text,
              'useSSL': _useSSL,
              'port': _portController.text.isNotEmpty
                  ? int.tryParse(_portController.text)
                  : null,
              'customName': _customNameController.text,
            });
          },
          child: Text(context.l10n.save),
        ),
      ],
    );
  }
}

// --- 同步状态卡 ---

class _SyncStatusCard extends ConsumerWidget {
  const _SyncStatusCard({required this.active});

  final CloudServiceConfig active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerAsync = ref.watch(currentLedgerIdProvider);
    final syncAsync = ref.watch(syncServiceProvider);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ledgerAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Text(context.l10n.syncLedgerLoadFailed(e.toString())),
          data: (ledgerId) => syncAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(context.l10n.syncInitFailed(e.toString())),
            data: (service) => _SyncStatusBody(
              service: service,
              ledgerId: ledgerId,
              backendName: active.name,
              backendLocation: active.obfuscatedUrl(),
              backendType: active.type,
            ),
          ),
        ),
      ),
    );
  }
}

class _SyncStatusBody extends ConsumerStatefulWidget {
  const _SyncStatusBody({
    required this.service,
    required this.ledgerId,
    required this.backendName,
    required this.backendLocation,
    required this.backendType,
  });

  final SyncService service;
  final String ledgerId;
  final String backendName;
  final String backendLocation;
  final CloudBackendType backendType;

  @override
  ConsumerState<_SyncStatusBody> createState() => _SyncStatusBodyState();
}

class _SyncStatusBodyState extends ConsumerState<_SyncStatusBody> {
  Future<SyncStatus>? _statusFuture;
  bool _busy = false;
  bool _wasBackgroundSyncing = false;

  @override
  void initState() {
    super.initState();
    _refresh(force: false);
  }

  @override
  void didUpdateWidget(covariant _SyncStatusBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // service 引用变化(比如 syncServiceProvider 被 invalidate 后重新 build,
    // 但 Flutter 复用了同位置的 State)→ 必须重读 SyncStatus,否则状态卡
    // 停留在旧 service 给出的状态。invalidate 路径在 _saveConfig /
    // _handleInitialSync / _runWithBusy 都可能触发。
    if (oldWidget.service != widget.service ||
        oldWidget.ledgerId != widget.ledgerId) {
      _refresh(force: false);
    }
  }

  void _refresh({required bool force}) {
    setState(() {
      _statusFuture = widget.service.getStatus(
        ledgerId: widget.ledgerId,
        forceRefresh: force,
      );
    });
  }

  Future<void> _runWithBusy(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
      widget.service.clearCache();
      // 强制 push/pull 改了 5 张同步表,必须 invalidate 数据 provider,
      // 否则账本列表 / 流水汇总 / 统计 / 账户 / 预算停留在旧数据,
      // 用户得新建账本或杀进程才能看到云端数据。
      _invalidateDataProviders(ref);
      _refresh(force: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.operationFailedWithError(e.toString())),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forcePush() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.syncForcePush),
        content: Text(l10n.syncForcePushConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    return _runWithBusy(
      () => widget.service.forcePushAll(),
      successMessage: l10n.syncForcePushDone,
    );
  }

  Future<void> _forcePull() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.syncForcePull),
        content: Text(l10n.syncForcePullConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    return _runWithBusy(
      () => widget.service.forcePullAll(),
      successMessage: l10n.syncForcePullDone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final syncTriggerState = ref.watch(syncTriggerProvider);
    final isBackgroundSyncing = syncTriggerState.isRunning;
    if (_wasBackgroundSyncing && !isBackgroundSyncing && !_busy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refresh(force: true);
      });
    }
    _wasBackgroundSyncing = isBackgroundSyncing;
    final isAnyBusy = _busy || isBackgroundSyncing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.cloud_sync_outlined),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${widget.backendName} · ${widget.backendLocation}',
                style: Theme.of(context).textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: isAnyBusy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              tooltip: context.l10n.syncRefreshStatus,
              onPressed: isAnyBusy ? null : () => _refresh(force: true),
            ),
          ],
        ),
        if (isBackgroundSyncing) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 6),
              Text(
                context.l10n.recordSyncing,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        FutureBuilder<SyncStatus>(
          future: _statusFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(context.l10n.syncFetchingStatus),
              );
            }
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  context.l10n.syncStatusFetchFailed(snap.error.toString()),
                ),
              );
            }
            final status = snap.data!;
            final isRealAuth = widget.backendType == CloudBackendType.supabase ||
                widget.backendType == CloudBackendType.beecountCloud;
            final isIncremental =
                widget.backendType == CloudBackendType.supabase;
            return _StatusLine(
              status: status,
              isRealAuth: isRealAuth,
              isIncremental: isIncremental,
            );
          },
        ),
        const SizedBox(height: 12),
        Builder(builder: (context) {
          return Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text(context.l10n.syncForcePush),
                  onPressed: isAnyBusy ? null : _forcePush,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: Text(context.l10n.syncForcePull),
                  onPressed: isAnyBusy ? null : _forcePull,
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.status,
    this.isRealAuth = false,
    this.isIncremental = false,
  });

  final SyncStatus status;
  final bool isRealAuth;

  /// Step 17(云同步 V2):增量模式开关。
  /// - true(Supabase):用 [SyncStatus.localCount] 显示「待推送 N 条」,跳过
  ///   「本地 N / 云端 M」对比(增量模式没有"云端 N"概念);
  /// - false(V1 快照):走原本「本地 N / 云端 M」行。
  final bool isIncremental;

  String _label(BuildContext context) {
    switch (status.state) {
      case SyncState.notConfigured:
        return context.l10n.syncStatusNotConfigured;
      case SyncState.notAuthenticated:
        return context.l10n.syncStatusNotLoggedIn;
      case SyncState.localOnly:
        return context.l10n.syncStatusNoBackup;
      case SyncState.synced:
        return context.l10n.syncStatusSynced;
      case SyncState.outOfSync:
        if (status.isLocalNewer) return context.l10n.syncStatusLocalNewer;
        if (status.isCloudNewer) return context.l10n.syncStatusCloudNewer;
        return context.l10n.syncStatusDiverged;
      case SyncState.uploading:
        return context.l10n.syncStatusUploading;
      case SyncState.downloading:
        return context.l10n.syncStatusDownloading;
      case SyncState.error:
        return context.l10n.error;
      case SyncState.unknown:
        return context.l10n.unknown;
    }
  }

  Color _color(BuildContext ctx) {
    switch (status.state) {
      case SyncState.synced:
        return Colors.green;
      case SyncState.outOfSync:
      case SyncState.localOnly:
        return Colors.orange;
      case SyncState.error:
        return Theme.of(ctx).colorScheme.error;
      default:
        return Theme.of(ctx).colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = status.lastSyncedAt;
    final tsLabel = ts == null
        ? null
        : DateFormat('yyyy-MM-dd HH:mm').format(ts.toLocal());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.circle, size: 10, color: _color(context)),
            const SizedBox(width: 6),
            Text(
              _label(context),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        if (tsLabel != null) ...[
          const SizedBox(height: 4),
          Text(
            context.l10n.syncLastSyncAt(tsLabel),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        // 增量模式: 仅显示「待推送 N 条」(队列 = sync_op 行数)。
        // 快照模式: 显示「本地 N / 云端 M」对比。
        if (isIncremental && status.localCount != null) ...[
          const SizedBox(height: 4),
          Text(
            context.l10n.syncPendingCount(status.localCount!),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ] else if (!isIncremental &&
            status.localCount != null &&
            status.cloudCount != null) ...[
          const SizedBox(height: 4),
          Text(
            context.l10n.syncLocalCloudCount(
              status.localCount!,
              status.cloudCount!,
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (status.message != null && status.state == SyncState.error) ...[
          const SizedBox(height: 4),
          Text(status.message!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}
