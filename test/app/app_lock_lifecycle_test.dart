import 'package:bianbianbianbian/app/app.dart';
import 'package:bianbianbianbian/app/app_router.dart';
import 'package:bianbianbianbian/features/lock/app_lock_providers.dart';
import 'package:bianbianbianbian/features/lock/biometric_authenticator.dart';
import 'package:bianbianbianbian/features/lock/pin_credential.dart';
import 'package:bianbianbianbian/features/lock/privacy_mode_service.dart';
import 'package:bianbianbianbian/features/settings/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Clock {
  DateTime current;
  _Clock(this.current);
  DateTime call() => current;
}

class _RecordingPrivacyModeService implements PrivacyModeService {
  final calls = <bool>[];

  @override
  Future<void> setEnabled(bool enabled) async {
    calls.add(enabled);
  }
}

void main() {
  testWidgets('Android inactive 超过后台锁定阈值后 resumed 会锁屏', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final t0 = DateTime(2026, 5, 7, 12, 0, 0);
      final clock = _Clock(t0);
      final store = InMemoryPinCredentialStore();
      await store.writeEnabled(true);
      await store.writeBackgroundLockTimeoutSeconds(60);

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const SizedBox.shrink(),
          ),
        ],
      );
      addTearDown(router.dispose);

      final container = ProviderContainer(
        overrides: [
          pinCredentialStoreProvider.overrideWithValue(store),
          appLockClockProvider.overrideWithValue(clock.call),
          biometricAuthenticatorProvider.overrideWithValue(
            FakeBiometricAuthenticator(deviceSupported: false, enrolled: false),
          ),
          currentThemeProvider.overrideWithValue(ThemeData.light()),
          fontSizeScaleFactorProvider.overrideWithValue(1),
          goRouterProvider.overrideWithValue(router),
        ],
      );
      addTearDown(container.dispose);

      await container.read(backgroundLockTimeoutProvider.future);
      await container.read(appLockEnabledProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const BianBianApp(
            enableSyncLifecycle: false,
            enablePrivacyConsentGate: false,
          ),
        ),
      );
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      clock.current = t0.add(const Duration(seconds: 61));
      // Android 回前台前可能再次发 inactive；这不能刷新后台起点。
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(container.read(appLockGuardProvider).isLocked, isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Android 隐私模式进入多任务时先盖模糊遮罩再临时清 FLAG_SECURE', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final store = InMemoryPinCredentialStore();
      await store.writePrivacyMode(true);
      final clock = _Clock(DateTime(2026, 5, 7, 12, 0, 0));
      final privacyService = _RecordingPrivacyModeService();

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const SizedBox.shrink(),
          ),
        ],
      );
      addTearDown(router.dispose);

      final container = ProviderContainer(
        overrides: [
          pinCredentialStoreProvider.overrideWithValue(store),
          appLockClockProvider.overrideWithValue(clock.call),
          privacyModeServiceProvider.overrideWithValue(privacyService),
          biometricAuthenticatorProvider.overrideWithValue(
            FakeBiometricAuthenticator(deviceSupported: false, enrolled: false),
          ),
          currentThemeProvider.overrideWithValue(ThemeData.light()),
          fontSizeScaleFactorProvider.overrideWithValue(1),
          goRouterProvider.overrideWithValue(router),
        ],
      );
      addTearDown(container.dispose);

      await container.read(privacyModeProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const BianBianApp(
            enableSyncLifecycle: false,
            enablePrivacyConsentGate: false,
          ),
        ),
      );
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      expect(
        find.byKey(const ValueKey('privacy_snapshot_shield')),
        findsOneWidget,
      );
      expect(privacyService.calls, [false]);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(privacyService.calls, [false, true]);
      expect(
        find.byKey(const ValueKey('privacy_snapshot_shield')),
        findsNothing,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Android 应用锁已锁屏时不挂隐私快照遮罩，避免指纹解锁页被重建', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final store = InMemoryPinCredentialStore();
      await store.writeEnabled(true);
      await store.writePrivacyMode(true);
      final clock = _Clock(DateTime(2026, 5, 7, 12, 0, 0));
      final privacyService = _RecordingPrivacyModeService();

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const SizedBox.shrink(),
          ),
        ],
      );
      addTearDown(router.dispose);

      final container = ProviderContainer(
        overrides: [
          pinCredentialStoreProvider.overrideWithValue(store),
          appLockClockProvider.overrideWithValue(clock.call),
          privacyModeServiceProvider.overrideWithValue(privacyService),
          biometricAuthenticatorProvider.overrideWithValue(
            FakeBiometricAuthenticator(deviceSupported: false, enrolled: false),
          ),
          currentThemeProvider.overrideWithValue(ThemeData.light()),
          fontSizeScaleFactorProvider.overrideWithValue(1),
          goRouterProvider.overrideWithValue(router),
        ],
      );
      addTearDown(container.dispose);

      await container.read(privacyModeProvider.future);
      await container.read(appLockEnabledProvider.future);
      container.read(appLockGuardProvider.notifier).lock();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const BianBianApp(
            enableSyncLifecycle: false,
            enablePrivacyConsentGate: false,
          ),
        ),
      );
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      expect(
        find.byKey(const ValueKey('privacy_snapshot_shield')),
        findsNothing,
      );
      expect(privacyService.calls, isEmpty);
      expect(container.read(appLockGuardProvider).isLocked, isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
