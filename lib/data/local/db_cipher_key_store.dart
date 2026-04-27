import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 本地 SQLite (SQLCipher) 加密密钥的持久化容器。
///
/// 该密钥**只**保护本机 `bbb.db` 文件，与 Phase 11 的"用户同步密码派生密钥"
/// 是两回事——不要混用、不要上云、也不要写进 design-document §7.1 的任何字段。
///
/// 密钥以 64 字符的小写 hex 串保存，使用时配合 `PRAGMA key = "x'<hex>'"`
/// 传给 SQLCipher，以**跳过其内部 KDF**（我们已经保证随机来源是
/// `Random.secure()`，不必再走一次 PBKDF2）。
class DbCipherKeyStore {
  DbCipherKeyStore({
    SecureKeyValueStore? storage,
    Random? random,
  })  : _storage = storage ?? const FlutterSecureKeyValueStore(),
        _random = random ?? Random.secure();

  final SecureKeyValueStore _storage;
  final Random _random;

  /// `flutter_secure_storage` 中的条目名，与实施计划 Step 1.2 约定一致。
  static const String storageKey = 'local_db_cipher_key';

  /// SQLCipher 原始密钥长度（字节）。
  static const int keyByteLength = 32;

  /// 已存在 → 直接返回；不存在（或格式非法） → 生成 32 字节随机值并写回。
  Future<String> loadOrCreate() async {
    final existing = await _storage.read(storageKey);
    if (existing != null && _isValidHex(existing)) {
      return existing;
    }
    final bytes = Uint8List(keyByteLength);
    for (var i = 0; i < keyByteLength; i++) {
      bytes[i] = _random.nextInt(256);
    }
    final hex = _toHex(bytes);
    await _storage.write(storageKey, hex);
    return hex;
  }

  static bool _isValidHex(String value) {
    if (value.length != keyByteLength * 2) return false;
    for (var i = 0; i < value.length; i++) {
      final c = value.codeUnitAt(i);
      final isDigit = c >= 0x30 && c <= 0x39;
      final isLower = c >= 0x61 && c <= 0x66;
      if (!isDigit && !isLower) return false;
    }
    return true;
  }

  static String _toHex(Uint8List bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}

/// `DbCipherKeyStore` 依赖的最小接口——单元测试注入内存实现，生产注入
/// `FlutterSecureKeyValueStore`。刻意不暴露 delete/containsKey，避免诱导
/// 调用方在业务路径上"清空密钥"。
abstract class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  const FlutterSecureKeyValueStore([
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  ]) : _storage = storage;

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}
