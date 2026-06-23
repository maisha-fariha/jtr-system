import 'package:flutter/material.dart';
import '../responsive_helper.dart';

/// Pulse Animation Widget - Creates a pulsing effect
class PulseAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final double minScale;
  final double maxScale;
  final bool repeat;
  final Color? pulseColor;
  final double? pulseRadius;

  const PulseAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1000),
    this.curve = Curves.easeInOut,
    this.minScale = 0.9,
    this.maxScale = 1.1,
    this.repeat = true,
    this.pulseColor,
    this.pulseRadius,
  });

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    if (widget.repeat) {
      _controller.repeat(reverse: true);
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultRadius = widget.pulseRadius ??
        ResponsiveHelper.getResponsiveSize(context, 50);

    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulse effect (optional)
        if (widget.pulseColor != null)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                width: defaultRadius * _scaleAnimation.value,
                height: defaultRadius * _scaleAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.pulseColor!.withOpacity(
                    _opacityAnimation.value * 0.3,
                  ),
                ),
              );
            },
          ),
        // Main child
        ScaleTransition(
          scale: _scaleAnimation,
          child: widget.child,
        ),
      ],
    );
  }
}

/// Bounce Animation Widget - Creates a bouncing effect
class BounceAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final double bounceHeight;
  final bool repeat;
  final VoidCallback? onBounceComplete;

  const BounceAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.elasticOut,
    this.bounceHeight = 20.0,
    this.repeat = false,
    this.onBounceComplete,
  });

  @override
  State<BounceAnimation> createState() => _BounceAnimationState();
}

class _BounceAnimationState extends State<BounceAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _bounceAnimation = Tween<double>(
      begin: 0.0,
      end: widget.bounceHeight,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    if (widget.repeat) {
      _controller.repeat(reverse: true);
    } else {
      _controller.forward().then((_) {
        widget.onBounceComplete?.call();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_bounceAnimation.value),
          child: widget.child,
        );
      },
    );
  }
}
