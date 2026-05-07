import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/crypto/bianbian_crypto.dart';

/// Step 14.1：应用锁 PIN 的哈希存取层。
///
/// 设计要点：
/// - 仅持久化 PBKDF2-HMAC-SHA256 派生出的 32 字节哈希 + 16 字节 salt + 迭代次数；
///   **绝不**持久化 PIN 明文或可还原密钥。salt 与哈希都用 base64 串保存。
/// - 三个独立的 secure_storage 条目（[saltStorageKey] / [hashStorageKey] /
///   [iterationsStorageKey]）；缺任一项都视为"未设置 PIN"。`enabled` 标志独立第 4 个
///   条目（[enabledStorageKey]），允许"PIN 已设但开关临时关闭"的状态——目前 UI 不
///   暴露该路径，但底层支持，便于 14.2 生物识别接入时复用。
/// - 与 [DbCipherKeyStore] 的命名空间故意分开：本地 DB 加密密钥 (`local_db_cipher_key`)
///   与 PIN 哈希互不相关，前者丢失 = 本机库永久不可读，后者丢失 = 用户走"忘记 PIN"
///   清空本地数据流程。
const int kPinMinLength = 4;
const int kPinMaxLength = 6;

/// PBKDF2 迭代次数。生产侧与 [BianbianCrypto.defaultPbkdf2Iterations] 对齐。
/// 测试可注入 1 加速断言（见 `pin_credential_test.dart`）。
const int kPinPbkdf2Iterations = 100000;

/// salt 长度。AES-GCM 推荐 16 字节，[BianbianCrypto.deriveKey] 也接受这个长度。
const int kPinSaltBytes = 16;

/// PIN 凭据三元组——salt / 哈希 / 迭代次数；持久化时三项独立写入 secure storage。
class PinCredential {
  const PinCredential({
    required this.saltBase64,
    required this.hashBase64,
    required this.iterations,
  });

  final String saltBase64;
  final String hashBase64;
  final int iterations;

  @override
  bool operator ==(Object other) =>
      other is PinCredential &&
      other.saltBase64 == saltBase64 &&
      other.hashBase64 == hashBase64 &&
      other.iterations == iterations;

  @override
  int get hashCode => Object.hash(saltBase64, hashBase64, iterations);

  @override
  String toString() =>
      'PinCredential(saltBase64: $saltBase64, hashBase64: $hashBase64, '
      'iterations: $iterations)';
}

/// 生成 [kPinSaltBytes] 字节的 salt。生产默认 [Random.secure]，测试可注入种子化
/// `Random(42)` 保证可复现。
Uint8List generatePinSalt({Random? random}) {
  final r = random ?? Random.secure();
  final bytes = Uint8List(kPinSaltBytes);
  for (var i = 0; i < kPinSaltBytes; i++) {
    bytes[i] = r.nextInt(256);
  }
  return bytes;
}

/// 把明文 [pin] + [salt] 喂给 PBKDF2-HMAC-SHA256，得到 32 字节派生 key 并打包成
/// [PinCredential]。salt 长度任意，但建议沿用 [kPinSaltBytes]。
Future<PinCredential> hashPin(
  String pin,
  Uint8List salt, {
  int iterations = kPinPbkdf2Iterations,
}) async {
  final derived = await BianbianCrypto.deriveKey(
    pin,
    salt,
    iterations: iterations,
  );
  return PinCredential(
    saltBase64: base64.encode(salt),
    hashBase64: base64.encode(derived),
    iterations: iterations,
  );
}

/// 用同一 salt + iterations 派生 [pin] 后做**常量时间**比较，防止时序侧信道。
Future<bool> verifyPin(String pin, PinCredential credential) async {
  final salt = base64.decode(credential.saltBase64);
  final derived = await BianbianCrypto.deriveKey(
    pin,
    salt,
    iterations: credential.iterations,
  );
  final expected = base64.decode(credential.hashBase64);
  return _constantTimeEquals(derived, expected);
}

@visibleForTesting
bool constantTimeEqualsForTest(List<int> a, List<int> b) =>
    _constantTimeEquals(a, b);

bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// 校验 PIN 字符串：必须由数字组成，长度在 [kPinMinLength, kPinMaxLength]。
/// UI 与 setup 流程双重保护——避免有人 setState 越过表单进 hashPin。
String? validatePinFormat(String pin) {
  if (pin.length < kPinMinLength || pin.length > kPinMaxLength) {
    return 'PIN 必须为 $kPinMinLength-$kPinMaxLength 位数字';
  }
  for (var i = 0; i < pin.length; i++) {
    final c = pin.codeUnitAt(i);
    if (c < 0x30 || c > 0x39) {
      return 'PIN 仅允许数字';
    }
  }
  return null;
}

