import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:bianbianbianbian/features/lock/pin_credential.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validatePinFormat', () {
    test('合法 4-6 位数字通过', () {
      expect(validatePinFormat('1234'), isNull);
      expect(validatePinFormat('12345'), isNull);
      expect(validatePinFormat('123456'), isNull);
    });

    test('过短 / 过长返回错误', () {
      expect(validatePinFormat('123'), contains('4-6'));
      expect(validatePinFormat('1234567'), contains('4-6'));
      expect(validatePinFormat(''), contains('4-6'));
    });

    test('非数字字符被拒绝', () {
      expect(validatePinFormat('12a4'), contains('数字'));
      expect(validatePinFormat('12 34'), contains('数字'));
      expect(validatePinFormat('１２３４'), contains('数字'),
          reason: '全角数字也应当拒绝——secure storage 与 IME 兼容性差');
    });
  });

  group('generatePinSalt', () {
    test('返回 [kPinSaltBytes] 字节，且字节不全为 0（理论极小概率）', () {
      // 用种子化 Random 保证可复现。
      final salt = generatePinSalt(random: Random(7));
      expect(salt.length, kPinSaltBytes);
      final allZero = salt.every((b) => b == 0);
      expect(allZero, isFalse);
    });

    test('两次独立调用得到不同 salt（充分熵）', () {
      final s1 = generatePinSalt(random: Random.secure());
      final s2 = generatePinSalt(random: Random.secure());
      expect(s1, isNot(s2));
    });
  });

  group('hashPin / verifyPin', () {
    test('hashPin 输出 base64 salt + base64 hash + iterations 三件套', () async {
      final salt = generatePinSalt(random: Random(1));
      // 测试中用 iterations=1 加速——生产 100k 次。
      final cred = await hashPin('123456', salt, iterations: 1);
      expect(cred.iterations, 1);
      expect(base64.decode(cred.saltBase64), salt);
      // 32 字节派生 key → base64 应是 44 字符（含 padding）。
      expect(base64.decode(cred.hashBase64).length, 32);
    });

    test('正确 PIN 通过验证', () async {
      final salt = generatePinSalt(random: Random(2));
      final cred = await hashPin('1234', salt, iterations: 1);
      expect(await verifyPin('1234', cred), isTrue);
    });

    test('错误 PIN 不通过', () async {
      final salt = generatePinSalt(random: Random(3));
      final cred = await hashPin('1234', salt, iterations: 1);
      expect(await verifyPin('5678', cred), isFalse);
      expect(await verifyPin('12345', cred), isFalse);
      expect(await verifyPin('', cred), isFalse);
    });

    test('同一 PIN + 不同 salt 派生不同哈希——避免 rainbow table', () async {
      final saltA = generatePinSalt(random: Random(4));
      final saltB = generatePinSalt(random: Random(5));
      final credA = await hashPin('9999', saltA, iterations: 1);
      final credB = await hashPin('9999', saltB, iterations: 1);
      expect(credA.hashBase64, isNot(credB.hashBase64));
    });

    test('iterations 不一致但 salt 一致时 verifyPin 会失败（迭代写在凭据里，无法降级）',
        () async {
      final salt = generatePinSalt(random: Random(6));
      final cred = await hashPin('1234', salt, iterations: 1);
      // 篡改 iterations
      final tampered = PinCredential(
        saltBase64: cred.saltBase64,
        hashBase64: cred.hashBase64,
        iterations: 2,
      );
      expect(await verifyPin('1234', tampered), isFalse);
    });
  });

  group('constantTimeEquals', () {
    test('等长且内容一致返回 true', () {
      expect(
        constantTimeEqualsForTest(
            Uint8List.fromList([1, 2, 3]), Uint8List.fromList([1, 2, 3])),
        isTrue,
      );
    });

    test('等长但内容不一致返回 false', () {
      expect(
        constantTimeEqualsForTest(
            Uint8List.fromList([1, 2, 3]), Uint8List.fromList([1, 2, 4])),
        isFalse,
      );
    });

    test('长度不同返回 false', () {
      expect(
        constantTimeEqualsForTest(
            Uint8List.fromList([1, 2, 3]), Uint8List.fromList([1, 2])),
        isFalse,
      );
    });
  });

  group('PinCredential', () {
    test('== / hashCode 三字段全相等才相等', () {
      const a = PinCredential(
          saltBase64: 'AA==', hashBase64: 'BB==', iterations: 1);
      const b = PinCredential(
          saltBase64: 'AA==', hashBase64: 'BB==', iterations: 1);
      const c = PinCredential(
          saltBase64: 'AA==', hashBase64: 'BB==', iterations: 2);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('InMemoryPinCredentialStore', () {
    test('save/load roundtrip 保持字段', () async {
      final store = InMemoryPinCredentialStore();
      const cred = PinCredential(
          saltBase64: 'salt', hashBase64: 'hash', iterations: 100000);
      await store.save(cred);
      expect(await store.load(), cred);
    });

    test('clearCredential 后 load 为 null，但不影响 enabled 标志', () async {
      final store = InMemoryPinCredentialStore();
      await store.save(const PinCredential(
          saltBase64: 's', hashBase64: 'h', iterations: 1));
      await store.writeEnabled(true);
      await store.clearCredential();
      expect(await store.load(), isNull);
      expect(await store.readEnabled(), isTrue,
          reason: 'clearCredential 不应影响 enabled——调用方需显式 writeEnabled(false)');
    });

    test('readEnabled 默认 false', () async {
      final store = InMemoryPinCredentialStore();
      expect(await store.readEnabled(), isFalse);
    });

    test('readBiometricEnabled 默认 false 且独立于 enabled', () async {
      final store = InMemoryPinCredentialStore();
      expect(await store.readBiometricEnabled(), isFalse);
      await store.writeEnabled(true);
      // 写入 enabled 不应影响 biometricEnabled。
      expect(await store.readBiometricEnabled(), isFalse);
    });

    test('writeBiometricEnabled / readBiometricEnabled roundtrip', () async {
      final store = InMemoryPinCredentialStore();
      await store.writeBiometricEnabled(true);
      expect(await store.readBiometricEnabled(), isTrue);
      await store.writeBiometricEnabled(false);
      expect(await store.readBiometricEnabled(), isFalse);
    });

    test('clearCredential 不影响 biometricEnabled——清生物识别开关由调用方决定',
        () async {
      final store = InMemoryPinCredentialStore();
      await store.writeBiometricEnabled(true);
      await store.save(const PinCredential(
          saltBase64: 's', hashBase64: 'h', iterations: 1));
      await store.clearCredential();
      expect(await store.load(), isNull);
      expect(await store.readBiometricEnabled(), isTrue,
          reason: '14.2 决策：clearCredential 仅清三件套；'
              '生物识别开关由 AppLockController.disable 显式 writeBiometricEnabled(false)');
    });

    test('readBackgroundLockTimeoutSeconds 默认值 = kDefault', () async {
      final store = InMemoryPinCredentialStore();
      expect(
        await store.readBackgroundLockTimeoutSeconds(),
        kDefaultBackgroundLockTimeoutSeconds,
      );
    });

    test('writeBackgroundLockTimeoutSeconds / read roundtrip', () async {
      final store = InMemoryPinCredentialStore();
      await store.writeBackgroundLockTimeoutSeconds(0);
      expect(await store.readBackgroundLockTimeoutSeconds(), 0);
      await store.writeBackgroundLockTimeoutSeconds(300);
      expect(await store.readBackgroundLockTimeoutSeconds(), 300);
    });

    test('writeBackgroundLockTimeoutSeconds 拒绝负值（回落到默认）', () async {
      final store = InMemoryPinCredentialStore();
      await store.writeBackgroundLockTimeoutSeconds(-1);
      expect(
        await store.readBackgroundLockTimeoutSeconds(),
        kDefaultBackgroundLockTimeoutSeconds,
        reason: '负值视为非法 → 回退默认；避免误把负数当作"立即"',
      );
    });

    test('clearCredential / writeEnabled(false) 都不影响后台超时阈值', () async {
      final store = InMemoryPinCredentialStore();
      await store.writeBackgroundLockTimeoutSeconds(900);
      await store.save(const PinCredential(
          saltBase64: 's', hashBase64: 'h', iterations: 1));
      await store.clearCredential();
      await store.writeEnabled(false);
      expect(
        await store.readBackgroundLockTimeoutSeconds(),
        900,
        reason: '后台超时是用户偏好——关锁/重设 PIN 不应清掉用户的选择',
      );
    });

    test('readPrivacyMode 默认 false', () async {
      final store = InMemoryPinCredentialStore();
      expect(await store.readPrivacyMode(), isFalse);
    });

    test('writePrivacyMode / readPrivacyMode roundtrip', () async {
      final store = InMemoryPinCredentialStore();
      await store.writePrivacyMode(true);
      expect(await store.readPrivacyMode(), isTrue);
      await store.writePrivacyMode(false);
      expect(await store.readPrivacyMode(), isFalse);
    });

    test('clearCredential / writeEnabled(false) 都不影响隐私模式开关', () async {
      final store = InMemoryPinCredentialStore();
      await store.writePrivacyMode(true);
      await store.save(const PinCredential(
          saltBase64: 's', hashBase64: 'h', iterations: 1));
      await store.clearCredential();
      await store.writeEnabled(false);
      expect(
        await store.readPrivacyMode(),
        isTrue,
        reason: '14.4 决策：隐私模式独立于 PIN 锁——关锁不应清隐私模式偏好',
      );
    });
  });
}
