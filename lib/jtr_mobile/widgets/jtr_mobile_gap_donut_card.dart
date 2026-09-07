import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/responsive.dart';
import '../models/dashboard_models.dart';
import '../theme/jtr_mobile_theme.dart';
import '../utils/jtr_mobile_formatters.dart';
import 'jtr_mobile_shared_widgets.dart';

class JtrMobileGapDonutCard extends StatelessWidget {
  const JtrMobileGapDonutCard({
    super.key,
    required this.segments,
    required this.total,
    required this.onDetailTap,
  });

  final List<JtrGapSegment> segments;
  final double total;
  final VoidCallback onDetailTap;

  @override
  Widget build(BuildContext context) {
    final donutSize = JtrResponsive.getResponsiveSize(context, 108);
    const stroke = 12.0;
    final holeSize = donutSize - stroke * 2.4;

    return JtrMobileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Répartition de l'écart",
            style: TextStyle(
              fontSize: JtrResponsive.getResponsiveFontSize(context, 13),
              fontWeight: FontWeight.w600,
              color: JtrMobileTheme.textPrimary,
            ),
          ),
          SizedBox(height: JtrResponsive.getResponsiveHeight(context, 12)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: donutSize,
                height: donutSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: Size.square(donutSize),
                      painter: _DonutPainter(segments: segments, stroke: stroke),
                    ),
                    Container(
                      width: holeSize,
                      height: holeSize,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: JtrMobileTheme.surfaceCard,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: JtrResponsive.getResponsiveWidth(context, 4),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              JtrMobileFormatters.currency(total, compact: true)
                                  .replaceAll(' DH', ''),
                              style: TextStyle(
                                fontSize: JtrResponsive.getResponsiveFontSize(
                                  context,
                                  13,
                                ),
                                fontWeight: FontWeight.w600,
                                color: JtrMobileTheme.textPrimary,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              'non encaissé',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: JtrResponsive.getResponsiveFontSize(
                                  context,
                                  8.5,
                                ),
                                color: JtrMobileTheme.textMuted,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: JtrResponsive.getResponsiveWidth(context, 16)),
              Expanded(
                child: Column(
                  children: segments
                      .map(
                        (s) => Padding(
                          padding: EdgeInsets.only(
                            bottom: JtrResponsive.getResponsiveHeight(context, 8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      width: JtrResponsive.getResponsiveSize(
                                        context,
                                        8,
                                      ),
                                      height: JtrResponsive.getResponsiveSize(
                                        context,
                                        8,
                                      ),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: s.color,
                                      ),
                                    ),
                                    SizedBox(
                                      width:
                                          JtrResponsive.getResponsiveWidth(
                                        context,
                                        6,
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        s.label,
                                        style: TextStyle(
                                          fontSize: JtrResponsive
                                              .getResponsiveFontSize(
                                            context,
                                            12,
                                          ),
                                          color: JtrMobileTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                JtrMobileFormatters.currency(s.amount),
                                style: TextStyle(
                                  fontSize: JtrResponsive.getResponsiveFontSize(
                                    context,
                                    12,
                                  ),
                                  color: JtrMobileTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
          SizedBox(height: JtrResponsive.getResponsiveHeight(context, 4)),
          JtrMobileDetailButton(
            label: 'Voir le détail par catégorie',
            onTap: onDetailTap,
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.segments, required this.stroke});

  final List<JtrGapSegment> segments;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<double>(0, (s, e) => s + e.amount);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    var start = -math.pi / 2;

    for (final segment in segments) {
      final sweep = (segment.amount / total) * 2 * math.pi;
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - stroke / 2),
        start,
        sweep,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.segments != segments || oldDelegate.stroke != stroke;
}
