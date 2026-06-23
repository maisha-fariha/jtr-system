import 'package:flutter/material.dart';
import '../responsive_helper.dart';
import 'animated_list_item.dart';

/// Responsive Grid Widget - Automatically adjusts columns based on screen size
/// Supports stagger animations and responsive spacing
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int? smallColumns;
  final int? mediumColumns;
  final int? largeColumns;
  final double spacing;
  final double runSpacing;
  final EdgeInsets? padding;
  final bool enableStaggerAnimation;
  final Duration staggerDelay;
  final ListAnimationType? animationType;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.smallColumns,
    this.mediumColumns,
    this.largeColumns,
    this.spacing = 8.0,
    this.runSpacing = 8.0,
    this.padding,
    this.enableStaggerAnimation = false,
    this.staggerDelay = const Duration(milliseconds: 50),
    this.animationType,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final columns = ResponsiveHelper.getResponsiveValue<int>(
      context,
      small: smallColumns ?? 1,
      medium: mediumColumns ?? 2,
      large: largeColumns ?? 3,
    );

    final responsiveSpacing = ResponsiveHelper.getResponsiveWidth(context, spacing);
    final responsiveRunSpacing = ResponsiveHelper.getResponsiveHeight(context, runSpacing);
    final responsivePadding = padding ?? ResponsiveHelper.getResponsivePadding(context, all: 8);

    return Padding(
      padding: responsivePadding,
      child: _ResponsiveGridLayout(
        columns: columns,
        spacing: responsiveSpacing,
        runSpacing: responsiveRunSpacing,
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        enableStaggerAnimation: enableStaggerAnimation,
        staggerDelay: staggerDelay,
        animationType: animationType,
        children: children,
      ),
    );
  }
}

class _ResponsiveGridLayout extends StatelessWidget {
  final int columns;
  final double spacing;
  final double runSpacing;
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final bool enableStaggerAnimation;
  final Duration staggerDelay;
  final ListAnimationType? animationType;

  const _ResponsiveGridLayout({
    required this.columns,
    required this.spacing,
    required this.runSpacing,
    required this.children,
    required this.mainAxisAlignment,
    required this.crossAxisAlignment,
    required this.enableStaggerAnimation,
    required this.staggerDelay,
    this.animationType,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final rows = <Widget>[];
    for (int i = 0; i < children.length; i += columns) {
      final rowChildren = <Widget>[];
      for (int j = 0; j < columns && (i + j) < children.length; j++) {
        final child = children[i + j];
        final index = i + j;

        Widget wrappedChild = child;
        if (enableStaggerAnimation) {
          wrappedChild = AnimatedListItem(
            key: child.key ?? ValueKey(index),
            index: index,
            animationType: animationType ?? ListAnimationType.fadeSlide,
            slideDirection: ListSlideDirection.fromBottom,
            delay: staggerDelay,
            child: child,
          );
        }

        rowChildren.add(
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: j < columns - 1 ? spacing : 0,
              ),
              child: wrappedChild,
            ),
          ),
        );
      }

      rows.add(
        Padding(
          padding: EdgeInsets.only(
            bottom: i + columns < children.length ? runSpacing : 0,
          ),
          child: Row(
            mainAxisAlignment: mainAxisAlignment,
            crossAxisAlignment: crossAxisAlignment,
            children: rowChildren,
          ),
        ),
      );
    }

    return Column(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: rows,
    );
  }
}
