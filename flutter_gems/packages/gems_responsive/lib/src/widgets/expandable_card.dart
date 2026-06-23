import 'package:flutter/material.dart';
import '../responsive_helper.dart';

/// Expandable Card Widget with smooth expand/collapse animations
/// Perfect for accordions, collapsible sections, and expandable content
class ExpandableCard extends StatefulWidget {
  final Widget title;
  final Widget? subtitle;
  final Widget child;
  final bool initiallyExpanded;
  final Duration duration;
  final Curve curve;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? backgroundColor;
  final double? elevation;
  final BorderRadius? borderRadius;
  final IconData? expandIcon;
  final IconData? collapseIcon;
  final VoidCallback? onExpansionChanged;
  final bool maintainState;
  final Widget? leading;
  final Widget? trailing;

  const ExpandableCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.initiallyExpanded = false,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.elevation,
    this.borderRadius,
    this.expandIcon,
    this.collapseIcon,
    this.onExpansionChanged,
    this.maintainState = false,
    this.leading,
    this.trailing,
  });

  @override
  State<ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<ExpandableCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
      widget.onExpansionChanged?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final defaultPadding = ResponsiveHelper.getResponsivePadding(
      context,
      all: 16,
    );
    final defaultMargin = ResponsiveHelper.getResponsiveMargin(
      context,
      bottom: 12,
    );
    final defaultBorderRadius = BorderRadius.circular(
      ResponsiveHelper.getResponsiveRadius(context, 12),
    );

    return Container(
      margin: widget.margin ?? defaultMargin,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Theme.of(context).cardColor,
        borderRadius: widget.borderRadius ?? defaultBorderRadius,
        boxShadow: widget.elevation != null
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: widget.elevation!,
                  offset: Offset(0, widget.elevation! / 2),
                )
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          InkWell(
            onTap: _toggleExpansion,
            borderRadius: widget.borderRadius ?? defaultBorderRadius,
            child: Padding(
              padding: widget.padding ?? defaultPadding,
              child: Row(
                children: [
                  if (widget.leading != null) ...[
                    widget.leading!,
                    SizedBox(
                      width: ResponsiveHelper.getResponsiveWidth(context, 12),
                    ),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DefaultTextStyle(
                          style: Theme.of(context).textTheme.titleMedium ??
                              const TextStyle(),
                          child: widget.title,
                        ),
                        if (widget.subtitle != null) ...[
                          SizedBox(
                            height: ResponsiveHelper.getResponsiveHeight(
                              context,
                              4,
                            ),
                          ),
                          DefaultTextStyle(
                            style: Theme.of(context).textTheme.bodySmall ??
                                const TextStyle(),
                            child: widget.subtitle!,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.trailing != null) ...[
                    SizedBox(
                      width: ResponsiveHelper.getResponsiveWidth(context, 12),
                    ),
                    widget.trailing!,
                  ],
                  SizedBox(
                    width: ResponsiveHelper.getResponsiveWidth(context, 8),
                  ),
                  RotationTransition(
                    turns: Tween<double>(begin: 0.0, end: 0.5)
                        .animate(_expandAnimation),
                    child: Icon(
                      _isExpanded
                          ? (widget.collapseIcon ?? Icons.expand_less)
                          : (widget.expandIcon ?? Icons.expand_more),
                      color: Theme.of(context).iconTheme.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expandable content
          ClipRect(
            child: SizeTransition(
              sizeFactor: _expandAnimation,
              axisAlignment: -1.0,
              child: widget.maintainState
                  ? widget.child
                  : _isExpanded
                      ? Padding(
                          padding: widget.padding ?? defaultPadding,
                          child: widget.child,
                        )
                      : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
