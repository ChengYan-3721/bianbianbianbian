import 'package:flutter/material.dart';

import '../../core/l10n/l10n_ext.dart';
import 'policy_body.dart';

/// Step 17.3："我的 → 关于 → 用户协议"详情页。
///
/// 与 [PrivacyPolicyPage] 平级——通过共享 [TermsOfServiceBody] 保证
/// 与首次启动 [PrivacyConsentDialog] 中的协议正文一致。
class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.aboutTermsOfService),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: const TermsOfServiceBody(),
        ),
      ),
    );
  }
}
