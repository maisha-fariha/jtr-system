import 'package:flutter/material.dart';
import '../responsive_helper.dart';

/// Fade Transition Widget with customizable duration and curve
class FadeTransitionWidget extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final double beginOpacity;
  final double endOpacity;

  const FadeTransitionWidget({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
    this.beginOpacity = 0.0,
    this.endOpacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      curve: curve,
      tween: Tween(begin: beginOpacity, end: endOpacity),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: child,
        );
      },
      child: child,
    );
  }
}

/// Slide Transition Widget with customizable direction and distance
class SlideTransitionWidget extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final SlideDirection direction;
  final double? distance;

  const SlideTransitionWidget({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
    this.direction = SlideDirection.fromBottom,
    this.distance,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = ResponsiveHelper.getScreenHeight(context);
    final defaultDistance = distance ?? screenHeight * 0.1;

    Offset beginOffset;
    switch (direction) {
      case SlideDirection.fromTop:
        beginOffset = Offset(0, -defaultDistance);
        break;
      case SlideDirection.fromBottom:
        beginOffset = Offset(0, defaultDistance);
        break;
      case SlideDirection.fromLeft:
        beginOffset = Offset(-defaultDistance, 0);
        break;
      case SlideDirection.fromRight:
        beginOffset = Offset(defaultDistance, 0);
        break;
    }

    return TweenAnimationBuilder<Offset>(
      duration: duration,
      curve: curve,
      tween: Tween(begin: beginOffset, end: Offset.zero),
      builder: (context, value, child) {
        return Transform.translate(
          offset: value,
          child: child,
        );
      },
      child: child,
    );
  }
}

/// Combined Fade and Slide Transition
class FadeSlideTransition extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final SlideDirection slideDirection;
  final double? slideDistance;
  final double beginOpacity;
  final double endOpacity;

  const FadeSlideTransition({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
    this.slideDirection = SlideDirection.fromBottom,
    this.slideDistance,
    this.beginOpacity = 0.0,
    this.endOpacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransitionWidget(
      duration: duration,
      curve: curve,
      beginOpacity: beginOpacity,
      endOpacity: endOpacity,
      child: SlideTransitionWidget(
        duration: duration,
        curve: curve,
        direction: slideDirection,
        distance: slideDistance,
        child: child,
      ),
    );
  }
}

/// Scale Transition Widget
class ScaleTransitionWidget extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final double beginScale;
  final double endScale;

  const ScaleTransitionWidget({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
    this.beginScale = 0.0,
    this.endScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      curve: curve,
      tween: Tween(begin: beginScale, end: endScale),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: child,
    );
  }
}

/// Slide direction enum
enum SlideDirection {
  fromTop,
  fromBottom,
  fromLeft,
  fromRight,
}
