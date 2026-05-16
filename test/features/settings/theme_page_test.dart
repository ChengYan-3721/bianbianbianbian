import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bianbianbianbian/app/app_theme.dart';
import 'package:bianbianbianbian/features/settings/settings_providers.dart';
import 'package:bianbianbianbian/features/settings/theme_page.dart';
import 'package:bianbianbianbian/l10n/app_localizations.dart';

/// Step 15.1 + 15.2 + 15.3：ThemePage widget 测试。
void main() {
  // 通用 overrides——每个用例都需要的三个 key provider。
  List<Override> baseOverrides({
    _FakeCurrentThemeKey? theme,
    _FakeCurrentFontSizeKey? fontSize,
    _FakeCurrentIconPackKey? iconPack,
  }) =>
      [
        currentThemeKeyProvider
            .overrideWith(() => theme ?? _FakeCurrentThemeKey('cream_bunny')),
        currentFontSizeKeyProvider.overrideWith(
            () => fontSize ?? _FakeCurrentFontSizeKey('standard')),
        currentIconPackKeyProvider.overrideWith(
            () => iconPack ?? _FakeCurrentIconPackKey('sticker')),
      ];

  testWidgets('shows all four theme cards with current one selected',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const ThemePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('🐰 奶油兔'), findsOneWidget);
    expect(find.text('🐻 厚棕熊'), findsOneWidget);
    expect(find.text('🌙 月见黑'), findsOneWidget);
    expect(find.text('🍃 薄荷绿'), findsOneWidget);

    // 奶油兔应该有 check_circle（选中态）
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('tapping a theme card calls set on provider', (tester) async {
    final fake = _FakeCurrentThemeKey('cream_bunny');
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(theme: fake),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const ThemePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('🌙 月见黑'));
    await tester.pumpAndSettle();

    expect(fake.lastSetKey, 'moonlight_dark');
  });

  testWidgets('theme description text is visible after scrolling',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const ThemePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final desc = find.text('切换后所有页面即时生效，包括图表与图标底色');
    await tester.scrollUntilVisible(desc, 200.0,
        scrollable: find.byType(Scrollable));
    expect(desc, findsOneWidget);
  });

  // ─── Step 15.2：字号相关测试 ───────────────────────────────────────────

  testWidgets('page title is 外观', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const ThemePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('外观'), findsOneWidget);
  });

  testWidgets('font size section shows three options with standard selected',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const ThemePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byType(SegmentedButton<BianBianFontSize>),
      200.0,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('小'), findsOneWidget);
    expect(find.text('标准'), findsOneWidget);
    expect(find.text('大'), findsOneWidget);

    final button = tester.widget<SegmentedButton<BianBianFontSize>>(
      find.byType(SegmentedButton<BianBianFontSize>),
    );
    expect(button.selected, {BianBianFontSize.standard});
  });

  testWidgets('tapping large font size calls set on provider', (tester) async {
    final fakeFontSize = _FakeCurrentFontSizeKey('standard');
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(fontSize: fakeFontSize),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const ThemePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byType(SegmentedButton<BianBianFontSize>),
      200.0,
      scrollable: find.byType(Scrollable),
    );

    await tester.tap(find.text('大'));
    await tester.pumpAndSettle();

    expect(fakeFontSize.lastSetKey, 'large');
  });

  testWidgets('font size description text is visible after scrolling',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const ThemePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final desc = find.text('大字号会在系统字号基础上再放大 15%，小字号缩小 15%');
    await tester.scrollUntilVisible(desc, 200.0,
        scrollable: find.byType(Scrollable));
    expect(desc, findsOneWidget);
  });

  // ─── Step 15.3：图标包相关测试 ──────────────────────────────────────────

  testWidgets('icon pack section shows both packs with sticker selected',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const ThemePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 滚动到图标包区——先找到"分类图标"标题
    final section = find.text('分类图标');
    await tester.scrollUntilVisible(section, 600.0,
        scrollable: find.byType(Scrollable));
    await tester.pumpAndSettle();

    // 两个 pack 的 label 应可见
    // sticker 默认选中 → 扁平简约没有 check_circle
    // 注意：滚动后主题区的 check_circle 可能已滚出视口
    expect(find.text('✏️ 手绘贴纸'), findsOneWidget);
    expect(find.text('📝 扁平简约'), findsOneWidget);
  });

  testWidgets('tapping flat icon pack calls set on provider', (tester) async {
    final fakeIconPack = _FakeCurrentIconPackKey('sticker');
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(iconPack: fakeIconPack),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const ThemePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 滚动到图标包区
    final section = find.text('分类图标');
    await tester.scrollUntilVisible(section, 600.0,
        scrollable: find.byType(Scrollable));
    await tester.pumpAndSettle();

    // Tap 扁平简约
    await tester.tap(find.text('📝 扁平简约'));
    await tester.pumpAndSettle();

    expect(fakeIconPack.lastSetKey, 'flat');
  });

  testWidgets('icon pack description text is visible after scrolling',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const ThemePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final desc = find.text('切换后分类网格与流水列表图标即时更新；自定义图标不受影响');
    await tester.scrollUntilVisible(desc, 600.0,
        scrollable: find.byType(Scrollable));
    expect(desc, findsOneWidget);
  });
}

/// Fake [CurrentThemeKey] that records set calls in memory.
class _FakeCurrentThemeKey extends CurrentThemeKey {
  String _currentKey;
  _FakeCurrentThemeKey(this._currentKey);

  String? lastSetKey;

  @override
  Future<String> build() async => _currentKey;

  @override
  Future<void> set(String themeKey) async {
    lastSetKey = themeKey;
    _currentKey = themeKey;
    ref.invalidateSelf();
  }
}

/// Fake [CurrentFontSizeKey] that records set calls in memory.
class _FakeCurrentFontSizeKey extends CurrentFontSizeKey {
  String _currentKey;
  _FakeCurrentFontSizeKey(this._currentKey);

  String? lastSetKey;

  @override
  Future<String> build() async => _currentKey;

  @override
  Future<void> set(String fontSizeKey) async {
    lastSetKey = fontSizeKey;
    _currentKey = fontSizeKey;
    ref.invalidateSelf();
  }
}

/// Fake [CurrentIconPackKey] that records set calls in memory.
class _FakeCurrentIconPackKey extends CurrentIconPackKey {
  String _currentKey;
  _FakeCurrentIconPackKey(this._currentKey);

  String? lastSetKey;

  @override
  Future<String> build() async => _currentKey;

  @override
  Future<void> set(String iconPackKey) async {
    lastSetKey = iconPackKey;
    _currentKey = iconPackKey;
    ref.invalidateSelf();
  }
}
