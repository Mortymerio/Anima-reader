import 'package:flutter/material.dart';

/// The three display modes available in Anima Reader.
///
/// - [normal]: Black text on white background. Classic E-ink optimized.
/// - [dark]: White text on dark background. Reduces visible E-ink flash.
/// - [warm]: Dark text on warm-tinted background. Reduces blue light for
///   extended desktop reading sessions (solarized/sepia style).
enum AppThemeMode { normal, dark, warm }

/// Builds ThemeData for each of the three display modes.
class AppTheme {
  AppTheme._();

  // ─── Color Palettes ───

  // Normal: Pure B&W for maximum E-ink contrast
  static const _normalBg = Colors.white;
  static const _normalFg = Colors.black;

  // Dark: Soft dark (not pure black to reduce ghosting on E-ink)
  static const _darkBg = Color(0xFF1A1A1A);
  static const _darkFg = Color(0xFFE8E8E8);
  static const _darkSurface = Color(0xFF252525);

  // Warm: Sepia/solarized tones for eye care on LCD/desktop
  static const _warmBg = Color(0xFFF5F0E8);       // Warm paper
  static const _warmFg = Color(0xFF3E3529);        // Dark brown
  static const _warmSurface = Color(0xFFEDE7DB);   // Slightly darker warm
  static const _warmAccent = Color(0xFF8B7355);     // Muted brown accent

  // ─── Shared typography ───

  static const _fontFamily = 'Serif';

  static TextTheme _textTheme(Color fg) => TextTheme(
    bodyLarge: TextStyle(color: fg, fontSize: 18, fontFamily: _fontFamily, height: 1.5),
    bodyMedium: TextStyle(color: fg, fontSize: 14, fontFamily: _fontFamily, height: 1.4),
    bodySmall: TextStyle(color: fg, fontSize: 12),
    titleLarge: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 20),
    titleMedium: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 16),
  );

  // ─── Theme Builders ───

  static ThemeData get normal => _buildTheme(
    brightness: Brightness.light,
    bg: _normalBg,
    fg: _normalFg,
    surface: _normalBg,
  );

  static ThemeData get dark => _buildTheme(
    brightness: Brightness.dark,
    bg: _darkBg,
    fg: _darkFg,
    surface: _darkSurface,
  );

  static ThemeData get warm => _buildTheme(
    brightness: Brightness.light,
    bg: _warmBg,
    fg: _warmFg,
    surface: _warmSurface,
    accent: _warmAccent,
  );

  /// Get ThemeData for a given mode.
  static ThemeData forMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.normal:
        return normal;
      case AppThemeMode.dark:
        return dark;
      case AppThemeMode.warm:
        return warm;
    }
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color bg,
    required Color fg,
    required Color surface,
    Color? accent,
  }) {
    final effectiveAccent = accent ?? fg;

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      primaryColor: fg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: fg,
        onPrimary: bg,
        secondary: effectiveAccent,
        onSecondary: bg,
        surface: surface,
        onSurface: fg,
        error: const Color(0xFFB00020),
        onError: Colors.white,
      ),
      textTheme: _textTheme(fg),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 1,
        iconTheme: IconThemeData(color: fg),
        titleTextStyle: TextStyle(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: 20,
          fontFamily: _fontFamily,
        ),
      ),
      listTileTheme: ListTileThemeData(
        textColor: fg,
        iconColor: fg,
      ),
      dividerTheme: DividerThemeData(
        color: fg.withValues(alpha: 0.2),
        thickness: 1,
      ),
      iconTheme: IconThemeData(color: fg),
      // Disable all animations for E-ink
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }
}
