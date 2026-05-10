import 'package:flutter/material.dart';

// ─── 主题枚举 ───────────────────────────────────────────────────────────────

/// 四套主题标识，与 `user_pref.theme` 列值一一对应。
enum BianBianTheme {
  creamBunny('cream_bunny'),
  thickBrownBear('thick_brown_bear'),
  moonlightDark('moonlight_dark'),
  mintGreen('mint_green');

  const BianBianTheme(this.key);
  final String key;

  /// 从 `user_pref.theme` 列值解析；未知值回退默认。
  static BianBianTheme fromKey(String? key) {
    return BianBianTheme.values.firstWhere(
      (t) => t.key == key,
      orElse: () => BianBianTheme.creamBunny,
    );
  }

  /// 显示名 + emoji 前缀。
  String get label => switch (this) {
        BianBianTheme.creamBunny => '🐰 奶油兔',
        BianBianTheme.thickBrownBear => '🐻 厚棕熊',
        BianBianTheme.moonlightDark => '🌙 月见黑',
        BianBianTheme.mintGreen => '🍃 薄荷绿',
      };

  bool get isDark => this == BianBianTheme.moonlightDark;
}

// ─── 字号枚举 ───────────────────────────────────────────────────────────────

/// 三档字号，与 `user_pref.font_size` 列值一一对应。
/// [scaleFactor] 为相对系统字号的乘数——`standard` 完全跟随系统，
/// `small` / `large` 在系统基础上缩小 / 放大 15%。
enum BianBianFontSize {
  small('small', 0.85, '小'),
  standard('standard', 1.0, '标准'),
  large('large', 1.15, '大');

  const BianBianFontSize(this.key, this.scaleFactor, this.label);
  final String key;
  final double scaleFactor;
  final String label;

  static BianBianFontSize fromKey(String? key) => switch (key) {
        'small' => BianBianFontSize.small,
        'large' => BianBianFontSize.large,
        _ => BianBianFontSize.standard,
      };
}

// ─── 色板常量 ───────────────────────────────────────────────────────────────

// 奶油兔（design-document §10.2）
const _creamYellow = Color(0xFFFFE9B0);
const _sakuraPink = Color(0xFFFFB7C5);
const _cocoaBrown = Color(0xFF8A5A3B);
const _matchaGreen = Color(0xFFA8D8B9);
const _honeyOrange = Color(0xFFF4A261);
const _appleRed = Color(0xFFE76F51);
const _rice = Color(0xFFFFF9EF);
const _mist = Color(0xFFFDF3E7);

// 厚棕熊
const _warmBrown = Color(0xFF6D4C41);
const _warmBrownLight = Color(0xFFD7CCC8);
const _warmBeige = Color(0xFFEFEBE9);
const _warmCream = Color(0xFFF5F0EC);
const _warmAmber = Color(0xFFFFB74D);
const _warmRose = Color(0xFFE57373);

// 月见黑
const _moonPurple = Color(0xFFB39DDB);
const _moonSurface = Color(0xFF1E1E2E);
const _moonOnSurface = Color(0xFFE0E0E8);
const _moonCard = Color(0xFF2A2A3C);
const _moonPrimary = Color(0xFFCE93D8);
const _moonError = Color(0xFFEF5350);
const _moonSuccess = Color(0xFF81C784);
const _moonWarning = Color(0xFFFFB74D);

// 薄荷绿
const _mintPrimary = Color(0xFF2E7D32);
const _mintPrimaryLight = Color(0xFFC8E6C9);
const _mintSurface = Color(0xFFF1F8E9);
const _mintCard = Color(0xFFDCEDC8);
const _mintAccent = Color(0xFF66BB6A);
const _mintError = Color(0xFFE57373);
const _mintWarning = Color(0xFFFFB74D);

// 阴影色：可可棕 8% alpha（设计文档 §10.5）
const _cardShadow = Color(0x148A5A3B);
const _darkCardShadow = Color(0x24000000);

// ─── 色板构建 ──────────────────────────────────────────────────────────────

