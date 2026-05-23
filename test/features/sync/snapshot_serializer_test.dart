import 'dart:convert';
import 'dart:io' show GZipCodec;

import 'package:bianbianbianbian/domain/entity/account.dart';
import 'package:bianbianbianbian/domain/entity/category.dart';
import 'package:bianbianbianbian/domain/entity/ledger.dart';
import 'package:bianbianbianbian/features/sync/snapshot_serializer.dart';
import 'package:flutter_test/flutter_test.dart';

/// 覆盖 SVG 图标字段在 LedgerSnapshot / MultiLedgerSnapshot 序列化与
/// LedgerSnapshotSerializer.fingerprint 中的行为。
///
/// 生产代码委托 entity 层 toJson/fromJson，理论上 SVG 自动随行；这里
/// 用测试把不变量钉死，防止未来重构（例如改 stable map 字段名时）漏掉。

const _devId = 'test-dev';

Ledger _ledger({String? coverSvg}) => Ledger(
      id: 'L1',
      name: '生活',
      coverEmoji: '📒',
      coverSvg: coverSvg,
      createdAt: DateTime.utc(2026, 5, 1),
      updatedAt: DateTime.utc(2026, 5, 1),
      deviceId: _devId,
    );

Category _category({String? iconSvg}) => Category(
      id: 'C1',
      name: '餐饮',
      parentKey: 'food',
      icon: '🍚',
      iconSvg: iconSvg,
      updatedAt: DateTime.utc(2026, 5, 1),
      deviceId: _devId,
    );

Account _account({String? iconSvg}) => Account(
      id: 'A1',
      name: '现金',
      type: 'cash',
      icon: '💵',
      iconSvg: iconSvg,
      updatedAt: DateTime.utc(2026, 5, 1),
      deviceId: _devId,
    );

LedgerSnapshot _snapshot({
  String? ledgerCoverSvg,
  String? categoryIconSvg,
  String? accountIconSvg,
}) =>
    LedgerSnapshot(
      version: LedgerSnapshot.kVersion,
      exportedAt: DateTime.utc(2026, 5, 4, 12),
      deviceId: _devId,
      ledger: _ledger(coverSvg: ledgerCoverSvg),
      categories: [_category(iconSvg: categoryIconSvg)],
      accounts: [_account(iconSvg: accountIconSvg)],
      transactions: const [],
      budgets: const [],
    );

