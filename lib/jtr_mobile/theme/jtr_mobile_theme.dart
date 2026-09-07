import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';

/// Semantic tokens for the JTR Mobile manager dashboard.
/// Reads [AppTheme] / [AppTheme.isDark] so light–dark stays in sync with the app.
class JtrMobileTheme {
  JtrMobileTheme._();

  static bool get _dark => AppTheme.isDark;

  static Color get pageBackground => AppTheme.connectBackground;

  static Color get surfaceCard => AppTheme.background;

  static Color get surfaceTile => AppTheme.inactiveSurface;

  static Color get border => AppTheme.cardBorder;

  static Color get borderStrong =>
      _dark ? const Color(0xFF47443D) : const Color(0xFFC9C6BB);

  static Color get textPrimary => AppTheme.darkText;

  static Color get textSecondary => AppTheme.textSecondary;

  static Color get textMuted =>
      _dark ? const Color(0xFF78766C) : const Color(0xFF9A988E);

  static Color get accent =>
      _dark ? const Color(0xFF85B7EB) : const Color(0xFF185FA5);

  static Color get accentBg =>
      _dark ? const Color(0xFF10263C) : const Color(0xFFE6F1FB);

  static Color get danger =>
      _dark ? const Color(0xFFF09595) : const Color(0xFFC1392B);

  static Color get warning =>
      _dark ? const Color(0xFFFAC775) : const Color(0xFFB5790E);

  static Color get success =>
      _dark ? const Color(0xFF97C459) : const Color(0xFF3B6D11);

  static Color get pro =>
      _dark ? const Color(0xFFAFA9EC) : const Color(0xFF534AB7);

  static Color get dangerBg =>
      _dark ? const Color(0xFF3A1414) : const Color(0xFFFCEBEB);

  static Color get warningBg =>
      _dark ? const Color(0xFF3A2A0C) : const Color(0xFFFAEEDA);

  static Color get successBg =>
      _dark ? const Color(0xFF1E2A10) : const Color(0xFFEAF3DE);

  static Color get proBg =>
      _dark ? const Color(0xFF211F3B) : const Color(0xFFEEEDFE);

  static Color get barDefault =>
      _dark ? const Color(0xFF4A4840) : const Color(0xFFD3D1C7);

  static double dashboardMaxWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w > 720) return 480;
    if (w > 520) return 520;
    return w;
  }
}
