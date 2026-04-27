import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

/// AES-256-GCM + PBKDF2-HMAC-SHA256 加密工具集。
///
/// 本封装的消费者（均在后续 Phase 填充）：
/// - Phase 11 Step 11.2：`transaction_entry.note_encrypted` / `attachments_encrypted`
///   字段级加密——写入 drift 前 [encrypt]，读出后 [decrypt]，上层看到的始终是明文。
/// - Phase 11 Step 11.3：附件上传 Supabase Storage 前生成 `.enc` 临时文件。
/// - Phase 11 Step 11.4：「同步码」的对称加密外壳。
/// - Phase 13 Step 13.2：`.bbbak` 加密备份包。
/// - `user_pref.ai_api_key_encrypted` 的存取。
///
/// **不要用本工具加密本机 SQLite**——那是 [DbCipherKeyStore] + SQLCipher
/// 在 [AppDatabase._openEncrypted] 里用 `PRAGMA key = "x'<hex>'"` 直接交给
/// SQLCipher 自己加密，走的是另一条路径。命名空间故意分开（见 Step 1.5 备忘）。
///
/// ## 数据格式（encrypt 输出 / decrypt 输入）
///
/// 为了让密文能自包含地被解出，[encrypt] 把 12 字节 nonce 直接前置、16 字节
/// GCM tag 后置：
///
/// ```
/// ┌──────────────┬──────────────────────┬───────────────┐
/// │ nonce (12 B) │ ciphertext (N bytes) │ tag (16 B)    │
/// └──────────────┴──────────────────────┴───────────────┘
/// ```
///
/// [decrypt] 先做长度校验（至少 `12 + 16 = 28` 字节），再切片成 `(nonce,
/// ciphertext, tag)` 喂给 `AesGcm`。校验失败统一抛 [DecryptionFailure]——不要
/// 透传 `SecretBoxAuthenticationError`，上层只需要知道"密文不可信"这一件事。
///
/// ## 安全注意
///
/// - [encrypt] 每次都用 `AesGcm.newNonce()`（即 `Random.secure()`）生成全新 nonce，
///   同一个 key 不会 nonce 重用——GCM nonce 重用会让攻击者可以恢复明文，这是
///   把它加进包头"自包含"设计的主要动机。
/// - [encryptWithFixedNonce] **仅限测试**：它存在是为了让 KAT 用已知 (K, N, P)
///   对照已知 (C, T)。生产绝不要让 nonce 可控，否则任何调用方误传相同 nonce
///   都会破掉安全假设。
/// - [deriveKey] 用 PBKDF2-HMAC-SHA256，默认 10 万次迭代——OWASP 2023 建议至少
///   10 万；若未来算力/审计要求提升，单独开一步升迁并处理已加密数据的密钥轮换。
class BianbianCrypto {
  BianbianCrypto._();

  /// AES-GCM 推荐 nonce 长度 = 96 bit = 12 byte。
  static const int _nonceBytes = 12;

  /// AES-GCM 认证 tag 长度 = 128 bit = 16 byte（GCM 默认最大值）。
  static const int _tagBytes = 16;

  /// 32 字节 = 256 bit AES 密钥。
  static const int _keyBytes = 32;

  /// PBKDF2 默认迭代数。与 design-document §5.5.4、Step 1.6 实施计划一致。
  static const int defaultPbkdf2Iterations = 100000;

  // `AesGcm.with256bits()` 内部没状态，可安全复用单例避免每次构造开销。
  static final AesGcm _aesGcm = AesGcm.with256bits();

