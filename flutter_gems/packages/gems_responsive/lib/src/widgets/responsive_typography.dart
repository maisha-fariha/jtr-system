import 'package:flutter/material.dart';
import '../responsive_helper.dart';

/// Responsive Typography System
/// Provides pre-defined text styles that adapt to screen size and accessibility
class ResponsiveText extends StatelessWidget {
  final String text;
  final ResponsiveTextStyle style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final Color? color;
  final FontWeight? fontWeight;
  final double? letterSpacing;
  final double? lineHeight;

  const ResponsiveText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.color,
    this.fontWeight,
    this.letterSpacing,
    this.lineHeight,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = ResponsiveTypography.getStyle(
      context,
      style: style,
      color: color,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      lineHeight: lineHeight,
    );

    return Text(
      text,
      style: textStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Responsive Typography Helper
class ResponsiveTypography {
  /// Get responsive text style
  static TextStyle getStyle(
    BuildContext context, {
    required ResponsiveTextStyle style,
    Color? color,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? lineHeight,
  }) {
    final baseStyle = _getBaseStyle(context, style);
    
    return baseStyle.copyWith(
      color: color ?? baseStyle.color,
      fontWeight: fontWeight ?? baseStyle.fontWeight,
      letterSpacing: letterSpacing ?? baseStyle.letterSpacing,
      height: lineHeight ?? baseStyle.height,
    );
  }

  static TextStyle _getBaseStyle(BuildContext context, ResponsiveTextStyle style) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    
    // Base font sizes (will be made responsive)
    double fontSize;
    FontWeight? fontWeight;
    double? letterSpacing;
    double? height;

    switch (style) {
      case ResponsiveTextStyle.displayLarge:
        fontSize = ResponsiveHelper.getResponsiveFontSize(context, 57);
        fontWeight = FontWeight.w400;
        letterSpacing = -0.25;
        height = 1.12;
        break;
      case ResponsiveTextStyle.displayMedium:
        fontSize = ResponsiveHelper.getResponsiveFontSize(context, 45);
        fontWeight = FontWeight.w400;
        letterSpacing = 0;
        height = 1.16;
        break;
      case ResponsiveTextStyle.displaySmall:
        fontSize = ResponsiveHelper.getResponsiveFontSize(context, 36);
        fontWeight = FontWeight.w400;
        letterSpacing = 0;
        height = 1.22;
        break;
      case ResponsiveTextStyle.headlineLarge:
        fontSize = ResponsiveHelper.getResponsiveFontSize(context, 32);
        fontWeight = FontWeight.w400;
        letterSpacing = 0;
        height = 1.25;
        break;
      case ResponsiveTextStyle.headlineMedium:
        fontSize = ResponsiveHelper.getResponsiveFontSize(context, 28);
        fontWeight = FontWeight.w400;
        letterSpacing = 0;
        height = 1.29;
        break;
      case ResponsiveTextStyle.headlineSmall:
        fontSize = ResponsiveHelper.getResponsiveFontSize(context, 24);
        fontWeight = FontWeight.w400;
        letterSpacing = 0;
        height = 1.33;
        break;
      case ResponsiveTextStyle.titleLarge:
        fontSize = ResponsiveHelper.getResponsiveFontSize(context, 22);
        fontWeight = FontWeight.w500;
        letterSpacing = 0;
        height = 1.27;
        break;
      case ResponsiveTextStyle.titleMedium:
        fontSize = ResponsiveHelper.getResponsiveFontSize(context, 16);
        fontWeight = FontWeight.w500;
        letterSpacing = 0.15;
        height = 1.5;
        break;
      case ResponsiveTextStyle.titleSmall:
        fontSize = ResponsiveHelper.getResponsiveFontSize(context, 14);
        fontWeight = FontWeight.w500;
        letterSpacing = 0.1;
        height = 1.43;
        break;
      case ResponsiveTextStyle.bodyLarge:
        fontSize = ResponsiveHelper.getResponsiveFontSize(context, 16);
        fontWeight = FontWeight.w400;
        letterSpacing = 0.5;
        height = 1.5;
        break;
      case ResponsiveTextStyle.bodyMedium:
        fontSize = ResponsiveHelper.getResponsiveFontSize(context, 14);
        fontWeight = FontWeight.w400;
        letterSpacing = 0.25;
        height = 1.43;
        break;
      case ResponsiveTextStyle.bodySmall:
        fontSize = ResponsiveHelper.getResponsiveFontSize(context, 12);
        fontWeight = FontWeight.w400;
        letterSpacing = 0.4;
        height = 1.33;
        break;
      case ResponsiveTextStyle.labelLarge:
        fontSize = ResponsiveHelper.getResponsiveFontSize(context, 14);
        fontWeight = FontWeight.w500;
        letterSpacing = 0.1;
        height = 1.43;
        break;
      case ResponsiveTextStyle.labelMedium:
        fontSize = ResponsiveHelper.getResponsiveFontSize(context, 12);
        fontWeight = FontWeight.w500;
        letterSpacing = 0.5;
        height = 1.33;
        break;
      case ResponsiveTextStyle.labelSmall:
        fontSize = ResponsiveHelper.getResponsiveFontSize(context, 11);
        fontWeight = FontWeight.w500;
        letterSpacing = 0.5;
        height = 1.45;
        break;
    }

    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      color: textTheme.bodyLarge?.color,
    );
  }
}

/// Responsive Text Styles
enum ResponsiveTextStyle {
  displayLarge,
  displayMedium,
  displaySmall,
  headlineLarge,
  headlineMedium,
  headlineSmall,
  titleLarge,
  titleMedium,
  titleSmall,
  bodyLarge,
  bodyMedium,
  bodySmall,
  labelLarge,
  labelMedium,
  labelSmall,
}
