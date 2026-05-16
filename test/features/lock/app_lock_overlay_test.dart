import 'package:bianbianbianbian/features/lock/app_lock_overlay.dart';
import 'package:bianbianbianbian/features/lock/app_lock_providers.dart';
import 'package:bianbianbianbian/features/lock/biometric_authenticator.dart';
import 'package:bianbianbianbian/features/lock/pin_credential.dart';
import 'package:bianbianbianbian/features/lock/pin_unlock_page.dart';
import 'package:bianbianbianbian/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Step 14.3：[AppLockOverlay] widget 测试。
///
/// 三个层面：
/// 1. lockGuard.isLocked == true 时 overlay 显示 PinUnlockPage（无 AppBar）；
/// 2. 输入正确 PIN → onUnlocked 回调 → guard.unlock() → overlay 消失；
/// 3. PopScope canPop=false 阻止 Android 物理返回键穿透——这里不易通过 widget
///    test 模拟硬件返回键，只验证 PopScope 实际被挂载。

class _Clock {
  DateTime current;
  _Clock(this.current);
  DateTime call() => current;
}

List<Override> _baseOverrides({
  required PinCredentialStore store,
  required _Clock clock,
  BiometricAuthenticator? auth,
}) =>
    [
      pinCredentialStoreProvider.overrideWithValue(store),
      appLockClockProvider.overrideWithValue(clock.call),
      if (auth != null) biometricAuthenticatorProvider.overrideWithValue(auth),
    ];

Future<void> _seedPinAndEnable(InMemoryPinCredentialStore store) async {
  final salt = generatePinSalt();
  await store.save(await hashPin('1234', salt, iterations: 1));
  await store.writeEnabled(true);
}

void main() {
  group('AppLockOverlay', () {
    testWidgets('isLocked=true 时显示 PinUnlockPage（无 AppBar）', (tester) async {
      final store = InMemoryPinCredentialStore();
      await _seedPinAndEnable(store);
      final clock = _Clock(DateTime(2026, 5, 7));
      final auth = FakeBiometricAuthenticator(
        deviceSupported: false,
        enrolled: false,
      );

      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(store: store, clock: clock, auth: auth),
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                locale: const Locale('zh'),
                home: AppLockOverlay(),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 触发锁屏。
      container.read(appLockGuardProvider.notifier).lock();
      await tester.pumpAndSettle();

      // PinUnlockPage 显示，但因为 showAppBar=false 不应有"解锁" AppBar 标题。
      expect(find.byType(PinUnlockPage), findsOneWidget);
      expect(find.byType(AppBar), findsNothing,
          reason: '锁屏 overlay 不应显示返回箭头暗示用户可以退出');
      expect(find.text('请输入 PIN 解锁边边记账'), findsOneWidget);
    });

    testWidgets('输入正确 PIN → onUnlocked 触发 guard.unlock', (tester) async {
      final store = InMemoryPinCredentialStore();
      await _seedPinAndEnable(store);
      final clock = _Clock(DateTime(2026, 5, 7));
      final auth = FakeBiometricAuthenticator(
        deviceSupported: false,
        enrolled: false,
      );

      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(store: store, clock: clock, auth: auth),
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                locale: const Locale('zh'),
                home: Stack(
                  children: const [
                    Material(child: Center(child: Text('protected-content'))),
                    AppLockOverlay(),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 锁起来。
      final guard = container.read(appLockGuardProvider.notifier);
      guard.lock();
      await tester.pumpAndSettle();

      // 输入正确 PIN 1234。
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('确认'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(container.read(appLockGuardProvider).isLocked, isFalse);
    });

    testWidgets('AppLockOverlay 包了 PopScope canPop=false', (tester) async {
      final store = InMemoryPinCredentialStore();
      await _seedPinAndEnable(store);
      final clock = _Clock(DateTime(2026, 5, 7));
      final auth = FakeBiometricAuthenticator(
        deviceSupported: false,
        enrolled: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(store: store, clock: clock, auth: auth),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: const AppLockOverlay(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isFalse);
    });
  });
}
