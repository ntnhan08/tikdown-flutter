import 'package:flutter/material.dart';

class AppTheme {
  // ── Neon palette ──────────────────────────────────
  static const Color primary      = Color(0xFFFF6B35);
  static const Color primaryDark  = Color(0xFFE8551F);
  static const Color primaryLight = Color(0xFFFF8A60);
  static const Color accentYellow = Color(0xFFFFAA00);
  static const Color accentPink   = Color(0xFFFF4757);
  static const Color accentPurple = Color(0xFFA29BFE);
  static const Color accentCyan   = Color(0xFF00D2D3);
  static const Color accentGreen  = Color(0xFF7BED9F);
  static const Color accentBlue   = Color(0xFF70A1FF);

  // ── Backgrounds ───────────────────────────────────
  static const Color bgDark   = Color(0xFF0D0D1A);
  static const Color bgSurface = Color(0xFF1A1A2E);

  // ── Gradients ─────────────────────────────────────
  static const LinearGradient rainbowGradient = LinearGradient(
    colors: [primary, accentYellow, accentPink],
  );

  static const LinearGradient splashBg = RadialGradient(
    center: Alignment.center,
    radius: 1.2,
    colors: [Color(0xFF1A0A2E), Color(0xFF0D0D1A)],
  ) as LinearGradient;

  static const List<Color> particleColors = [
    Color(0xCCFF6B35), Color(0xCCFF4757), Color(0xCCFFAA00),
    Color(0xCC7BED9F), Color(0xCC70A1FF), Color(0xCCA29BFE),
    Color(0xCCFF6B9D), Color(0xCC00D2D3),
  ];

  // ── Light theme ───────────────────────────────────
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: bgDark,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
        elevation: 6,
        shadowColor: primary.withOpacity(0.4),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF1A1A2E),
      contentTextStyle: TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );

  // ── Dark theme ────────────────────────────────────
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: bgDark,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
        elevation: 6,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF1A1A2E),
      contentTextStyle: TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