void main() {
  // LedgerSnapshot 没有覆盖 ==，比较 toJson() 的 Map 结构而非实例本身。
  // 想换回 expect(decoded, snap) 须先给 LedgerSnapshot 加 == / hashCode。
  group('LedgerSnapshot SVG round-trip', () {
    test('toJson / fromJson 保留 ledger.coverSvg', () {
      const svg = '<svg viewBox="0 0 24 24"><rect width="24" height="24"/></svg>';
      final snap = _snapshot(ledgerCoverSvg: svg);
      final decoded = LedgerSnapshot.fromJson(snap.toJson());
      expect(decoded.ledger.coverSvg, svg);
      expect(decoded.toJson(), snap.toJson());
    });

    test('toJson / fromJson 保留 category.iconSvg', () {
      const svg = '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="8"/></svg>';
      final snap = _snapshot(categoryIconSvg: svg);
      final decoded = LedgerSnapshot.fromJson(snap.toJson());
      expect(decoded.categories.single.iconSvg, svg);
      expect(decoded.toJson(), snap.toJson());
    });

    test('toJson / fromJson 保留 account.iconSvg', () {
      const svg = '<svg viewBox="0 0 24 24"><path d="M0 0h24v24"/></svg>';
      final snap = _snapshot(accountIconSvg: svg);
      final decoded = LedgerSnapshot.fromJson(snap.toJson());
      expect(decoded.accounts.single.iconSvg, svg);
      expect(decoded.toJson(), snap.toJson());
    });

    test('MultiLedgerSnapshot 包一层后 SVG 仍然 round-trip', () {
      const svg = '<svg/>';
      final multi = MultiLedgerSnapshot(
        version: MultiLedgerSnapshot.kVersion,
        exportedAt: DateTime.utc(2026, 5, 4, 12),
        deviceId: _devId,
        ledgers: [
          _snapshot(
            ledgerCoverSvg: svg,
            categoryIconSvg: svg,
            accountIconSvg: svg,
          ),
        ],
      );
      final decoded = MultiLedgerSnapshot.fromJson(multi.toJson());
      expect(decoded.ledgers.single.ledger.coverSvg, svg);
      expect(decoded.ledgers.single.categories.single.iconSvg, svg);
      expect(decoded.ledgers.single.accounts.single.iconSvg, svg);
    });
  });

  group('LedgerSnapshotSerializer.fingerprint 对 SVG 变化敏感', () {
    const serializer = LedgerSnapshotSerializer();

    Future<String> fp(LedgerSnapshot s) async =>
        serializer.fingerprint(await serializer.serialize(s));

    test('改 ledger.coverSvg 指纹变化', () async {
      final a = _snapshot(ledgerCoverSvg: '<svg id="a"/>');
      final b = _snapshot(ledgerCoverSvg: '<svg id="b"/>');
      expect(await fp(a), isNot(await fp(b)));
    });

    test('改 categories[0].iconSvg 指纹变化', () async {
      final a = _snapshot(categoryIconSvg: '<svg id="a"/>');
      final b = _snapshot(categoryIconSvg: '<svg id="b"/>');
      expect(await fp(a), isNot(await fp(b)));
    });

    test('改 accounts[0].iconSvg 指纹变化', () async {
      final a = _snapshot(accountIconSvg: '<svg id="a"/>');
      final b = _snapshot(accountIconSvg: '<svg id="b"/>');
      expect(await fp(a), isNot(await fp(b)));
    });

    test('三处 SVG 全等时指纹相等（control case）', () async {
      const svg = '<svg id="same"/>';
      final a = _snapshot(
        ledgerCoverSvg: svg,
        categoryIconSvg: svg,
        accountIconSvg: svg,
      );
      final b = _snapshot(
        ledgerCoverSvg: svg,
        categoryIconSvg: svg,
        accountIconSvg: svg,
      );
      expect(await fp(a), await fp(b));
    });
  });

  /// gzip 压缩（2026-05-21 起）—— 验证体积节省、round-trip、向下兼容、
  /// fingerprint 跨格式稳定四个不变量。
  group('LedgerSnapshotSerializer · gzip 压缩', () {
    const serializer = LedgerSnapshotSerializer();

    // 构造一个含较多重复字段的较大 snapshot,验证 gzip 实际有压缩收益。
    LedgerSnapshot bigSnap() => LedgerSnapshot(
          version: LedgerSnapshot.kVersion,
          exportedAt: DateTime.utc(2026, 5, 4, 12),
          deviceId: _devId,
          ledger: _ledger(),
          categories: List.generate(20, (i) => _category()),
          accounts: List.generate(10, (i) => _account()),
          transactions: const [],
          budgets: const [],
        );

    test('serialize 输出以 "gz:" 前缀开头', () async {
      final out = await serializer.serialize(bigSnap());
      expect(out.startsWith('gz:'), isTrue);
    });

    test('serialize 输出体积明显小于原 JSON（>= 30% 节省）', () async {
      final snap = bigSnap();
      final rawJson = jsonEncode(snap.toJson());
      final compressed = await serializer.serialize(snap);
      // 实测 20 categories + 10 accounts 重复字段名,gzip+base64 净节省
      // 通常 > 50%;保守阈值 30% 防止环境差异 flakiness。
      expect(
        compressed.length,
        lessThan((rawJson.length * 0.7).floor()),
        reason: 'raw=${rawJson.length} compressed=${compressed.length}',
      );
    });

    test('serialize → deserialize round-trip 数据一致', () async {
      final snap = bigSnap();
      final encoded = await serializer.serialize(snap);
      final decoded = await serializer.deserialize(encoded);
      expect(decoded.toJson(), snap.toJson());
    });

    test('向下兼容:deserialize 老 JSON 格式(无 gz: 前缀)仍工作', () async {
      final snap = bigSnap();
      // 老格式 = 直接 jsonEncode,无 gz: 前缀
      final legacyJson = jsonEncode(snap.toJson());
      final decoded = await serializer.deserialize(legacyJson);
      expect(decoded.toJson(), snap.toJson());
    });

    test('fingerprint 跨格式稳定:gzip 与老 JSON 同数据 → 同 fingerprint', () {
      final snap = bigSnap();
      final legacyJson = jsonEncode(snap.toJson());
      // 同步触发 _encodeGzipBase64(jsonEncode(...))——绕过 await 拿同样的字节。
      // 通过 serializer.serialize 路径拿压缩字符串。
      // 这里直接对 legacyJson 做一次 gzip+base64 包装,模拟"升级后的客户端"
      // 输出格式。
      final compressed =
          'gz:${base64Encode(GZipCodec().encode(utf8.encode(legacyJson)))}';
      final fpLegacy = serializer.fingerprint(legacyJson);
      final fpGzipped = serializer.fingerprint(compressed);
      expect(
        fpGzipped,
        fpLegacy,
        reason: '升级后的 fingerprint 不能突变,否则会触发 spurious upload',
      );
    });
  });
}
