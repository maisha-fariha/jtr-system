import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Represents a single table order row in the dashboard table.
class TableOrder {
  const TableOrder({
    required this.tableNumber,
    required this.guests,
    required this.post,
    required this.serviceType,
    required this.covers,
    required this.imprimes,
    required this.total,
    this.isActive = true,
  });

  /// Table identifier, e.g. "T5" or "T6"
  final String tableNumber;

  /// Number of guests
  final int guests;

  /// Post / position (e.g. "POC1")
  final String post;

  /// Service type (e.g. "SUR PLACE")
  final String serviceType;

  /// Cover count
  final int covers;

  /// Printed / imprimé count
  final int imprimes;

  /// Total amount in EUR
  final double total;

  /// Whether this table is currently active (occupied)
  final bool isActive;

  /// Returns the display color for the table number label.
  /// Active tables are salmon (primary), inactive are info blue.
  Color get tableColor =>
      isActive ? AppColors.primary : AppColors.info;

  /// Returns badge color based on imprimes value.
  Color get imprimeBadgeColor =>
      imprimes == 0 ? AppColors.error : AppColors.warning;

  Color get imprimeBadgeBorderColor =>
      imprimes == 0 ? AppColors.errorBorder : AppColors.warningBorder;

  /// Badge text colour for contrast.
  Color get imprimeBadgeTextColor =>
      imprimes == 0 ? AppColors.textPrimary : AppColors.background;

  String get formattedTotal =>
      '${total.toStringAsFixed(2).replaceAll('.', ',')} €';
}
