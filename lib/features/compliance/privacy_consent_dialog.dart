import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_ext.dart';
import 'policy_body.dart';
import 'privacy_consent_providers.dart';

/// Step 17.3：首次启动展示的"隐私政策与用户协议"同意页。
///
/// 不用 [showDialog]——而是作为完整 Scaffold 直接由 [PrivacyConsentGate]
/// 替代主界面渲染。理由：
/// 1) 内容较长（隐私政策 7 段 + 用户协议 4 段），AlertDialog 高度受限；
/// 2) gate 完全遮挡主界面，"未同意时绝不让 UI 浮现"的语义最直接；
/// 3) 路由还未稳定时调 showDialog 容易触发 GlobalKey 重复等断言。
///
/// **"不同意"二次确认用 Stack overlay 而非 showDialog**：本页位于
/// `MaterialApp.router.builder` 链中 router 内部 [Navigator] 之外，
/// [showDialog] 沿 widget tree 向上找不到 Navigator 会抛
/// `Navigator operation requested with a context that does not include
/// a Navigator`。本页只是一个全屏挡板，没有导航需求，setState +
/// `Stack` 配合半透明遮罩 + 卡片就够；同时也避开"未同意时却创建了
/// 命名路由栈"的语义模糊。
///
/// "退出"动作走 [SystemNavigator.pop]：Android 真正关闭 Activity；
/// iOS Apple HIG 不允许主动退出，系统忽略——但 gate 仍挡在最外层，
/// 用户只能继续点"同意"或杀进程。
class PrivacyConsentDialog extends ConsumerStatefulWidget {
  const PrivacyConsentDialog({super.key});

  @override
  ConsumerState<PrivacyConsentDialog> createState() =>
      _PrivacyConsentDialogState();
}

class _PrivacyConsentDialogState extends ConsumerState<PrivacyConsentDialog> {
  bool _showRejectConfirm = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        _buildMainPage(theme),
        if (_showRejectConfirm) _buildRejectConfirmOverlay(theme),
      ],
    );
  }

  Widget _buildMainPage(ThemeData theme) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.privacyConsentTitle,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PrivacyPolicyBody(),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      height: 1,
                      color: theme.dividerColor,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.termsOfServiceTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const TermsOfServiceBody(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          setState(() => _showRejectConfirm = true),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(l10n.privacyConsentReject),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () =>
                          ref.read(privacyConsentProvider.notifier).accept(),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(l10n.privacyConsentAccept),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 半透明遮罩 + 居中卡片，模拟 AlertDialog 视觉但完全本地渲染——
  /// 不沿用 [showDialog] 是因为本页处于 router Navigator 之外。
  Widget _buildRejectConfirmOverlay(ThemeData theme) {
    final l10n = context.l10n;
    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.privacyConsentRejectAlertTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.privacyConsentRejectAlertMessage,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () =>
                            setState(() => _showRejectConfirm = false),
                        child: Text(l10n.privacyConsentRejectAlertReread),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          // Android 真正关闭 Activity；iOS Apple HIG 不允许
                          // 主动退出，系统将忽略此调用——gate 仍挡在最外层，
                          // 用户只能继续阅读或同意。
                          await SystemNavigator.pop();
                        },
                        child: Text(l10n.privacyConsentRejectAlertExit),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
