import 'package:flutter/material.dart';
import '../responsive_helper.dart';

/// Breakpoint information
class Breakpoint {
  final bool isSmall;
  final bool isMedium;
  final bool isLarge;
  final double width;
  final double height;
  final Orientation orientation;

  const Breakpoint({
    required this.isSmall,
    required this.isMedium,
    required this.isLarge,
    required this.width,
    required this.height,
    required this.orientation,
  });
}

/// Breakpoint Builder - Conditional rendering based on screen size
class BreakpointBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, Breakpoint breakpoint) builder;
  final Widget? small;
  final Widget? medium;
  final Widget? large;
  final bool rebuildOnOrientationChange;

  const BreakpointBuilder({
    super.key,
    required this.builder,
    this.small,
    this.medium,
    this.large,
    this.rebuildOnOrientationChange = true,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = ResponsiveHelper.getScreenWidth(context);
    final screenHeight = ResponsiveHelper.getScreenHeight(context);
    final orientation = MediaQuery.of(context).orientation;
    
    final isSmall = ResponsiveHelper.isSmallDevice(context);
    final isMedium = ResponsiveHelper.isMediumDevice(context);
    final isLarge = ResponsiveHelper.isLargeDevice(context);

    final breakpoint = Breakpoint(
      isSmall: isSmall,
      isMedium: isMedium,
      isLarge: isLarge,
      width: screenWidth,
      height: screenHeight,
      orientation: orientation,
    );

    // If specific widgets are provided, use them
    if (small != null && isSmall) return small!;
    if (medium != null && isMedium) return medium!;
    if (large != null && isLarge) return large!;

    // Otherwise use the builder
    return builder(context, breakpoint);
  }
}

/// Responsive Value Builder - Get different values based on breakpoint
class ResponsiveValueBuilder<T> extends StatelessWidget {
  final T small;
  final T? medium;
  final T? large;
  final Widget Function(BuildContext context, T value) builder;

  const ResponsiveValueBuilder({
    super.key,
    required this.small,
    this.medium,
    this.large,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final value = ResponsiveHelper.getResponsiveValue<T>(
      context,
      small: small,
      medium: medium,
      large: large,
    );
    return builder(context, value);
  }
}
