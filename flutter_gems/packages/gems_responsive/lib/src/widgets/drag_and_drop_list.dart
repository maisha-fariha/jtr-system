import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../responsive_helper.dart';
import 'transitions.dart';

/// Drag and Drop List Item
class DragAndDropListItem<T> {
  final T data;
  final Widget child;
  final String? id;

  const DragAndDropListItem({
    required this.data,
    required this.child,
    this.id,
  });
}

/// Drag and Drop List - Reorderable list with smooth animations
class DragAndDropList<T> extends StatefulWidget {
  final List<DragAndDropListItem<T>> items;
  final void Function(int oldIndex, int newIndex) onReorder;
  final EdgeInsets? padding;
  final double spacing;
  final bool enableHapticFeedback;
  final Duration animationDuration;
  final Curve animationCurve;
  final Color? dragColor;
  final double? dragElevation;

  const DragAndDropList({
    super.key,
    required this.items,
    required this.onReorder,
    this.padding,
    this.spacing = 8.0,
    this.enableHapticFeedback = true,
    this.animationDuration = const Duration(milliseconds: 300),
    this.animationCurve = Curves.easeInOut,
    this.dragColor,
    this.dragElevation,
  });

  @override
  State<DragAndDropList<T>> createState() => _DragAndDropListState<T>();
}

class _DragAndDropListState<T> extends State<DragAndDropList<T>> {
  @override
  Widget build(BuildContext context) {
    final responsivePadding = widget.padding ??
        ResponsiveHelper.getResponsivePadding(context, all: 8);
    final responsiveSpacing = ResponsiveHelper.getResponsiveHeight(context, widget.spacing);

    return ReorderableListView(
      padding: responsivePadding,
      onReorder: (oldIndex, newIndex) {
        if (widget.enableHapticFeedback) {
          HapticFeedback.mediumImpact();
        }
        widget.onReorder(oldIndex, newIndex);
      },
      proxyDecorator: (child, index, animation) {
        return Material(
          elevation: widget.dragElevation ?? 8,
          color: widget.dragColor ?? Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(
            ResponsiveHelper.getResponsiveRadius(context, 12),
          ),
          child: ScaleTransitionWidget(
            beginScale: 1.0,
            endScale: 1.05,
            duration: widget.animationDuration,
            child: child,
          ),
        );
      },
      children: widget.items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        
        return FadeSlideTransition(
          key: ValueKey(item.id ?? index),
          slideDirection: SlideDirection.fromBottom,
          duration: widget.animationDuration,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: index < widget.items.length - 1 ? responsiveSpacing : 0,
            ),
            child: item.child,
          ),
        );
      }).toList(),
    );
  }
}
