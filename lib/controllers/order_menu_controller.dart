import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/demo_menu.dart';
import '../data/demo_preset_menus.dart';
import '../models/menu_active_selection.dart';
import '../models/menu_category.dart';
import '../models/menu_item.dart';
import '../models/preset_menu.dart';
import 'session_controller.dart';

class OrderMenuController extends GetxController {
  final currentTable = ''.obs;
  final _selected = RxMap<String, bool>();

  bool returnToSelection = false;
  PresetMenu? presetMenu;
  int choiceNumber = 1;

  List<MenuCategory> get visibleCategories =>
      presetMenu?.categories ?? demoMenuCategories;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is! Map) return;

    currentTable.value = (args['table'] as String?) ?? '';
    returnToSelection = args['returnToSelection'] == true;
    choiceNumber = (args['choiceNumber'] as int?) ?? 1;

    final presetMenuNumber = args['presetMenu'] as int?;
    if (presetMenuNumber != null) {
      presetMenu = demoPresetMenus.firstWhere(
        (menu) => menu.number == presetMenuNumber,
        orElse: () => demoPresetMenus.first,
      );
    }

    final initialSelections = args['initialSelections'];
    if (initialSelections is Map) {
      for (final entry in initialSelections.entries) {
        final item = entry.value;
        if (item is MenuItem) {
          _selected[_key(item)] = true;
        }
      }
    }
  }

  String _key(MenuItem item) => '${item.courseNumber}_${item.name}';

  bool isSelected(MenuItem item) => _selected[_key(item)] == true;

  void toggleItem(MenuItem item) {
    final k = _key(item);
    _selected[k] = !(_selected[k] ?? false);
  }

  int get selectedCount => _selected.values.where((v) => v).length;

  List<MenuItem> get selectedItems {
    final result = <MenuItem>[];
    for (final category in visibleCategories) {
      for (final item in category.items) {
        if (isSelected(item)) result.add(item);
      }
    }
    return result;
  }

  double get selectedTotal =>
      selectedItems.fold(0, (sum, item) => sum + item.priceValue);

  Map<int, MenuItem> _selectedItemsByCourse() {
    final map = <int, MenuItem>{};
    for (final item in selectedItems) {
      map[item.courseNumber] = item;
    }
    return map;
  }

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

    if (returnToSelection && presetMenu != null) {
      Get.back(
        result: MenuActiveSelection(
          menu: presetMenu!,
          choiceNumber: choiceNumber,
          selectedItemsByCourse: _selectedItemsByCourse(),
        ),
      );
      return;
    }

    final session = Get.find<SessionController>();
    session.addProductsToOrder(currentTable.value, selectedItems);
    Get.back();
  }

  static Color courseColor(int courseNumber) {
    return demoMenuCategories
        .firstWhere(
          (c) => c.number == courseNumber,
          orElse: () => demoMenuCategories.first,
        )
        .color;
  }
}
