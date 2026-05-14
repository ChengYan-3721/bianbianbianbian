import 'package:flutter/material.dart';

import '../../core/l10n/l10n_ext.dart';

/// Step 17.3：隐私政策正文的共享渲染组件。
///
/// 同时被首次启动的 [PrivacyConsentDialog] 与"我的 → 关于 → 隐私政策"
/// 详情页 [PrivacyPolicyPage] 消费——保证两处文本完全一致，避免
/// "弹窗版本 vs 关于页版本"漂移。
///
/// 段落结构对应 ARB key 的 `privacyConsent*` 系列，覆盖 PIPL（个人信息
/// 保护法）+ GDPR 通用要求：数据项 / 用途 / 存储位置 / 共享方 / 用户权
/// 利 / 联系方式 + 版本号。
///
/// 故意不引入 flutter_markdown：纯 Flutter Text + Padding + 居左对齐
/// 足够呈现段落式条款；少一个依赖 = 少一个潜在风险面。
class PrivacyPolicyBody extends StatelessWidget {
  const PrivacyPolicyBody({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.privacyConsentIntro,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        _Section(
          title: l10n.privacyConsentDataSectionTitle,
          body: l10n.privacyConsentDataSectionBody,
        ),
        _Section(
          title: l10n.privacyConsentUsageSectionTitle,
          body: l10n.privacyConsentUsageSectionBody,
        ),
        _Section(
          title: l10n.privacyConsentStorageSectionTitle,
          body: l10n.privacyConsentStorageSectionBody,
        ),
        _Section(
          title: l10n.privacyConsentSharingSectionTitle,
          body: l10n.privacyConsentSharingSectionBody,
        ),
        _Section(
          title: l10n.privacyConsentRightsSectionTitle,
          body: l10n.privacyConsentRightsSectionBody,
        ),
        _Section(
          title: l10n.privacyConsentContactSectionTitle,
          body: l10n.privacyConsentContactSectionBody,
        ),
        const SizedBox(height: 12),
        Text(
          '${l10n.privacyConsentVersionLabel}：${l10n.privacyConsentVersionValue}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

/// Step 17.3：用户协议正文的共享渲染组件。
///
/// 与 [PrivacyPolicyBody] 平级——同时被 [PrivacyConsentDialog]（首次
/// 启动一并展示）与 [TermsOfServicePage]（关于页详情）消费。
class TermsOfServiceBody extends StatelessWidget {
  const TermsOfServiceBody({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.termsOfServiceIntro,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        _Section(
          title: l10n.termsOfServiceLicenseSectionTitle,
          body: l10n.termsOfServiceLicenseSectionBody,
        ),
        _Section(
          title: l10n.termsOfServiceResponsibilitySectionTitle,
          body: l10n.termsOfServiceResponsibilitySectionBody,
        ),
        _Section(
          title: l10n.termsOfServiceDisclaimerSectionTitle,
          body: l10n.termsOfServiceDisclaimerSectionBody,
        ),
        const SizedBox(height: 12),
        Text(
          '${l10n.termsOfServiceVersionLabel}：${l10n.termsOfServiceVersionValue}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                ),
          ),
        ],
      ),
    );
  }
}
