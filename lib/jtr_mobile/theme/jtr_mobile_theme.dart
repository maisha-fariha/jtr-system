import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';

/// JTR Mobile tokens — thin layer over [AppTheme] (salmon brand, POS light/dark).
/// Chart/segment colors reuse the existing toolbar semantic palette.
class JtrMobileTheme {
  JtrMobileTheme._();

  // ─── Surfaces & text (AppTheme) ───────────────────────────────────────────

  static Color get pageBackground => AppTheme.connectBackground;

  static Color get surfaceCard => AppTheme.background;

  static Color get surfaceTile => AppTheme.inactiveSurface;

  static Color get border => AppTheme.cardBorder;

  static Color get borderStrong => AppTheme.suggestionsPanelBorder;

  static Color get textPrimary => AppTheme.darkText;

  /// Dark: slightly lighter greys than POS default for readable labels.
  static Color get textSecondary =>
      AppTheme.isDark ? const Color(0xFFBDBDBD) : AppTheme.textSecondary;

  static Color get textMuted =>
      AppTheme.isDark ? const Color(0xFFA3A3A3) : AppTheme.textSecondary.withValues(alpha: 0.72);

  // ─── Brand ─────────────────────────────────────────────────────────────────

  static Color get accent => AppTheme.primary;

  static Color get accentBg => AppTheme.lightButton;

  static Color get accentOnAccent => Colors.white;

  // ─── Chart / status (POS toolbar palette) ───────────────────────────────────

  static Color get danger => AppTheme.toolbarKitchen;

  static Color get warning => AppTheme.toolbarQuantity;

  static Color get success => AppTheme.toolbarSuivre;

  static Color get info => AppTheme.toolbarTicket;

  static Color get pro => AppTheme.toolbarMenu;

  static Color get chartAlt => AppTheme.toolbarPayment;

  static Color get chartMuted => AppTheme.toolbarStatistics;

  static Color get barDefault => AppTheme.subtleDivider;

  static Color get liveDot => AppTheme.toolbarSuivre;

  static List<Color> get categoryPalette => const [
        AppTheme.primary,
        AppTheme.toolbarMenu,
        AppTheme.toolbarQuantity,
        AppTheme.toolbarTicket,
        AppTheme.toolbarSuivre,
        AppTheme.toolbarPayment,
      ];

  static double dashboardMaxWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w > 720) return 480;
    if (w > 520) return 520;
    return w;
  }
}
