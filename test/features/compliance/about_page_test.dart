import 'package:bianbianbianbian/features/compliance/about_page.dart';
import 'package:bianbianbianbian/features/compliance/privacy_consent_providers.dart';
import 'package:bianbianbianbian/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Step 17.3：[AboutPage] widget 测试。
///
/// `package_info_plus` 在 test 环境会通过 [BinaryMessenger] 与 platform
/// channel 通信，本测试用 `setMockMethodCallHandler` 注入固定回包，
/// 避免 [MissingPluginException] 把 FutureBuilder 卡在 loading。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GoRouter router;

  setUpAll(() {
    // mock package_info_plus 的 method channel：
    // 不同 plus 包版本走 'getAll' 或 'PackageInfo.getAll'，两个都注册。
    Future<Object?> handler(MethodCall call) async {
      return <String, dynamic>{
        'appName': '边边记账',
        'packageName': 'com.bianbianbianbian.bianbianbianbian',
        'version': '1.0.0',
        'buildNumber': '1',
        'buildSignature': '',
        'installerStore': null,
      };
    }

    TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      handler,
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      // 关于页只在"已同意"后才能进入；预置同意态。
      kPrivacyPolicyAcceptedVersionPrefKey: kCurrentPrivacyPolicyVersion,
    });

    router = GoRouter(
      initialLocation: '/about',
      routes: [
        GoRoute(path: '/about', builder: (c, s) => const AboutPage()),
        GoRoute(
          path: '/about/privacy',
          builder: (c, s) => const Scaffold(
            body: Center(child: Text('PRIVACY_PAGE_MARKER')),
          ),
        ),
        GoRoute(
          path: '/about/terms',
          builder: (c, s) => const Scaffold(
            body: Center(child: Text('TERMS_PAGE_MARKER')),
          ),
        ),
      ],
    );
  });

  Widget makeApp() {
    return ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
      ),
    );
  }

  testWidgets('AboutPage 渲染所有入口', (tester) async {
    await tester.pumpWidget(makeApp());
    await tester.pumpAndSettle();

    expect(find.text('边边记账'), findsWidgets); // header + AppBar title 可能多个
    expect(find.text('版本'), findsOneWidget);
    expect(find.text('隐私政策'), findsOneWidget);
    expect(find.text('用户协议'), findsOneWidget);
    expect(find.text('开源许可'), findsOneWidget);
    expect(find.text('撤回同意'), findsOneWidget);
  });

  testWidgets('版本号 ListTile 显示来自 mock 的值', (tester) async {
    await tester.pumpWidget(makeApp());
    await tester.pumpAndSettle();

    // mock 注入：version=1.0.0, build=1 → ARB 模板 '{version}（构建 {build}）'
    expect(find.text('1.0.0（构建 1）'), findsOneWidget);
  });

  testWidgets('点击"隐私政策"导航到详情页', (tester) async {
    await tester.pumpWidget(makeApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('隐私政策'));
    await tester.pumpAndSettle();

    expect(find.text('PRIVACY_PAGE_MARKER'), findsOneWidget);
  });

  testWidgets('点击"用户协议"导航到详情页', (tester) async {
    await tester.pumpWidget(makeApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('用户协议'));
    await tester.pumpAndSettle();

    expect(find.text('TERMS_PAGE_MARKER'), findsOneWidget);
  });

  testWidgets('点击"撤回同意"显示二次确认 dialog', (tester) async {
    await tester.pumpWidget(makeApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('撤回同意'));
    await tester.pumpAndSettle();

    expect(find.text('撤回同意？'), findsOneWidget);
    // ARB 中的取消按钮文本（context.l10n.cancel）
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('撤回并退出'), findsOneWidget);

    // 点取消应回到关于页
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('撤回同意？'), findsNothing);
    // 同意状态仍保留
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(kPrivacyPolicyAcceptedVersionPrefKey),
      kCurrentPrivacyPolicyVersion,
    );
  });
}
