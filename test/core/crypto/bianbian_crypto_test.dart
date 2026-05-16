import 'dart:convert';
import 'dart:typed_data';

import 'package:bianbianbianbian/core/crypto/bianbian_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Step 1.6 验证：BianbianCrypto 的 PBKDF2 + AES-256-GCM 行为。
///
/// 两条 KAT（Known-Answer Test）锁死底层实现：
/// - **PBKDF2**：RFC 7914 §11 给出的
///   `PBKDF2-HMAC-SHA-256("passwd","salt",1,64)` 向量（取前 32 字节）。
/// - **AES-256-GCM**：NIST SP 800-38D 的 Test Case 13（256-bit 全零 key +
///   96-bit 全零 nonce + 16 字节全零明文），密文 `cea7403d4d606b6e074ec5d3baf39d18`
///   + tag `d0d1c8a799996bf0265b98b5d48ab919`。
///
/// 往返测试确认 nonce 随机、tag 完整性生效、错误 key 不泄漏明文。
void main() {
  group('BianbianCrypto.deriveKey', () {
    test('KAT: RFC 7914 PBKDF2-HMAC-SHA256 ("passwd","salt",c=1) 前 32 字节',
        () async {
      final expected = _hex(
        '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc',
      );

      final derived = await BianbianCrypto.deriveKey(
        'passwd',
        Uint8List.fromList(utf8.encode('salt')),
        iterations: 1,
      );

      expect(derived, expected);
    });

    test('默认 iterations=100000 产出 32 字节', () async {
      final derived = await BianbianCrypto.deriveKey(
        'correct horse battery staple',
        Uint8List.fromList(utf8.encode('16-byte-salt!!!!')),
      );
      expect(derived.length, 32);
    });

    test('相同输入确定性 / 不同 salt 产出不同密钥', () async {
      final salt1 = Uint8List.fromList(utf8.encode('salt-one--------'));
      final salt2 = Uint8List.fromList(utf8.encode('salt-two--------'));
      // 迭代数降到 1 让本例跑得更快——真实场景仍用默认值
      final a = await BianbianCrypto.deriveKey('pw', salt1, iterations: 1);
      final b = await BianbianCrypto.deriveKey('pw', salt1, iterations: 1);
      final c = await BianbianCrypto.deriveKey('pw', salt2, iterations: 1);
      expect(a, b, reason: '相同 (password, salt, iter) 必须确定性');
      expect(a, isNot(c), reason: '不同 salt 必须产出不同密钥');
    });
  });

  group('BianbianCrypto.encrypt / decrypt', () {
    test('KAT: NIST AES-256-GCM Test Case 13（零 key / 零 nonce / 16 字节零明文）',
        () async {
      final key = Uint8List(32); // 32 零字节
      final nonce = Uint8List(12); // 12 零字节
      final plaintext = Uint8List(16); // 16 零字节
      final expectedCiphertext =
          _hex('cea7403d4d606b6e074ec5d3baf39d18');
      final expectedTag = _hex('d0d1c8a799996bf0265b98b5d48ab919');
      final expectedPacked = Uint8List(12 + 16 + 16)
        ..setRange(0, 12, nonce)
        ..setRange(12, 28, expectedCiphertext)
        ..setRange(28, 44, expectedTag);

      final packed =
          await BianbianCrypto.encryptWithFixedNonce(plaintext, key, nonce);

      expect(packed, expectedPacked);

      // 反向验证:同一密钥解包得回 16 个零字节
      final roundtrip = await BianbianCrypto.decrypt(packed, key);
      expect(roundtrip, plaintext);
    });

    test('roundtrip:encrypt → decrypt 回到原明文（含非 ASCII）', () async {
      final key = _countingBytes(32);
      final plaintext = Uint8List.fromList(
        utf8.encode('你好，边边！Hello 🐱'),
      );

      final packed = await BianbianCrypto.encrypt(plaintext, key);
      expect(packed.length, greaterThan(12 + 16),
          reason: '打包必须大于 nonce+tag 固定开销');

      final decrypted = await BianbianCrypto.decrypt(packed, key);
      expect(decrypted, plaintext);
    });

    test('同一明文两次 encrypt 产出不同 bytes（fresh nonce），但都能被 decrypt',
        () async {
      final key = _countingBytes(32);
      final plaintext = Uint8List.fromList(utf8.encode('same text'));

      final a = await BianbianCrypto.encrypt(plaintext, key);
      final b = await BianbianCrypto.encrypt(plaintext, key);

      expect(a, isNot(b), reason: 'nonce 每次都应随机');
      expect(await BianbianCrypto.decrypt(a, key), plaintext);
      expect(await BianbianCrypto.decrypt(b, key), plaintext);
    });

    test('错误密钥解密抛 DecryptionFailure', () async {
      final key = _countingBytes(32);
      final wrongKey = Uint8List(32); // 全零,与 countingBytes 不同
      final packed = await BianbianCrypto.encrypt(
        Uint8List.fromList(utf8.encode('secret')),
        key,
      );

      await expectLater(
        BianbianCrypto.decrypt(packed, wrongKey),
        throwsA(isA<DecryptionFailure>()),
      );
    });

    test('密文被篡改一字节即抛 DecryptionFailure（GCM tag 认证生效）', () async {
      final key = _countingBytes(32);
      final packed = await BianbianCrypto.encrypt(
        Uint8List.fromList(utf8.encode('sensitive')),
        key,
      );
      final tampered = Uint8List.fromList(packed);
      // 翻转密文段的第一个字节(跳过 nonce 12 字节)
      tampered[12] ^= 0xFF;

      await expectLater(
        BianbianCrypto.decrypt(tampered, key),
        throwsA(isA<DecryptionFailure>()),
      );
    });

    test('tag 被篡改一字节即抛 DecryptionFailure', () async {
      final key = _countingBytes(32);
      final packed = await BianbianCrypto.encrypt(
        Uint8List.fromList(utf8.encode('sensitive')),
        key,
      );
      final tampered = Uint8List.fromList(packed);
      tampered[tampered.length - 1] ^= 0xFF;

      await expectLater(
        BianbianCrypto.decrypt(tampered, key),
        throwsA(isA<DecryptionFailure>()),
      );
    });

    test('packed 长度不足 nonce+tag 时抛 DecryptionFailure', () async {
      final key = _countingBytes(32);
      final tooShort = Uint8List(27); // 小于 12 + 16 = 28

      await expectLater(
        BianbianCrypto.decrypt(tooShort, key),
        throwsA(isA<DecryptionFailure>()),
      );
    });

    test('encrypt 对非 32 字节 key 抛 ArgumentError', () async {
      await expectLater(
        BianbianCrypto.encrypt(
          Uint8List.fromList(utf8.encode('x')),
          Uint8List(16), // 错误长度
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

/// 构造 `[0, 1, 2, ..., length-1]` 的 Uint8List。
/// `_countingBytes(32)` 刚好 32 字节，可作为 AES-256 的合法（非零）key。
Uint8List _countingBytes(int length) {
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = i & 0xFF;
  }
  return bytes;
}

Uint8List _hex(String hex) {
  assert(hex.length.isEven, 'hex 必须是偶数长度');
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}
