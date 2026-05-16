import 'package:bianbianbianbian/features/lock/biometric_authenticator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FakeBiometricAuthenticator', () {
    test('默认 deviceSupported / enrolled = true，nextResult = success', () async {
      final fake = FakeBiometricAuthenticator();
      expect(await fake.isDeviceSupported(), isTrue);
      expect(await fake.hasEnrolledBiometrics(), isTrue);
      final result = await fake.authenticate(reason: '解锁');
      expect(result, BiometricResult.success);
    });

    test('deviceSupported = false 反映到 isDeviceSupported', () async {
      final fake = FakeBiometricAuthenticator(deviceSupported: false);
      expect(await fake.isDeviceSupported(), isFalse);
    });

    test('enrolled = false 反映到 hasEnrolledBiometrics', () async {
      final fake = FakeBiometricAuthenticator(enrolled: false);
      expect(await fake.hasEnrolledBiometrics(), isFalse);
    });

    test('nextResult 控制 authenticate 返回值（cancelled / lockedOut / etc）',
        () async {
      for (final r in BiometricResult.values) {
        final fake = FakeBiometricAuthenticator(nextResult: r);
        expect(await fake.authenticate(reason: 'x'), r);
      }
    });

    test('authenticateCalls 计数每次 authenticate 调用', () async {
      final fake = FakeBiometricAuthenticator();
      expect(fake.authenticateCalls, 0);
      await fake.authenticate(reason: 'a');
      expect(fake.authenticateCalls, 1);
      await fake.authenticate(reason: 'b');
      expect(fake.authenticateCalls, 2);
    });

    test('lastReason 保留最近一次 reason 字符串', () async {
      final fake = FakeBiometricAuthenticator();
      expect(fake.lastReason, isNull);
      await fake.authenticate(reason: '解锁理由 1');
      expect(fake.lastReason, '解锁理由 1');
      await fake.authenticate(reason: '另一个理由');
      expect(fake.lastReason, '另一个理由');
    });
  });
}
