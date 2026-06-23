import 'package:flutter/material.dart';
import '../responsive_helper.dart';
import 'animated_icon.dart';

/// Responsive Carousel - Adaptive carousel with responsive item sizing
class ResponsiveCarousel extends StatefulWidget {
  final List<Widget> children;
  final double? height;
  final double? itemWidth;
  final double spacing;
  final bool autoPlay;
  final Duration autoPlayInterval;
  final Curve animationCurve;
  final Duration animationDuration;
  final bool showIndicators;
  final bool showArrows;
  final Color? indicatorColor;
  final Color? activeIndicatorColor;
  final VoidCallback? onPageChanged;
  final int initialPage;

  const ResponsiveCarousel({
    super.key,
    required this.children,
    this.height,
    this.itemWidth,
    this.spacing = 16.0,
    this.autoPlay = false,
    this.autoPlayInterval = const Duration(seconds: 3),
    this.animationCurve = Curves.easeInOut,
    this.animationDuration = const Duration(milliseconds: 300),
    this.showIndicators = true,
    this.showArrows = true,
    this.indicatorColor,
    this.activeIndicatorColor,
    this.onPageChanged,
    this.initialPage = 0,
  });

  @override
  State<ResponsiveCarousel> createState() => _ResponsiveCarouselState();
}

class _ResponsiveCarouselState extends State<ResponsiveCarousel> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(
      initialPage: widget.initialPage,
      viewportFraction: _getViewportFraction(),
    );

    if (widget.autoPlay) {
      _startAutoPlay();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  double _getViewportFraction() {
    if (widget.itemWidth != null) {
      final screenWidth = ResponsiveHelper.getScreenWidth(context);
      return widget.itemWidth! / screenWidth;
    }
    // Auto-calculate based on screen size
    if (ResponsiveHelper.isSmallDevice(context)) {
      return 0.9; // Show most of one item on phone
    } else if (ResponsiveHelper.isMediumDevice(context)) {
      return 0.7; // Show part of next item on tablet
    } else {
      return 0.6; // Show more items on desktop
    }
  }

  void _startAutoPlay() {
    Future.delayed(widget.autoPlayInterval, () {
      if (mounted && widget.autoPlay) {
        final nextPage = (_currentPage + 1) % widget.children.length;
        _pageController.animateToPage(
          nextPage,
          duration: widget.animationDuration,
          curve: widget.animationCurve,
        );
        _startAutoPlay();
      }
    });
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    widget.onPageChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return const SizedBox.shrink();

    final responsiveHeight = widget.height ??
        ResponsiveHelper.getResponsiveHeight(
          context,
          ResponsiveHelper.isSmallDevice(context) ? 200 : 300,
        );
    final responsiveSpacing = ResponsiveHelper.getResponsiveWidth(context, widget.spacing);

    return Column(
      children: [
        SizedBox(
          height: responsiveHeight,
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: widget.children.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: responsiveSpacing / 2),
                    child: widget.children[index],
                  );
                },
              ),
              // Navigation arrows
              if (widget.showArrows && widget.children.length > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Previous arrow
                    Padding(
                      padding: ResponsiveHelper.getResponsivePadding(context, all: 8),
                      child: GestureDetector(
                        onTap: () {
                          final prevPage = (_currentPage - 1) % widget.children.length;
                          _pageController.animateToPage(
                            prevPage < 0 ? widget.children.length - 1 : prevPage,
                            duration: widget.animationDuration,
                            curve: widget.animationCurve,
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: ResponsiveHelper.getResponsivePadding(context, all: 8),
                          child: GemsAnimatedIcon(
                            icon: Icons.chevron_left,
                            color: Colors.white,
                            animationType: AnimationType.scale,
                          ),
                        ),
                      ),
                    ),
                    // Next arrow
                    Padding(
                      padding: ResponsiveHelper.getResponsivePadding(context, all: 8),
                      child: GestureDetector(
                        onTap: () {
                          final nextPage = (_currentPage + 1) % widget.children.length;
                          _pageController.animateToPage(
                            nextPage,
                            duration: widget.animationDuration,
                            curve: widget.animationCurve,
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: ResponsiveHelper.getResponsivePadding(context, all: 8),
                          child: GemsAnimatedIcon(
                            icon: Icons.chevron_right,
                            color: Colors.white,
                            animationType: AnimationType.scale,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        // Indicators
        if (widget.showIndicators && widget.children.length > 1)
          Padding(
            padding: ResponsiveHelper.getResponsivePadding(context, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.children.length, (index) {
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveHelper.getResponsiveWidth(context, 4),
                  ),
                  child: Container(
                    width: ResponsiveHelper.getResponsiveSize(context, 8),
                    height: ResponsiveHelper.getResponsiveSize(context, 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == _currentPage
                          ? (widget.activeIndicatorColor ??
                              Theme.of(context).colorScheme.primary)
                          : (widget.indicatorColor ?? Colors.grey.shade400),
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}
