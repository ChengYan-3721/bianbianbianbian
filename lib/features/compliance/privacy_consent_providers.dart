import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'privacy_consent_providers.g.dart';

/// Step 17.3：当前应用要求生效的隐私政策版本。
///
/// 用户首次同意后，把这个字符串写到 [SharedPreferences] 的
/// [kPrivacyPolicyAcceptedVersionPrefKey] 上。日后若政策发生重大变更
/// （新增数据项、新增共享方、用途变化等），把这里的版本号往上调，
/// 即可触发"持有旧版本同意的老用户被再次征求同意"。
///
/// 与 ARB key `privacyConsentVersionValue` 中展示给用户的版本字符串
/// 一一对应（'1.0' / '2.0' / ...）。
const String kCurrentPrivacyPolicyVersion = '1.0';

/// Step 17.3：SharedPreferences key，存"用户上次同意的隐私政策版本号"。
///
/// 选 SharedPreferences 而非 user_pref 表是为了：
/// 1) 与 [IdleReminderShownDate] 同走轻量 prefs 路径，免一次 schema 迁移；
/// 2) 同步恢复 DB 到新机时，新设备不会"自动继承"老设备的同意状态——
///    PIPL/GDPR 都要求每台设备独立同意，prefs 不参与同步是正确语义。
const String kPrivacyPolicyAcceptedVersionPrefKey =
    'privacy_policy_accepted_version';

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
@Riverpod(keepAlive: true)
class PrivacyConsent extends _$PrivacyConsent {
  @override
  Future<String?> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kPrivacyPolicyAcceptedVersionPrefKey);
  }

  /// 用户点击"同意并继续"。写当前版本号 + 同步刷新 state。
  Future<void> accept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kPrivacyPolicyAcceptedVersionPrefKey,
      kCurrentPrivacyPolicyVersion,
    );
    state = const AsyncValue.data(kCurrentPrivacyPolicyVersion);
  }

  /// "我的 → 关于 → 撤回同意"。删除 key + 同步刷新 state。
  /// 调用方应在 `await` 后立即 `SystemNavigator.pop()`。
  Future<void> revoke() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kPrivacyPolicyAcceptedVersionPrefKey);
    state = const AsyncValue.data(null);
  }
}
