import 'package:bianbianbianbian/features/compliance/privacy_consent_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer makeContainer() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  group('privacyConsentProvider', () {
    setUp(() {
      // 每个用例独立的 prefs 沙箱。
      SharedPreferences.setMockInitialValues({});
    });

    test('首次启动：未同意（值为 null）', () async {
      final c = makeContainer();
      final v = await c.read(privacyConsentProvider.future);
      expect(v, isNull);
    });

    test('accept() 写入 kCurrentPrivacyPolicyVersion 并刷新 state', () async {
      final c = makeContainer();
      await c.read(privacyConsentProvider.future); // 预热
      await c.read(privacyConsentProvider.notifier).accept();
      final v = await c.read(privacyConsentProvider.future);
      expect(v, kCurrentPrivacyPolicyVersion);

      // 直接验证 SharedPreferences 也写入了。
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(kPrivacyPolicyAcceptedVersionPrefKey),
        kCurrentPrivacyPolicyVersion,
      );
    });

    test('revoke() 清除 key 并刷新 state', () async {
      // 先种入"已同意"状态。
      SharedPreferences.setMockInitialValues({
        kPrivacyPolicyAcceptedVersionPrefKey: kCurrentPrivacyPolicyVersion,
      });
      final c = makeContainer();
      final v1 = await c.read(privacyConsentProvider.future);
      expect(v1, kCurrentPrivacyPolicyVersion);

      await c.read(privacyConsentProvider.notifier).revoke();
      final v2 = await c.read(privacyConsentProvider.future);
      expect(v2, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(kPrivacyPolicyAcceptedVersionPrefKey),
        isNull,
      );
    });

    test('跨 container 持久化（accept → 新 container 读回）', () async {
      final c1 = makeContainer();
      await c1.read(privacyConsentProvider.future);
      await c1.read(privacyConsentProvider.notifier).accept();

      // 模拟 App 重启：建一个新 container 重新走 build()。
      final c2 = makeContainer();
      final v = await c2.read(privacyConsentProvider.future);
      expect(v, kCurrentPrivacyPolicyVersion);
    });

    test('持有旧版本号时，按"未同意当前版本"语义应被识别为需要再次征求', () async {
      SharedPreferences.setMockInitialValues({
        kPrivacyPolicyAcceptedVersionPrefKey: 'legacy-0.9',
      });
      final c = makeContainer();
      final v = await c.read(privacyConsentProvider.future);
      // build() 仍返回原值——消费方（gate）应自行比对常量识别"非当前版本"。
      expect(v, 'legacy-0.9');
      expect(v == kCurrentPrivacyPolicyVersion, isFalse);
    });
  });
}
