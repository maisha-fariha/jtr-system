import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';

/// JTR Mobile tokens — surfaces from [AppTheme]; chart/accent from
/// `docs/JTR Mobile.html` (soft palette, not POS salmon/toolbar).
class JtrMobileTheme {
  JtrMobileTheme._();

  static bool get _dark => AppTheme.isDark;

  // ─── Surfaces & text (AppTheme + readable dark greys) ─────────────────────

  static Color get pageBackground => AppTheme.connectBackground;

  static Color get surfaceCard => AppTheme.background;

  static Color get surfaceTile => AppTheme.inactiveSurface;

  static Color get border => AppTheme.cardBorder;

  static Color get borderStrong => AppTheme.suggestionsPanelBorder;

  static Color get textPrimary => AppTheme.darkText;

  /// Dark: slightly lighter greys than POS default for readable labels.
  static Color get textSecondary =>
      _dark ? const Color(0xFFBDBDBD) : AppTheme.textSecondary;

  static Color get textMuted =>
      _dark ? const Color(0xFFA3A3A3) : AppTheme.textSecondary.withValues(alpha: 0.72);

  // ─── Brand / semantic (HTML reference) ─────────────────────────────────────

  static Color get accent =>
      _dark ? const Color(0xFF85B7EB) : const Color(0xFF185FA5);

  static Color get accentBg =>
      _dark ? const Color(0xFF10263C) : const Color(0xFFE6F1FB);

  static Color get accentOnAccent => Colors.white;

  /// Annulations
  static Color get danger =>
      _dark ? const Color(0xFFF09595) : const Color(0xFFC1392B);

  /// Remises
  static Color get warning =>
      _dark ? const Color(0xFFFAC775) : const Color(0xFFB5790E);

  static Color get success =>
      _dark ? const Color(0xFF97C459) : const Color(0xFF3B6D11);

  /// Offerts
  static Color get pro =>
      _dark ? const Color(0xFFAFA9EC) : const Color(0xFF534AB7);

  /// Pertes / info accents → same as HTML `--accent`
  static Color get info => accent;

  static Color get chartAlt => warning;

  static Color get chartMuted => textMuted;

  static Color get barDefault =>
      _dark ? const Color(0xFF47443D) : const Color(0xFFD3D1C7);

  static Color get liveDot => success;

  /// Category / zone bars: accent → pro → warning → success (HTML order).
  static List<Color> get categoryPalette => [
        accent,
        pro,
        warning,
        success,
        danger,
        info,
      ];

  static Color paletteAt(int index) {
    final p = categoryPalette;
    return p[index % p.length];
  }

  /// Gap donut colors match HTML legend (danger / warning / pro / accent).
  static Color gapColorForLabel(String label) {
    switch (label.toLowerCase()) {
      case 'annulations':
        return danger;
      case 'remises':
        return warning;
      case 'offerts':
        return pro;
      case 'pertes':
        return accent;
      default:
        return textMuted;
    }
  }

  static double dashboardMaxWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w > 720) return 480;
    if (w > 520) return 520;
    return w;
  }
}