ColorScheme _colorSchemeFor(BianBianTheme theme) => switch (theme) {
      BianBianTheme.creamBunny => const ColorScheme(
          brightness: Brightness.light,
          primary: _cocoaBrown,
          onPrimary: Colors.white,
          primaryContainer: _creamYellow,
          onPrimaryContainer: _cocoaBrown,
          secondary: _sakuraPink,
          onSecondary: _cocoaBrown,
          tertiary: _cocoaBrown,
          onTertiary: Colors.white,
          error: _appleRed,
          onError: Colors.white,
          surface: _rice,
          onSurface: _cocoaBrown,
          surfaceContainerHighest: _mist,
          surfaceTint: _cocoaBrown,
        ),
      BianBianTheme.thickBrownBear => const ColorScheme(
          brightness: Brightness.light,
          primary: _warmBrown,
          onPrimary: Colors.white,
          primaryContainer: _warmBrownLight,
          onPrimaryContainer: _warmBrown,
          secondary: _warmAmber,
          onSecondary: _warmBrown,
          tertiary: _warmBrown,
          onTertiary: Colors.white,
          error: _warmRose,
          onError: Colors.white,
          surface: _warmCream,
          onSurface: _warmBrown,
          surfaceContainerHighest: _warmBeige,
          surfaceTint: _warmBrown,
        ),
      BianBianTheme.moonlightDark => const ColorScheme(
          brightness: Brightness.dark,
          primary: _moonPrimary,
          onPrimary: _moonSurface,
          primaryContainer: _moonPurple,
          onPrimaryContainer: Colors.white,
          secondary: _moonPurple,
          onSecondary: Colors.white,
          tertiary: _moonPurple,
          onTertiary: Colors.white,
          error: _moonError,
          onError: Colors.white,
          surface: _moonSurface,
          onSurface: _moonOnSurface,
          surfaceContainerHighest: _moonCard,
          surfaceTint: _moonPrimary,
        ),
      BianBianTheme.mintGreen => const ColorScheme(
          brightness: Brightness.light,
          primary: _mintPrimary,
          onPrimary: Colors.white,
          primaryContainer: _mintPrimaryLight,
          onPrimaryContainer: _mintPrimary,
          secondary: _mintAccent,
          onSecondary: Colors.white,
          tertiary: _mintPrimary,
          onTertiary: Colors.white,
          error: _mintError,
          onError: Colors.white,
          surface: _mintSurface,
          onSurface: _mintPrimary,
          surfaceContainerHighest: _mintCard,
          surfaceTint: _mintPrimary,
        ),
    };

BianBianSemanticColors _semanticColorsFor(BianBianTheme theme) => switch (theme) {
      BianBianTheme.creamBunny => const BianBianSemanticColors(
          success: _matchaGreen,
          warning: _honeyOrange,
          danger: _appleRed,
        ),
      BianBianTheme.thickBrownBear => const BianBianSemanticColors(
          success: Color(0xFF81C784),
          warning: _warmAmber,
          danger: _warmRose,
        ),
      BianBianTheme.moonlightDark => const BianBianSemanticColors(
          success: _moonSuccess,
          warning: _moonWarning,
          danger: _moonError,
        ),
      BianBianTheme.mintGreen => const BianBianSemanticColors(
          success: _mintAccent,
          warning: _mintWarning,
          danger: _mintError,
        ),
    };

Color _shadowColorFor(BianBianTheme theme) =>
    theme.isDark ? _darkCardShadow : _cardShadow;

Color _scaffoldBgFor(BianBianTheme theme, ColorScheme cs) =>
    theme.isDark ? cs.surface : _rice;

// ─── 主题构建 ───────────────────────────────────────────────────────────────

/// 根据主题标识构建完整 [ThemeData]。
ThemeData buildAppTheme(BianBianTheme theme) {
  final cs = _colorSchemeFor(theme);
  final shadow = _shadowColorFor(theme);
  return ThemeData(
    useMaterial3: true,
    brightness: cs.brightness,
    colorScheme: cs,
    scaffoldBackgroundColor: _scaffoldBgFor(theme, cs),
    cardTheme: CardThemeData(
      color: theme.isDark ? cs.surfaceContainerHighest : Colors.white,
      elevation: 4,
      shadowColor: shadow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: cs.surface,
      selectedItemColor: cs.primary,
      unselectedItemColor: cs.onSurface.withAlpha(0x60),
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
      elevation: 0,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: cs.surface,
      foregroundColor: cs.onSurface,
      elevation: 0,
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        shadowColor: shadow,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.primary,
        side: BorderSide(color: cs.primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cs.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
    ),
    extensions: [_semanticColorsFor(theme)],
  );
}

// ─── 语义色 ThemeExtension ─────────────────────────────────────────────────

class BianBianSemanticColors
    extends ThemeExtension<BianBianSemanticColors> {
  const BianBianSemanticColors({
    required this.success,
    required this.warning,
    required this.danger,
  });

  final Color success;
  final Color warning;
  final Color danger;

  @override
  BianBianSemanticColors copyWith({
    Color? success,
    Color? warning,
    Color? danger,
  }) {
    return BianBianSemanticColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
    );
  }

  @override
  BianBianSemanticColors lerp(
    ThemeExtension<BianBianSemanticColors>? other,
    double t,
  ) {
    if (other is! BianBianSemanticColors) return this;
    return BianBianSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

// ─── 向后兼容 ──────────────────────────────────────────────────────────────

/// 默认（奶油兔）主题。保留给 widget_test 等不依赖 provider 的场景。
final ThemeData appTheme = buildAppTheme(BianBianTheme.creamBunny);
