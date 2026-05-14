import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'privacy_consent_dialog.dart';
import 'privacy_consent_providers.dart';

/// Step 17.3：套在 [MaterialApp.router] builder 链中，未同意当前版本
/// 隐私政策时强制展示 [PrivacyConsentDialog]，已同意则透传 child。
///
/// 与 [_AppLockGate]（lib/app/app.dart）平级嵌套——本 gate 应位于
/// 锁屏 gate 之外（更靠 root），保证"首次同意"先于"应用锁解锁"，
/// 避免新装用户被 PIN 弹屏卡死却无法看到隐私政策。
///
/// 与 [_BootstrapErrorApp] 路径完全独立：bootstrap 失败走兜底页，
/// 不经过本 gate；本 gate 仅在 bootstrap 成功后才被嵌入 widget 树。
///
/// `consent` 的 [AsyncValue] 三态处理：
/// - `data(version == kCurrentPrivacyPolicyVersion)` → 透传 child；
/// - `data(其他)`（含 null） → 渲染 [PrivacyConsentDialog]；
/// - `loading` —— main.dart 已预热，理论极短；显示空底色避免内容闪烁；
/// - `error` —— SharedPreferences 异常等极端场景，按"未同意"处理，
///    避免读失败时绕过门控。
class PrivacyConsentGate extends ConsumerWidget {
  const PrivacyConsentGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consent = ref.watch(privacyConsentProvider);
    return consent.when(
      data: (acceptedVersion) {
        if (acceptedVersion == kCurrentPrivacyPolicyVersion) {
          return child;
        }
        return const PrivacyConsentDialog();
      },
      loading: () => _LoadingShim(
        background: Theme.of(context).colorScheme.surface,
      ),
      error: (_, _) => const PrivacyConsentDialog(),
    );
  }
}

class _LoadingShim extends StatelessWidget {
  const _LoadingShim({required this.background});

  final Color background;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
