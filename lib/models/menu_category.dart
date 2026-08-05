import 'package:flutter/material.dart';

import 'menu_item.dart';

class MenuCategory {
  const MenuCategory({
    required this.number,
    required this.label,
    required this.items,
    required this.color,
    this.isRequired = true,
    this.minSelections = 1,
    this.maxSelections = 1,
  });

  final int number;
  final String label;
  final List<MenuItem> items;
  final Color color;

  /// From product `menu_categories[].is_required` (per composed product).
  final bool isRequired;

  /// From product `menu_categories[].min_selections`.
  final int minSelections;

  /// From product `menu_categories[].max_selections`.
  /// Values `<= 0` mean unlimited.
  final int maxSelections;

  /// Minimum picks required for this CHOIX on this product.
  int get effectiveMin {
    if (items.isEmpty) return 0;
    if (!isRequired && minSelections <= 0) return 0;
    final min = minSelections > 0 ? minSelections : (isRequired ? 1 : 0);
    return min.clamp(0, items.length);
  }

  /// Maximum picks allowed; `null` means unlimited.
  int? get effectiveMax {
    if (items.isEmpty) return 0;
    if (maxSelections <= 0) return null;
    final max = maxSelections.clamp(1, items.length);
    final min = effectiveMin;
    return max < min ? min : max;
  }

  bool allowsSelectionCount(int count) {
    if (count < effectiveMin) return false;
    final max = effectiveMax;
    if (max != null && count > max) return false;
    return true;
  }
}
