// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_input_settings_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$aiInputEnhanceServiceHash() =>
    r'7ff42aa74f82e0a9a7568c0a3558b103ea712ec1';

/// Step 9.3：AI 增强服务 provider。`keepAlive` 保证同一 settings 期内
/// 服务实例稳定（不每帧新建 http.Client）。settings 变更（用户在配置页保
/// 存）会自动重建本 provider，[QuickConfirmCard] 看到的是新配置。
///
/// 测试可通过 `aiInputEnhanceServiceProvider.overrideWithValue(fakeService)`
/// 注入伪造服务（避免真实 HTTP 请求）。
///
/// Copied from [aiInputEnhanceService].
@ProviderFor(aiInputEnhanceService)
final aiInputEnhanceServiceProvider = Provider<AiInputEnhanceService>.internal(
  aiInputEnhanceService,
  name: r'aiInputEnhanceServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$aiInputEnhanceServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AiInputEnhanceServiceRef = ProviderRef<AiInputEnhanceService>;
String _$aiInputSettingsNotifierHash() =>
    r'b7b8d67e1a33775df05f784535e7ccf69cbcc1e5';

/// Step 9.3：AI 增强配置 AsyncNotifier provider。
///
/// 数据源是 `user_pref` 5 列。读路径在 [build] 一次性 load；写路径走 [save]
/// 持久化后 `invalidateSelf()`，UI 通过 `ref.watch(aiInputSettingsProvider)`
/// 自动响应。
///
/// 写入策略：
/// - [save] 接收一份完整的 [AiInputSettings] 快照，五列**全量覆盖**——这是
///   配置页的"保存"按钮语义，避免局部更新让 controller 与 DB 不一致。
/// - 字符串字段空值（empty / whitespace-only）一律落 NULL，便于
///   [hasMinimalConfig] 用 `isNotEmpty` 判断。
/// - API key 当前 V1 落 UTF-8 bytes 到 BLOB 列；Phase 11 会改为 BianbianCrypto
///   加密（届时同一列名 `ai_api_key_encrypted` 才真的"encrypted"）。
///
/// Copied from [AiInputSettingsNotifier].
@ProviderFor(AiInputSettingsNotifier)
final aiInputSettingsNotifierProvider =
    AsyncNotifierProvider<AiInputSettingsNotifier, AiInputSettings>.internal(
      AiInputSettingsNotifier.new,
      name: r'aiInputSettingsNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$aiInputSettingsNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AiInputSettingsNotifier = AsyncNotifier<AiInputSettings>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
