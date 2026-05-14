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
import '../ledger/ledger_providers.dart';
import '../record/record_providers.dart';
import '../stats/stats_range_providers.dart';
import 'attachment/attachment_migration.dart';
import 'sync_provider.dart';
import 'sync_service.dart';

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
      appBar: AppBar(
        title: Text(context.l10n.syncTitle),
      ),
      body: activeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(context.l10n.syncError(e.toString()))),
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

          final supabaseReady = readyFor(CloudBackendType.supabase, supabaseAsync);
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
                    borderRadius: BorderRadius.circular(12)),
                child: SwitchListTile(
                  title: Text(context.l10n.syncEnable),
                  subtitle: Text(cloudEnabled
                      ? context.l10n.syncCurrentBackend(active.name)
                      : context.l10n.syncDisabled),
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
      data: (cfg) =>
          cfg == null || !cfg.valid ? context.l10n.syncNotConfiguredFormat(defaultText) : defaultText,
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
  }) {
    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: Card(
        elevation: isSelected ? 4 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSelected
              ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
              : BorderSide.none,
        ),
        child: ListTile(
          leading: Icon(icon, size: 40),
          title: Text(title),
          subtitle: Text(subtitle),
          onTap: isDisabled ? null : onTap,
          trailing: onConfigure != null
              ? IconButton(
                  tooltip: context.l10n.a11yCloudServiceConfigure,
                  icon: const Icon(Icons.settings),
                  onPressed: onConfigure,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildICloudCard(BuildContext context, CloudServiceConfig active, {bool isDisabled = false}) {
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
            context.l10n.syncMigrateAttachmentsDetail(remoteAttachments, _typeLabel(context, type)),
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
                    context.l10n.syncSwitchNotConfigured(_typeLabel(context, type)))),
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
            ? context.l10n.syncSwitchedWithMigration(_typeLabel(context, type), migratedRows)
            : context.l10n.syncSwitched(_typeLabel(context, type));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.syncCloudDisabled)),
        );
      }
      return;
    }

    final restored = await store.reactivateLast() ?? await store.findFirstReady();
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
        SnackBar(content: Text(context.l10n.syncEnabledWith(_typeLabel(context, restored)))),
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

  Future<void> _showSupabaseConfigDialog() async {
    final existing = await ref.read(supabaseConfigProvider.future);
    if (!mounted) return;
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (context) => _SupabaseConfigDialog(
        initialUrl: existing?.supabaseUrl ?? '',
        initialKey: existing?.supabaseAnonKey ?? '',
        initialCustomName: existing?.customName ?? '',
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
        initialRegion: existing?.s3Region ?? 'us-east-1',
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

  Future<void> _saveConfig(CloudBackendType type, Map<String, dynamic> data) async {
    final store = ref.read(cloudServiceStoreProvider);
    CloudServiceConfig? cfg;

    try {
      // 通用：自定义名称——空 / 全空白视为未设置；统一存到 CloudServiceConfig.customName
      final customNameRaw = (data['customName'] as String?)?.trim();
      final customName =
          (customNameRaw == null || customNameRaw.isEmpty) ? null : customNameRaw;
      if (type == CloudBackendType.supabase) {
        cfg = CloudServiceConfig(
          type: CloudBackendType.supabase,
          name: 'Supabase',
          customName: customName,
          supabaseUrl: data['url'] as String,
          supabaseAnonKey: data['key'] as String,
        );
      } else if (type == CloudBackendType.webdav) {
        cfg = CloudServiceConfig(
          type: CloudBackendType.webdav,
          name: 'WebDAV',
          customName: customName,
          webdavUrl: data['url'] as String,
          webdavUsername: data['username'] as String,
          webdavPassword: data['password'] as String,
          webdavRemotePath: data['path'] as String,
        );
      } else if (type == CloudBackendType.s3) {
        cfg = CloudServiceConfig(
          type: CloudBackendType.s3,
          name: 'S3',
          customName: customName,
          s3Endpoint: data['endpoint'] as String,
          s3Region: data['region'] as String,
          s3AccessKey: data['accessKey'] as String,
          s3SecretKey: data['secretKey'] as String,
          s3Bucket: data['bucket'] as String,
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
              content: Text(testError == null
                  ? context.l10n.syncConfigSavedAndTested
                  : context.l10n.syncConfigSavedTestFailed(testError)),
              duration: testError == null
                  ? const Duration(seconds: 3)
                  : const Duration(seconds: 6),
            ),
          );
        }
      } else {
        throw Exception(context.l10n.syncConfigInvalid);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.saveFailedWithError(e.toString()))),
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
}

