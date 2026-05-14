// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'privacy_consent_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$privacyConsentHash() => r'8452ebc2797bc8c24de44dfb1705773fad713f31';

/// Step 17.3：隐私政策同意状态 provider。
///
/// 建模为 `Future<String?>`：
/// - `null` —— 从未同意（首次启动 / 老用户首次升级到含本步骤的版本）；
/// - 非 null —— 用户上次同意的版本字符串（如 '1.0'）。
///
/// 消费方判断"已同意当前版本"应比对 [kCurrentPrivacyPolicyVersion]——
/// 而不是简单地 `!= null`，否则将来政策升版后无法触发再次征求同意。
///
/// 写路径：
/// - [accept] —— 写入 [kCurrentPrivacyPolicyVersion]；
/// - [revoke] —— 删除 key（用于"撤回同意"，调用方负责其后退出应用）。
///
/// `keepAlive: true` 让 provider 跨页面持有同一 cache，避免每次进入
/// 「我的 → 关于」都重新 await SharedPreferences。
///
/// Copied from [PrivacyConsent].
@ProviderFor(PrivacyConsent)
final privacyConsentProvider =
    AsyncNotifierProvider<PrivacyConsent, String?>.internal(
      PrivacyConsent.new,
      name: r'privacyConsentProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$privacyConsentHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$PrivacyConsent = AsyncNotifier<String?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
