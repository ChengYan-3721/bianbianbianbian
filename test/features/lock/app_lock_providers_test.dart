import 'dart:math';

import 'package:bianbianbianbian/features/lock/app_lock_providers.dart';
import 'package:bianbianbianbian/features/lock/biometric_authenticator.dart';
import 'package:bianbianbianbian/features/lock/pin_credential.dart';
import 'package:bianbianbianbian/features/lock/privacy_mode_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 这些测试驱动 PIN 校验的会话级冷却语义：
/// - 凭据缺失：永远 false；
/// - 错误 1-2 次：累计 failures + 不进冷却；
/// - 错误 第 3 次：进入 [kPinCooldownDuration] 冷却 + failures 重置为 0；
/// - 冷却中再次调用 tryVerify：直接 false，**不**消耗 attempt（防止冷却被无限拉长）；
/// - 成功：归零 + 解冷却（虽然冷却中根本走不到 verify，但成功路径仍写归零状态）。

class _Clock {
  DateTime current;
  _Clock(this.current);
  DateTime call() => current;
}

ProviderContainer _container({
  required PinCredentialStore store,
  required _Clock clock,
  BiometricAuthenticator? auth,
  PrivacyModeService? privacyService,
}) {
  return ProviderContainer(overrides: [
    pinCredentialStoreProvider.overrideWithValue(store),
    appLockClockProvider.overrideWithValue(clock.call),
    if (auth != null) biometricAuthenticatorProvider.overrideWithValue(auth),
    if (privacyService != null)
      privacyModeServiceProvider.overrideWithValue(privacyService),
  ]);
}

Future<void> _seedPin(InMemoryPinCredentialStore store, String pin) async {
  final salt = generatePinSalt(random: Random(123));
  final cred = await hashPin(pin, salt, iterations: 1);
  await store.save(cred);
  await store.writeEnabled(true);
}

