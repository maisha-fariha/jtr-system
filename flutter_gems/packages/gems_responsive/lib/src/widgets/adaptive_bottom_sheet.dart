import 'package:flutter/material.dart';
import '../responsive_helper.dart';
import 'transitions.dart';

/// Adaptive Bottom Sheet - Smart bottom sheets with auto height calculation
class AdaptiveBottomSheet {
  /// Show adaptive bottom sheet
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    List<Widget>? actions,
    bool isDismissible = true,
    bool enableDrag = true,
    bool isScrollControlled = true,
    Color? backgroundColor,
    double? maxHeight,
    double? minHeight,
    bool fullScreen = false,
    Duration transitionDuration = const Duration(milliseconds: 300),
    Curve transitionCurve = Curves.easeOut,
  }) {
    final screenHeight = ResponsiveHelper.getScreenHeight(context);
    final isSmall = ResponsiveHelper.isSmallDevice(context);
    
    // Calculate max height
    final calculatedMaxHeight = maxHeight ??
        (fullScreen
            ? screenHeight
            : (isSmall ? screenHeight * 0.9 : screenHeight * 0.7));

    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: isScrollControlled,
      backgroundColor: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(
            ResponsiveHelper.getResponsiveRadius(context, 20),
          ),
        ),
      ),
      builder: (context) => ScaleTransitionWidget(
        beginScale: 0.95,
        endScale: 1.0,
        duration: transitionDuration,
        curve: transitionCurve,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: calculatedMaxHeight,
            minHeight: minHeight ?? ResponsiveHelper.getResponsiveHeight(context, 200),
          ),
          child: _AdaptiveBottomSheetContent(
            title: title,
            actions: actions,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _AdaptiveBottomSheetContent extends StatelessWidget {
  final String? title;
  final List<Widget>? actions;
  final Widget child;

  const _AdaptiveBottomSheetContent({
    this.title,
    this.actions,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: ResponsiveHelper.getResponsiveMargin(context, vertical: 8),
            width: ResponsiveHelper.getResponsiveWidth(context, 40),
            height: ResponsiveHelper.getResponsiveHeight(context, 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(
                ResponsiveHelper.getResponsiveRadius(context, 2),
              ),
            ),
          ),
          // Title
          if (title != null)
            Padding(
              padding: ResponsiveHelper.getResponsivePadding(
                context,
                horizontal: 20,
                vertical: 12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 20),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (actions != null && actions!.isNotEmpty)
                    ...actions!,
                ],
              ),
            ),
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: ResponsiveHelper.getResponsivePadding(context, all: 20),
              child: FadeTransitionWidget(
                duration: const Duration(milliseconds: 400),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
