import 'package:flutter/material.dart';

// 奶油兔主题色板（design-document.md §10.2）
const _creamYellow = Color(0xFFFFE9B0);
const _sakuraPink = Color(0xFFFFB7C5);
const _cocoaBrown = Color(0xFF8A5A3B);
const _matchaGreen = Color(0xFFA8D8B9);
const _honeyOrange = Color(0xFFF4A261);
const _appleRed = Color(0xFFE76F51);
const _rice = Color(0xFFFFF9EF);
const _mist = Color(0xFFFDF3E7);

// 阴影色：可可棕 8% alpha（设计文档 §10.5 "0 4 12 rgba(138,90,59,.08)"）
const _cardShadow = Color(0x148A5A3B);

const _colorScheme = ColorScheme(
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
);

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: _colorScheme,
  scaffoldBackgroundColor: _rice,
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 4,
    shadowColor: _cardShadow,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: _rice,
    selectedItemColor: _cocoaBrown,
    unselectedItemColor: Color(0x998A5A3B),
    type: BottomNavigationBarType.fixed,
    showUnselectedLabels: true,
    elevation: 0,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: _rice,
    foregroundColor: _cocoaBrown,
    elevation: 0,
    centerTitle: true,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _cocoaBrown,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: _cardShadow,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: _cocoaBrown,
      side: const BorderSide(color: _cocoaBrown, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: _mist,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _cocoaBrown, width: 2),
    ),
  ),
  extensions: const [
    BianBianSemanticColors(
      success: _matchaGreen,
      warning: _honeyOrange,
      danger: _appleRed,
    ),
  ],
);

// 语义色放在 ThemeExtension 以免 ColorScheme 被污染；后续 stats/budget 等
// 页面读取 Theme.of(context).extension<BianBianSemanticColors>()! 获取。
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
