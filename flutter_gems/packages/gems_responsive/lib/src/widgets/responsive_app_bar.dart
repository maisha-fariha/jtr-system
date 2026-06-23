import 'package:flutter/material.dart';
import '../responsive_helper.dart';
import 'transitions.dart';

/// Responsive App Bar - Adaptive app bar with auto-collapsing
class ResponsiveAppBar extends StatefulWidget implements PreferredSizeWidget {
  final Widget? title;
  final String? titleText;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final bool? centerTitle;
  final PreferredSizeWidget? bottom;
  final bool collapseOnScroll;
  final ScrollController? scrollController;
  final double collapseThreshold;
  final Widget? flexibleSpace;
  final double? toolbarHeight;
  final double? leadingWidth;

  const ResponsiveAppBar({
    super.key,
    this.title,
    this.titleText,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.centerTitle,
    this.bottom,
    this.collapseOnScroll = false,
    this.scrollController,
    this.collapseThreshold = 100.0,
    this.flexibleSpace,
    this.toolbarHeight,
    this.leadingWidth,
  });

  @override
  State<ResponsiveAppBar> createState() => _ResponsiveAppBarState();

  @override
  Size get preferredSize {
    // Default height: 56 for small devices, 64 for larger
    final defaultHeight = 56.0;
    return Size.fromHeight(
      (toolbarHeight ?? defaultHeight) + (bottom?.preferredSize.height ?? 0),
    );
  }
}

class _ResponsiveAppBarState extends State<ResponsiveAppBar> {
  bool _isCollapsed = false;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    if (widget.collapseOnScroll) {
      _scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    } else {
      if (widget.collapseOnScroll) {
        _scrollController.removeListener(_onScroll);
      }
    }
    super.dispose();
  }

  void _onScroll() {
    final threshold = ResponsiveHelper.getResponsiveHeight(
      context,
      widget.collapseThreshold,
    );
    final shouldCollapse = _scrollController.offset > threshold;

    if (shouldCollapse != _isCollapsed) {
      setState(() {
        _isCollapsed = shouldCollapse;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsiveToolbarHeight = widget.toolbarHeight ??
        ResponsiveHelper.getResponsiveHeight(
          context,
          ResponsiveHelper.isSmallDevice(context) ? 56 : 64,
        );

    final titleWidget = widget.title ??
        (widget.titleText != null
            ? FadeSlideTransition(
                slideDirection: SlideDirection.fromTop,
                duration: const Duration(milliseconds: 300),
                child: Text(
                  widget.titleText!,
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, 20),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null);

    return AppBar(
      title: titleWidget,
      actions: widget.actions,
      leading: widget.leading,
      automaticallyImplyLeading: widget.automaticallyImplyLeading,
      backgroundColor: widget.backgroundColor,
      foregroundColor: widget.foregroundColor,
      elevation: widget.elevation ??
          (_isCollapsed
              ? 4
              : ResponsiveHelper.getResponsiveValue<double>(
                  context,
                  small: 0,
                  medium: 2,
                  large: 4,
                )),
      centerTitle: widget.centerTitle != null
          ? widget.centerTitle!
          : ResponsiveHelper.getResponsiveValue<bool>(
              context,
              small: false,
              medium: true,
              large: true,
            ),
      bottom: widget.bottom,
      toolbarHeight: responsiveToolbarHeight,
      leadingWidth: widget.leadingWidth,
      flexibleSpace: widget.flexibleSpace,
    );
  }
}
