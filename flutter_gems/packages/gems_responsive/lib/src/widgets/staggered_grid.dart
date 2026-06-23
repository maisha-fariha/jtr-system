import 'package:flutter/material.dart';
import '../responsive_helper.dart';
import 'animated_list_item.dart';

/// Staggered Grid Widget - Pinterest-style masonry grid with responsive columns
class StaggeredGrid extends StatelessWidget {
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

  const StaggeredGrid({
    super.key,
    required this.children,
    this.smallColumns,
    this.mediumColumns,
    this.largeColumns,
    this.spacing = 8.0,
    this.runSpacing = 8.0,
    this.padding,
    this.enableStaggerAnimation = true,
    this.staggerDelay = const Duration(milliseconds: 50),
    this.animationType,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final columns = ResponsiveHelper.getResponsiveValue<int>(
      context,
      small: smallColumns ?? 2,
      medium: mediumColumns ?? 3,
      large: largeColumns ?? 4,
    );

    final responsiveSpacing = ResponsiveHelper.getResponsiveWidth(context, spacing);
    final responsiveRunSpacing = ResponsiveHelper.getResponsiveHeight(context, runSpacing);
    final responsivePadding = padding ?? ResponsiveHelper.getResponsivePadding(context, all: 8);

    return Padding(
      padding: responsivePadding,
      child: _StaggeredGridLayout(
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

class _StaggeredGridLayout extends StatelessWidget {
  final int columns;
  final double spacing;
  final double runSpacing;
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final bool enableStaggerAnimation;
  final Duration staggerDelay;
  final ListAnimationType? animationType;

  const _StaggeredGridLayout({
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

    // Distribute children across columns
    final columnHeights = List<double>.filled(columns, 0.0);
    final columnWidgets = List<List<Widget>>.generate(columns, (_) => []);

    for (int i = 0; i < children.length; i++) {
      // Find column with minimum height
      final minHeightIndex = columnHeights.indexOf(columnHeights.reduce((a, b) => a < b ? a : b));
      
      final child = children[i];
      Widget wrappedChild = child;
      
      if (enableStaggerAnimation) {
        wrappedChild = AnimatedListItem(
          key: child.key ?? ValueKey(i),
          index: i,
          animationType: animationType ?? ListAnimationType.fadeSlide,
          slideDirection: ListSlideDirection.fromBottom,
          delay: staggerDelay,
          child: child,
        );
      }

      columnWidgets[minHeightIndex].add(wrappedChild);
      // Estimate height (will be calculated during layout)
      columnHeights[minHeightIndex] += 100; // Base estimate
    }

    // Build columns
    return Row(
      crossAxisAlignment: crossAxisAlignment,
      children: List.generate(columns, (index) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index < columns - 1 ? spacing : 0,
            ),
            child: Column(
              mainAxisAlignment: mainAxisAlignment,
              crossAxisAlignment: crossAxisAlignment,
              children: columnWidgets[index].asMap().entries.map((entry) {
                final itemIndex = entry.key;
                final item = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: itemIndex < columnWidgets[index].length - 1 ? runSpacing : 0,
                  ),
                  child: item,
                );
              }).toList(),
            ),
          ),
        );
      }),
    );
  }
}
