import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/menu_active_selection.dart';
import '../models/menu_category.dart';
import '../models/menu_item.dart';
import '../models/preset_menu.dart';

class OrderMenuController extends GetxController {
  final currentTable = ''.obs;
  final _selected = RxMap<String, bool>();
  final collapsedCategories = <int>{}.obs;

  bool returnToSelection = false;
  PresetMenu? presetMenu;
  int choiceNumber = 1;

  List<MenuCategory> get visibleCategories =>
      presetMenu?.categories ?? const [];

  bool isCategoryExpanded(int courseNumber) =>
      !collapsedCategories.contains(courseNumber);

  void toggleCategoryExpanded(int courseNumber) {
    if (collapsedCategories.contains(courseNumber)) {
      collapsedCategories.remove(courseNumber);
    } else {
      collapsedCategories.add(courseNumber);
    }
    collapsedCategories.refresh();
  }

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is! Map) return;

    // GetX can reuse the controller instance across route opens.
    _selected.clear();
    collapsedCategories.clear();

    currentTable.value = (args['table'] as String?) ?? '';
    returnToSelection = args['returnToSelection'] == true;
    choiceNumber = (args['choiceNumber'] as int?) ?? 1;

    final menuArg = args['presetMenu'];
    if (menuArg is PresetMenu) {
      presetMenu = menuArg;
    }

    final initialSelections = args['initialSelections'];
    if (initialSelections is Map) {
      for (final entry in initialSelections.entries) {
        final value = entry.value;
        if (value is MenuItem) {
          _selected[_key(value)] = true;
          continue;
        }
        if (value is List) {
          for (final v in value) {
            if (v is MenuItem) _selected[_key(v)] = true;
          }
        }
      }
    }

    final focusCourse = args['focusCourse'];
    if (focusCourse is int && focusCourse > 0) {
      for (final category in visibleCategories) {
        if (category.number != focusCourse) {
          collapsedCategories.add(category.number);
        }
      }
      collapsedCategories.refresh();
    }
  }

  String _key(MenuItem item) => '${item.courseNumber}_${item.name}';

  bool isSelected(MenuItem item) => _selected[_key(item)] == true;

  void toggleItem(MenuItem item) {
    final key = _key(item);
    final isOn = _selected[key] == true;

    if (isOn) {
      _selected.remove(key);
      return;
    }

    final maxAllowed = choiceNumber < 1 ? 1 : choiceNumber;
    final currentlySelectedInCourse = selectedItems
        .where((e) => e.courseNumber == item.courseNumber)
        .length;

    if (currentlySelectedInCourse >= maxAllowed) {
      Get.snackbar(
        'Limite atteinte',
        'Vous pouvez sélectionner au maximum $maxAllowed article(s) pour ce choix.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      );
      return;
    }

    _selected[key] = true;
  }

  int get selectedCount => _selected.values.where((value) => value).length;

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

  Map<int, List<MenuItem>> _selectedItemsByCourse() {
    final map = <int, List<MenuItem>>{};
    for (final item in selectedItems) {
      map.putIfAbsent(item.courseNumber, () => <MenuItem>[]).add(item);
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

    if (presetMenu != null) {
      Get.back(
        result: MenuActiveSelection(
          menu: presetMenu!,
          choiceNumber: choiceNumber,
          selectedItemsByCourse: _selectedItemsByCourse(),
        ),
      );
      return;
    }

    Get.back();
  }
}
