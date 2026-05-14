import 'package:flutter/material.dart';

import '../../core/l10n/l10n_ext.dart';
import 'policy_body.dart';

/// Step 17.3："我的 → 关于 → 隐私政策"详情页。
///
/// 与首次启动的 [PrivacyConsentDialog] 内容一致——通过共享 [PrivacyPolicyBody]
/// 保证两处文本永不漂移。区别仅在：本页面通过 AppBar 提供返回，作为常规
/// 路由页面渲染（已同意用户在 gate 之内进入）。
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.aboutPrivacyPolicy),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: const PrivacyPolicyBody(),
        ),
      ),
    );
  }
}
