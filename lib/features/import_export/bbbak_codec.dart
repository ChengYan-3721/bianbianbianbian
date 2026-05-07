import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../core/crypto/bianbian_crypto.dart';

/// `.bbbak` 加密备份包的二进制 codec（Step 13.2）。
///
/// **不持有 Flutter 依赖**——可在 Dart-only 环境单测，与 [BianbianCrypto]
/// 一样是纯函数式工具。
///
/// ## 文件格式
///
/// ```text
/// ┌──────────────┬──────────────┬───────────────┬──────────────────────────────┐
/// │ magic 4 B    │ version 1 B  │ salt 16 B     │ packed AES-GCM bytes (rest)  │
/// │ 0x42 'B'     │ 0x01         │ Random.secure │ nonce(12) + ct(N) + tag(16)  │
/// │ 0x42 'B'     │              │               │                              │
/// │ 0x42 'B'     │              │               │                              │
/// │ 0x4B 'K'     │              │               │                              │
/// └──────────────┴──────────────┴───────────────┴──────────────────────────────┘
/// ```
///
/// - **magic `BBBK`**：让用户/工具能一眼辨认是边边记账加密备份；
///   同时让 [decode] 在密码错误前就能拒绝完全不相关的文件。
/// - **version 1 B**：未来如果要换 KDF / cipher / payload shape，本字节升 v2，
///   [decode] 按版本路由到不同解码路径。当前仅支持 v1。
/// - **salt 16 B**：每个备份包独立随机 salt，让相同密码下两次导出产出
///   不同的派生 key + 密文——避免离线密码字典攻击批量复用。
/// - **packed bytes**：直接调 [BianbianCrypto.encrypt] 输出（已自带 nonce 前置 +
///   tag 后置）。
///
/// ## 加密管线
///
/// ```text
/// password ─┐
///           ├─► PBKDF2-HMAC-SHA256(salt, iter=100000) ─► key 32 B
/// salt ─────┘                                              │
///                                                          ▼
/// json bytes ──────────────────────────────────► AES-256-GCM(key, fresh nonce)
///                                                          │
///                                                          ▼
///                                            magic ‖ ver ‖ salt ‖ nonce‖ct‖tag
///                                                          │
///                                                          ▼
///                                                     `.bbbak` 文件
/// ```
///
/// 解密反向：读 magic / version / salt → 派生 key → 调 [BianbianCrypto.decrypt]
/// 校验 GCM tag → 还原 JSON 字节流。错误密码 / 篡改 / 文件损坏统一抛
/// [DecryptionFailure]；魔数错 / 版本不识别抛 [BbbakFormatException]。
///
/// ## 安全性
///
/// - **PBKDF2 100k iterations**：与 [BianbianCrypto.defaultPbkdf2Iterations]
///   一致；OWASP 2023 推荐下限。
/// - **salt 16 字节由 `Random.secure()` 生成**：跨平台密码学安全 RNG（POSIX
///   `/dev/urandom`、Windows `BCryptGenRandom`、iOS / macOS `SecRandomCopyBytes`）。
/// - **AES-GCM nonce 由 [BianbianCrypto.encrypt] 内部 fresh 生成**：每个文件
///   独立，不会跨文件复用。
/// - **密码不持久化**：`.bbbak` 内不含密码也不含密码 hash——丢失密码 = 无法恢复。
///   UI 必须以醒目文案提示用户（design-document §5.5.4 + Step 13.2 验收要求）。
class BbbakCodec {
  BbbakCodec._();

  /// `BBBK` 魔数 4 字节。
  static const List<int> magic = <int>[0x42, 0x42, 0x42, 0x4B];

  /// 当前文件格式版本号。
  static const int kVersion = 1;

  /// 每个备份包的随机 salt 长度。
  static const int saltLength = 16;

  /// 头部固定长度 = magic + version + salt = 4 + 1 + 16 = 21 字节。
  static const int headerLength = 4 + 1 + saltLength;

  /// 默认随机 salt 生成器（生产用 [Random.secure]，测试可注入固定 [Random]）。
  static List<int> _defaultSaltGenerator() {
    final rng = Random.secure();
    final out = Uint8List(saltLength);
    for (var i = 0; i < saltLength; i++) {
      out[i] = rng.nextInt(256);
    }
    return out;
  }

