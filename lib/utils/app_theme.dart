import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Central design-system tokens.
///
/// Colors marked with [→] change in dark mode.
/// `primary` is invariant (same salmon in both modes).
class AppTheme {
  AppTheme._();

  // ─── Invariant brand colour ───────────────────────────────────────────────
  static const Color primary = Color(0xFFEE8B78);

  // ─── Theme-aware colour getters ───────────────────────────────────────────
  // These are computed on every access, so they always return the right value
  // after Get.changeThemeMode() triggers a full widget rebuild.

  /// → Scaffold / dialog / card background
  static Color get background =>
      _dark ? const Color(0xFF121212) : Colors.white;

  /// → Lighter background for pages like Connect / Loading
  static Color get connectBackground =>
      _dark ? const Color(0xFF1A1A1A) : const Color(0xFFF9F9F9);

  /// → Primary text colour
  static Color get darkText =>
      _dark ? const Color(0xFFF2F2F2) : const Color(0xFF2D2D2D);

  /// → Secondary / muted text colour
  static Color get textSecondary =>
      _dark ? const Color(0xFF9E9E9E) : const Color(0xFF5A5A5A);

  /// → Light tinted button / chip background
  static Color get lightButton =>
      _dark ? const Color(0xFF3D2820) : const Color(0xFFFDE9E6);

  /// → Card border / divider
  static Color get cardBorder =>
      _dark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8);

  // ─── Helper ───────────────────────────────────────────────────────────────

  static bool get _dark {
    try {
      return Get.isDarkMode;
    } catch (_) {
      return false;
    }
  }

  // ─── ThemeData ─────────────────────────────────────────────────────────────

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: primary,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: Color(0xFF2D2D2D),
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: primary),
          titleTextStyle: TextStyle(
            color: primary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        dividerColor: const Color(0xFFE8E8E8),
        cardColor: Colors.white,
        fontFamily: 'Roboto',
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          onPrimary: Colors.white,
          surface: Color(0xFF1E1E1E),
          onSurface: Color(0xFFF2F2F2),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: primary),
          titleTextStyle: TextStyle(
            color: primary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        dividerColor: const Color(0xFF2A2A2A),
        cardColor: const Color(0xFF1E1E1E),
        fontFamily: 'Roboto',
      );
}
