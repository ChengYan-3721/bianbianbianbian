import 'package:shared_preferences/shared_preferences.dart';
import 'cloud_service_config.dart';

/// 云服务配置持久化存储
/// 支持类型: 本地存储、BeeCount Cloud、自定义 Supabase、自定义 WebDAV、iCloud、S3
class CloudServiceStore {
  static const _kActiveType =
      'cloud_active_type'; // local | beecount_cloud | supabase | webdav | icloud | s3
  // 全局开关关闭时（切回 local），把当前激活的非 local 类型记到这里，方便
  // 重新打开开关时一键恢复，避免用户再去逐个挑选 / 重新配置。
  static const _kLastActiveType = 'cloud_last_active_type';
  // 持久化"配置已保存但最近一次连接测试失败"的后端集合（逗号分隔的枚举名）。
  // UI 据此把卡片置灰；保存配置后再次测试通过会从集合移除。语义是"已知失败"，
  // 因此从未测过的配置不在集合里——保持向后兼容（旧配置默认视为 ready）。
  static const _kFailedBackends = 'cloud_failed_backends';
  static const _kBeeCountCloudCfg = 'cloud_beecount_cloud_cfg';
  static const _kSupabaseCfg = 'cloud_supabase_cfg';
  static const _kWebdavCfg = 'cloud_webdav_cfg';
  static const _kS3Cfg = 'cloud_s3_cfg';

  /// 加载当前激活的云服务配置
  Future<CloudServiceConfig> loadActive() async {
    final sp = await SharedPreferences.getInstance();
    final activeType = sp.getString(_kActiveType) ?? 'local';

    switch (activeType) {
      case 'local':
        return CloudServiceConfig.localStorage();

      case 'beecount_cloud':
        final raw = sp.getString(_kBeeCountCloudCfg);
        if (raw != null) {
          try {
            return decodeCloudConfig(raw);
          } catch (e) {
            // 解析失败，静默回退到本地存储
          }
        }
        return CloudServiceConfig.localStorage();

      case 'supabase':
        final raw = sp.getString(_kSupabaseCfg);
        if (raw != null) {
          try {
            return decodeCloudConfig(raw);
          } catch (e) {
            // 解析失败，静默回退到本地存储
          }
        }
        // 回退到本地存储
        return CloudServiceConfig.localStorage();

      case 'webdav':
        final raw = sp.getString(_kWebdavCfg);
        if (raw != null) {
          try {
            return decodeCloudConfig(raw);
          } catch (e) {
            // 解析失败，静默回退到本地存储
          }
        }
        // 回退到本地存储
        return CloudServiceConfig.localStorage();

      case 'icloud':
        // iCloud 无需额外配置，返回 iCloud 类型的配置
        return const CloudServiceConfig(
          type: CloudBackendType.icloud,
          name: 'iCloud',
        );

      case 's3':
        final raw = sp.getString(_kS3Cfg);
        if (raw != null) {
          try {
            return decodeCloudConfig(raw);
          } catch (e) {
            // 解析失败，静默回退到本地存储
          }
        }
        // 回退到本地存储
        return CloudServiceConfig.localStorage();

      default:
        return CloudServiceConfig.localStorage();
    }
  }

