import 'package:flutter/material.dart';
import '../responsive_helper.dart';

/// Animated List Item with stagger animations
class AnimatedListItem extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration delay;
  final Duration duration;
  final Curve curve;
  final ListAnimationType animationType;
  final ListSlideDirection? slideDirection;
  final double? slideDistance;

  const AnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.delay = const Duration(milliseconds: 100),
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.easeOut,
    this.animationType = ListAnimationType.fadeSlide,
    this.slideDirection,
    this.slideDistance,
  });

  @override
  Widget build(BuildContext context) {
    return _AnimatedListItemStateful(
      key: key,
      index: index,
      delay: delay,
      duration: duration,
      curve: curve,
      animationType: animationType,
      slideDirection: slideDirection,
      slideDistance: slideDistance,
      child: child,
    );
  }
}

class _AnimatedListItemStateful extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;
  final Duration duration;
  final Curve curve;
  final ListAnimationType animationType;
  final ListSlideDirection? slideDirection;
  final double? slideDistance;

  const _AnimatedListItemStateful({
    super.key,
    required this.child,
    required this.index,
    required this.delay,
    required this.duration,
    required this.curve,
    required this.animationType,
    this.slideDirection,
    this.slideDistance,
  });

  @override
  State<_AnimatedListItemStateful> createState() =>
      _AnimatedListItemStatefulState();
}

class _AnimatedListItemStatefulState
    extends State<_AnimatedListItemStateful>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    final direction = widget.slideDirection ?? ListSlideDirection.fromBottom;
    final screenHeight = ResponsiveHelper.getScreenHeight(context);
    final defaultDistance = widget.slideDistance ?? screenHeight * 0.05;

    Offset beginOffset;
    switch (direction) {
      case ListSlideDirection.fromTop:
        beginOffset = Offset(0, -defaultDistance);
        break;
      case ListSlideDirection.fromBottom:
        beginOffset = Offset(0, defaultDistance);
        break;
      case ListSlideDirection.fromLeft:
        beginOffset = Offset(-defaultDistance, 0);
        break;
      case ListSlideDirection.fromRight:
        beginOffset = Offset(defaultDistance, 0);
        break;
    }

    _slideAnimation = Tween<Offset>(begin: beginOffset, end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    // Start animation after delay (only on first build)
    if (!_hasAnimated) {
      Future.delayed(widget.delay * widget.index, () {
        if (mounted && !_hasAnimated) {
          _hasAnimated = true;
          _controller.forward();
        }
      });
    } else {
      // If already animated, set to final state immediately
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget animatedChild = widget.child;

    switch (widget.animationType) {
      case ListAnimationType.fade:
        animatedChild = FadeTransition(
          opacity: _fadeAnimation,
          child: animatedChild,
        );
        break;
      case ListAnimationType.slide:
        animatedChild = SlideTransition(
          position: _slideAnimation,
          child: animatedChild,
        );
        break;
      case ListAnimationType.scale:
        animatedChild = ScaleTransition(
          scale: _scaleAnimation,
          child: animatedChild,
        );
        break;
      case ListAnimationType.fadeSlide:
        animatedChild = FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: animatedChild,
          ),
        );
        break;
      case ListAnimationType.fadeScale:
        animatedChild = FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: animatedChild,
          ),
        );
        break;
    }

    return animatedChild;
  }
}

/// Animation types for list items
enum ListAnimationType {
  fade,
  slide,
  scale,
  fadeSlide,
  fadeScale,
}

/// Slide direction enum for list items
enum ListSlideDirection {
  fromTop,
  fromBottom,
  fromLeft,
  fromRight,
}
