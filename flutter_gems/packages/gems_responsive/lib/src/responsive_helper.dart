import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Professional responsive helper class for consistent sizing across devices
/// Uses flutter_screenutil for better tablet and multi-device support
/// Ensures widgets look exactly the same on different screen sizes
class ResponsiveHelper {
  // Base design dimensions (reference device - typically a standard phone)
  // These are used as fallback when ScreenUtil is not initialized
  static const double baseWidth = 375.0; // iPhone X/11/12 standard width
  static const double baseHeight = 812.0; // iPhone X/11/12 standard height
  
  // Check if ScreenUtil is initialized
  static bool get _isScreenUtilInitialized {
    try {
      return ScreenUtil().screenWidth > 0;
    } catch (_) {
      return false;
    }
  }
  
  // Get screen dimensions
  static Size getScreenSize(BuildContext context) {
    if (_isScreenUtilInitialized) {
      return Size(ScreenUtil().screenWidth, ScreenUtil().screenHeight);
    }
    return MediaQuery.sizeOf(context);
  }
  
  // Get screen width
  static double getScreenWidth(BuildContext context) {
    if (_isScreenUtilInitialized) {
      return ScreenUtil().screenWidth;
    }
    return MediaQuery.sizeOf(context).width;
  }
  
  // Get screen height
  static double getScreenHeight(BuildContext context) {
    if (_isScreenUtilInitialized) {
      return ScreenUtil().screenHeight;
    }
    return MediaQuery.sizeOf(context).height;
  }
  
  // Get responsive width based on base design
  // This ensures widgets maintain the same proportional size across devices
  // Uses ScreenUtil for better tablet support with smart scaling
  static double getResponsiveWidth(BuildContext context, double baseValue) {
    if (_isScreenUtilInitialized) {
      final scaledValue = baseValue.w;
      // For tablets, limit scaling to prevent elements from becoming too large
      if (isLargeDevice(context) || isMediumDevice(context)) {
        // Limit maximum scale to 1.5x for tablets to keep UI consistent
        final maxScale = 1.5;
        final maxValue = baseValue * maxScale;
        return scaledValue > maxValue ? maxValue : scaledValue;
      }
      return scaledValue;
    }
    final screenWidth = getScreenWidth(context);
    final scaleFactor = screenWidth / baseWidth;
    // Limit scaling for tablets
    if (isLargeDevice(context) || isMediumDevice(context)) {
      final limitedFactor = scaleFactor.clamp(1.0, 1.5);
      return baseValue * limitedFactor;
    }
    return baseValue * scaleFactor;
  }
  
  // Get responsive height based on base design
  // Uses ScreenUtil for better tablet support with smart scaling
  static double getResponsiveHeight(BuildContext context, double baseValue) {
    if (_isScreenUtilInitialized) {
      final scaledValue = baseValue.h;
      // For tablets, limit scaling to prevent elements from becoming too large
      if (isLargeDevice(context) || isMediumDevice(context)) {
        // Limit maximum scale to 1.5x for tablets to keep UI consistent
        final maxScale = 1.5;
        final maxValue = baseValue * maxScale;
        return scaledValue > maxValue ? maxValue : scaledValue;
      }
      return scaledValue;
    }
    final screenHeight = getScreenHeight(context);
    final scaleFactor = screenHeight / baseHeight;
    // Limit scaling for tablets
    if (isLargeDevice(context) || isMediumDevice(context)) {
      final limitedFactor = scaleFactor.clamp(1.0, 1.5);
      return baseValue * limitedFactor;
    }
    return baseValue * scaleFactor;
  }
  
