import 'package:flutter/material.dart';
import '../responsive_helper.dart';

/// Animated Button with micro-interactions
/// Supports scale, ripple, and loading animations
class AnimatedButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final Duration animationDuration;
  final Curve animationCurve;
  final double? minScale;
  final double? maxScale;
  final bool showRipple;
  final bool isLoading;
  final Widget? loadingWidget;
  final EdgeInsets? padding;
  final double? borderRadius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final Size? minimumSize;
  final Size? maximumSize;
  final bool enabled;

  const AnimatedButton({
    super.key,
    required this.child,
    this.onPressed,
    this.style,
    this.animationDuration = const Duration(milliseconds: 150),
    this.animationCurve = Curves.easeInOut,
    this.minScale,
    this.maxScale,
    this.showRipple = true,
    this.isLoading = false,
    this.loadingWidget,
    this.padding,
    this.borderRadius,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.minimumSize,
    this.maximumSize,
    this.enabled = true,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    final minScale = widget.minScale ?? 0.95;
    final maxScale = widget.maxScale ?? 1.0;

    _scaleAnimation = Tween<double>(begin: maxScale, end: minScale)
        .animate(CurvedAnimation(
      parent: _controller,
      curve: widget.animationCurve,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.enabled && !widget.isLoading) {
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.enabled && !widget.isLoading) {
      _controller.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.enabled && !widget.isLoading) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.enabled && !widget.isLoading && widget.onPressed != null;

    final defaultPadding = ResponsiveHelper.getResponsivePadding(
      context,
      horizontal: 24,
      vertical: 12,
    );
    final defaultBorderRadius = BorderRadius.circular(
      widget.borderRadius ?? ResponsiveHelper.getResponsiveRadius(context, 8),
    );

    Widget buttonChild = widget.isLoading
        ? (widget.loadingWidget ??
            SizedBox(
              width: ResponsiveHelper.getResponsiveSize(context, 20),
              height: ResponsiveHelper.getResponsiveSize(context, 20),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  widget.foregroundColor ??
                      Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ))
        : widget.child;

    Widget button = ScaleTransition(
      scale: _scaleAnimation,
      child: Material(
        color: widget.backgroundColor ??
            (isEnabled
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).disabledColor),
        borderRadius: defaultBorderRadius,
        elevation: widget.elevation ?? (isEnabled ? 2 : 0),
        child: InkWell(
          onTap: isEnabled ? widget.onPressed : null,
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          borderRadius: defaultBorderRadius,
          child: Container(
            padding: widget.padding ?? defaultPadding,
            constraints: BoxConstraints(
              minWidth: widget.minimumSize?.width ??
                  ResponsiveHelper.getResponsiveWidth(context, 120),
              minHeight: widget.minimumSize?.height ??
                  ResponsiveHelper.getResponsiveHeight(context, 48),
              maxWidth: widget.maximumSize?.width ?? double.infinity,
              maxHeight: widget.maximumSize?.height ?? double.infinity,
            ),
            alignment: Alignment.center,
            child: DefaultTextStyle(
              style: TextStyle(
                color: widget.foregroundColor ??
                    (isEnabled
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).disabledColor),
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                fontWeight: FontWeight.w600,
              ),
              child: buttonChild,
            ),
          ),
        ),
      ),
    );

    return button;
  }
}
