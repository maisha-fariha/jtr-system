import 'package:flutter/material.dart';
import '../responsive_helper.dart';

/// Chart Data Point
class ChartDataPoint {
  final String label;
  final double value;
  final Color? color;

  const ChartDataPoint({
    required this.label,
    required this.value,
    this.color,
  });
}

/// Responsive Chart Container - Wrapper for charts with responsive sizing
class ResponsiveChartContainer extends StatelessWidget {
  final Widget chart;
  final String? title;
  final String? subtitle;
  final Widget? legend;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final double? borderRadius;
  final double? elevation;

  const ResponsiveChartContainer({
    super.key,
    required this.chart,
    this.title,
    this.subtitle,
    this.legend,
    this.padding,
    this.backgroundColor,
    this.borderRadius,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    final responsivePadding = padding ??
        ResponsiveHelper.getResponsivePadding(context, all: 16);
    final responsiveRadius = borderRadius ??
        ResponsiveHelper.getResponsiveRadius(context, 12);
    final chartHeight = ResponsiveHelper.getResponsiveHeight(
      context,
      ResponsiveHelper.isSmallDevice(context) ? 200 : 300,
    );

    return Card(
      color: backgroundColor,
      elevation: elevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(responsiveRadius),
      ),
      child: Padding(
        padding: responsivePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Padding(
                padding: ResponsiveHelper.getResponsiveMargin(
                  context,
                  bottom: 8,
                ),
                child: Text(
                  title!,
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, 18),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (subtitle != null)
              Padding(
                padding: ResponsiveHelper.getResponsiveMargin(
                  context,
                  bottom: 16,
                ),
                child: Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            SizedBox(
              height: chartHeight,
              child: chart,
            ),
            if (legend != null)
              Padding(
                padding: ResponsiveHelper.getResponsiveMargin(
                  context,
                  top: 16,
                ),
                child: legend!,
              ),
          ],
        ),
      ),
    );
  }
}

/// Responsive Legend - Adaptive legend for charts
class ResponsiveLegend extends StatelessWidget {
  final List<ChartDataPoint> dataPoints;
  final bool horizontal;
  final int? maxItemsPerRow;
  final double spacing;

  const ResponsiveLegend({
    super.key,
    required this.dataPoints,
    this.horizontal = true,
    this.maxItemsPerRow,
    this.spacing = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final responsiveSpacing = ResponsiveHelper.getResponsiveWidth(context, spacing);

    if (horizontal) {
      return Wrap(
        spacing: responsiveSpacing,
        runSpacing: responsiveSpacing,
        children: dataPoints.map((point) {
          return _LegendItem(
            label: point.label,
            color: point.color ?? Theme.of(context).colorScheme.primary,
          );
        }).toList(),
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: dataPoints.map((point) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: ResponsiveHelper.getResponsiveHeight(context, 8),
            ),
            child: _LegendItem(
              label: point.label,
              color: point.color ?? Theme.of(context).colorScheme.primary,
            ),
          );
        }).toList(),
      );
    }
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendItem({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: ResponsiveHelper.getResponsiveSize(context, 12),
          height: ResponsiveHelper.getResponsiveSize(context, 12),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: ResponsiveHelper.getResponsiveWidth(context, 8)),
        Text(
          label,
          style: TextStyle(
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
          ),
        ),
      ],
    );
  }
}
