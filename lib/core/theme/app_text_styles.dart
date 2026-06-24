import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Typography system extracted from the Figma design.
/// Primary font: Hanken Grotesk | Fallback: Inter
abstract final class AppTextStyles {
  static const String _fontFamily = 'HankenGrotesk';

  // ── Display ─────────────────────────────────────────────────────────────────
  static const TextStyle displayLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.0,
  );

  // ── Headline ─────────────────────────────────────────────────────────────────
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: 0.9,
    height: 28 / 18,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
    letterSpacing: -0.18,
    height: 28 / 18,
  );

  // ── Title ────────────────────────────────────────────────────────────────────
  static const TextStyle titleLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 20 / 14,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: 1.2,
    height: 16 / 12,
  );

  // ── Body ─────────────────────────────────────────────────────────────────────
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 24 / 16,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 20 / 14,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 16 / 12,
  );

  // ── Label ─────────────────────────────────────────────────────────────────────
  static const TextStyle labelLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 24 / 16,
  );

  /// Table header label (all caps, muted)
  static const TextStyle labelSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: AppColors.textTertiary,
    letterSpacing: -0.5,
    height: 15 / 10,
  );

  /// User role label (e.g. "MANAGER")
  static const TextStyle roleBadge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 1.0,
    height: 15 / 10,
  );

  /// Footer hint text
  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textHint,
    height: 22.75 / 14,
  );

  /// Action button inner label (all caps, bold)
  static const TextStyle actionButton = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: 0.55,
    height: 13.75 / 11,
  );

  /// Session date label
  static const TextStyle sessionDate = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 20 / 14,
  );
}
