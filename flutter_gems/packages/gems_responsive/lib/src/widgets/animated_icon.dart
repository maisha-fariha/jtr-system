import 'package:flutter/material.dart';
import '../responsive_helper.dart';

/// Animated Icon Widget with customizable animations
/// Supports rotation, scale, bounce, pulse, and fade animations
class GemsAnimatedIcon extends StatefulWidget {
  final IconData icon;
  final double? size;
  final Color? color;
  final AnimationType animationType;
  final Duration duration;
  final Curve curve;
  final VoidCallback? onTap;
  final bool repeat;
  final double? minScale;
  final double? maxScale;
  final double? rotationAngle;

  const GemsAnimatedIcon({
    super.key,
    required this.icon,
    this.size,
    this.color,
    this.animationType = AnimationType.scale,
    this.duration = const Duration(milliseconds: 500),
    this.curve = Curves.easeInOut,
    this.onTap,
    this.repeat = false,
    this.minScale,
    this.maxScale,
    this.rotationAngle,
  });

  @override
  State<GemsAnimatedIcon> createState() => _AnimatedIconState();
}

class _AnimatedIconState extends State<GemsAnimatedIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _setupAnimation();

    if (widget.repeat) {
      _controller.repeat(reverse: true);
    }
  }

  void _setupAnimation() {
    switch (widget.animationType) {
      case AnimationType.scale:
        final min = widget.minScale ?? 0.8;
        final max = widget.maxScale ?? 1.2;
        _animation = Tween<double>(begin: min, end: max)
            .animate(CurvedAnimation(parent: _controller, curve: widget.curve));
        break;
      case AnimationType.rotation:
        final angle = widget.rotationAngle ?? 360.0;
        _animation = Tween<double>(begin: 0, end: angle)
            .animate(CurvedAnimation(parent: _controller, curve: widget.curve));
        break;
      case AnimationType.bounce:
        _animation = Tween<double>(begin: 0, end: 1)
            .animate(CurvedAnimation(
                parent: _controller, curve: Curves.elasticOut));
        break;
      case AnimationType.pulse:
        _animation = Tween<double>(begin: 0.8, end: 1.2)
            .animate(CurvedAnimation(parent: _controller, curve: widget.curve));
        break;
      case AnimationType.fade:
        _animation = Tween<double>(begin: 0.3, end: 1.0)
            .animate(CurvedAnimation(parent: _controller, curve: widget.curve));
        break;
    }
  }

  @override
  void didUpdateWidget(GemsAnimatedIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationType != widget.animationType ||
        oldWidget.duration != widget.duration ||
        oldWidget.curve != widget.curve) {
      _controller.duration = widget.duration;
      _setupAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.repeat) {
      _controller.forward(from: 0).then((_) {
        _controller.reverse();
      });
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = widget.size ??
        ResponsiveHelper.getResponsiveFontSize(context, 24);

    Widget iconWidget = Icon(
      widget.icon,
      size: iconSize,
      color: widget.color ?? Theme.of(context).iconTheme.color,
    );

    // Apply transformations based on animation type
    switch (widget.animationType) {
      case AnimationType.scale:
      case AnimationType.pulse:
        iconWidget = ScaleTransition(
          scale: _animation,
          child: iconWidget,
        );
        break;
      case AnimationType.rotation:
        iconWidget = RotationTransition(
          turns: _animation,
          child: iconWidget,
        );
        break;
      case AnimationType.bounce:
        iconWidget = Transform.scale(
          scale: _animation.value,
          child: iconWidget,
        );
        break;
      case AnimationType.fade:
        iconWidget = FadeTransition(
          opacity: _animation,
          child: iconWidget,
        );
        break;
    }

    if (widget.onTap != null) {
      return GestureDetector(
        onTap: _handleTap,
        child: iconWidget,
      );
    }

    return iconWidget;
  }
}

/// Animation types for AnimatedIcon
enum AnimationType {
  scale,
  rotation,
  bounce,
  pulse,
  fade,
}
