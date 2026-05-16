import 'package:flutter_test/flutter_test.dart';

import 'package:bianbianbianbian/core/util/category_icon_packs.dart';

/// Step 15.3：BianBianIconPack 枚举 + 图标包映射 + resolveCategoryIcon 测试。
void main() {
  // ─── BianBianIconPack 枚举 ──────────────────────────────────────────────

  group('BianBianIconPack', () {
    test('fromKey parses known keys', () {
      expect(BianBianIconPack.fromKey('sticker'), BianBianIconPack.sticker);
      expect(BianBianIconPack.fromKey('flat'), BianBianIconPack.flat);
    });

    test('fromKey falls back to sticker for unknown/null', () {
      expect(BianBianIconPack.fromKey('unknown'), BianBianIconPack.sticker);
      expect(BianBianIconPack.fromKey(null), BianBianIconPack.sticker);
    });

    test('key roundtrip', () {
      for (final p in BianBianIconPack.values) {
        expect(BianBianIconPack.fromKey(p.key), p);
      }
    });

    test('label is non-empty for all packs', () {
      for (final p in BianBianIconPack.values) {
        expect(p.label, isNotEmpty);
      }
    });
  });

  // ─── packDefaultIcon ───────────────────────────────────────────────────

  group('packDefaultIcon', () {
    test('sticker pack returns correct emoji for known category', () {
      expect(packDefaultIcon(BianBianIconPack.sticker, 'food', '午餐'), '🍱');
      expect(packDefaultIcon(BianBianIconPack.sticker, 'income', '工资'), '💰');
      expect(
          packDefaultIcon(BianBianIconPack.sticker, 'transport', '打车'), '🚕');
    });

    test('flat pack returns correct emoji for known category', () {
      expect(packDefaultIcon(BianBianIconPack.flat, 'food', '午餐'), '🍜');
      expect(packDefaultIcon(BianBianIconPack.flat, 'income', '工资'), '💵');
      expect(
          packDefaultIcon(BianBianIconPack.flat, 'transport', '打车'), '🚖');
    });

    test('returns null for unknown parentKey', () {
      expect(
          packDefaultIcon(BianBianIconPack.sticker, 'unknown', '午餐'), isNull);
    });

    test('returns null for unknown category name', () {
      expect(packDefaultIcon(BianBianIconPack.sticker, 'food', '不存在'),
          isNull);
    });
  });

  // ─── resolveCategoryIcon ───────────────────────────────────────────────

  group('resolveCategoryIcon', () {
    test('null stored icon returns pack default', () {
      expect(
        resolveCategoryIcon(null, 'food', '午餐', BianBianIconPack.sticker),
        '🍱',
      );
      expect(
        resolveCategoryIcon(null, 'food', '午餐', BianBianIconPack.flat),
        '🍜',
      );
    });

    test('null stored icon with unknown category returns fallback', () {
      expect(
        resolveCategoryIcon(
            null, 'food', '不存在', BianBianIconPack.sticker),
        '📁',
      );
      expect(
        resolveCategoryIcon(
            null, 'food', '不存在', BianBianIconPack.flat, '❓'),
        '❓',
      );
    });

    test('stored icon matching sticker default resolves to current pack', () {
      // stored = sticker default '🍱' → current pack is flat → returns flat '🍜'
      expect(
        resolveCategoryIcon('🍱', 'food', '午餐', BianBianIconPack.flat),
        '🍜',
      );
      // stored = sticker default '🍱' → current pack is sticker → returns '🍱'
      expect(
        resolveCategoryIcon(
            '🍱', 'food', '午餐', BianBianIconPack.sticker),
        '🍱',
      );
    });

    test('stored icon matching flat default resolves to current pack', () {
      // stored = flat default '🍜' → current pack is sticker → returns sticker '🍱'
      expect(
        resolveCategoryIcon(
            '🍜', 'food', '午餐', BianBianIconPack.sticker),
        '🍱',
      );
      // stored = flat default '🍜' → current pack is flat → returns '🍜'
      expect(
        resolveCategoryIcon('🍜', 'food', '午餐', BianBianIconPack.flat),
        '🍜',
      );
    });

    test('user-customized icon is returned as-is', () {
      // '🎯' is not a pack default for (food, 午餐) → user custom
      expect(
        resolveCategoryIcon('🎯', 'food', '午餐', BianBianIconPack.sticker),
        '🎯',
      );
      expect(
        resolveCategoryIcon('🎯', 'food', '午餐', BianBianIconPack.flat),
        '🎯',
      );
    });

    test('emoji shared by both packs still resolves correctly', () {
      // Both packs use '⛽' for (transport, 加油) → resolves to same regardless
      expect(
        resolveCategoryIcon(
            '⛽', 'transport', '加油', BianBianIconPack.sticker),
        '⛽',
      );
      expect(
        resolveCategoryIcon(
            '⛽', 'transport', '加油', BianBianIconPack.flat),
        '⛽',
      );
    });

    test('custom icon for unknown parentKey returned as-is', () {
      expect(
        resolveCategoryIcon(
            '🎯', 'custom_key', 'anything', BianBianIconPack.sticker),
        '🎯',
      );
    });

    test('null icon for unknown parentKey uses fallback', () {
      expect(
        resolveCategoryIcon(
            null, 'custom_key', 'anything', BianBianIconPack.sticker),
        '📁',
      );
    });

    test('all 11 parentKeys have entries in both packs', () {
      const parentKeyFirstCategory = {
        'income': '工资',
        'food': '早餐',
        'shopping': '日用品',
        'transport': '地铁公交',
        'education': '书籍',
        'entertainment': '电影',
        'social': '礼物',
        'housing': '房租',
        'medical': '门诊',
        'investment': '基金',
        'other': '杂项',
      };
      for (final entry in parentKeyFirstCategory.entries) {
        final pk = entry.key;
        final firstName = entry.value;
        expect(
          packDefaultIcon(BianBianIconPack.sticker, pk, firstName),
          isNotNull,
          reason: 'sticker pack missing parentKey=$pk name=$firstName',
        );
        expect(
          packDefaultIcon(BianBianIconPack.flat, pk, firstName),
          isNotNull,
          reason: 'flat pack missing parentKey=$pk name=$firstName',
        );
      }
      expect(samplePackIcons(BianBianIconPack.sticker).length, 11);
      expect(samplePackIcons(BianBianIconPack.flat).length, 11);
    });
  });

  // ─── samplePackIcons ───────────────────────────────────────────────────

  group('samplePackIcons', () {
    test('returns 11 samples (one per parentKey)', () {
      expect(samplePackIcons(BianBianIconPack.sticker).length, 11);
      expect(samplePackIcons(BianBianIconPack.flat).length, 11);
    });

    test('samples match sticker first entries', () {
      final samples = samplePackIcons(BianBianIconPack.sticker);
      expect(samples[0], '💰'); // income first
      expect(samples[1], '🥣'); // food first
    });

    test('samples match flat first entries', () {
      final samples = samplePackIcons(BianBianIconPack.flat);
      expect(samples[0], '💵'); // income first
      expect(samples[1], '🍚'); // food first
    });
  });
}
