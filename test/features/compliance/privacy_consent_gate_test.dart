import 'package:bianbianbianbian/features/compliance/privacy_consent_dialog.dart';
import 'package:bianbianbianbian/features/compliance/privacy_consent_gate.dart';
import 'package:bianbianbianbian/features/compliance/privacy_consent_providers.dart';
import 'package:bianbianbianbian/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Step 17.3：[PrivacyConsentGate] + [PrivacyConsentDialog] widget 测试。
///
/// 不通过完整 [BianBianApp] 启动——只挂裸 gate + 子 marker，便于精确断言
/// "未同意时 child 不渲染 / 同意后 child 渲染"。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget makeApp({required Widget child}) {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: PrivacyConsentGate(child: child),
      ),
    );
  }

  const childMarker = Key('post-consent-child');

  group('PrivacyConsentGate', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('未同意时显示同意页，主界面被遮挡', (tester) async {
      await tester.pumpWidget(
        makeApp(child: const SizedBox(key: childMarker)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PrivacyConsentDialog), findsOneWidget);
      expect(find.byKey(childMarker), findsNothing);

      // 关键按钮存在
      expect(find.text('同意并继续'), findsOneWidget);
      expect(find.text('不同意'), findsOneWidget);
    });

    testWidgets('点击"同意并继续"后 child 渲染', (tester) async {
      await tester.pumpWidget(
        makeApp(child: const SizedBox(key: childMarker)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('同意并继续'));
      await tester.pumpAndSettle();

      expect(find.byType(PrivacyConsentDialog), findsNothing);
      expect(find.byKey(childMarker), findsOneWidget);

      // 验证 SharedPreferences 写入。
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(kPrivacyPolicyAcceptedVersionPrefKey),
        kCurrentPrivacyPolicyVersion,
      );
    });

    testWidgets('点击"不同意"显示二次确认 dialog', (tester) async {
      await tester.pumpWidget(
        makeApp(child: const SizedBox(key: childMarker)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('不同意'));
      await tester.pumpAndSettle();

      // 二次确认 dialog
      expect(find.text('未同意将无法使用'), findsOneWidget);
      expect(find.text('再次阅读'), findsOneWidget);
      expect(find.text('退出'), findsOneWidget);

      // 点"再次阅读"应回到政策页面，child 仍未渲染
      await tester.tap(find.text('再次阅读'));
      await tester.pumpAndSettle();
      expect(find.byType(PrivacyConsentDialog), findsOneWidget);
      expect(find.byKey(childMarker), findsNothing);
    });

    testWidgets('已同意（mock prefs 预置版本号）时直接渲染 child', (tester) async {
      SharedPreferences.setMockInitialValues({
        kPrivacyPolicyAcceptedVersionPrefKey: kCurrentPrivacyPolicyVersion,
      });

      await tester.pumpWidget(
        makeApp(child: const SizedBox(key: childMarker)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PrivacyConsentDialog), findsNothing);
      expect(find.byKey(childMarker), findsOneWidget);
    });

    testWidgets('持有旧版本号时按"未同意"处理（gate 仍展示同意页）',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        kPrivacyPolicyAcceptedVersionPrefKey: 'legacy-0.9',
      });

      await tester.pumpWidget(
        makeApp(child: const SizedBox(key: childMarker)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PrivacyConsentDialog), findsOneWidget);
      expect(find.byKey(childMarker), findsNothing);
    });

    testWidgets('同意页渲染了主要段落标题', (tester) async {
      await tester.pumpWidget(
        makeApp(child: const SizedBox(key: childMarker)),
      );
      await tester.pumpAndSettle();

      // PIPL/GDPR 通用要点中的若干小标题应出现
      expect(find.text('我们收集哪些数据'), findsOneWidget);
      expect(find.text('数据用途'), findsOneWidget);
      expect(find.text('存储位置'), findsOneWidget);
      expect(find.text('数据共享'), findsOneWidget);
      expect(find.text('您的权利'), findsOneWidget);
      expect(find.text('联系方式'), findsOneWidget);

      // 用户协议正文也在弹窗中（首次启动一并展示）
      expect(find.text('使用许可'), findsOneWidget);
      expect(find.text('用户责任'), findsOneWidget);
      expect(find.text('免责声明'), findsOneWidget);
    });
  });
}