  /// 用密码加密 [plaintextJson]，返回 `.bbbak` 文件二进制内容。
  ///
  /// [iterations] 默认 [BianbianCrypto.defaultPbkdf2Iterations]=100000；
  /// 仅测试为了跑得快才会降低。生产侧不要传——保持默认。
  ///
  /// [saltGenerator] 仅供测试注入固定 salt 让 KAT 可断言；生产路径走默认
  /// [Random.secure]。
  static Future<Uint8List> encode(
    Uint8List plaintextJson,
    String password, {
    int iterations = BianbianCrypto.defaultPbkdf2Iterations,
    List<int> Function()? saltGenerator,
  }) async {
    if (password.isEmpty) {
      throw ArgumentError.value(password, 'password', 'must not be empty');
    }
    final saltList = (saltGenerator ?? _defaultSaltGenerator)();
    if (saltList.length != saltLength) {
      throw ArgumentError.value(
        saltList.length,
        'salt.length',
        'must be $saltLength bytes',
      );
    }
    final salt = Uint8List.fromList(saltList);
    final key = await BianbianCrypto.deriveKey(
      password,
      salt,
      iterations: iterations,
    );
    final packed = await BianbianCrypto.encrypt(plaintextJson, key);

    final out = Uint8List(headerLength + packed.length);
    out.setRange(0, magic.length, magic);
    out[magic.length] = kVersion;
    out.setRange(magic.length + 1, headerLength, salt);
    out.setRange(headerLength, out.length, packed);
    return out;
  }

  /// 用密码解密 `.bbbak` 文件二进制内容，返回原始 JSON 字节流。
  ///
  /// 错误密码 / 篡改 / 文件损坏 → [DecryptionFailure]
  /// 魔数错 / 不支持的版本 / 文件过短 → [BbbakFormatException]
  static Future<Uint8List> decode(
    Uint8List packed,
    String password, {
    int iterations = BianbianCrypto.defaultPbkdf2Iterations,
  }) async {
    if (password.isEmpty) {
      throw ArgumentError.value(password, 'password', 'must not be empty');
    }
    if (packed.length < headerLength) {
      throw BbbakFormatException(
        'packed too short: ${packed.length} bytes (minimum $headerLength)',
      );
    }
    for (var i = 0; i < magic.length; i++) {
      if (packed[i] != magic[i]) {
        throw const BbbakFormatException('not a .bbbak file (magic mismatch)');
      }
    }
    final version = packed[magic.length];
    if (version != kVersion) {
      throw BbbakFormatException(
        'unsupported .bbbak version: $version (expected $kVersion)',
      );
    }
    final salt = Uint8List.fromList(
      packed.sublist(magic.length + 1, headerLength),
    );
    final body = Uint8List.fromList(packed.sublist(headerLength));
    final key = await BianbianCrypto.deriveKey(
      password,
      salt,
      iterations: iterations,
    );
    return BianbianCrypto.decrypt(body, key);
  }

  /// 仅供测试：暴露 packed bytes 切片，便于断言文件结构（魔数/版本/salt 偏移）。
  @visibleForTesting
  static ({List<int> magicBytes, int version, List<int> salt, List<int> body})
      inspect(Uint8List packed) {
    if (packed.length < headerLength) {
      throw BbbakFormatException(
        'packed too short: ${packed.length} bytes (minimum $headerLength)',
      );
    }
    return (
      magicBytes: packed.sublist(0, magic.length),
      version: packed[magic.length],
      salt: packed.sublist(magic.length + 1, headerLength),
      body: packed.sublist(headerLength),
    );
  }
}

/// `.bbbak` 文件结构层错误（魔数错 / 版本不支持 / 长度不足）。
///
/// 与 [DecryptionFailure] 区分：前者是"这压根不是合法 .bbbak 文件"，后者是
/// "文件结构 OK，但密码错或被篡改"。UI 文案应区别提示——前者建议用户检查
/// 文件来源，后者建议用户重新输入密码。
class BbbakFormatException implements Exception {
  const BbbakFormatException(this.message);

  final String message;

  @override
  String toString() => 'BbbakFormatException: $message';
}