/// PIN 凭据持久化抽象。生产实现 [FlutterSecurePinCredentialStore]，测试可用
/// [InMemoryPinCredentialStore] 注入。
abstract class PinCredentialStore {
  static const String saltStorageKey = 'local_app_lock_pin_salt';
  static const String hashStorageKey = 'local_app_lock_pin_hash';
  static const String iterationsStorageKey = 'local_app_lock_pin_iterations';
  static const String enabledStorageKey = 'local_app_lock_enabled';
  static const String biometricEnabledStorageKey =
      'local_app_lock_biometric_enabled';

  Future<PinCredential?> load();
  Future<void> save(PinCredential credential);

  /// 删除 salt / hash / iterations 三件套。**不**清 [readEnabled]——
  /// 调用方应显式 `writeEnabled(false)`。
  Future<void> clearCredential();

  Future<bool> readEnabled();
  Future<void> writeEnabled(bool enabled);

  /// Step 14.2：生物识别"用户开关"——独立于设备硬件能力。
  ///
  /// 真值源是 secure storage 的 `local_app_lock_biometric_enabled` 条目；缺省视
  /// 为关闭。**只**记录用户在设置页的选择，不反映"现在是否真能用"——后者由
  /// `biometricAuthenticator.isDeviceSupported` + `hasEnrolledBiometrics` 决定。
  Future<bool> readBiometricEnabled();
  Future<void> writeBiometricEnabled(bool enabled);
}

class FlutterSecurePinCredentialStore implements PinCredentialStore {
  const FlutterSecurePinCredentialStore([
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  ]) : _storage = storage;

  final FlutterSecureStorage _storage;

  @override
  Future<PinCredential?> load() async {
    final salt = await _storage.read(key: PinCredentialStore.saltStorageKey);
    final hash = await _storage.read(key: PinCredentialStore.hashStorageKey);
    final iterRaw =
        await _storage.read(key: PinCredentialStore.iterationsStorageKey);
    if (salt == null || hash == null || iterRaw == null) return null;
    final iterations = int.tryParse(iterRaw);
    if (iterations == null || iterations <= 0) return null;
    return PinCredential(
      saltBase64: salt,
      hashBase64: hash,
      iterations: iterations,
    );
  }

  @override
  Future<void> save(PinCredential credential) async {
    await _storage.write(
      key: PinCredentialStore.saltStorageKey,
      value: credential.saltBase64,
    );
    await _storage.write(
      key: PinCredentialStore.hashStorageKey,
      value: credential.hashBase64,
    );
    await _storage.write(
      key: PinCredentialStore.iterationsStorageKey,
      value: credential.iterations.toString(),
    );
  }

  @override
  Future<void> clearCredential() async {
    await _storage.delete(key: PinCredentialStore.saltStorageKey);
    await _storage.delete(key: PinCredentialStore.hashStorageKey);
    await _storage.delete(key: PinCredentialStore.iterationsStorageKey);
  }

  @override
  Future<bool> readEnabled() async {
    final raw = await _storage.read(key: PinCredentialStore.enabledStorageKey);
    return raw == 'true';
  }

  @override
  Future<void> writeEnabled(bool enabled) async {
    await _storage.write(
      key: PinCredentialStore.enabledStorageKey,
      value: enabled ? 'true' : 'false',
    );
  }

  @override
  Future<bool> readBiometricEnabled() async {
    final raw = await _storage.read(
      key: PinCredentialStore.biometricEnabledStorageKey,
    );
    return raw == 'true';
  }

  @override
  Future<void> writeBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: PinCredentialStore.biometricEnabledStorageKey,
      value: enabled ? 'true' : 'false',
    );
  }
}

/// 测试 / Riverpod override 用的内存实现。
@visibleForTesting
class InMemoryPinCredentialStore implements PinCredentialStore {
  PinCredential? _cred;
  bool _enabled = false;
  bool _biometricEnabled = false;

  @override
  Future<PinCredential?> load() async => _cred;

  @override
  Future<void> save(PinCredential credential) async {
    _cred = credential;
  }

  @override
  Future<void> clearCredential() async {
    _cred = null;
  }

  @override
  Future<bool> readEnabled() async => _enabled;

  @override
  Future<void> writeEnabled(bool enabled) async {
    _enabled = enabled;
  }

  @override
  Future<bool> readBiometricEnabled() async => _biometricEnabled;

  @override
  Future<void> writeBiometricEnabled(bool enabled) async {
    _biometricEnabled = enabled;
  }
}