// --- 配置对话框 ---

class _SupabaseConfigDialog extends StatefulWidget {
  final String initialUrl;
  final String initialKey;
  final String initialCustomName;

  const _SupabaseConfigDialog({
    required this.initialUrl,
    required this.initialKey,
    this.initialCustomName = '',
  });

  @override
  State<_SupabaseConfigDialog> createState() => _SupabaseConfigDialogState();
}

class _SupabaseConfigDialogState extends State<_SupabaseConfigDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController _keyController;
  late final TextEditingController _customNameController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl);
    _keyController = TextEditingController(text: widget.initialKey);
    _customNameController = TextEditingController(text: widget.initialCustomName);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.syncConfigSupabase),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _customNameController,
            decoration: InputDecoration(
              labelText: context.l10n.syncCustomName,
              hintText: context.l10n.syncCustomNameHint,
            ),
          ),
          TextField(controller: _urlController, decoration: const InputDecoration(labelText: 'URL')),
          TextField(controller: _keyController, decoration: const InputDecoration(labelText: 'Anon Key')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.l10n.cancel)),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop({
              'url': _urlController.text,
              'key': _keyController.text,
              'customName': _customNameController.text,
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
    _customNameController = TextEditingController(text: widget.initialCustomName);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.syncConfigWebdav),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _customNameController,
            decoration: InputDecoration(
              labelText: context.l10n.syncCustomName,
              hintText: context.l10n.syncCustomNameHint,
            ),
          ),
          TextField(controller: _urlController, decoration: const InputDecoration(labelText: 'URL')),
          TextField(controller: _usernameController, decoration: InputDecoration(labelText: context.l10n.syncWebdavUsername)),
          TextField(controller: _passwordController, decoration: InputDecoration(labelText: context.l10n.syncWebdavPassword), obscureText: true),
          TextField(controller: _pathController, decoration: InputDecoration(labelText: context.l10n.syncWebdavRemotePath)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.l10n.cancel)),
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
    _portController = TextEditingController(text: widget.initialPort?.toString() ?? '');
    _customNameController = TextEditingController(text: widget.initialCustomName);
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
            TextField(controller: _endpointController, decoration: const InputDecoration(labelText: 'Endpoint')),
            TextField(controller: _regionController, decoration: const InputDecoration(labelText: 'Region')),
            TextField(controller: _accessKeyController, decoration: const InputDecoration(labelText: 'Access Key')),
            TextField(controller: _secretKeyController, decoration: const InputDecoration(labelText: 'Secret Key'), obscureText: true),
            TextField(controller: _bucketController, decoration: const InputDecoration(labelText: 'Bucket')),
            TextField(controller: _portController, decoration: InputDecoration(labelText: 'Port (${context.l10n.optional})'), keyboardType: TextInputType.number),
            SwitchListTile(
              title: const Text('Use SSL'),
              value: _useSSL,
              onChanged: (value) => setState(() => _useSSL = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.l10n.cancel)),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop({
              'endpoint': _endpointController.text,
              'region': _regionController.text,
              'accessKey': _accessKeyController.text,
              'secretKey': _secretKeyController.text,
              'bucket': _bucketController.text,
              'useSSL': _useSSL,
              'port': _portController.text.isNotEmpty ? int.tryParse(_portController.text) : null,
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
          error: (e, _) => Text(context.l10n.syncLedgerLoadFailed(e.toString())),
          data: (ledgerId) => syncAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(context.l10n.syncInitFailed(e.toString())),
            data: (service) => _SyncStatusBody(
              service: service,
              ledgerId: ledgerId,
              backendName: active.name,
              backendLocation: active.obfuscatedUrl(),
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
  });

  final SyncService service;
  final String ledgerId;
  final String backendName;
  final String backendLocation;

  @override
  ConsumerState<_SyncStatusBody> createState() => _SyncStatusBodyState();
}

