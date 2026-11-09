import 'package:flutter/material.dart';
import '../../ui/theme/palette.dart';

/// The four theme options exposed in Settings. Distinct from Flutter's own
/// [ThemeMode] because that enum has no slot for [custom] — the UI layer
/// maps this onto [ThemeMode] when building the [MaterialApp].
enum CitadelThemeMode { system, light, dark, custom }

/// User-picked colors backing [CitadelThemeMode.custom]: a background, a
/// text color, and an "element" color (buttons, icons, highlights) — the
/// same three roles [AppTheme]'s dark/light presets fix to black/white.
class CustomThemeColors {
  final Color background;
  final Color text;
  final Color element;

  const CustomThemeColors({
    required this.background,
    required this.text,
    required this.element,
  });

  static const defaults = CustomThemeColors(
    background: Colors.black,
    text: Colors.white,
    element: Palette.primary,
  );

  /// The three roles as [scheme] renders them right now, so the Personal Theme
  /// editor can start from what's on screen when Light/Dark is active — editing
  /// one color then keeps the other two instead of jumping to [defaults].
  factory CustomThemeColors.fromScheme(ColorScheme scheme) => CustomThemeColors(
        background: scheme.surface,
        text: scheme.onSurface,
        element: scheme.primary,
      );

  CustomThemeColors copyWith({Color? background, Color? text, Color? element}) {
    return CustomThemeColors(
      background: background ?? this.background,
      text: text ?? this.text,
      element: element ?? this.element,
    );
  }
}
