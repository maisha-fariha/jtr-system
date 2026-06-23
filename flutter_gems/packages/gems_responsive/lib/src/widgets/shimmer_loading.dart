import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../responsive_helper.dart';

/// Shimmer Loading Widget for skeleton screens
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration period;
  final ShimmerDirection direction;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.period = const Duration(milliseconds: 1500),
    this.direction = ShimmerDirection.ltr,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.period,
      vsync: this,
    )..repeat();
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
        return ShimmerEffect(
          child: widget.child,
          baseColor: widget.baseColor ?? Colors.grey[300]!,
          highlightColor: widget.highlightColor ?? Colors.grey[100]!,
          progress: _controller.value,
          direction: widget.direction,
        );
      },
    );
  }
}

class ShimmerEffect extends StatelessWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final double progress;
  final ShimmerDirection direction;

  const ShimmerEffect({
    super.key,
    required this.child,
    required this.baseColor,
    required this.highlightColor,
    required this.progress,
    required this.direction,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ShimmerPainter(
        baseColor: baseColor,
        highlightColor: highlightColor,
        progress: progress,
        direction: direction,
      ),
      child: child,
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final Color baseColor;
  final Color highlightColor;
  final double progress;
  final ShimmerDirection direction;

  _ShimmerPainter({
    required this.baseColor,
    required this.highlightColor,
    required this.progress,
    required this.direction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        _getGradientStart(size),
        _getGradientEnd(size),
        [
          baseColor,
          highlightColor,
          baseColor,
        ],
        [0.0, progress, 1.0],
      );

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  Offset _getGradientStart(Size size) {
    switch (direction) {
      case ShimmerDirection.ltr:
        return Offset(-size.width * 2, 0);
      case ShimmerDirection.rtl:
        return Offset(size.width * 2, 0);
      case ShimmerDirection.ttb:
        return Offset(0, -size.height * 2);
      case ShimmerDirection.btt:
        return Offset(0, size.height * 2);
    }
  }

  Offset _getGradientEnd(Size size) {
    switch (direction) {
      case ShimmerDirection.ltr:
        return Offset(size.width * 2, 0);
      case ShimmerDirection.rtl:
        return Offset(-size.width * 2, 0);
      case ShimmerDirection.ttb:
        return Offset(0, size.height * 2);
      case ShimmerDirection.btt:
        return Offset(0, -size.height * 2);
    }
  }

  @override
  bool shouldRepaint(_ShimmerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.direction != direction;
  }
}

/// Shimmer direction enum
enum ShimmerDirection {
  ltr, // Left to right
  rtl, // Right to left
  ttb, // Top to bottom
  btt, // Bottom to top
}

/// Shimmer Container - Pre-built shimmer container
class ShimmerContainer extends StatelessWidget {
  final double? width;
  final double? height;
  final double? borderRadius;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration period;

  const ShimmerContainer({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.baseColor,
    this.highlightColor,
    this.period = const Duration(milliseconds: 1500),
  });

  @override
  Widget build(BuildContext context) {
    final defaultWidth = width ?? ResponsiveHelper.getResponsiveWidth(context, 200);
    final defaultHeight = height ?? ResponsiveHelper.getResponsiveHeight(context, 100);
    final defaultRadius = borderRadius ?? ResponsiveHelper.getResponsiveRadius(context, 8);

    return ShimmerLoading(
      baseColor: baseColor,
      highlightColor: highlightColor,
      period: period,
      child: Container(
        width: defaultWidth,
        height: defaultHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(defaultRadius),
        ),
      ),
    );
  }
}

/// Shimmer List Item - Pre-built shimmer list item
class ShimmerListItem extends StatelessWidget {
  final bool hasAvatar;
  final bool hasSubtitle;
  final int? lines;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerListItem({
    super.key,
    this.hasAvatar = true,
    this.hasSubtitle = true,
    this.lines = 2,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: ResponsiveHelper.getResponsivePadding(
        context,
        horizontal: 16,
        vertical: 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasAvatar)
            ShimmerContainer(
              width: ResponsiveHelper.getResponsiveSize(context, 48),
              height: ResponsiveHelper.getResponsiveSize(context, 48),
              borderRadius: ResponsiveHelper.getResponsiveRadius(context, 24),
              baseColor: baseColor,
              highlightColor: highlightColor,
            ),
          if (hasAvatar)
            SizedBox(
              width: ResponsiveHelper.getResponsiveWidth(context, 16),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerContainer(
                  width: double.infinity,
                  height: ResponsiveHelper.getResponsiveHeight(context, 16),
                  borderRadius: ResponsiveHelper.getResponsiveRadius(context, 4),
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                ),
                if (hasSubtitle) ...[
                  SizedBox(
                    height: ResponsiveHelper.getResponsiveHeight(context, 8),
                  ),
                  ShimmerContainer(
                    width: double.infinity,
                    height: ResponsiveHelper.getResponsiveHeight(context, 12),
                    borderRadius: ResponsiveHelper.getResponsiveRadius(context, 4),
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                  ),
                ],
                if (lines != null && lines! > 2)
                  ...List.generate(
                    lines! - 2,
                    (index) => Padding(
                      padding: EdgeInsets.only(
                        top: ResponsiveHelper.getResponsiveHeight(context, 8),
                      ),
                      child: ShimmerContainer(
                        width: index == lines! - 3
                            ? ResponsiveHelper.getResponsiveWidth(context, 150)
                            : double.infinity,
                        height: ResponsiveHelper.getResponsiveHeight(context, 12),
                        borderRadius: ResponsiveHelper.getResponsiveRadius(context, 4),
                        baseColor: baseColor,
                        highlightColor: highlightColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
