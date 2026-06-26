import 'package:flutter/material.dart';

import 'menu_item.dart';

class MenuCategory {
  const MenuCategory({
    required this.number,
    required this.label,
    required this.items,
    required this.color,
  });

  final int number;
  final String label;
  final List<MenuItem> items;
  final Color color;
}
