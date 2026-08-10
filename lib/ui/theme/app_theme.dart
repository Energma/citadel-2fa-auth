import 'package:flutter/material.dart';
import '../../core/models/theme_settings.dart';
import 'palette.dart';

class AppTheme {
  /// Black or white — whichever stays readable on top of [accent]. A light
  /// accent (Mint, Amber) would otherwise get unreadable white-on-white labels.
  static Color onAccent(Color accent) =>
      ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
          ? Colors.white
          : Colors.black;

  /// A deeper companion to [accent], used for [ColorScheme.secondary] the way
  /// [Palette.secondary] relates to [Palette.primary].
  static Color _deepen(Color accent) {
    final hsl = HSLColor.fromColor(accent);
    return hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
  }

  /// A subtle step from [base] toward [contrast], used for card/input
  /// surfaces so they stay visibly distinct from the scaffold background
  /// without giving up the "pure black" / "pure white" / user-chosen look.
  static Color _tonal(Color base, Color contrast, [double amount = 0.06]) {
    return Color.alphaBlend(contrast.withValues(alpha: amount), base);
  }

  static ThemeData darkTheme() => _monoTheme(
        brightness: Brightness.dark,
        background: Colors.black,
        onBackground: Colors.white,
      );

  static ThemeData lightTheme() => _monoTheme(
        brightness: Brightness.light,
        background: Colors.white,
        onBackground: Colors.black,
      );

  /// Fully user-driven theme: [colors.background] behind everything,
  /// [colors.text] for text/onSurface roles, [colors.element] for buttons,
  /// icons and highlights — the same three roles [_monoTheme] fixes to
  /// black/white for the Dark/Light presets.
  static ThemeData customTheme(CustomThemeColors colors) => _monoTheme(
        brightness: ThemeData.estimateBrightnessForColor(colors.background),
        background: colors.background,
        onBackground: colors.text,
        element: colors.element,
      );

  /// Shared builder behind [darkTheme], [lightTheme] and [customTheme]: a
  /// [background] surface, [onBackground] for text/icons, and an optional
  /// [element] accent (defaults to [onBackground] itself, so Dark/Light stay
  /// strictly monochrome — white-on-black / black-on-white).
  static ThemeData _monoTheme({
    required Brightness brightness,
    required Color background,
    required Color onBackground,
    Color? element,
  }) {
    final accent = element ?? onBackground;
    final onAccentColor = onAccent(accent);
    final card = _tonal(background, onBackground);
    final divider = onBackground.withValues(alpha: 0.16);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accent,
        onPrimary: onAccentColor,
        secondary: _deepen(accent),
        onSecondary: onAccentColor,
        tertiary: Palette.accent,
        error: Palette.error,
        onError: Colors.white,
        surface: background,
        onSurface: onBackground,
        primaryContainer: card,
        onPrimaryContainer: onBackground,
        secondaryContainer: card,
        onSecondaryContainer: onBackground,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        foregroundColor: onBackground,
        titleTextStyle: TextStyle(
          color: onBackground,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onAccentColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccentColor,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: accent.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: card,
        selectedItemColor: accent,
        unselectedItemColor: onBackground.withValues(alpha: 0.54),
      ),
      dividerTheme: DividerThemeData(color: divider),
    );
  }
}
