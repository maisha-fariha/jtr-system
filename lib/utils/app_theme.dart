import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/theme_controller.dart';
import 'app_assets.dart';

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

  /// → Lighter nested divider (e.g. between product rows)
  static Color get subtleDivider =>
      _dark ? const Color(0xFF252525) : const Color(0xFFF0F0F0);

  /// → Inactive button / surface background
  static Color get inactiveSurface =>
      _dark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F3F3);

  /// → Inactive action-button icon (session toolbar)
  static Color get actionIcon =>
      _dark ? const Color(0xFFF1C40F) : primary;

  /// → Modal dialog background
  static Color get dialogBackground => _dark ? const Color(0xFF212031) : Colors.white;

  /// → Dialog list-item / header icon button background
  static Color get dialogItemBackground =>
      _dark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F6F9);

  /// → Dialog barrier overlay
  static Color get dialogBarrier =>
      _dark ? Colors.black.withValues(alpha: 0.55) : Colors.black.withValues(alpha: 0.22);

  /// → Logo image path for the active theme
  static String get logo => _dark ? AppAssets.logoDark : AppAssets.logoLight;

  // ─── Helper ───────────────────────────────────────────────────────────────

  static bool get _dark {
    try {
      if (Get.isRegistered<ThemeController>()) {
        return ThemeController.to.isDark.value;
      }
      return Get.isDarkMode;
    } catch (_) {
      return false;
    }
  }

  static bool get isDark => _dark;

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
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
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
          backgroundColor: Color(0xFF121212),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
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
