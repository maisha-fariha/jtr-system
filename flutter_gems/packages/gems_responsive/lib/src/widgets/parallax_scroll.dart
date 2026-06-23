import 'package:flutter/material.dart';
import '../responsive_helper.dart';

/// Parallax Scroll Widget - Parallax scrolling effects with responsive calculations
class ParallaxScroll extends StatefulWidget {
  final Widget child;
  final Widget? backgroundImage;
  final String? backgroundImageUrl;
  final double scrollSpeed;
  final double? minScrollSpeed;
  final double? maxScrollSpeed;
  final Alignment backgroundAlignment;
  final BoxFit backgroundFit;
  final Color? backgroundColor;

  const ParallaxScroll({
    super.key,
    required this.child,
    this.backgroundImage,
    this.backgroundImageUrl,
    this.scrollSpeed = 0.5,
    this.minScrollSpeed,
    this.maxScrollSpeed,
    this.backgroundAlignment = Alignment.center,
    this.backgroundFit = BoxFit.cover,
    this.backgroundColor,
  }) : assert(
          backgroundImage != null || backgroundImageUrl != null,
          'Either backgroundImage or backgroundImageUrl must be provided',
        );

  @override
  State<ParallaxScroll> createState() => _ParallaxScrollState();
}

class _ParallaxScrollState extends State<ParallaxScroll> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  double _getResponsiveScrollSpeed() {
    final screenHeight = ResponsiveHelper.getScreenHeight(context);
    final baseSpeed = widget.scrollSpeed;
    
    // Adjust speed based on screen size
    final responsiveSpeed = baseSpeed * (screenHeight / 800.0);
    
    // Apply min/max constraints
    final minSpeed = widget.minScrollSpeed ?? responsiveSpeed * 0.5;
    final maxSpeed = widget.maxScrollSpeed ?? responsiveSpeed * 1.5;
    
    return responsiveSpeed.clamp(minSpeed, maxSpeed);
  }

  @override
  Widget build(BuildContext context) {
    final scrollSpeed = _getResponsiveScrollSpeed();
    final parallaxOffset = _scrollOffset * scrollSpeed;

    Widget backgroundWidget;
    if (widget.backgroundImage != null) {
      backgroundWidget = widget.backgroundImage!;
    } else if (widget.backgroundImageUrl != null) {
      backgroundWidget = Image.network(
        widget.backgroundImageUrl!,
        fit: widget.backgroundFit,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: widget.backgroundColor ?? Colors.grey.shade300,
            child: Icon(
              Icons.broken_image,
              size: ResponsiveHelper.getResponsiveSize(context, 48),
              color: Colors.grey.shade600,
            ),
          );
        },
      );
    } else {
      backgroundWidget = Container(color: widget.backgroundColor ?? Colors.grey.shade300);
    }

    return Stack(
      children: [
        // Parallax background
        Positioned.fill(
          child: Transform.translate(
            offset: Offset(0, parallaxOffset),
            child: Align(
              alignment: widget.backgroundAlignment,
              child: backgroundWidget,
            ),
          ),
        ),
        // Scrollable content
        SingleChildScrollView(
          controller: _scrollController,
          child: widget.child,
        ),
      ],
    );
  }
}
