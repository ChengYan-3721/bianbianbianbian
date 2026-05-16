import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bianbianbianbian/app/app_theme.dart';
import 'package:bianbianbianbian/core/util/category_icon_packs.dart';
import 'package:bianbianbianbian/features/settings/settings_providers.dart';

/// Step 15.1 + 15.2：主题 provider + buildAppTheme + BianBianTheme 枚举 +
/// BianBianFontSize 枚举 + fontSizeScaleFactor provider 测试。
void main() {
  // ─── BianBianTheme 枚举 ────────────────────────────────────────────────

  group('BianBianTheme', () {
    test('fromKey parses known keys', () {
      expect(BianBianTheme.fromKey('cream_bunny'), BianBianTheme.creamBunny);
      expect(
          BianBianTheme.fromKey('thick_brown_bear'), BianBianTheme.thickBrownBear);
      expect(BianBianTheme.fromKey('moonlight_dark'), BianBianTheme.moonlightDark);
      expect(BianBianTheme.fromKey('mint_green'), BianBianTheme.mintGreen);
    });

    test('fromKey falls back to creamBunny for unknown/null', () {
      expect(BianBianTheme.fromKey('unknown'), BianBianTheme.creamBunny);
      expect(BianBianTheme.fromKey(null), BianBianTheme.creamBunny);
    });

    test('key roundtrip', () {
      for (final t in BianBianTheme.values) {
        expect(BianBianTheme.fromKey(t.key), t);
      }
    });

    test('isDark only true for moonlightDark', () {
      expect(BianBianTheme.moonlightDark.isDark, isTrue);
      expect(BianBianTheme.creamBunny.isDark, isFalse);
      expect(BianBianTheme.thickBrownBear.isDark, isFalse);
      expect(BianBianTheme.mintGreen.isDark, isFalse);
    });

    // label 现在需要 BuildContext（通过 BianBianThemeL10n 扩展），
    // 在纯单元测试中无法验证；改由 widget 测试覆盖。
  });

  // ─── buildAppTheme ──────────────────────────────────────────────────────

  group('buildAppTheme', () {
    test('every theme produces valid ThemeData', () {
      for (final t in BianBianTheme.values) {
        final theme = buildAppTheme(t);
        expect(theme.colorScheme.brightness,
            t.isDark ? Brightness.dark : Brightness.light);
        expect(theme.useMaterial3, isTrue);
      }
    });

    test('moonlightDark has dark brightness', () {
      final theme = buildAppTheme(BianBianTheme.moonlightDark);
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, theme.colorScheme.surface);
    });

    test('creamBunny scaffold is rice color', () {
      final theme = buildAppTheme(BianBianTheme.creamBunny);
      expect(theme.scaffoldBackgroundColor, const Color(0xFFFFF9EF));
    });

    test('each theme has BianBianSemanticColors extension', () {
      for (final t in BianBianTheme.values) {
        final theme = buildAppTheme(t);
        final semantics = theme.extension<BianBianSemanticColors>();
        expect(semantics, isNotNull);
        expect(semantics!.success, isNotNull);
        expect(semantics.warning, isNotNull);
        expect(semantics.danger, isNotNull);
      }
    });

    test('different themes produce different primary colors', () {
      final primaries = <Color>{};
      for (final t in BianBianTheme.values) {
        final theme = buildAppTheme(t);
        primaries.add(theme.colorScheme.primary);
      }
      // 4 themes should have at least 3 distinct primary colors
      // (creamBunny and thickBrownBear might share brown-ish tones)
      expect(primaries.length, greaterThanOrEqualTo(3));
    });
  });

  // ─── BianBianSemanticColors lerp ────────────────────────────────────────

  group('BianBianSemanticColors', () {
    test('lerp interpolates between two instances', () {
      const a = BianBianSemanticColors(
        success: Color(0xFFA8D8B9),
        warning: Color(0xFFF4A261),
        danger: Color(0xFFE76F51),
      );
      const b = BianBianSemanticColors(
        success: Color(0xFF81C784),
        warning: Color(0xFFFFB74D),
        danger: Color(0xFFE57373),
      );
      final mid = a.lerp(b, 0.5);
      expect(mid.success, Color.lerp(a.success, b.success, 0.5));
      expect(mid.warning, Color.lerp(a.warning, b.warning, 0.5));
      expect(mid.danger, Color.lerp(a.danger, b.danger, 0.5));
    });

    test('lerp with null returns self', () {
      const a = BianBianSemanticColors(
        success: Color(0xFFA8D8B9),
        warning: Color(0xFFF4A261),
        danger: Color(0xFFE76F51),
      );
      expect(a.lerp(null, 0.5), same(a));
    });

    test('copyWith preserves unspecified fields', () {
      const a = BianBianSemanticColors(
        success: Color(0xFFA8D8B9),
        warning: Color(0xFFF4A261),
        danger: Color(0xFFE76F51),
      );
      final b = a.copyWith(success: const Color(0xFF81C784));
      expect(b.success, const Color(0xFF81C784));
      expect(b.warning, a.warning);
      expect(b.danger, a.danger);
    });
  });

  // ─── currentThemeProvider ───────────────────────────────────────────────

  group('currentThemeProvider', () {
    test('returns creamBunny theme when no pref set', () async {
      final container = ProviderContainer(
        overrides: [
          currentThemeKeyProvider.overrideWith(() => _TestCurrentThemeKey('cream_bunny')),
        ],
      );
      await container.read(currentThemeKeyProvider.future);
      final theme = container.read(currentThemeProvider);
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, const Color(0xFF8A5A3B));
      container.dispose();
    });

    test('returns moonlightDark theme for dark key', () async {
      final container = ProviderContainer(
        overrides: [
          currentThemeKeyProvider.overrideWith(() => _TestCurrentThemeKey('moonlight_dark')),
        ],
      );
      await container.read(currentThemeKeyProvider.future);
      final theme = container.read(currentThemeProvider);
      expect(theme.colorScheme.brightness, Brightness.dark);
      container.dispose();
    });

    test('returns mintGreen theme for mint_green key', () async {
      final container = ProviderContainer(
        overrides: [
          currentThemeKeyProvider.overrideWith(() => _TestCurrentThemeKey('mint_green')),
        ],
      );
      await container.read(currentThemeKeyProvider.future);
      final theme = container.read(currentThemeProvider);
      expect(theme.colorScheme.primary, const Color(0xFF2E7D32));
      container.dispose();
    });

    test('returns thickBrownBear theme for thick_brown_bear key', () async {
      final container = ProviderContainer(
        overrides: [
          currentThemeKeyProvider.overrideWith(() => _TestCurrentThemeKey('thick_brown_bear')),
        ],
      );
      await container.read(currentThemeKeyProvider.future);
      final theme = container.read(currentThemeProvider);
      expect(theme.colorScheme.primary, const Color(0xFF6D4C41));
      container.dispose();
    });
  });

  // ─── BianBianFontSize 枚举 (Step 15.2) ─────────────────────────────────

  group('BianBianFontSize', () {
    test('fromKey parses known keys', () {
      expect(BianBianFontSize.fromKey('small'), BianBianFontSize.small);
      expect(BianBianFontSize.fromKey('standard'), BianBianFontSize.standard);
      expect(BianBianFontSize.fromKey('large'), BianBianFontSize.large);
    });

    test('fromKey falls back to standard for unknown/null', () {
      expect(BianBianFontSize.fromKey('unknown'), BianBianFontSize.standard);
      expect(BianBianFontSize.fromKey(null), BianBianFontSize.standard);
    });

    test('key roundtrip', () {
      for (final fs in BianBianFontSize.values) {
        expect(BianBianFontSize.fromKey(fs.key), fs);
      }
    });

    test('scaleFactor values are correct', () {
      expect(BianBianFontSize.small.scaleFactor, 0.85);
      expect(BianBianFontSize.standard.scaleFactor, 1.0);
      expect(BianBianFontSize.large.scaleFactor, 1.15);
    });

    // label 现在需要 BuildContext（通过 BianBianFontSizeL10n 扩展），
    // 在纯单元测试中无法验证；改由 widget 测试覆盖。
  });

  // ─── fontSizeScaleFactorProvider (Step 15.2) ────────────────────────────

  group('fontSizeScaleFactorProvider', () {
    test('returns 1.0 for standard key', () async {
      final container = ProviderContainer(
        overrides: [
          currentFontSizeKeyProvider.overrideWith(
              () => _TestCurrentFontSizeKey('standard')),
        ],
      );
      await container.read(currentFontSizeKeyProvider.future);
      expect(container.read(fontSizeScaleFactorProvider), 1.0);
      container.dispose();
    });

    test('returns 0.85 for small key', () async {
      final container = ProviderContainer(
        overrides: [
          currentFontSizeKeyProvider.overrideWith(
              () => _TestCurrentFontSizeKey('small')),
        ],
      );
      await container.read(currentFontSizeKeyProvider.future);
      expect(container.read(fontSizeScaleFactorProvider), 0.85);
      container.dispose();
    });

    test('returns 1.15 for large key', () async {
      final container = ProviderContainer(
        overrides: [
          currentFontSizeKeyProvider.overrideWith(
              () => _TestCurrentFontSizeKey('large')),
        ],
      );
      await container.read(currentFontSizeKeyProvider.future);
      expect(container.read(fontSizeScaleFactorProvider), 1.15);
      container.dispose();
    });

    test('falls back to 1.0 when key provider is loading', () {
      final container = ProviderContainer(
        overrides: [
          currentFontSizeKeyProvider.overrideWith(
              () => _TestCurrentFontSizeKey('standard')),
        ],
      );
      // 不等 future 完成——模拟 AsyncLoading 态，valueOrNull 为 null。
      expect(container.read(fontSizeScaleFactorProvider), 1.0);
      container.dispose();
    });
  });

  // ─── BianBianIconPack 枚举 (Step 15.3) ─────────────────────────────────

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

  // ─── currentIconPackProvider (Step 15.3) ────────────────────────────────

  group('currentIconPackProvider', () {
    test('returns sticker when no pref set', () async {
      final container = ProviderContainer(
        overrides: [
          currentIconPackKeyProvider
              .overrideWith(() => _TestCurrentIconPackKey('sticker')),
        ],
      );
      await container.read(currentIconPackKeyProvider.future);
      expect(container.read(currentIconPackProvider),
          BianBianIconPack.sticker);
      container.dispose();
    });

    test('returns flat for flat key', () async {
      final container = ProviderContainer(
        overrides: [
          currentIconPackKeyProvider
              .overrideWith(() => _TestCurrentIconPackKey('flat')),
        ],
      );
      await container.read(currentIconPackKeyProvider.future);
      expect(container.read(currentIconPackProvider), BianBianIconPack.flat);
      container.dispose();
    });

    test('falls back to sticker when key provider is loading', () {
      final container = ProviderContainer(
        overrides: [
          currentIconPackKeyProvider
              .overrideWith(() => _TestCurrentIconPackKey('sticker')),
        ],
      );
      expect(container.read(currentIconPackProvider),
          BianBianIconPack.sticker);
      container.dispose();
    });
  });
}

/// Fake [CurrentThemeKey] that returns a fixed key.
class _TestCurrentThemeKey extends CurrentThemeKey {
  final String _key;
  _TestCurrentThemeKey(this._key);

  @override
  Future<String> build() async => _key;
}

/// Fake [CurrentFontSizeKey] that returns a fixed key.
class _TestCurrentFontSizeKey extends CurrentFontSizeKey {
  final String _key;
  _TestCurrentFontSizeKey(this._key);

  @override
  Future<String> build() async => _key;
}

/// Fake [CurrentIconPackKey] that returns a fixed key.
class _TestCurrentIconPackKey extends CurrentIconPackKey {
  final String _key;
  _TestCurrentIconPackKey(this._key);

  @override
  Future<String> build() async => _key;
}
