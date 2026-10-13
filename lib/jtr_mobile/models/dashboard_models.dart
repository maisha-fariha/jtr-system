import 'package:flutter/material.dart';

class JtrDashboardKpis {
  const JtrDashboardKpis({
    required this.revenue,
    required this.collected,
    required this.trendLabel,
    required this.trendPositive,
  });

  final double revenue;
  final double collected;
  final String trendLabel;
  final bool trendPositive;

  double get collectedPercentOfRevenue =>
      revenue > 0 ? (collected / revenue) * 100 : 0;
}

class JtrPaymentBreakdownItem {
  const JtrPaymentBreakdownItem({
    required this.label,
    required this.amount,
    required this.percent,
  });

  final String label;
  final double amount;
  final double percent;
}

class JtrGapSegment {
  const JtrGapSegment({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final double amount;
  final Color color;
}

class JtrCategoryRevenue {
  const JtrCategoryRevenue({
    required this.name,
    required this.amount,
    required this.percent,
    required this.color,
  });

  final String name;
  final double amount;
  final double percent;
  final Color color;
}

class JtrZoneRevenue {
  const JtrZoneRevenue({
    required this.name,
    required this.amount,
    required this.percent,
    required this.color,
  });

  final String name;
  final double amount;
  final double percent;
  final Color color;
}

class JtrActivityStats {
  const JtrActivityStats({
    required this.tickets,
    required this.avgTicket,
    required this.covers,
    required this.avgCover,
  });

  final int tickets;
  final double avgTicket;
  final int covers;
  final double avgCover;
}

class JtrMovementRow {
  const JtrMovementRow({
    required this.label,
    required this.value,
    required this.subValue,
    required this.color,
    this.highlightDanger = false,
  });

  final String label;
  final String value;
  final String? subValue;
  final Color color;
  final bool highlightDanger;
}

class JtrHourlyBar {
  const JtrHourlyBar({
    required this.hourLabel,
    required this.amount,
    required this.isPeak,
  });

  final String hourLabel;
  final double amount;
  final bool isPeak;
}

class JtrDashboardData {
  const JtrDashboardData({
    required this.storeName,
    required this.dateLabel,
    required this.periodLabel,
    required this.kpis,
    required this.payments,
    required this.gapSegments,
    required this.gapTotal,
    required this.categories,
    required this.zones,
    required this.activity,
    required this.movements,
    required this.hourlyBars,
    required this.peakCaption,
    required this.periodFrom,
    required this.periodTo,
  });

  final String storeName;
  final String dateLabel;
  final String periodLabel;
  final JtrDashboardKpis kpis;
  final List<JtrPaymentBreakdownItem> payments;
  final List<JtrGapSegment> gapSegments;
  final double gapTotal;
  final List<JtrCategoryRevenue> categories;
  final List<JtrZoneRevenue> zones;
  final JtrActivityStats activity;
  final List<JtrMovementRow> movements;
  final List<JtrHourlyBar> hourlyBars;
  final String peakCaption;
  final DateTime periodFrom;
  final DateTime periodTo;
}
