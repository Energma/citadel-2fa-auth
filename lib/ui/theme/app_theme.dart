import 'package:flutter/material.dart';
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

  /// A muted tint of [accent] for tonal surfaces. Overriding [ColorScheme
  /// .primary] alone leaves the *container* roles at Material's stock defaults,
  /// so tonal buttons and chips would ignore the accent entirely.
  static Color _container(Color accent, Brightness brightness) {
    final hsl = HSLColor.fromColor(accent);
    return brightness == Brightness.dark
        ? hsl
            .withSaturation((hsl.saturation * 0.65).clamp(0.0, 1.0))
            .withLightness((hsl.lightness * 0.38).clamp(0.0, 1.0))
            .toColor()
        : hsl
            .withSaturation((hsl.saturation * 0.55).clamp(0.0, 1.0))
            .withLightness((hsl.lightness + 0.34).clamp(0.0, 0.92))
            .toColor();
  }

  static ThemeData darkTheme(Color accent) {
    final onAccentColor = onAccent(accent);
    final container = _container(accent, Brightness.dark);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: accent,
        secondary: _deepen(accent),
        tertiary: Palette.accent,
        error: Palette.error,
        surface: Palette.darkSurface,
        onPrimary: onAccentColor,
        primaryContainer: container,
        onPrimaryContainer: onAccent(container),
        secondaryContainer: container,
        onSecondaryContainer: onAccent(container),
      ),
      scaffoldBackgroundColor: Palette.darkBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: Palette.darkBg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: Palette.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onAccentColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Palette.darkCard,
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
        backgroundColor: Palette.darkCard,
        selectedColor: accent.withAlpha(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Palette.darkSurface,
        selectedItemColor: accent,
        unselectedItemColor: Colors.white54,
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF2A3F5F)),
    );
  }

  static ThemeData lightTheme(Color accent) {
    final onAccentColor = onAccent(accent);
    final container = _container(accent, Brightness.light);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: accent,
        secondary: _deepen(accent),
        tertiary: Palette.accent,
        error: Palette.error,
        surface: Palette.lightSurface,
        onSurface: const Color(0xFF1E293B),
        onPrimary: onAccentColor,
        primaryContainer: container,
        onPrimaryContainer: onAccent(container),
        secondaryContainer: container,
        onSecondaryContainer: onAccent(container),
      ),
      scaffoldBackgroundColor: Palette.lightBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: Palette.lightBg,
        elevation: 0,
        centerTitle: false,
        foregroundColor: Color(0xFF1E293B),
        titleTextStyle: TextStyle(
          color: Color(0xFF1E293B),
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: Palette.lightSurface,
        elevation: 1,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onAccentColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Palette.lightCard,
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
        backgroundColor: Palette.lightCard,
        selectedColor: accent.withAlpha(30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Palette.lightSurface,
        selectedItemColor: accent,
        unselectedItemColor: const Color(0xFF94A3B8),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFE2E8F0)),
    );
  }
}
