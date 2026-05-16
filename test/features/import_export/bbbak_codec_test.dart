import 'dart:convert';
import 'dart:typed_data';

import 'package:bianbianbianbian/core/crypto/bianbian_crypto.dart';
import 'package:bianbianbianbian/features/import_export/bbbak_codec.dart';
import 'package:flutter_test/flutter_test.dart';

/// Step 13.2 验证：BbbakCodec 的 encode / decode 行为。
///
/// 单测覆盖：
/// - 空密码、错误盐长度的参数校验
/// - 文件结构（魔数 + 版本 + salt + body）
/// - encode/decode roundtrip（含非 ASCII / 大块字节）
/// - 同密码两次 encode 产出不同字节（盐 + nonce 都新）
/// - 错误密码 → DecryptionFailure
/// - 篡改密文 / 篡改 salt → DecryptionFailure
/// - 损坏魔数 / 损坏版本 / 文件过短 → BbbakFormatException
///
/// **iterations 全部用 1**——把 PBKDF2 时间从 ~50ms 压到 <1ms，让单测套件
/// 跑完仍在秒级；安全语义由 `bianbian_crypto_test.dart` 的 KAT 套件保证。
void main() {
  group('BbbakCodec.encode 参数校验', () {
    test('空密码抛 ArgumentError', () async {
      await expectLater(
        BbbakCodec.encode(
          Uint8List.fromList(utf8.encode('json')),
          '',
          iterations: 1,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('saltGenerator 返回非 16 字节抛 ArgumentError', () async {
      await expectLater(
        BbbakCodec.encode(
          Uint8List.fromList(utf8.encode('json')),
          'pw',
          iterations: 1,
          saltGenerator: () => List<int>.filled(15, 0),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('BbbakCodec.encode 文件结构', () {
    test('开头是 BBBK 魔数 + version=1 + 16 字节 salt + AES-GCM body',
        () async {
      final salt = List<int>.generate(16, (i) => i + 1);
      final packed = await BbbakCodec.encode(
        Uint8List.fromList(utf8.encode('hello')),
        'pw',
        iterations: 1,
        saltGenerator: () => salt,
      );
      final inspected = BbbakCodec.inspect(packed);
      expect(inspected.magicBytes, [0x42, 0x42, 0x42, 0x4B]); // 'BBBK'
      expect(inspected.version, 1);
      expect(inspected.salt, salt);
      // body 是 BianbianCrypto.encrypt 产出（nonce 12 + ct + tag 16），
      // 即至少 28 字节（5 字节 plaintext → ct 5 + nonce 12 + tag 16 = 33）
      expect(inspected.body.length, greaterThanOrEqualTo(28));
      expect(inspected.body.length, 12 + 5 + 16);
    });

    test('headerLength 常量与实测偏移一致', () {
      expect(BbbakCodec.headerLength, 21);
      expect(BbbakCodec.magic.length + 1 + BbbakCodec.saltLength, 21);
    });
  });

  group('BbbakCodec.encode/decode roundtrip', () {
    test('简短英文明文', () async {
      final plain = Uint8List.fromList(utf8.encode('plain ascii text'));
      final packed = await BbbakCodec.encode(plain, 'pw', iterations: 1);
      final decoded =
          await BbbakCodec.decode(packed, 'pw', iterations: 1);
      expect(decoded, plain);
    });

    test('含中文 / emoji / 换行的明文', () async {
      final plain = Uint8List.fromList(
        utf8.encode('你好 🐱\n第二行：边边记账测试 \n 1234567890'),
      );
      final packed = await BbbakCodec.encode(plain, '同步密码', iterations: 1);
      final decoded =
          await BbbakCodec.decode(packed, '同步密码', iterations: 1);
      expect(decoded, plain);
    });

    test('长明文（10KB）', () async {
      final plain = Uint8List.fromList(
        utf8.encode(List.generate(10000, (i) => 'x').join()),
      );
      final packed =
          await BbbakCodec.encode(plain, 'long-pw', iterations: 1);
      final decoded =
          await BbbakCodec.decode(packed, 'long-pw', iterations: 1);
      expect(decoded.length, 10000);
      expect(decoded, plain);
    });

    test('相同密码两次 encode 产出不同 packed（salt + nonce 都新）',
        () async {
      final plain = Uint8List.fromList(utf8.encode('same plaintext'));
      final a = await BbbakCodec.encode(plain, 'pw', iterations: 1);
      final b = await BbbakCodec.encode(plain, 'pw', iterations: 1);
      expect(a, isNot(b), reason: '每次都应有新 salt + 新 nonce');
      // 两份都能用同一密码解开
      expect(
        await BbbakCodec.decode(a, 'pw', iterations: 1),
        plain,
      );
      expect(
        await BbbakCodec.decode(b, 'pw', iterations: 1),
        plain,
      );
    });
  });

  group('BbbakCodec.decode 错误密码 / 篡改', () {
    test('错误密码抛 DecryptionFailure', () async {
      final plain = Uint8List.fromList(utf8.encode('secret'));
      final packed = await BbbakCodec.encode(plain, 'right-pw', iterations: 1);
      await expectLater(
        BbbakCodec.decode(packed, 'wrong-pw', iterations: 1),
        throwsA(isA<DecryptionFailure>()),
      );
    });

    test('密码大小写敏感', () async {
      final plain = Uint8List.fromList(utf8.encode('case-sensitive'));
      final packed = await BbbakCodec.encode(plain, 'PassWord', iterations: 1);
      await expectLater(
        BbbakCodec.decode(packed, 'password', iterations: 1),
        throwsA(isA<DecryptionFailure>()),
      );
    });

    test('密文体被翻一字节即抛 DecryptionFailure（GCM tag 校验生效）',
        () async {
      final plain = Uint8List.fromList(utf8.encode('sensitive payload'));
      final packed = await BbbakCodec.encode(plain, 'pw', iterations: 1);
      final tampered = Uint8List.fromList(packed);
      // 翻 body 区第一个字节（跳过 21 字节头）
      tampered[BbbakCodec.headerLength] ^= 0xFF;
      await expectLater(
        BbbakCodec.decode(tampered, 'pw', iterations: 1),
        throwsA(isA<DecryptionFailure>()),
      );
    });

    test('salt 被改一字节 → 派生 key 不同 → DecryptionFailure', () async {
      final plain = Uint8List.fromList(utf8.encode('payload'));
      final packed = await BbbakCodec.encode(plain, 'pw', iterations: 1);
      final tampered = Uint8List.fromList(packed);
      // 翻 salt 区第一个字节（位置 5 = magic 4 + version 1）
      tampered[5] ^= 0xFF;
      await expectLater(
        BbbakCodec.decode(tampered, 'pw', iterations: 1),
        throwsA(isA<DecryptionFailure>()),
      );
    });

    test('decode 空密码抛 ArgumentError', () async {
      final packed =
          await BbbakCodec.encode(Uint8List(1), 'pw', iterations: 1);
      await expectLater(
        BbbakCodec.decode(packed, '', iterations: 1),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('BbbakCodec.decode 文件格式错误', () {
    test('文件长度小于 headerLength 抛 BbbakFormatException', () async {
      final tooShort = Uint8List(BbbakCodec.headerLength - 1);
      await expectLater(
        BbbakCodec.decode(tooShort, 'pw', iterations: 1),
        throwsA(isA<BbbakFormatException>()),
      );
    });

    test('魔数错(非 BBBK)抛 BbbakFormatException', () async {
      final plain = Uint8List.fromList(utf8.encode('p'));
      final packed = await BbbakCodec.encode(plain, 'pw', iterations: 1);
      final tampered = Uint8List.fromList(packed);
      tampered[0] = 0x00; // 把第一个字节由 'B' 改为 0x00
      await expectLater(
        BbbakCodec.decode(tampered, 'pw', iterations: 1),
        throwsA(isA<BbbakFormatException>()),
      );
    });

    test('版本号不识别(非 1)抛 BbbakFormatException', () async {
      final plain = Uint8List.fromList(utf8.encode('p'));
      final packed = await BbbakCodec.encode(plain, 'pw', iterations: 1);
      final tampered = Uint8List.fromList(packed);
      tampered[BbbakCodec.magic.length] = 0xFE; // 把版本号改为 0xFE
      await expectLater(
        BbbakCodec.decode(tampered, 'pw', iterations: 1),
        throwsA(isA<BbbakFormatException>()),
      );
    });

    test('inspect 在过短文件上抛 BbbakFormatException', () {
      expect(
        () => BbbakCodec.inspect(Uint8List(20)),
        throwsA(isA<BbbakFormatException>()),
      );
    });
  });

  group('BbbakCodec 与 JSON 序列化集成', () {
    test('JSON 字符串经 encode → decode 后字节级一致', () async {
      const jsonStr =
          '{"version":1,"exported_at":"2026-05-04T12:00:00.000Z","ledgers":[]}';
      final plain = Uint8List.fromList(utf8.encode(jsonStr));
      final packed = await BbbakCodec.encode(plain, '同步密码', iterations: 1);
      final decoded =
          await BbbakCodec.decode(packed, '同步密码', iterations: 1);
      expect(utf8.decode(decoded), jsonStr);
    });
  });
}
