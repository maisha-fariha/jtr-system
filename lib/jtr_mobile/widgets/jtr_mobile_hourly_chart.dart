import 'package:flutter/material.dart';

import '../../utils/responsive.dart';
import '../models/dashboard_models.dart';
import '../theme/jtr_mobile_theme.dart';
import '../utils/jtr_mobile_formatters.dart';
import 'jtr_mobile_shared_widgets.dart';

class JtrMobileHourlyChart extends StatefulWidget {
  const JtrMobileHourlyChart({
    super.key,
    required this.bars,
    required this.peakCaption,
  });

  final List<JtrHourlyBar> bars;
  final String peakCaption;

  @override
  State<JtrMobileHourlyChart> createState() => _JtrMobileHourlyChartState();
}

class _JtrMobileHourlyChartState extends State<JtrMobileHourlyChart> {
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _defaultSelectedIndex(widget.bars);
  }

  @override
  void didUpdateWidget(covariant JtrMobileHourlyChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bars != widget.bars) {
      final stillValid = _selectedIndex != null &&
          _selectedIndex! >= 0 &&
          _selectedIndex! < widget.bars.length;
      if (!stillValid) {
        _selectedIndex = _defaultSelectedIndex(widget.bars);
      }
    }
  }

  int? _defaultSelectedIndex(List<JtrHourlyBar> bars) {
    if (bars.isEmpty) return null;
    final peak = bars.indexWhere((b) => b.isPeak);
    if (peak >= 0) return peak;
    var best = 0;
    for (var i = 1; i < bars.length; i++) {
      if (bars[i].amount > bars[best].amount) best = i;
    }
    return best;
  }

  String _captionFor(JtrHourlyBar bar, {required bool isPeakDefault}) {
    final amount = JtrMobileFormatters.currency(bar.amount);
    if (isPeakDefault && bar.isPeak) {
      // Keep server peak wording when the peak bar is selected.
      if (widget.peakCaption.trim().isNotEmpty) return widget.peakCaption;
    }
    return '${bar.hourLabel} · $amount';
  }

  @override
  Widget build(BuildContext context) {
    final bars = widget.bars;
    final maxAmount =
        bars.fold<double>(0, (m, b) => b.amount > m ? b.amount : m);
    final chartHeight = JtrResponsive.getResponsiveHeight(context, 80);
    final selected = _selectedIndex != null &&
            _selectedIndex! >= 0 &&
            _selectedIndex! < bars.length
        ? bars[_selectedIndex!]
        : null;

    return JtrMobileCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          SizedBox(
            height: chartHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < bars.length; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal:
                            JtrResponsive.getResponsiveWidth(context, 2),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => setState(() => _selectedIndex = i),
                          borderRadius: BorderRadius.circular(4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Full column is tappable, including short bars.
                              const Expanded(child: SizedBox.expand()),
                              Builder(
                                builder: (context) {
                                  final h = maxAmount > 0
                                      ? (bars[i].amount / maxAmount) *
                                          chartHeight
                                      : 0.0;
                                  return Container(
                                    height: h < 1 ? 1.0 : h,
                                    decoration: BoxDecoration(
                                      color: i == _selectedIndex
                                          ? JtrMobileTheme.accent
                                          : JtrMobileTheme.barDefault,
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(
                                          JtrResponsive.getResponsiveRadius(
                                            context,
                                            2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: JtrResponsive.getResponsiveHeight(context, 6)),
          Row(
            children: [
              for (var i = 0; i < bars.length; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedIndex = i),
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      bars[i].hourLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize:
                            JtrResponsive.getResponsiveFontSize(context, 9),
                        color: i == _selectedIndex
                            ? JtrMobileTheme.accent
                            : JtrMobileTheme.textMuted,
                        fontWeight: i == _selectedIndex
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: JtrResponsive.getResponsiveHeight(context, 10)),
          Text(
            selected == null
                ? widget.peakCaption
                : _captionFor(
                    selected,
                    isPeakDefault: selected.isPeak,
                  ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: JtrResponsive.getResponsiveFontSize(context, 11),
              color: JtrMobileTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
