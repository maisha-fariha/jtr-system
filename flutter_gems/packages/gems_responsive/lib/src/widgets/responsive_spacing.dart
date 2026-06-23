import 'package:flutter/material.dart';
import '../responsive_helper.dart';

/// Responsive Spacing System - Consistent spacing that scales appropriately
class ResponsiveSpacing {
  /// Extra small spacing (4px on phone, 8px on tablet)
  static Widget xs(BuildContext context) {
    return SizedBox(
      height: ResponsiveHelper.getResponsiveHeight(
        context,
        ResponsiveHelper.isSmallDevice(context) ? 4 : 8,
      ),
    );
  }

  /// Small spacing (8px on phone, 12px on tablet)
  static Widget sm(BuildContext context) {
    return SizedBox(
      height: ResponsiveHelper.getResponsiveHeight(
        context,
        ResponsiveHelper.isSmallDevice(context) ? 8 : 12,
      ),
    );
  }

  /// Medium spacing (16px on phone, 24px on tablet)
  static Widget md(BuildContext context) {
    return SizedBox(
      height: ResponsiveHelper.getResponsiveHeight(
        context,
        ResponsiveHelper.isSmallDevice(context) ? 16 : 24,
      ),
    );
  }

  /// Large spacing (24px on phone, 32px on tablet)
  static Widget lg(BuildContext context) {
    return SizedBox(
      height: ResponsiveHelper.getResponsiveHeight(
        context,
        ResponsiveHelper.isSmallDevice(context) ? 24 : 32,
      ),
    );
  }

  /// Extra large spacing (32px on phone, 48px on tablet)
  static Widget xl(BuildContext context) {
    return SizedBox(
      height: ResponsiveHelper.getResponsiveHeight(
        context,
        ResponsiveHelper.isSmallDevice(context) ? 32 : 48,
      ),
    );
  }

  /// 2XL spacing (48px on phone, 64px on tablet)
  static Widget xxl(BuildContext context) {
    return SizedBox(
      height: ResponsiveHelper.getResponsiveHeight(
        context,
        ResponsiveHelper.isSmallDevice(context) ? 48 : 64,
      ),
    );
  }

  /// Get spacing value as double
  static double xsValue(BuildContext context) {
    return ResponsiveHelper.getResponsiveHeight(
      context,
      ResponsiveHelper.isSmallDevice(context) ? 4 : 8,
    );
  }

  static double smValue(BuildContext context) {
    return ResponsiveHelper.getResponsiveHeight(
      context,
      ResponsiveHelper.isSmallDevice(context) ? 8 : 12,
    );
  }

  static double mdValue(BuildContext context) {
    return ResponsiveHelper.getResponsiveHeight(
      context,
      ResponsiveHelper.isSmallDevice(context) ? 16 : 24,
    );
  }

  static double lgValue(BuildContext context) {
    return ResponsiveHelper.getResponsiveHeight(
      context,
      ResponsiveHelper.isSmallDevice(context) ? 24 : 32,
    );
  }

  static double xlValue(BuildContext context) {
    return ResponsiveHelper.getResponsiveHeight(
      context,
      ResponsiveHelper.isSmallDevice(context) ? 32 : 48,
    );
  }

  static double xxlValue(BuildContext context) {
    return ResponsiveHelper.getResponsiveHeight(
      context,
      ResponsiveHelper.isSmallDevice(context) ? 48 : 64,
    );
  }

  /// Horizontal spacing
  static Widget horizontalXs(BuildContext context) {
    return SizedBox(
      width: ResponsiveHelper.getResponsiveWidth(
        context,
        ResponsiveHelper.isSmallDevice(context) ? 4 : 8,
      ),
    );
  }

  static Widget horizontalSm(BuildContext context) {
    return SizedBox(
      width: ResponsiveHelper.getResponsiveWidth(
        context,
        ResponsiveHelper.isSmallDevice(context) ? 8 : 12,
      ),
    );
  }

  static Widget horizontalMd(BuildContext context) {
    return SizedBox(
      width: ResponsiveHelper.getResponsiveWidth(
        context,
        ResponsiveHelper.isSmallDevice(context) ? 16 : 24,
      ),
    );
  }

  static Widget horizontalLg(BuildContext context) {
    return SizedBox(
      width: ResponsiveHelper.getResponsiveWidth(
        context,
        ResponsiveHelper.isSmallDevice(context) ? 24 : 32,
      ),
    );
  }

  static Widget horizontalXl(BuildContext context) {
    return SizedBox(
      width: ResponsiveHelper.getResponsiveWidth(
        context,
        ResponsiveHelper.isSmallDevice(context) ? 32 : 48,
      ),
    );
  }
}
