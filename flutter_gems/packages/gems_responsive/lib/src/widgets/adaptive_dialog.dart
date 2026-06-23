import 'package:flutter/material.dart';
import '../responsive_helper.dart';
import 'transitions.dart';

/// Adaptive Dialog - Shows as dialog on tablet/desktop, bottom sheet on phone
class AdaptiveDialog {
  /// Show adaptive dialog/sheet
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    List<Widget>? actions,
    bool barrierDismissible = true,
    Color? backgroundColor,
    double? maxWidth,
    double? maxHeight,
    bool fullScreen = false,
    Duration transitionDuration = const Duration(milliseconds: 300),
  }) {
    final isSmallDevice = ResponsiveHelper.isSmallDevice(context);
    
    if (isSmallDevice && !fullScreen) {
      // Show as bottom sheet on small devices
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        backgroundColor: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
        barrierColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ResponsiveHelper.getResponsiveRadius(context, 20)),
          ),
        ),
        builder: (context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: _AdaptiveDialogContent(
            title: title,
            actions: actions,
            child: child,
            maxHeight: maxHeight,
          ),
        ),
      );
    } else {
      // Show as dialog on larger devices
      return showDialog<T>(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: (context) => ScaleTransitionWidget(
          beginScale: 0.8,
          endScale: 1.0,
          duration: transitionDuration,
          child: AlertDialog(
            backgroundColor: backgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveHelper.getResponsiveRadius(context, 16),
              ),
            ),
            title: title != null
                ? FadeTransitionWidget(
                    child: Text(title),
                  )
                : null,
            content: FadeTransitionWidget(
              duration: const Duration(milliseconds: 400),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxWidth ?? ResponsiveHelper.getResponsiveWidth(context, 400),
                  maxHeight: maxHeight ?? ResponsiveHelper.getScreenHeight(context) * 0.7,
                ),
                child: child,
              ),
            ),
            actions: actions,
          ),
        ),
      );
    }
  }
}

class _AdaptiveDialogContent extends StatelessWidget {
  final String? title;
  final List<Widget>? actions;
  final Widget child;
  final double? maxHeight;

  const _AdaptiveDialogContent({
    this.title,
    this.actions,
    required this.child,
    this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = ResponsiveHelper.getScreenHeight(context);
    final maxContentHeight = maxHeight ?? screenHeight * 0.7;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxContentHeight,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Padding(
              padding: ResponsiveHelper.getResponsivePadding(
                context,
                horizontal: 20,
                vertical: 16,
              ),
              child: Text(
                title!,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          Flexible(
            child: SingleChildScrollView(
              padding: ResponsiveHelper.getResponsivePadding(context, all: 20),
              child: child,
            ),
          ),
          if (actions != null && actions!.isNotEmpty)
            Padding(
              padding: ResponsiveHelper.getResponsivePadding(
                context,
                horizontal: 20,
                vertical: 12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions!,
              ),
            ),
        ],
      ),
    );
  }
}
