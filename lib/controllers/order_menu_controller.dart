import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/demo_menu.dart';
import '../models/menu_item.dart';
import 'session_controller.dart';

class OrderMenuController extends GetxController {
  final currentTable = ''.obs;
  // key = "${courseNumber}_${itemName}"  — RxMap notifies on every []=
  final _selected = RxMap<String, bool>();

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is Map) {
      currentTable.value = (args['table'] as String?) ?? '';
    }
  }

  String _key(MenuItem item) => '${item.courseNumber}_${item.name}';

  bool isSelected(MenuItem item) => _selected[_key(item)] == true;

  void toggleItem(MenuItem item) {
    final k = _key(item);
    _selected[k] = !(_selected[k] ?? false);
  }

  int get selectedCount =>
      _selected.values.where((v) => v).length;

  List<MenuItem> get selectedItems {
    final result = <MenuItem>[];
    for (final category in demoMenuCategories) {
      for (final item in category.items) {
        if (isSelected(item)) result.add(item);
      }
    }
    return result;
  }

  double get selectedTotal =>
      selectedItems.fold(0, (sum, item) => sum + item.priceValue);

  void confirmOrder() {
    if (selectedCount == 0) {
      Get.snackbar(
        'Sélection vide',
        'Veuillez sélectionner au moins un article.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      );
      return;
    }

    final session = Get.find<SessionController>();
    session.addProductsToOrder(currentTable.value, selectedItems);
    Get.back();
  }

  // Returns the accent color for a course number.
  static Color courseColor(int courseNumber) {
    return demoMenuCategories
        .firstWhere(
          (c) => c.number == courseNumber,
          orElse: () => demoMenuCategories.first,
        )
        .color;
  }
}