  // Get responsive font size
  // Uses ScreenUtil for better tablet support with proper text scaling
  static double getResponsiveFontSize(BuildContext context, double baseFontSize) {
    if (_isScreenUtilInitialized) {
      final scaledSize = baseFontSize.sp;
      // For tablets, increase font scaling for better readability
      if (isLargeDevice(context) || isMediumDevice(context)) {
        // Increase font size scaling to 1.6x max for tablets (was 1.3x - too small)
        // This ensures text is readable and appropriately sized on larger screens
        final maxSize = baseFontSize * 1.6;
        final minSize = baseFontSize * 1.2; // Ensure minimum scaling for tablets
        if (scaledSize < minSize) {
          return minSize;
        }
        return scaledSize > maxSize ? maxSize : scaledSize;
      }
      // For mobile, ensure minimum readable size
      final minMobileSize = baseFontSize * 0.9;
      return scaledSize < minMobileSize ? minMobileSize : scaledSize;
    }
    final screenWidth = getScreenWidth(context);
    final scaleFactor = screenWidth / baseWidth;
    // For tablets, use better scaling for readability
    if (isLargeDevice(context) || isMediumDevice(context)) {
      // Increase scaling range for tablets: 1.2x to 1.6x (was 1.0x to 1.3x)
      final limitedFactor = scaleFactor.clamp(1.2, 1.6);
      return baseFontSize * limitedFactor;
    }
    // For mobile, maintain reasonable scaling
    return (baseFontSize * scaleFactor).clamp(baseFontSize * 0.9, baseFontSize * 1.2);
  }
  
  // Get responsive padding
  // Uses ScreenUtil for better tablet support with smart scaling
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
    if (_isScreenUtilInitialized) {
      // For tablets, use more conservative padding scaling
      final isTablet = isLargeDevice(context) || isMediumDevice(context);
      final maxScale = isTablet ? 1.4 : null;
      
      double scaleValue(double value) {
        final scaled = value.w;
        if (isTablet && maxScale != null && scaled > value * maxScale) {
          return value * maxScale;
        }
        return scaled;
      }
      
      double scaleHeightValue(double value) {
        final scaled = value.h;
        if (isTablet && maxScale != null && scaled > value * maxScale) {
          return value * maxScale;
        }
        return scaled;
      }
      
      if (all != null) {
        return EdgeInsets.all(scaleValue(all));
      }
      return EdgeInsets.only(
        left: scaleValue(left ?? horizontal ?? 0),
        right: scaleValue(right ?? horizontal ?? 0),
        top: scaleHeightValue(top ?? vertical ?? 0),
        bottom: scaleHeightValue(bottom ?? vertical ?? 0),
      );
    }
    
    final screenWidth = getScreenWidth(context);
    final scaleFactor = screenWidth / baseWidth;
    final isTablet = isLargeDevice(context) || isMediumDevice(context);
    final limitedFactor = isTablet ? scaleFactor.clamp(1.0, 1.4) : scaleFactor;
    
    if (all != null) {
      final padding = all * limitedFactor;
      return EdgeInsets.all(padding);
    }
    
