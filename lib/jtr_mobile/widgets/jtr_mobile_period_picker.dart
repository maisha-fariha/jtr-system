import 'package:flutter/material.dart';

import '../../utils/responsive.dart';
import '../theme/jtr_mobile_theme.dart';
import '../utils/jtr_mobile_formatters.dart';
import 'jtr_mobile_shared_widgets.dart';

class JtrMobilePeriodPicker extends StatelessWidget {
  const JtrMobilePeriodPicker({
    super.key,
    required this.expanded,
    required this.from,
    required this.to,
    required this.onToggle,
    required this.onApply,
  });

  final bool expanded;
  final DateTime from;
  final DateTime to;
  final VoidCallback onToggle;
  final void Function(DateTime from, DateTime to) onApply;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(
              JtrResponsive.getResponsiveRadius(context, 8),
            ),
            child: Ink(
              padding: JtrResponsive.getResponsivePadding(
                context,
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: JtrMobileTheme.surfaceCard,
                borderRadius: BorderRadius.circular(
                  JtrResponsive.getResponsiveRadius(context, 8),
                ),
                border: Border.all(
                  color: JtrMobileTheme.borderStrong,
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    size: JtrResponsive.getResponsiveSize(context, 15),
                    color: JtrMobileTheme.textSecondary,
                  ),
                  SizedBox(width: JtrResponsive.getResponsiveWidth(context, 8)),
                  Expanded(
                    child: Text(
                      JtrMobileFormatters.isoDateRange(from, to),
                      style: TextStyle(
                        fontSize:
                            JtrResponsive.getResponsiveFontSize(context, 13),
                        fontWeight: FontWeight.w600,
                        color: JtrMobileTheme.textPrimary,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: JtrMobileTheme.textSecondary,
                      size: JtrResponsive.getResponsiveSize(context, 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded) ...[
          SizedBox(height: JtrResponsive.getResponsiveHeight(context, 8)),
          Container(
            padding: JtrResponsive.getResponsivePadding(
              context,
              horizontal: 16,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: JtrMobileTheme.surfaceCard,
              borderRadius: BorderRadius.circular(
                JtrResponsive.getResponsiveRadius(context, 12),
              ),
              border: Border.all(color: JtrMobileTheme.border, width: 0.5),
            ),
            child: _PeriodForm(
              from: from,
              to: to,
              onApply: onApply,
            ),
          ),
        ],
      ],
    );
  }
}

class _PeriodForm extends StatefulWidget {
  const _PeriodForm({
    required this.from,
    required this.to,
    required this.onApply,
  });

  final DateTime from;
  final DateTime to;
  final void Function(DateTime from, DateTime to) onApply;

  @override
  State<_PeriodForm> createState() => _PeriodFormState();
}

class _PeriodFormState extends State<_PeriodForm> {
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    _from = widget.from;
    _to = widget.to;
  }

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) onPicked(picked);
  }

  String _format(DateTime d) => JtrMobileFormatters.isoDate(d);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DateField(
          label: 'Du',
          value: _format(_from),
          onTap: () => _pickDate(
            initial: _from,
            onPicked: (d) => setState(() => _from = d),
          ),
        ),
        SizedBox(height: JtrResponsive.getResponsiveHeight(context, 10)),
        _DateField(
          label: 'Au',
          value: _format(_to),
          onTap: () => _pickDate(
            initial: _to,
            onPicked: (d) => setState(() => _to = d),
          ),
        ),
        SizedBox(height: JtrResponsive.getResponsiveHeight(context, 10)),
        JtrMobileDetailButton(
          label: 'Appliquer',
          onTap: () => widget.onApply(_from, _to),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: JtrResponsive.getResponsiveFontSize(context, 12),
            color: JtrMobileTheme.textSecondary,
          ),
        ),
        SizedBox(height: JtrResponsive.getResponsiveHeight(context, 4)),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(
              JtrResponsive.getResponsiveRadius(context, 8),
            ),
            child: Ink(
              width: double.infinity,
              padding: JtrResponsive.getResponsivePadding(
                context,
                horizontal: 8,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: JtrMobileTheme.surfaceTile,
                borderRadius: BorderRadius.circular(
                  JtrResponsive.getResponsiveRadius(context, 8),
                ),
                border: Border.all(
                  color: JtrMobileTheme.borderStrong,
                  width: 0.5,
                ),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: JtrResponsive.getResponsiveFontSize(context, 13),
                  color: JtrMobileTheme.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
