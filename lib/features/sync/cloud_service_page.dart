import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_cloud_sync_icloud/flutter_cloud_sync_icloud.dart';
import 'package:intl/intl.dart';

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
        title: const Text('云服务'),
      ),
      body: activeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('错误: $e')),
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
                  title: const Text('启用云同步'),
                  subtitle: Text(cloudEnabled
                      ? '当前后端：${active.name}'
                      : '关闭中——数据仅保存在本机'),
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
                  defaultText: '自托管 WebDAV 服务',
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
                title: 'S3 兼容存储',
                subtitle: _cardSubtitle(
                  defaultText: 'Cloudflare R2, AWS S3, MinIO 等',
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
                  defaultText: '使用 Supabase 后端',
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
    required String defaultText,
    required AsyncValue<CloudServiceConfig?> cfgAsync,
    required bool isFailed,
  }) {
    if (isFailed) return '上次连接测试失败，点击右侧设置重新配置';
    return cfgAsync.maybeWhen(
      data: (cfg) =>
          cfg == null || !cfg.valid ? '$defaultText（未配置）' : defaultText,
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
      subtitle: '使用 iCloud Drive 同步',
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
            const SnackBar(content: Text('iCloud 不可用，请检查系统设置')),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('切换云服务?'),
        content: const Text('切换服务后，需要重新进行首次同步。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认'),
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
          title: const Text('迁移附件到新后端？'),
          content: Text(
            '当前后端已上传 $remoteAttachments 张附件。\n\n'
            '切换后新附件会上传到 ${_typeLabel(type)}，但已在旧后端的附件不会跨设备访问。\n\n'
            '选择"迁移"会在下次同步时把这些附件重新上传到新后端（耗时较长，'
            '取决于网络与图片数量）；选择"暂不迁移"则旧附件保留在旧后端，'
            '可稍后切回去再用。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('暂不迁移'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('迁移'),
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
                    '切换失败：${_typeLabel(type)} 尚未配置，请先点击右侧设置图标完成配置')),
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
            ? '已切换到 ${_typeLabel(type)}（已标记 $migratedRows 条流水的附件待重传）'
            : '已切换到 ${_typeLabel(type)}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('切换失败: $e')),
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
          title: const Text('关闭云同步?'),
          content: const Text('关闭后将仅使用本机数据，已上传到云端的备份不受影响。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('关闭'),
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
          const SnackBar(content: Text('云同步已关闭')),
        );
      }
      return;
    }

    final restored = await store.reactivateLast() ?? await store.findFirstReady();
    if (restored == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先在下方任选一个云服务并完成配置')),
        );
      }
      return;
    }
    ref.invalidate(activeCloudConfigProvider);
    ref.invalidate(authServiceProvider);
    ref.invalidate(syncServiceProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已启用云同步：${_typeLabel(restored)}')),
      );
    }
  }

  String _typeLabel(CloudBackendType type) {
    switch (type) {
      case CloudBackendType.local:
        return '本地存储';
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
                  ? '配置已保存并通过连接测试'
                  : '配置已保存，但连接测试失败：$testError'),
              duration: testError == null
                  ? const Duration(seconds: 3)
                  : const Duration(seconds: 6),
            ),
          );
        }
      } else {
        throw Exception('配置无效');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  /// 真实跑一次 provider 初始化，验证配置可用。务必 dispose 释放底层连接。
  /// 返回正常即视为通过；任何异常（含 timeout）由调用方捕获并写入 failed 集。
  Future<void> _testConnection(CloudServiceConfig cfg) async {
    CloudProvider? provider;
    try {
      final services = await createCloudServices(cfg);
      provider = services.provider;
      if (provider == null) {
        throw Exception('Provider 初始化返回空');
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
      title: const Text('配置 Supabase'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _customNameController,
            decoration: const InputDecoration(
              labelText: '自定义名称',
              hintText: '用作卡片标题（可选）',
            ),
          ),
          TextField(controller: _urlController, decoration: const InputDecoration(labelText: 'URL')),
          TextField(controller: _keyController, decoration: const InputDecoration(labelText: 'Anon Key')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop({
              'url': _urlController.text,
              'key': _keyController.text,
              'customName': _customNameController.text,
            });
          },
          child: const Text('保存'),
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
      title: const Text('配置 WebDAV'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _customNameController,
            decoration: const InputDecoration(
              labelText: '自定义名称',
              hintText: '用作卡片标题（可选）',
            ),
          ),
          TextField(controller: _urlController, decoration: const InputDecoration(labelText: 'URL')),
          TextField(controller: _usernameController, decoration: const InputDecoration(labelText: '用户名')),
          TextField(controller: _passwordController, decoration: const InputDecoration(labelText: '密码'), obscureText: true),
          TextField(controller: _pathController, decoration: const InputDecoration(labelText: '远程路径')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
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
          child: const Text('保存'),
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
      title: const Text('配置 S3'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _customNameController,
              decoration: const InputDecoration(
                labelText: '自定义名称',
                hintText: '用作卡片标题与云端文件夹名（可选）',
              ),
            ),
            TextField(controller: _endpointController, decoration: const InputDecoration(labelText: 'Endpoint')),
            TextField(controller: _regionController, decoration: const InputDecoration(labelText: 'Region')),
            TextField(controller: _accessKeyController, decoration: const InputDecoration(labelText: 'Access Key')),
            TextField(controller: _secretKeyController, decoration: const InputDecoration(labelText: 'Secret Key'), obscureText: true),
            TextField(controller: _bucketController, decoration: const InputDecoration(labelText: 'Bucket')),
            TextField(controller: _portController, decoration: const InputDecoration(labelText: 'Port (可选)'), keyboardType: TextInputType.number),
            SwitchListTile(
              title: const Text('Use SSL'),
              value: _useSSL,
              onChanged: (value) => setState(() => _useSSL = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
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
          child: const Text('保存'),
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
          error: (e, _) => Text('账本加载失败：$e'),
          data: (ledgerId) => syncAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('同步服务初始化失败：$e'),
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
        SnackBar(content: Text('操作失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() => _runWithBusy(
        () => widget.service.upload(ledgerId: widget.ledgerId),
        successMessage: '已上传到云端',
      );

  Future<void> _download() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('从云端恢复'),
        content: const Text(
            '当前账本的本地流水与预算将被云端备份覆盖（categories/accounts 仅 upsert）。继续？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('恢复')),
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
          SnackBar(content: Text('已恢复 $inserted 条流水')),
        );
      },
      successMessage: '已从云端恢复',
    );
  }

  Future<void> _deleteRemote() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除云端备份'),
        content: const Text('云端的此账本备份将被删除。本地数据不受影响。继续？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('删除')),
        ],
      ),
    );
    if (confirmed != true) return;
    return _runWithBusy(
      () => widget.service.deleteRemote(ledgerId: widget.ledgerId),
      successMessage: '云端备份已删除',
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
              tooltip: '刷新状态',
              onPressed: _busy ? null : () => _refresh(force: true),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FutureBuilder<SyncStatus>(
          future: _statusFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('正在获取云端状态…'),
              );
            }
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('状态获取失败：${snap.error}'),
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
                label: const Text('上传'),
                onPressed: _busy ? null : _upload,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('下载'),
                onPressed: _busy ? null : _download,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '删除云端备份',
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

  String _label() {
    switch (status.state) {
      case SyncState.notConfigured:
        return '未配置';
      case SyncState.notAuthenticated:
        return '未登录';
      case SyncState.localOnly:
        return '云端无备份';
      case SyncState.synced:
        return '已同步';
      case SyncState.outOfSync:
        if (status.isLocalNewer) return '本地较新（建议上传）';
        if (status.isCloudNewer) return '云端较新（建议下载）';
        return '本地与云端不一致';
      case SyncState.uploading:
        return '上传中…';
      case SyncState.downloading:
        return '下载中…';
      case SyncState.error:
        return '错误';
      case SyncState.unknown:
        return '未知';
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
            Text(_label(), style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        if (tsLabel != null) ...[
          const SizedBox(height: 4),
          Text('上次同步：$tsLabel',
              style: Theme.of(context).textTheme.bodySmall),
        ],
        if (status.localCount != null && status.cloudCount != null) ...[
          const SizedBox(height: 4),
          Text('本地 ${status.localCount} · 云端 ${status.cloudCount}',
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