class _SyncStatusBodyState extends ConsumerState<_SyncStatusBody> {
  Future<SyncStatus>? _statusFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh(force: false);
  }

  void _refresh({required bool force}) {
    setState(() {
      _statusFuture = widget.service.getStatus(
        ledgerId: widget.ledgerId,
        forceRefresh: force,
      );
    });
  }

  Future<void> _runWithBusy(Future<void> Function() action,
      {required String successMessage}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
      widget.service.clearCache();
      _refresh(force: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.operationFailedWithError(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() => _runWithBusy(
        () => widget.service.upload(ledgerId: widget.ledgerId),
        successMessage: context.l10n.syncUploaded,
      );

  Future<void> _download() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.syncRestoreFromCloud),
        content: Text(l10n.syncRestoreConfirmMsg),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancel)),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.syncRestore)),
        ],
      ),
    );
    if (confirmed != true) return;
    return _runWithBusy(
      () async {
        final inserted = await widget.service.downloadAndRestore(
          ledgerId: widget.ledgerId,
        );
        // 下载直接走 db.batch 写库（绕过 repository.save），Riverpod 不会感知
        // DB 变化——必须手动 invalidate 各数据 provider，否则 UI 沿用旧 cache，
        // 要等冷启动重建 ProviderContainer 才会刷新。
        _invalidateDataProviders();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.syncRestoredCount(inserted))),
        );
      },
      successMessage: l10n.syncRestored,
    );
  }

  Future<void> _deleteRemote() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.syncDeleteCloudBackup),
        content: Text(l10n.syncDeleteCloudConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancel)),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.delete)),
        ],
      ),
    );
    if (confirmed != true) return;
    return _runWithBusy(
      () => widget.service.deleteRemote(ledgerId: widget.ledgerId),
      successMessage: l10n.syncCloudDeleted,
    );
  }

  /// 下载恢复后必须 invalidate 所有受 DB 变化影响的数据 provider——保持与
  /// `record_new_providers.save` 的 invalidate 列表一致，并补上账户/预算/
  /// 账本流水计数（恢复路径会改这三类数据，普通保存只改流水）。
  void _invalidateDataProviders() {
    // 流水
    ref.invalidate(recordMonthSummaryProvider);
    // 统计 4 个聚合
    ref.invalidate(statsLinePointsProvider);
    ref.invalidate(statsPieSlicesProvider);
    ref.invalidate(statsRankItemsProvider);
    ref.invalidate(statsHeatmapCellsProvider);
    // 账户
    ref.invalidate(accountsListProvider);
    ref.invalidate(accountBalancesProvider);
    ref.invalidate(totalAssetsProvider);
    // 预算
    ref.invalidate(activeBudgetsProvider);
    ref.invalidate(budgetableCategoriesProvider);
    ref.invalidate(budgetProgressForProvider);
    // 账本流水计数（账本列表卡显示）
    ref.invalidate(ledgerTxCountsProvider);
  }

  @override
  Widget build(BuildContext context) {
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
              icon: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              tooltip: context.l10n.syncRefreshStatus,
              onPressed: _busy ? null : () => _refresh(force: true),
            ),
          ],
        ),
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
                child: Text(context.l10n.syncStatusFetchFailed(snap.error.toString())),
              );
            }
            final status = snap.data!;
            return _StatusLine(status: status);
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text(context.l10n.syncUpload),
                onPressed: _busy ? null : _upload,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.cloud_download_outlined),
                label: Text(context.l10n.syncDownload),
                onPressed: _busy ? null : _download,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: context.l10n.syncDeleteCloudBackupShort,
              onPressed: _busy ? null : _deleteRemote,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status});

  final SyncStatus status;

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
            Text(_label(context), style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        if (tsLabel != null) ...[
          const SizedBox(height: 4),
          Text(context.l10n.syncLastSyncAt(tsLabel),
              style: Theme.of(context).textTheme.bodySmall),
        ],
        if (status.localCount != null && status.cloudCount != null) ...[
          const SizedBox(height: 4),
          Text(context.l10n.syncLocalCloudCount(status.localCount!, status.cloudCount!),
              style: Theme.of(context).textTheme.bodySmall),
        ],
        if (status.message != null && status.state == SyncState.error) ...[
          const SizedBox(height: 4),
          Text(status.message!,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}