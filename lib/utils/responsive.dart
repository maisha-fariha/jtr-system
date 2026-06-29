// JTR responsive layer — wraps Flutter Gems [ResponsiveHelper].
//
// Phone/tablet scaling uses the original 375×812 design reference.
// 480×480 POS tweaks apply only to compact square screens and product grids.
library;

export 'package:gems_responsive/gems_responsive.dart';

import 'package:flutter/material.dart';
import 'package:gems_responsive/gems_responsive.dart';

class JtrResponsive {
  JtrResponsive._();

  /// Original phone design reference (unchanged scaling for buttons, text, etc.).
  static const double baseWidth = ResponsiveHelper.baseWidth;
  static const double baseHeight = ResponsiveHelper.baseHeight;

  /// Square or near-square compact display (e.g. 480×480).
  static bool isCompactSquare(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.shortestSide <= 520 && size.longestSide <= 560;
  }

  /// Narrow POS width — used for product grid columns only.
  static bool isPosWidth(BuildContext context) =>
      getScreenWidth(context) <= 520;

  static bool isSmallDevice(BuildContext context) {
    if (isCompactSquare(context)) return true;
    return ResponsiveHelper.isSmallDevice(context);
  }

  static bool isMediumDevice(BuildContext context) {
    if (isCompactSquare(context)) return false;
    return ResponsiveHelper.isMediumDevice(context);
  }

  static bool isLargeDevice(BuildContext context) {
    if (isCompactSquare(context)) return false;
    return ResponsiveHelper.isLargeDevice(context);
  }

  static double _compactVerticalScale(BuildContext context) =>
      isCompactSquare(context) ? 0.84 : 1;

  static double _compactFontScale(BuildContext context) =>
      isCompactSquare(context) ? 0.94 : 1;

  static double getScreenWidth(BuildContext context) =>
      ResponsiveHelper.getScreenWidth(context);

  static double getScreenHeight(BuildContext context) =>
      ResponsiveHelper.getScreenHeight(context);

  static double getResponsiveWidth(BuildContext context, double base) =>
      ResponsiveHelper.getResponsiveWidth(context, base);

  static double getResponsiveHeight(BuildContext context, double base) =>
      ResponsiveHelper.getResponsiveHeight(context, base) *
      _compactVerticalScale(context);

  static double getResponsiveFontSize(BuildContext context, double base) =>
      ResponsiveHelper.getResponsiveFontSize(context, base) *
      _compactFontScale(context);

  static double getResponsiveSize(BuildContext context, double base) {
    final scale = isCompactSquare(context) ? 0.92 : 1.0;
    return ResponsiveHelper.getResponsiveSize(context, base) * scale;
  }

  static double getResponsiveRadius(BuildContext context, double base) =>
      ResponsiveHelper.getResponsiveRadius(context, base);

  static EdgeInsets getResponsivePadding(
    BuildContext context, {
    double? all,
    double? horizontal,
    double? vertical,
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    final padding = ResponsiveHelper.getResponsivePadding(
      context,
      all: all,
      horizontal: horizontal,
      vertical: vertical,
      top: top,
      bottom: bottom,
      left: left,
      right: right,
    );
    if (!isCompactSquare(context)) return padding;

    final vScale = _compactVerticalScale(context);
    const hScale = 0.9;
    return EdgeInsets.fromLTRB(
      padding.left * hScale,
      padding.top * vScale,
      padding.right * hScale,
      padding.bottom * vScale,
    );
  }

  static EdgeInsets getResponsiveMargin(
    BuildContext context, {
    double? all,
    double? horizontal,
    double? vertical,
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) =>
      getResponsivePadding(
        context,
        all: all,
        horizontal: horizontal,
        vertical: vertical,
        top: top,
        bottom: bottom,
        left: left,
        right: right,
      );

  static SizedBox getResponsiveSpacing(BuildContext context, double base) =>
      SizedBox(height: getResponsiveHeight(context, base));

  static SizedBox getResponsiveHorizontalSpacing(
    BuildContext context,
    double base,
  ) =>
      SizedBox(width: getResponsiveWidth(context, base));

  static T getResponsiveValue<T>(
    BuildContext context, {
    required T small,
    T? medium,
    T? large,
  }) {
    if (isLargeDevice(context)) return large ?? medium ?? small;
    if (isMediumDevice(context)) return medium ?? small;
    return small;
  }

  /// Product grid columns — 3 per row on 480px POS / compact square screens.
  static T gridColumns<T>(
    BuildContext context, {
    required T small,
    T? medium,
    T? large,
  }) {
    if (isCompactSquare(context) || isPosWidth(context)) return small;
    if (ResponsiveHelper.isLargeDevice(context)) return large ?? medium ?? small;
    if (ResponsiveHelper.isMediumDevice(context)) {
      return medium ?? small;
    }
    return small;
  }

  /// Use a smaller base height on compact square screens when provided.
  static double adaptiveHeight(
    BuildContext context,
    double base, {
    double? compact,
  }) {
    final value = isCompactSquare(context) && compact != null ? compact : base;
    return getResponsiveHeight(context, value);
  }
}
