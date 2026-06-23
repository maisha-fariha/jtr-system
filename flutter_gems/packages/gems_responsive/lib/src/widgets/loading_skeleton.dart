import 'package:flutter/material.dart';
import '../responsive_helper.dart';
import 'shimmer_loading.dart';

/// Loading Skeleton - Pre-built skeleton screens for common UI patterns
class LoadingSkeleton {
  /// Article layout skeleton
  static Widget article(BuildContext context) {
    return Padding(
      padding: ResponsiveHelper.getResponsivePadding(context, all: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          ShimmerContainer(
            width: double.infinity,
            height: ResponsiveHelper.getResponsiveHeight(context, 24),
            borderRadius: ResponsiveHelper.getResponsiveRadius(context, 4),
          ),
          ResponsiveHelper.getResponsiveSpacing(context, 12),
          // Subtitle
          ShimmerContainer(
            width: ResponsiveHelper.getResponsiveWidth(context, 200),
            height: ResponsiveHelper.getResponsiveHeight(context, 16),
            borderRadius: ResponsiveHelper.getResponsiveRadius(context, 4),
          ),
          ResponsiveHelper.getResponsiveSpacing(context, 16),
          // Image
          ShimmerContainer(
            width: double.infinity,
            height: ResponsiveHelper.getResponsiveHeight(context, 200),
            borderRadius: ResponsiveHelper.getResponsiveRadius(context, 8),
          ),
          ResponsiveHelper.getResponsiveSpacing(context, 16),
          // Content lines
          ...List.generate(5, (index) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: ResponsiveHelper.getResponsiveHeight(context, 8),
              ),
              child: ShimmerContainer(
                width: index == 4
                    ? ResponsiveHelper.getResponsiveWidth(context, 150)
                    : double.infinity,
                height: ResponsiveHelper.getResponsiveHeight(context, 12),
                borderRadius: ResponsiveHelper.getResponsiveRadius(context, 4),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Card layout skeleton
  static Widget card(BuildContext context) {
    return Card(
      margin: ResponsiveHelper.getResponsiveMargin(context, all: 8),
      child: Padding(
        padding: ResponsiveHelper.getResponsivePadding(context, all: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ShimmerContainer(
              width: double.infinity,
              height: ResponsiveHelper.getResponsiveHeight(context, 150),
              borderRadius: ResponsiveHelper.getResponsiveRadius(context, 8),
            ),
            ResponsiveHelper.getResponsiveSpacing(context, 12),
            // Title
            ShimmerContainer(
              width: double.infinity,
              height: ResponsiveHelper.getResponsiveHeight(context, 20),
              borderRadius: ResponsiveHelper.getResponsiveRadius(context, 4),
            ),
            ResponsiveHelper.getResponsiveSpacing(context, 8),
            // Subtitle
            ShimmerContainer(
              width: ResponsiveHelper.getResponsiveWidth(context, 120),
              height: ResponsiveHelper.getResponsiveHeight(context, 16),
              borderRadius: ResponsiveHelper.getResponsiveRadius(context, 4),
            ),
          ],
        ),
      ),
    );
  }

  /// Profile layout skeleton
  static Widget profile(BuildContext context) {
    return Padding(
      padding: ResponsiveHelper.getResponsivePadding(context, all: 16),
      child: Row(
        children: [
          // Avatar
          ShimmerContainer(
            width: ResponsiveHelper.getResponsiveSize(context, 64),
            height: ResponsiveHelper.getResponsiveSize(context, 64),
            borderRadius: ResponsiveHelper.getResponsiveRadius(context, 32),
          ),
          SizedBox(width: ResponsiveHelper.getResponsiveWidth(context, 16)),
          // Name and details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerContainer(
                  width: ResponsiveHelper.getResponsiveWidth(context, 150),
                  height: ResponsiveHelper.getResponsiveHeight(context, 20),
                  borderRadius: ResponsiveHelper.getResponsiveRadius(context, 4),
                ),
                ResponsiveHelper.getResponsiveSpacing(context, 8),
                ShimmerContainer(
                  width: ResponsiveHelper.getResponsiveWidth(context, 100),
                  height: ResponsiveHelper.getResponsiveHeight(context, 16),
                  borderRadius: ResponsiveHelper.getResponsiveRadius(context, 4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// List layout skeleton
  static Widget list(BuildContext context, {int itemCount = 3}) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => ShimmerListItem(
          hasAvatar: true,
          hasSubtitle: true,
          lines: 2,
        ),
      ),
    );
  }

  /// Grid layout skeleton
  static Widget grid(BuildContext context, {int columns = 2, int rows = 2}) {
    return Column(
      children: List.generate(rows, (rowIndex) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: ResponsiveHelper.getResponsiveHeight(context, 8),
          ),
          child: Row(
            children: List.generate(columns, (colIndex) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: colIndex < columns - 1
                        ? ResponsiveHelper.getResponsiveWidth(context, 8)
                        : 0,
                  ),
                  child: ShimmerContainer(
                    height: ResponsiveHelper.getResponsiveHeight(context, 150),
                    borderRadius: ResponsiveHelper.getResponsiveRadius(context, 8),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}
