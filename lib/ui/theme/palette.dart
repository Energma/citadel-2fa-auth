import 'package:flutter/material.dart';

/// Central color palette for the app.
/// Change colors here to re-skin the entire app.
class Palette {
  // ─── Brand ───
  static const Color primary = Color(0xFF06B6D4);     // Cyan
  static const Color secondary = Color(0xFF0891B2);    // Darker Cyan
  static const Color accent = Color(0xFF84FFDA);       // Mint / Energma green

  // ─── Semantic ───
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);

  // ─── Dark surfaces ───
  static const Color darkBg = Color(0xFF0B1120);       // Deep navy
  static const Color darkSurface = Color(0xFF152238);   // Navy
  static const Color darkCard = Color(0xFF1E3050);      // Slate navy

  // ─── Light surfaces ───
  static const Color lightBg = Color(0xFFF8FAFC);      // Slate 50
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF1F5F9);    // Slate 100

  // ─── Splash / Branding ───
  static const Color splashBg = Color(0xFF0B1120);
  static const Color splashText = Color(0xFF84FFDA);

  // ─── Profile color presets ───
  static const List<Color> profileColors = [
    Color(0xFF06B6D4), // Cyan
    Color(0xFF0EA5E9), // Sky
    Color(0xFF3B82F6), // Blue
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Pink
    Color(0xFFEF4444), // Red
    Color(0xFFF97316), // Orange
    Color(0xFFEAB308), // Yellow
    Color(0xFF22C55E), // Green
    Color(0xFF64748B), // Slate
  ];

  // ─── Personal theme accent presets ───
  /// Selectable accents for the Personal Theme setting. These override
  /// [primary]/[secondary] only — surfaces and cards keep the house palette.
  static const List<(String, Color)> accentPresets = [
    ('Cyan', primary),
    ('Mint', accent),
    ('Sky', Color(0xFF0EA5E9)),
    ('Violet', Color(0xFF8B5CF6)),
    ('Green', Color(0xFF22C55E)),
    ('Amber', Color(0xFFF59E0B)),
    ('Rose', Color(0xFFEC4899)),
    ('Red', Color(0xFFEF4444)),
  ];
}