    return EdgeInsets.only(
      left: (left ?? horizontal ?? 0) * limitedFactor,
      right: (right ?? horizontal ?? 0) * limitedFactor,
      top: (top ?? vertical ?? 0) * limitedFactor,
      bottom: (bottom ?? vertical ?? 0) * limitedFactor,
    );
  }
  
  // Get responsive padding with directional support
  // Uses ScreenUtil for better tablet support
  static EdgeInsetsDirectional getResponsivePaddingDirectional(
    BuildContext context, {
    double? all,
    double? horizontal,
    double? vertical,
    double? top,
    double? bottom,
    double? start,
    double? end,
  }) {
    if (_isScreenUtilInitialized) {
      if (all != null) {
        return EdgeInsetsDirectional.all(all.w);
      }
      return EdgeInsetsDirectional.only(
        start: (start ?? horizontal ?? 0).w,
        end: (end ?? horizontal ?? 0).w,
        top: (top ?? vertical ?? 0).h,
        bottom: (bottom ?? vertical ?? 0).h,
      );
    }
    
    final screenWidth = getScreenWidth(context);
    final scaleFactor = screenWidth / baseWidth;
    
    if (all != null) {
      final padding = all * scaleFactor;
      return EdgeInsetsDirectional.all(padding);
    }
    
    return EdgeInsetsDirectional.only(
      start: (start ?? horizontal ?? 0) * scaleFactor,
      end: (end ?? horizontal ?? 0) * scaleFactor,
      top: (top ?? vertical ?? 0) * scaleFactor,
      bottom: (bottom ?? vertical ?? 0) * scaleFactor,
    );
  }
  
  // Get responsive margin
  static EdgeInsets getResponsiveMargin(
    BuildContext context, {
    double? all,
    double? horizontal,
    double? vertical,
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    return getResponsivePadding(
      context,
      all: all,
      horizontal: horizontal,
      vertical: vertical,
      top: top,
      bottom: bottom,
      left: left,
      right: right,
    );
  }
  
  // Get responsive size (for square widgets)
  // Uses ScreenUtil for better tablet support with smart scaling
  static double getResponsiveSize(BuildContext context, double baseSize) {
    if (_isScreenUtilInitialized) {
      final scaledValue = baseSize.w;
      // For tablets, limit scaling to prevent elements from becoming too large
      if (isLargeDevice(context) || isMediumDevice(context)) {
        // Limit maximum scale to 1.5x for tablets to keep UI consistent
        final maxScale = 1.5;
        final maxValue = baseSize * maxScale;
        return scaledValue > maxValue ? maxValue : scaledValue;
      }
      return scaledValue;
    }
    final screenWidth = getScreenWidth(context);
    final scaleFactor = screenWidth / baseWidth;
    // Limit scaling for tablets
    if (isLargeDevice(context) || isMediumDevice(context)) {
      final limitedFactor = scaleFactor.clamp(1.0, 1.5);
      return baseSize * limitedFactor;
    }
    return baseSize * scaleFactor;
  }
  
  // Get responsive border radius
  // Uses ScreenUtil for better tablet support with smart scaling
  static double getResponsiveRadius(BuildContext context, double baseRadius) {
    if (_isScreenUtilInitialized) {
      final scaledValue = baseRadius.r;
      // For tablets, limit scaling to keep border radius proportional
      if (isLargeDevice(context) || isMediumDevice(context)) {
        final maxScale = 1.4;
        final maxValue = baseRadius * maxScale;
        return scaledValue > maxValue ? maxValue : scaledValue;
      }
      return scaledValue;
    }
    final screenWidth = getScreenWidth(context);
    final scaleFactor = screenWidth / baseWidth;
    // Limit scaling for tablets
    if (isLargeDevice(context) || isMediumDevice(context)) {
      final limitedFactor = scaleFactor.clamp(1.0, 1.4);
      return baseRadius * limitedFactor;
    }
    return baseRadius * scaleFactor;
  }
  
  // Get responsive spacing
  // Uses ScreenUtil for better tablet support
  static SizedBox getResponsiveSpacing(BuildContext context, double baseSpacing) {
    if (_isScreenUtilInitialized) {
      return SizedBox(height: baseSpacing.h);
    }
    final screenWidth = getScreenWidth(context);
    final scaleFactor = screenWidth / baseWidth;
    return SizedBox(height: baseSpacing * scaleFactor);
  }
  
  // Get responsive horizontal spacing
  // Uses ScreenUtil for better tablet support
  static SizedBox getResponsiveHorizontalSpacing(BuildContext context, double baseSpacing) {
    if (_isScreenUtilInitialized) {
      return SizedBox(width: baseSpacing.w);
    }
    final screenWidth = getScreenWidth(context);
    final scaleFactor = screenWidth / baseWidth;
    return SizedBox(width: baseSpacing * scaleFactor);
  }
  
  // Check if device is small (phone)
  static bool isSmallDevice(BuildContext context) {
    return getScreenWidth(context) < 480;
  }
  
  // Check if device is medium (tablet)
  static bool isMediumDevice(BuildContext context) {
    final width = getScreenWidth(context);
    return width >= 480 && width < 768;
  }
  
  // Check if device is large (desktop/tablet landscape)
  static bool isLargeDevice(BuildContext context) {
    return getScreenWidth(context) >= 768;
  }
  
  // Get responsive value based on device size
  static T getResponsiveValue<T>(
    BuildContext context, {
    required T small,
    T? medium,
    T? large,
  }) {
    if (isLargeDevice(context)) {
      return large ?? medium ?? small;
    } else if (isMediumDevice(context)) {
      return medium ?? small;
    } else {
      return small;
    }
  }
  
  // Get safe area padding
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    return MediaQuery.paddingOf(context);
  }
  
  // Get viewport height (excluding safe areas)
  static double getViewportHeight(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.size.height - mediaQuery.padding.top - mediaQuery.padding.bottom;
  }
  
  // Get viewport width (excluding safe areas)
  static double getViewportWidth(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.size.width - mediaQuery.padding.left - mediaQuery.padding.right;
  }
  
  // Get responsive container constraints
  // Uses ScreenUtil for better tablet support
  static BoxConstraints getResponsiveConstraints(
    BuildContext context, {
    double? minWidth,
    double? maxWidth,
    double? minHeight,
    double? maxHeight,
    double? widthPercent,
    double? heightPercent,
  }) {
    final screenWidth = getScreenWidth(context);
    final screenHeight = getScreenHeight(context);
    
    if (_isScreenUtilInitialized) {
      return BoxConstraints(
        minWidth: minWidth != null ? minWidth.w : 0,
        maxWidth: maxWidth != null 
            ? maxWidth.w 
            : (widthPercent != null ? screenWidth * widthPercent : double.infinity),
        minHeight: minHeight != null ? minHeight.h : 0,
        maxHeight: maxHeight != null 
            ? maxHeight.h 
            : (heightPercent != null ? screenHeight * heightPercent : double.infinity),
      );
    }
    
    final scaleFactor = screenWidth / baseWidth;
    
    return BoxConstraints(
      minWidth: minWidth != null ? minWidth * scaleFactor : 0,
      maxWidth: maxWidth != null 
          ? maxWidth * scaleFactor 
          : (widthPercent != null ? screenWidth * widthPercent : double.infinity),
      minHeight: minHeight != null ? minHeight * scaleFactor : 0,
      maxHeight: maxHeight != null 
          ? maxHeight * scaleFactor 
          : (heightPercent != null ? screenHeight * heightPercent : double.infinity),
    );
  }
  
  // Clamp value between min and max based on screen size
  // Uses ScreenUtil for better tablet support
  static double clampResponsive(
    BuildContext context,
    double baseValue, {
    double? min,
    double? max,
  }) {
    double scaledValue;
    if (_isScreenUtilInitialized) {
      scaledValue = baseValue.w;
    } else {
      final screenWidth = getScreenWidth(context);
      final scaleFactor = screenWidth / baseWidth;
      scaledValue = baseValue * scaleFactor;
    }
    
    if (min != null && max != null) {
      return scaledValue.clamp(min, max);
    } else if (min != null) {
      return scaledValue < min ? min : scaledValue;
    } else if (max != null) {
      return scaledValue > max ? max : scaledValue;
    }
    
    return scaledValue;
  }
  
  // Additional helper methods using ScreenUtil directly for convenience
  // These can be used when you need more control
  
  /// Get responsive width using ScreenUtil (shorthand)
  static double w(double width) {
    if (_isScreenUtilInitialized) {
      return width.w;
    }
    return width;
  }
  
  /// Get responsive height using ScreenUtil (shorthand)
  static double h(double height) {
    if (_isScreenUtilInitialized) {
      return height.h;
    }
    return height;
  }
  
  /// Get responsive font size using ScreenUtil (shorthand)
  static double sp(double fontSize) {
    if (_isScreenUtilInitialized) {
      return fontSize.sp;
    }
    return fontSize;
  }
  
  /// Get responsive radius using ScreenUtil (shorthand)
  static double r(double radius) {
    if (_isScreenUtilInitialized) {
      return radius.r;
    }
    return radius;
  }
  
  /// Get top bar height including safe area and padding
  /// This helps position content below the top bar correctly
  static double getTopBarHeight(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final safeAreaTop = mediaQuery.padding.top;
    // Top bar structure: safe area + 5.0 top padding + 40.0 height + 8.0 bottom padding
    final topBarTopPadding = getResponsiveHeight(context, 5.0);
    final topBarHeight = getResponsiveHeight(context, 40.0);
    final topBarBottomPadding = getResponsiveHeight(context, 8.0);
    
    return safeAreaTop + topBarTopPadding + topBarHeight + topBarBottomPadding;
  }
  
  /// Get responsive top padding that accounts for top bar height
  /// Use this for content that should appear below the top bar
  static double getContentTopPadding(BuildContext context, {double additionalSpacing = 10.0}) {
    final topBarHeight = getTopBarHeight(context);
    final spacing = getResponsiveHeight(context, additionalSpacing);
    return topBarHeight + spacing;
  }
}

