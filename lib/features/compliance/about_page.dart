import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/l10n/l10n_ext.dart';
import 'privacy_consent_providers.dart';

/// Step 17.3："我的 → 关于"页。
///
/// ListView 五项：
/// 1) 应用版本号——从 [PackageInfo.fromPlatform] 读取（test 环境下若插件未
///    bind 会抛 [MissingPluginException]，本页用 FutureBuilder 兜底显示 "—"）；
/// 2) 隐私政策 → [PrivacyPolicyPage]；
/// 3) 用户协议 → [TermsOfServicePage]；
/// 4) 开源许可 → Flutter 原生 [showLicensePage]；
/// 5) 撤回同意——红色文字，二次确认 AlertDialog 后调
///    [PrivacyConsent.revoke] 立即 [SystemNavigator.pop]。
///
/// "撤回同意 → 退出"组合保证：撤回后下次冷启动时 [PrivacyConsentGate]
/// 检查到 null 又会弹出同意页——满足 GDPR "随时可撤回"要求且语义闭环。
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.about)),
      body: SafeArea(
        child: ListView(
          children: [
            const _AppHeader(),
            const Divider(height: 1),
            FutureBuilder<PackageInfo>(
              future: _loadPackageInfo(),
              builder: (context, snapshot) {
                final info = snapshot.data;
                final value = info == null
                    ? '—'
                    : l10n.aboutAppVersionValue(
                        info.version,
                        info.buildNumber,
                      );
                return ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(l10n.aboutAppVersion),
                  trailing: Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(l10n.aboutPrivacyPolicy),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/about/privacy'),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(l10n.aboutTermsOfService),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/about/terms'),
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: Text(l10n.aboutLicenses),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLicenses(context),
            ),
            const Divider(),
            ListTile(
              leading: Icon(
                Icons.logout,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                l10n.aboutRevokeConsent,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              subtitle: Text(l10n.aboutRevokeConsentSubtitle),
              onTap: () => _confirmRevoke(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  /// PackageInfo 在 test 环境（无 platform channel）会抛
  /// [MissingPluginException]，统一吞回 null 让 UI 兜底 "—"。
  Future<PackageInfo> _loadPackageInfo() async {
    return PackageInfo.fromPlatform();
  }

  Future<void> _showLicenses(BuildContext context) async {
    final l10n = context.l10n;
    final appName = l10n.aboutAppName;
    final legalese = l10n.aboutLicensesLegalese;
    final info = await PackageInfo.fromPlatform().catchError(
      (_) => PackageInfo(
        appName: appName,
        packageName: '',
        version: '',
        buildNumber: '',
      ),
    );
    if (!context.mounted) return;
    showLicensePage(
      context: context,
      applicationName: appName,
      applicationVersion: info.version.isEmpty ? null : info.version,
      applicationLegalese: legalese,
    );
  }

  Future<void> _confirmRevoke(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.aboutRevokeConsentConfirmTitle),
        content: Text(l10n.aboutRevokeConsentConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.aboutRevokeConsentConfirm),
          ),
        ],
      ),
    );
    if (result != true) return;
    await ref.read(privacyConsentProvider.notifier).revoke();
    // Android 真正退出；iOS Apple HIG 不允许主动退出，系统忽略——
    // 但 gate 会立刻挡住主界面，用户只能看到隐私同意页。下次启动
    // 同样从 gate 重新开始流程。
    await SystemNavigator.pop();
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: const Center(
              child: Text('🐰', style: TextStyle(fontSize: 36)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.aboutAppName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.aboutAppTagline,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