void main() {
  group('PinAttemptSession.tryVerify', () {
    test('凭据缺失时直接返回 false，不改 state', () async {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7, 12));
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);

      final session = container.read(pinAttemptSessionProvider.notifier);
      final ok = await session.tryVerify('1234');
      expect(ok, isFalse);
      expect(container.read(pinAttemptSessionProvider),
          PinAttemptState.initial);
    });

    test('成功路径：state 重置为 initial', () async {
      final store = InMemoryPinCredentialStore();
      await _seedPin(store, '1234');
      final clock = _Clock(DateTime(2026, 5, 7, 12));
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);

      final session = container.read(pinAttemptSessionProvider.notifier);
      final ok = await session.tryVerify('1234');
      expect(ok, isTrue);
      expect(container.read(pinAttemptSessionProvider).failures, 0);
      expect(container.read(pinAttemptSessionProvider).cooldownUntil, isNull);
    });

    test('错误 1-2 次：累计 failures，不进入冷却', () async {
      final store = InMemoryPinCredentialStore();
      await _seedPin(store, '1234');
      final clock = _Clock(DateTime(2026, 5, 7, 12));
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);

      final session = container.read(pinAttemptSessionProvider.notifier);
      expect(await session.tryVerify('0000'), isFalse);
      expect(container.read(pinAttemptSessionProvider).failures, 1);
      expect(session.isCoolingDown(), isFalse);

      expect(await session.tryVerify('0000'), isFalse);
      expect(container.read(pinAttemptSessionProvider).failures, 2);
      expect(session.isCoolingDown(), isFalse);
    });

    test('错误第 3 次：进入冷却 30 秒，failures 重置为 0', () async {
      final store = InMemoryPinCredentialStore();
      await _seedPin(store, '1234');
      final t0 = DateTime(2026, 5, 7, 12, 0, 0);
      final clock = _Clock(t0);
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);

      final session = container.read(pinAttemptSessionProvider.notifier);
      await session.tryVerify('0000');
      await session.tryVerify('0000');
      await session.tryVerify('0000');

      final state = container.read(pinAttemptSessionProvider);
      expect(state.failures, 0,
          reason: '触发冷却后 failures 应重置为 0，避免下一轮叠加更长冷却');
      expect(state.cooldownUntil, t0.add(kPinCooldownDuration));
      expect(session.isCoolingDown(), isTrue);
    });

    test('冷却中调用 tryVerify：返回 false，不消耗 attempt（不重置 cooldownUntil）',
        () async {
      final store = InMemoryPinCredentialStore();
      await _seedPin(store, '1234');
      final t0 = DateTime(2026, 5, 7, 12, 0, 0);
      final clock = _Clock(t0);
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);

      final session = container.read(pinAttemptSessionProvider.notifier);
      await session.tryVerify('0000');
      await session.tryVerify('0000');
      await session.tryVerify('0000');
      final cooldownUntilAfterTrigger =
          container.read(pinAttemptSessionProvider).cooldownUntil;

      // 冷却窗口内时间推进了 5 秒，但还没到点。
      clock.current = t0.add(const Duration(seconds: 5));
      // 即使输入正确，冷却中也直接拒绝。
      expect(await session.tryVerify('1234'), isFalse);
      // cooldownUntil 不应被刷新。
      expect(container.read(pinAttemptSessionProvider).cooldownUntil,
          cooldownUntilAfterTrigger);
    });

    test('冷却结束后可继续输入；输错继续累计 failures（从 0 重新计）', () async {
      final store = InMemoryPinCredentialStore();
      await _seedPin(store, '1234');
      final t0 = DateTime(2026, 5, 7, 12, 0, 0);
      final clock = _Clock(t0);
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);

      final session = container.read(pinAttemptSessionProvider.notifier);
      await session.tryVerify('0000');
      await session.tryVerify('0000');
      await session.tryVerify('0000');

      // 跳到冷却之后 1 秒。
      clock.current = t0.add(kPinCooldownDuration + const Duration(seconds: 1));
      expect(session.isCoolingDown(), isFalse);

      // 冷却结束后输错一次，进入第 1 次失败计数。
      expect(await session.tryVerify('0000'), isFalse);
      expect(container.read(pinAttemptSessionProvider).failures, 1);
    });

    test('cooldownRemainingSeconds 正确反映剩余时间（向上取整）', () async {
      final store = InMemoryPinCredentialStore();
      await _seedPin(store, '1234');
      final t0 = DateTime(2026, 5, 7, 12, 0, 0);
      final clock = _Clock(t0);
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);

      final session = container.read(pinAttemptSessionProvider.notifier);
      await session.tryVerify('0000');
      await session.tryVerify('0000');
      await session.tryVerify('0000');
      // 刚触发：剩余 = 30 秒。
      expect(session.cooldownRemainingSeconds(), 30);

      clock.current = t0.add(const Duration(seconds: 10));
      expect(session.cooldownRemainingSeconds(), 20);

      clock.current = t0.add(const Duration(seconds: 29, milliseconds: 999));
      expect(session.cooldownRemainingSeconds(), 1,
          reason: '向上取整，剩 1 秒应展示 1 秒');

      clock.current = t0.add(kPinCooldownDuration);
      expect(session.cooldownRemainingSeconds(), 0);
      expect(session.isCoolingDown(), isFalse);
    });

    test('reset 清空 failures + cooldownUntil', () async {
      final store = InMemoryPinCredentialStore();
      await _seedPin(store, '1234');
      final clock = _Clock(DateTime(2026, 5, 7, 12, 0, 0));
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);

      final session = container.read(pinAttemptSessionProvider.notifier);
      await session.tryVerify('0000');
      await session.tryVerify('0000');
      await session.tryVerify('0000');
      expect(session.isCoolingDown(), isTrue);

      session.reset();
      expect(container.read(pinAttemptSessionProvider),
          PinAttemptState.initial);
    });
  });

  group('AppLockController', () {
    test('setupPin 写入凭据 + enabled=true，附带 reset 失败计数', () async {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7, 12));
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);

      // 模拟之前积累的失败次数。
      container.read(pinAttemptSessionProvider.notifier);
      // 直接通过 reset 反向：先用 InMemoryPinCredentialStore 装一个真凭据触发失败。
      await _seedPin(store, '0000');
      final session = container.read(pinAttemptSessionProvider.notifier);
      await session.tryVerify('1111');
      await session.tryVerify('1111');
      expect(container.read(pinAttemptSessionProvider).failures, 2);

      final controller = container.read(appLockControllerProvider);
      await controller.setupPin('1234');
      expect(await store.readEnabled(), isTrue);
      expect(await store.load(), isNotNull);
      expect(container.read(pinAttemptSessionProvider).failures, 0,
          reason: 'setupPin 后失败计数应重置');
    });

    test('setupPin 拒绝非法 PIN 格式（throws ArgumentError）', () async {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7, 12));
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);

      final controller = container.read(appLockControllerProvider);
      expect(() => controller.setupPin('abc'),
          throwsA(isA<ArgumentError>()));
      expect(() => controller.setupPin('123'),
          throwsA(isA<ArgumentError>()));
      expect(() => controller.setupPin('1234567'),
          throwsA(isA<ArgumentError>()));
      // 写入应未发生。
      expect(await store.load(), isNull);
      expect(await store.readEnabled(), isFalse);
    });

    test('changePin 替换凭据，但保持 enabled 不变', () async {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7, 12));
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);

      final controller = container.read(appLockControllerProvider);
      await controller.setupPin('1234');
      final origCred = await store.load();

      await controller.changePin('5678');
      final newCred = await store.load();
      expect(newCred, isNot(origCred));
      expect(await store.readEnabled(), isTrue);

      // 旧 PIN 不再通过验证；新 PIN 通过。
      final session = container.read(pinAttemptSessionProvider.notifier);
      expect(await session.tryVerify('1234'), isFalse);
      expect(await session.tryVerify('5678'), isTrue);
    });

    test('disable 清凭据 + enabled=false', () async {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7, 12));
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);

      final controller = container.read(appLockControllerProvider);
      await controller.setupPin('1234');
      await controller.disable();
      expect(await store.load(), isNull);
      expect(await store.readEnabled(), isFalse);
    });

    test('forgetPinAndDisable 与 disable 行为一致（14.1 阶段不清库）', () async {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7, 12));
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);

      final controller = container.read(appLockControllerProvider);
      await controller.setupPin('1234');
      await controller.forgetPinAndDisable();
      expect(await store.load(), isNull);
      expect(await store.readEnabled(), isFalse);
    });
  });

  group('appLockEnabledProvider', () {
    test('默认 false', () async {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7, 12));
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);
      expect(await container.read(appLockEnabledProvider.future), isFalse);
    });

    test('setupPin → invalidate 后变 true', () async {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7, 12));
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);

      final controller = container.read(appLockControllerProvider);
      await controller.setupPin('1234');
      container.invalidate(appLockEnabledProvider);
      expect(await container.read(appLockEnabledProvider.future), isTrue);
    });
  });

  group('biometricCapabilityProvider', () {
    test('设备支持 + 已录入 → isUsable=true', () async {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7, 12));
      final auth = FakeBiometricAuthenticator(
        deviceSupported: true,
        enrolled: true,
      );
      final container = _container(store: store, clock: clock, auth: auth);
      addTearDown(container.dispose);
      final cap = await container.read(biometricCapabilityProvider.future);
      expect(cap.supported, isTrue);
      expect(cap.hasEnrolled, isTrue);
      expect(cap.isUsable, isTrue);
    });

    test('设备不支持 → 不再调 hasEnrolledBiometrics 且 isUsable=false', () async {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7, 12));
      final auth = FakeBiometricAuthenticator(
        deviceSupported: false,
        enrolled: true,
      );
      final container = _container(store: store, clock: clock, auth: auth);
      addTearDown(container.dispose);
      final cap = await container.read(biometricCapabilityProvider.future);
      expect(cap.supported, isFalse);
      expect(cap.hasEnrolled, isFalse,
          reason: '设备不支持时短路返回，不应再调 enrolled 探测');
      expect(cap.isUsable, isFalse);
    });

    test('设备支持但未录入 → isUsable=false', () async {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7, 12));
      final auth = FakeBiometricAuthenticator(
        deviceSupported: true,
        enrolled: false,
      );
      final container = _container(store: store, clock: clock, auth: auth);
      addTearDown(container.dispose);
      final cap = await container.read(biometricCapabilityProvider.future);
      expect(cap.supported, isTrue);
      expect(cap.hasEnrolled, isFalse);
      expect(cap.isUsable, isFalse);
    });

    test('BiometricCapability == 与 hashCode 双字段', () {
      const a =
          BiometricCapability(supported: true, hasEnrolled: true);
      const b =
          BiometricCapability(supported: true, hasEnrolled: true);
      const c =
          BiometricCapability(supported: true, hasEnrolled: false);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('biometricEnabledProvider + setBiometricEnabled', () {
    test('默认 false', () async {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7, 12));
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);
      expect(await container.read(biometricEnabledProvider.future), isFalse);
    });

    test('setBiometricEnabled(true) → invalidate 后变 true', () async {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7, 12));
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);

      final controller = container.read(appLockControllerProvider);
      await controller.setBiometricEnabled(true);
      container.invalidate(biometricEnabledProvider);
      expect(await container.read(biometricEnabledProvider.future), isTrue);

      await controller.setBiometricEnabled(false);
      container.invalidate(biometricEnabledProvider);
      expect(await container.read(biometricEnabledProvider.future), isFalse);
    });

    test('AppLockController.disable 同步清生物识别开关', () async {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7, 12));
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);

      final controller = container.read(appLockControllerProvider);
      await controller.setupPin('1234');
      await controller.setBiometricEnabled(true);
      expect(await store.readBiometricEnabled(), isTrue);

      await controller.disable();
      expect(await store.load(), isNull);
      expect(await store.readEnabled(), isFalse);
      expect(await store.readBiometricEnabled(), isFalse,
          reason: 'disable 必须同步清生物识别开关——避免下次重新设 PIN 后旧 enabled=true 残留');
    });

    test('forgetPinAndDisable 同样清生物识别开关', () async {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7, 12));
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);

      final controller = container.read(appLockControllerProvider);
      await controller.setupPin('1234');
      await controller.setBiometricEnabled(true);

      await controller.forgetPinAndDisable();
      expect(await store.readBiometricEnabled(), isFalse);
    });
  });

  group('backgroundLockTimeoutProvider + setBackgroundLockTimeoutSeconds', () {
    test('默认值 = kDefaultBackgroundLockTimeoutSeconds（60 秒）', () async {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7, 12));
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);
      expect(
        await container.read(backgroundLockTimeoutProvider.future),
        kDefaultBackgroundLockTimeoutSeconds,
      );
    });

    test('setBackgroundLockTimeoutSeconds(0) → invalidate 后读到 0', () async {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7, 12));
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);

      final controller = container.read(appLockControllerProvider);
      await controller.setBackgroundLockTimeoutSeconds(0);
      container.invalidate(backgroundLockTimeoutProvider);
      expect(await container.read(backgroundLockTimeoutProvider.future), 0);
    });

    test('setBackgroundLockTimeoutSeconds 拒绝负值（throws ArgumentError）',
        () async {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7, 12));
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);

      final controller = container.read(appLockControllerProvider);
      expect(
        () => controller.setBackgroundLockTimeoutSeconds(-1),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('AppLockGuard 状态机', () {
    test('初始状态：unlocked + lastBackgroundedAt = null', () async {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7, 12, 0, 0));
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);

      final state = container.read(appLockGuardProvider);
      expect(state.isLocked, isFalse);
      expect(state.lastBackgroundedAt, isNull);
    });

    test('lock() → isLocked=true；unlock() → unlocked', () {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7, 12, 0, 0));
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);

      final guard = container.read(appLockGuardProvider.notifier);
      guard.lock();
      expect(container.read(appLockGuardProvider).isLocked, isTrue);

      guard.unlock();
      expect(container.read(appLockGuardProvider).isLocked, isFalse);
      expect(container.read(appLockGuardProvider).lastBackgroundedAt, isNull);
    });

    test('onPaused 记录 lastBackgroundedAt = now，但不锁屏', () {
      final store = InMemoryPinCredentialStore();
      final t0 = DateTime(2026, 5, 7, 12, 0, 0);
      final clock = _Clock(t0);
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);

      final guard = container.read(appLockGuardProvider.notifier);
      guard.onPaused();
      final state = container.read(appLockGuardProvider);
      expect(state.isLocked, isFalse);
      expect(state.lastBackgroundedAt, t0);
    });

    test('onResumed elapsed < timeout：不锁，但清 lastBackgroundedAt', () {
      final store = InMemoryPinCredentialStore();
      final t0 = DateTime(2026, 5, 7, 12, 0, 0);
      final clock = _Clock(t0);
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);

      final guard = container.read(appLockGuardProvider.notifier);
      guard.setTimeoutSeconds(60);

      guard.onPaused();
      // 推进 30 秒（< 60）。
      clock.current = t0.add(const Duration(seconds: 30));
      guard.onResumed();

      final state = container.read(appLockGuardProvider);
      expect(state.isLocked, isFalse);
      expect(state.lastBackgroundedAt, isNull,
          reason: '已"消化"本次后台会话，避免后续重复触发判定');
    });

    test('onResumed elapsed >= timeout：锁屏', () {
      final store = InMemoryPinCredentialStore();
      final t0 = DateTime(2026, 5, 7, 12, 0, 0);
      final clock = _Clock(t0);
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);

      final guard = container.read(appLockGuardProvider.notifier);
      guard.setTimeoutSeconds(60);

      guard.onPaused();
      // 推进刚好 60 秒——边界含等号触发锁。
      clock.current = t0.add(const Duration(seconds: 60));
      guard.onResumed();

      expect(container.read(appLockGuardProvider).isLocked, isTrue);
    });

    test('timeout=0 立即锁定：任何 paused→resumed 都触发锁', () {
      final store = InMemoryPinCredentialStore();
      final t0 = DateTime(2026, 5, 7, 12, 0, 0);
      final clock = _Clock(t0);
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);

      final guard = container.read(appLockGuardProvider.notifier);
      guard.setTimeoutSeconds(0);

      guard.onPaused();
      // 几乎瞬间 resume。
      clock.current = t0.add(const Duration(milliseconds: 10));
      guard.onResumed();

      expect(container.read(appLockGuardProvider).isLocked, isTrue);
    });

    test('onResumed lastBackgroundedAt == null：不动', () {
      final store = InMemoryPinCredentialStore();
      final t0 = DateTime(2026, 5, 7, 12, 0, 0);
      final clock = _Clock(t0);
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);

      final guard = container.read(appLockGuardProvider.notifier);
      // 没走过 onPaused，直接 onResumed 应被忽略。
      guard.onResumed();
      expect(container.read(appLockGuardProvider), AppLockGuardState.unlocked);
    });

    test('setTimeoutSeconds 即时生效，不重建 Notifier 也不丢失 lastBackgroundedAt',
        () {
      final store = InMemoryPinCredentialStore();
      final t0 = DateTime(2026, 5, 7, 12, 0, 0);
      final clock = _Clock(t0);
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);

      final guard = container.read(appLockGuardProvider.notifier);
      guard.setTimeoutSeconds(60);
      guard.onPaused();
      final pausedAt = container.read(appLockGuardProvider).lastBackgroundedAt;

      // 用户在后台时调整 timeout（模拟 backgroundLockTimeoutProvider invalidate）。
      guard.setTimeoutSeconds(0);
      // lastBackgroundedAt 应保留——guard 没被重建。
      expect(container.read(appLockGuardProvider).lastBackgroundedAt, pausedAt);
      expect(guard.timeoutSeconds, 0);

      // 此时 onResumed 应按新 timeout=0 立即锁。
      clock.current = t0.add(const Duration(seconds: 1));
      guard.onResumed();
      expect(container.read(appLockGuardProvider).isLocked, isTrue);
    });

    test('setTimeoutSeconds 拒绝负值（保留旧值）', () {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7, 12, 0, 0));
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);

      final guard = container.read(appLockGuardProvider.notifier);
      guard.setTimeoutSeconds(60);
      guard.setTimeoutSeconds(-1);
      expect(guard.timeoutSeconds, 60,
          reason: '负值视为非法输入；保留上一次写入');
    });

    test('appLockEnabled true→false：guard 自动 forceUnlock', () async {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7, 12, 0, 0));
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);

      // 先开启 + 锁屏，模拟"用户已被锁着"状态。
      final controller = container.read(appLockControllerProvider);
      await controller.setupPin('1234');
      container.invalidate(appLockEnabledProvider);
      await container.read(appLockEnabledProvider.future);

      final guard = container.read(appLockGuardProvider.notifier);
      guard.lock();
      expect(container.read(appLockGuardProvider).isLocked, isTrue);

      // 用户关闭应用锁——但他必须已经 unlock 才能进设置页，这里只验证 listen
      // 路径：当 enabledProvider 通知 false 时，guard 自动解锁。
      await controller.disable();
      container.invalidate(appLockEnabledProvider);
      // 等 listen 派发完。
      await container.read(appLockEnabledProvider.future);

      expect(container.read(appLockGuardProvider).isLocked, isFalse);
    });

    test('backgroundLockTimeoutProvider invalidate 后 guard 同步新 timeout',
        () async {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7, 12, 0, 0));
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);

      // 先 read provider 让其 build；guard 通过 ref.read maybeWhen 拿默认 60。
      await container.read(backgroundLockTimeoutProvider.future);
      final guard = container.read(appLockGuardProvider.notifier);
      expect(guard.timeoutSeconds, kDefaultBackgroundLockTimeoutSeconds);

      // 用户改成 0。
      await container
          .read(appLockControllerProvider)
          .setBackgroundLockTimeoutSeconds(0);
      container.invalidate(backgroundLockTimeoutProvider);
      await container.read(backgroundLockTimeoutProvider.future);

      expect(guard.timeoutSeconds, 0);
    });
  });

  group('AppLockGuardState', () {
    test('== / hashCode 双字段', () {
      final t = DateTime(2026, 5, 7, 12);
      final a = AppLockGuardState(isLocked: false, lastBackgroundedAt: t);
      final b = AppLockGuardState(isLocked: false, lastBackgroundedAt: t);
      final c = AppLockGuardState(isLocked: true, lastBackgroundedAt: t);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('copyWith clearLastBackgroundedAt 优先于 lastBackgroundedAt 入参', () {
      final t = DateTime(2026, 5, 7, 12);
      final a = AppLockGuardState(isLocked: false, lastBackgroundedAt: t);
      final cleared = a.copyWith(clearLastBackgroundedAt: true);
      expect(cleared.lastBackgroundedAt, isNull);
    });
  });

  group('privacyModeProvider + setPrivacyMode', () {
    test('privacyModeProvider 默认 false', () async {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7));
      final container = _container(store: store, clock: clock);
      addTearDown(container.dispose);

      final value = await container.read(privacyModeProvider.future);
      expect(value, isFalse);
    });

    test('setPrivacyMode(true) 同时写 store 与 native service', () async {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7));
      final fakeService = FakePrivacyModeService();
      final container = _container(
        store: store,
        clock: clock,
        privacyService: fakeService,
      );
      addTearDown(container.dispose);

      await container.read(appLockControllerProvider).setPrivacyMode(true);

      expect(await store.readPrivacyMode(), isTrue);
      expect(fakeService.callCount, 1);
      expect(fakeService.lastEnabled, isTrue);
    });

    test('setPrivacyMode(false) 同时写 store 与 native service', () async {
      final store = InMemoryPinCredentialStore();
      // 先打开。
      await store.writePrivacyMode(true);
      final clock = _Clock(DateTime(2026, 5, 7));
      final fakeService = FakePrivacyModeService();
      final container = _container(
        store: store,
        clock: clock,
        privacyService: fakeService,
      );
      addTearDown(container.dispose);

      await container.read(appLockControllerProvider).setPrivacyMode(false);

      expect(await store.readPrivacyMode(), isFalse);
      expect(fakeService.lastEnabled, isFalse);
    });

    test('setPrivacyMode 后 invalidate 让 provider 拿到新值', () async {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7));
      final fakeService = FakePrivacyModeService();
      final container = _container(
        store: store,
        clock: clock,
        privacyService: fakeService,
      );
      addTearDown(container.dispose);

      // 先读默认值预热 cache。
      expect(await container.read(privacyModeProvider.future), isFalse);

      // 用户开启 → 应当触发 store 写入；调用方负责 invalidate。
      await container.read(appLockControllerProvider).setPrivacyMode(true);
      container.invalidate(privacyModeProvider);

      expect(await container.read(privacyModeProvider.future), isTrue);
    });
  });
}
