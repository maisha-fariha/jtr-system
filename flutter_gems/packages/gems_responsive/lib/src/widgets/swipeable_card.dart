import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../responsive_helper.dart';

/// Swipeable Card Widget - Swipe actions with smooth animations
class SwipeableCard extends StatefulWidget {
  final Widget child;
  final Widget? leftAction;
  final Widget? rightAction;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final Color? leftActionColor;
  final Color? rightActionColor;
  final double swipeThreshold;
  final Duration animationDuration;
  final Curve animationCurve;
  final bool enableHapticFeedback;
  final VoidCallback? onSwipeStart;
  final VoidCallback? onSwipeEnd;

  const SwipeableCard({
    super.key,
    required this.child,
    this.leftAction,
    this.rightAction,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.leftActionColor,
    this.rightActionColor,
    this.swipeThreshold = 0.3,
    this.animationDuration = const Duration(milliseconds: 300),
    this.animationCurve = Curves.easeOut,
    this.enableHapticFeedback = true,
    this.onSwipeStart,
    this.onSwipeEnd,
  });

  @override
  State<SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<SwipeableCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _offsetAnimation;
  double _dragOffset = 0.0;
  double _actionOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _offsetAnimation = Tween<double>(begin: 0.0, end: 0.0)
        .animate(CurvedAnimation(parent: _controller, curve: widget.animationCurve));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    widget.onSwipeStart?.call();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final screenWidth = ResponsiveHelper.getScreenWidth(context);
    final delta = details.primaryDelta ?? 0.0;
    
    setState(() {
      _dragOffset += delta;
      // Clamp the offset
      final maxOffset = screenWidth * 0.5;
      _dragOffset = _dragOffset.clamp(-maxOffset, maxOffset);
      
      // Update action opacity based on drag distance
      _actionOpacity = (_dragOffset.abs() / (screenWidth * widget.swipeThreshold)).clamp(0.0, 1.0);
    });

    // Haptic feedback when threshold is reached
    if (widget.enableHapticFeedback) {
      final threshold = screenWidth * widget.swipeThreshold;
      if (_dragOffset.abs() >= threshold && _dragOffset.abs() < threshold + 10) {
        HapticFeedback.mediumImpact();
      }
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    final screenWidth = ResponsiveHelper.getScreenWidth(context);
    final threshold = screenWidth * widget.swipeThreshold;
    
    widget.onSwipeEnd?.call();

    if (_dragOffset.abs() >= threshold) {
      // Swipe completed - trigger action
      if (_dragOffset < 0 && widget.onSwipeLeft != null) {
        // Swipe left
        widget.onSwipeLeft?.call();
        _reset();
      } else if (_dragOffset > 0 && widget.onSwipeRight != null) {
        // Swipe right
        widget.onSwipeRight?.call();
        _reset();
      } else {
        _reset();
      }
    } else {
      // Snap back
      _reset();
    }
  }

  void _reset() {
    _offsetAnimation = Tween<double>(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.animationCurve),
    );
    _controller.forward(from: 0.0).then((_) {
      setState(() {
        _dragOffset = 0.0;
        _actionOpacity = 0.0;
      });
      _controller.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = ResponsiveHelper.getScreenWidth(context);
    final hasLeftAction = widget.leftAction != null || widget.onSwipeLeft != null;
    final hasRightAction = widget.rightAction != null || widget.onSwipeRight != null;

    return GestureDetector(
      onHorizontalDragStart: hasLeftAction || hasRightAction ? _handleDragStart : null,
      onHorizontalDragUpdate: hasLeftAction || hasRightAction ? _handleDragUpdate : null,
      onHorizontalDragEnd: hasLeftAction || hasRightAction ? _handleDragEnd : null,
      child: Stack(
        children: [
          // Background actions
          if (hasLeftAction || hasRightAction)
            Positioned.fill(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left action
                  if (hasLeftAction)
                    Opacity(
                      opacity: _dragOffset < 0 ? _actionOpacity : 0.0,
                      child: Container(
                        width: screenWidth * 0.2,
                        color: widget.leftActionColor ?? Colors.red,
                        alignment: Alignment.centerLeft,
                        padding: ResponsiveHelper.getResponsivePadding(context, all: 16),
                        child: widget.leftAction ??
                            Icon(
                              Icons.delete,
                              color: Colors.white,
                              size: ResponsiveHelper.getResponsiveSize(context, 24),
                            ),
                      ),
                    ),
                  const Spacer(),
                  // Right action
                  if (hasRightAction)
                    Opacity(
                      opacity: _dragOffset > 0 ? _actionOpacity : 0.0,
                      child: Container(
                        width: screenWidth * 0.2,
                        color: widget.rightActionColor ?? Colors.green,
                        alignment: Alignment.centerRight,
                        padding: ResponsiveHelper.getResponsivePadding(context, all: 16),
                        child: widget.rightAction ??
                            Icon(
                              Icons.check,
                              color: Colors.white,
                              size: ResponsiveHelper.getResponsiveSize(context, 24),
                            ),
                      ),
                    ),
                ],
              ),
            ),
          // Main card content
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final offset = _controller.isAnimating ? _offsetAnimation.value : _dragOffset;
              return Transform.translate(
                offset: Offset(offset, 0),
                child: widget.child,
              );
            },
          ),
        ],
      ),
    );
  }
}
