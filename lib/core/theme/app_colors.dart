import 'package:flutter/material.dart';

/// All color tokens extracted from the JTR System Figma design.
/// Source: figma.com/design/HDP804C1VPIh8Kw97kvftC
abstract final class AppColors {
  // ── Background ──────────────────────────────────────────────────────────────
  /// Main scaffold background: deep navy/dark purple
  static const Color background = Color(0xFF212031);

  /// Slightly darker surface used for cards, bottom sheets
  static const Color surface = Color(0xFF1A1926);

  /// Semi-transparent card overlay used in table rows
  static const Color cardOverlay = Color(0x66181726); // rgba(24,23,38,0.4)

  // ── Brand / Primary ─────────────────────────────────────────────────────────
  /// Salmon/coral — brand primary accent
  static const Color primary = Color(0xFFEE8677);

  /// Primary with low opacity shadow (20%)
  static const Color primaryShadow = Color(0x33EE8677); // rgba(238,134,119,0.2)

  // ── Semantic ────────────────────────────────────────────────────────────────
  /// Bright blue — used for active/live table indicators
  static const Color info = Color(0xFF38BDF8);

  /// Red — used for zero/inactive state badge
  static const Color error = Color(0xEFEF4444); // rgba(239,68,68,0.9)
  static const Color errorBorder = Color(0xFFF87171);

  /// Yellow — used for pending/partial state badge
  static const Color warning = Color(0xFFFACC15);
  static const Color warningBorder = Color(0xFFFEF08A);

  // ── Text ────────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textTertiary = Color(0xFF6B7280);
  static const Color textHint = Color(0x99FFFFFF); // rgba(255,255,255,0.6)

  // ── Border ──────────────────────────────────────────────────────────────────
  static const Color borderDefault = Color(0xFF4B5563);
  static const Color borderSubtle = Color(0x0DFFFFFF); // rgba(255,255,255,0.05)
  static const Color borderLight = Color(0x1AFFFFFF);  // rgba(255,255,255,0.1)

  // ── Button overlay ──────────────────────────────────────────────────────────
  static const Color buttonOverlay = Color(0x1AFFFFFF); // rgba(255,255,255,0.1)
  static const Color iconOverlay = Color(0x33FFFFFF);   // rgba(255,255,255,0.2)
}