  /// PBKDF2-HMAC-SHA256 派生 32 字节密钥。
  ///
  /// 调用方需自备 16 字节及以上的 [salt]（Phase 11 Step 11.1 用 `user_pref.enc_salt`
  /// 持久化）；[iterations] 默认 [defaultPbkdf2Iterations]=100000，仅测试为了快
  /// 才会降低。返回的 bytes 可直接喂给 [encrypt] / [decrypt] 的 `key` 参数。
  static Future<Uint8List> deriveKey(
    String password,
    Uint8List salt, {
    int iterations = defaultPbkdf2Iterations,
  }) async {
    final kdf = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: _keyBytes * 8,
    );
    final derived = await kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final bytes = await derived.extractBytes();
    return Uint8List.fromList(bytes);
  }

  /// 用 [key]（32 字节）对 [plaintext] 做 AES-256-GCM 加密，返回
  /// `nonce ‖ ciphertext ‖ tag` 连续打包的 bytes。每次调用生成新 nonce。
  static Future<Uint8List> encrypt(
    Uint8List plaintext,
    Uint8List key,
  ) async {
    final nonce = _aesGcm.newNonce();
    return _encryptWithNonce(plaintext, key, nonce);
  }

  /// **仅用于测试**（KAT）。生产代码 nonce 由 [encrypt] 内部随机生成，不可控、
  /// 无需控制。暴露此接口是为了让已知的 `(K, N, P)` → `(C, T)` 向量能被断言。
  /// nonce 与 key 重用会让 GCM 失去机密性——这是 GCM 的硬性约束。
  @visibleForTesting
  static Future<Uint8List> encryptWithFixedNonce(
    Uint8List plaintext,
    Uint8List key,
    Uint8List nonce,
  ) {
    return _encryptWithNonce(plaintext, key, nonce);
  }

  static Future<Uint8List> _encryptWithNonce(
    Uint8List plaintext,
    Uint8List key,
    List<int> nonce,
  ) async {
    if (key.length != _keyBytes) {
      throw ArgumentError.value(
        key.length,
        'key.length',
        'AES-256 key must be $_keyBytes bytes',
      );
    }
    if (nonce.length != _nonceBytes) {
      throw ArgumentError.value(
        nonce.length,
        'nonce.length',
        'AES-GCM nonce must be $_nonceBytes bytes',
      );
    }
    final box = await _aesGcm.encrypt(
      plaintext,
      secretKey: SecretKey(key),
      nonce: nonce,
    );
    return _pack(nonce, box.cipherText, box.mac.bytes);
  }

  /// 解密 [encrypt] 产出的打包 bytes。
  ///
  /// 失败（长度不足 / tag 验证失败 / 错误 key）统一抛 [DecryptionFailure]——
  /// 上层不关心具体是哪种错，只关心"密文不可信"。
  static Future<Uint8List> decrypt(
    Uint8List packed,
    Uint8List key,
  ) async {
    if (key.length != _keyBytes) {
      throw ArgumentError.value(
        key.length,
        'key.length',
        'AES-256 key must be $_keyBytes bytes',
      );
    }
    if (packed.length < _nonceBytes + _tagBytes) {
      throw DecryptionFailure(
        'packed too short: ${packed.length} bytes '
        '(minimum ${_nonceBytes + _tagBytes})',
      );
    }
    final nonce = packed.sublist(0, _nonceBytes);
    final tag = packed.sublist(packed.length - _tagBytes);
    final ciphertext = packed.sublist(_nonceBytes, packed.length - _tagBytes);
    final box = SecretBox(ciphertext, nonce: nonce, mac: Mac(tag));
    try {
      final plaintext =
          await _aesGcm.decrypt(box, secretKey: SecretKey(key));
      return Uint8List.fromList(plaintext);
    } on SecretBoxAuthenticationError catch (e) {
      throw DecryptionFailure('authentication failed', e);
    }
  }

  static Uint8List _pack(
    List<int> nonce,
    List<int> ciphertext,
    List<int> tag,
  ) {
    final out = Uint8List(nonce.length + ciphertext.length + tag.length);
    var offset = 0;
    out.setRange(offset, offset + nonce.length, nonce);
    offset += nonce.length;
    out.setRange(offset, offset + ciphertext.length, ciphertext);
    offset += ciphertext.length;
    out.setRange(offset, offset + tag.length, tag);
    return out;
  }
}

/// [BianbianCrypto.decrypt] 在长度校验失败 / GCM tag 不匹配时抛出的异常。
///
/// 不透传底层 `SecretBoxAuthenticationError`——上层只需要"不可信"这一个
/// 信号即可决定降级策略（比如提示用户重新输入同步密码）。
class DecryptionFailure implements Exception {
  const DecryptionFailure(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'DecryptionFailure: $message'
      : 'DecryptionFailure: $message ($cause)';
}