  /// 加载 BeeCount Cloud 配置(不管是否激活)
  Future<CloudServiceConfig?> loadBeeCountCloud() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kBeeCountCloudCfg);
    if (raw == null) return null;
    try {
      return decodeCloudConfig(raw);
    } catch (e) {
      return null;
    }
  }

  /// 加载Supabase配置(不管是否激活)
  Future<CloudServiceConfig?> loadSupabase() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kSupabaseCfg);
    if (raw == null) return null;
    try {
      return decodeCloudConfig(raw);
    } catch (e) {
      return null;
    }
  }

  /// 加载WebDAV配置(不管是否激活)
  Future<CloudServiceConfig?> loadWebdav() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kWebdavCfg);
    if (raw == null) return null;
    try {
      return decodeCloudConfig(raw);
    } catch (e) {
      return null;
    }
  }

  /// 加载S3配置(不管是否激活)
  Future<CloudServiceConfig?> loadS3() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kS3Cfg);
    if (raw == null) return null;
    try {
      return decodeCloudConfig(raw);
    } catch (e) {
      return null;
    }
  }

  /// 保存并激活配置
  Future<void> saveAndActivate(CloudServiceConfig cfg) async {
    final sp = await SharedPreferences.getInstance();

    switch (cfg.type) {
      case CloudBackendType.local:
        await sp.setString(_kActiveType, 'local');
        // Provider 会在下次使用时自动初始化
        break;

      case CloudBackendType.beecountCloud:
        await sp.setString(_kBeeCountCloudCfg, encodeCloudConfig(cfg));
        await sp.setString(_kActiveType, 'beecount_cloud');
        break;

      case CloudBackendType.supabase:
        await sp.setString(_kSupabaseCfg, encodeCloudConfig(cfg));
        await sp.setString(_kActiveType, 'supabase');
        // Provider 会在下次使用时自动初始化
        break;

      case CloudBackendType.webdav:
        await sp.setString(_kWebdavCfg, encodeCloudConfig(cfg));
        await sp.setString(_kActiveType, 'webdav');
        // Provider 会在下次使用时自动初始化
        break;

      case CloudBackendType.icloud:
        await sp.setString(_kActiveType, 'icloud');
        // iCloud 无需额外配置，Provider 会在下次使用时自动初始化
        break;

      case CloudBackendType.s3:
        await sp.setString(_kS3Cfg, encodeCloudConfig(cfg));
        await sp.setString(_kActiveType, 's3');
        // Provider 会在下次使用时自动初始化
        break;
    }
  }

  /// 仅保存配置,不激活
  Future<void> saveOnly(CloudServiceConfig cfg) async {
    final sp = await SharedPreferences.getInstance();

    switch (cfg.type) {
      case CloudBackendType.local:
        // 本地存储无需保存
        break;

      case CloudBackendType.beecountCloud:
        await sp.setString(_kBeeCountCloudCfg, encodeCloudConfig(cfg));
        break;

      case CloudBackendType.supabase:
        await sp.setString(_kSupabaseCfg, encodeCloudConfig(cfg));
        break;

      case CloudBackendType.webdav:
        await sp.setString(_kWebdavCfg, encodeCloudConfig(cfg));
        break;

      case CloudBackendType.icloud:
        // iCloud 无需保存额外配置
        break;

      case CloudBackendType.s3:
        await sp.setString(_kS3Cfg, encodeCloudConfig(cfg));
        break;
    }
  }

  /// 激活指定类型的配置
  Future<bool> activate(CloudBackendType type) async {
    final sp = await SharedPreferences.getInstance();

    switch (type) {
      case CloudBackendType.local:
        await sp.setString(_kActiveType, 'local');
        return true;

      case CloudBackendType.beecountCloud:
        final raw = sp.getString(_kBeeCountCloudCfg);
        if (raw == null) return false;
        try {
          final cfg = decodeCloudConfig(raw);
          if (!cfg.valid) return false;
          await sp.setString(_kActiveType, 'beecount_cloud');
          return true;
        } catch (e) {
          return false;
        }

      case CloudBackendType.supabase:
        final raw = sp.getString(_kSupabaseCfg);
        if (raw == null) return false;
        try {
          final cfg = decodeCloudConfig(raw);
          if (!cfg.valid) return false;
          await sp.setString(_kActiveType, 'supabase');
          return true;
        } catch (e) {
          return false;
        }

      case CloudBackendType.webdav:
        final raw = sp.getString(_kWebdavCfg);
        if (raw == null) return false;
        try {
          final cfg = decodeCloudConfig(raw);
          if (!cfg.valid) return false;
          await sp.setString(_kActiveType, 'webdav');
          return true;
        } catch (e) {
          return false;
        }

      case CloudBackendType.icloud:
        // iCloud 无需配置，直接激活
        await sp.setString(_kActiveType, 'icloud');
        return true;

      case CloudBackendType.s3:
        final raw = sp.getString(_kS3Cfg);
        if (raw == null) return false;
        try {
          final cfg = decodeCloudConfig(raw);
          if (!cfg.valid) return false;
          await sp.setString(_kActiveType, 's3');
          return true;
        } catch (e) {
          return false;
        }
    }
  }

  /// 关闭云同步：切到本地，并把当前的非 local 类型记到 [_kLastActiveType]。
  /// 后续 [reactivateLast] 可一键恢复，避免用户重新挑选。
  /// 已经是 local 时仅作幂等处理（不覆盖已存的 last）。
  Future<void> disableCloudSync() async {
    final sp = await SharedPreferences.getInstance();
    final prev = sp.getString(_kActiveType);
    if (prev != null && prev != 'local') {
      await sp.setString(_kLastActiveType, prev);
    }
    await sp.setString(_kActiveType, 'local');
  }

  /// 还原 [disableCloudSync] 之前的激活类型。
  /// - 找不到 last 记录 → null；
  /// - last 记录指向的配置已失效 / 缺失 → null（让 UI 提示"请先配置"）；
  /// - 成功激活 → 返回对应 [CloudBackendType]。
  Future<CloudBackendType?> reactivateLast() async {
    final sp = await SharedPreferences.getInstance();
    final last = sp.getString(_kLastActiveType);
    if (last == null || last == 'local') return null;
    final type = _parseTypeName(last);
    if (type == null) return null;
    final ok = await activate(type);
    return ok ? type : null;
  }

  /// 把持久化字符串还原成 [CloudBackendType]。与 [_kActiveType] 写入约定一致：
  /// 大多数枚举名直接匹配，唯独 `beecountCloud` 落盘成 `beecount_cloud`。
  CloudBackendType? _parseTypeName(String name) {
    if (name == 'beecount_cloud') return CloudBackendType.beecountCloud;
    for (final t in CloudBackendType.values) {
      if (t.name == name) return t;
    }
    return null;
  }

  /// 记录后端的连接测试结果。
  /// - `success=true`：从失败集合中移除（如果在的话），表示"已知 ready"；
  /// - `success=false`：加入失败集合，UI 会把卡片置灰直到下次测试通过。
  Future<void> markBackendTested({
    required CloudBackendType type,
    required bool success,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final current = _decodeFailedSet(sp.getString(_kFailedBackends));
    final changed = success ? current.remove(type.name) : current.add(type.name);
    if (!changed) return;
    if (current.isEmpty) {
      await sp.remove(_kFailedBackends);
    } else {
      await sp.setString(_kFailedBackends, current.join(','));
    }
  }

  /// 当前已知"测试失败"的后端集合。
  Future<Set<CloudBackendType>> failedBackends() async {
    final sp = await SharedPreferences.getInstance();
    final names = _decodeFailedSet(sp.getString(_kFailedBackends));
    final result = <CloudBackendType>{};
    for (final n in names) {
      final t = _parseTypeName(n);
      if (t != null) result.add(t);
    }
    return result;
  }

  Set<String> _decodeFailedSet(String? raw) {
    if (raw == null || raw.isEmpty) return <String>{};
    return raw.split(',').where((s) => s.isNotEmpty).toSet();
  }

  /// 全局开关 ON 路径的兜底：按 s3 > supabase > webdav 顺序找首个"配置有效且
  /// 未被标记测试失败"的后端，激活并返回。仅在 [reactivateLast] 找不到记录
  /// （例如首次配置）时使用，避免在用户已有偏好时覆盖它。
  /// iCloud 默认不参与扫描——iOS 上想用 iCloud 应让用户显式点卡片。
  Future<CloudBackendType?> findFirstReady() async {
    final failed = await failedBackends();
    final candidates = <CloudBackendType>[
      CloudBackendType.s3,
      CloudBackendType.supabase,
      CloudBackendType.webdav,
    ];
    for (final t in candidates) {
      if (failed.contains(t)) continue;
      if (await activate(t)) return t;
    }
    return null;
  }
}
