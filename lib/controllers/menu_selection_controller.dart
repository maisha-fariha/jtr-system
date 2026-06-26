import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/demo_preset_menus.dart';
import '../models/menu_active_selection.dart';
import '../models/menu_item.dart';
import '../models/preset_menu.dart';
import '../models/menu_message_target.dart';
import '../routes/app_pages.dart';
import '../widgets/menu_choice_number_dialog.dart';
import '../widgets/menu_message_picker_dialog.dart';
import '../widgets/menu_message_typing_dialog.dart';
import 'session_controller.dart';

class MenuSelectionController extends GetxController {
  final selectedMenuIndex = RxnInt();
  final activeSelection = Rxn<MenuActiveSelection>();

  late final String orderNumber;

  static const successGreen = Color(0xFF27AE60);

  List<PresetMenu> get menus => demoPresetMenus;

  bool get hasActiveSelection => activeSelection.value != null;

  PresetMenu? get selectedMenu {
    final index = selectedMenuIndex.value;
    if (index == null || index < 0 || index >= menus.length) return null;
    return menus[index];
  }

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    orderNumber = (args is Map ? args['orderNumber'] as String? : null) ?? '';
  }

  void selectMenu(int index) {
    selectedMenuIndex.value = index;
    final menu = menus[index];
    if (hasActiveSelection && activeSelection.value?.menu.number != menu.number) {
      activeSelection.value = null;
    }
    _showChoiceNumberDialog(menu);
  }

  void confirmSelection() {
    final menu = selectedMenu;
    if (menu == null) {
      Get.snackbar(
        'Sélection vide',
        'Veuillez sélectionner un menu.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      );
      return;
    }

    if (hasActiveSelection) {
      finalizeActiveSelection();
      return;
    }

    _showChoiceNumberDialog(menu);
  }

  void openCourseChoice(int courseNumber) {
    final selection = activeSelection.value;
    if (selection == null) return;

    _openMenuPage(
      menu: selection.menu,
      choiceNumber: selection.choiceNumber,
      initialSelections: selection.selectedItemsByCourse,
      focusCourse: courseNumber,
    );
  }

  void showMessagePicker() {
    final selection = activeSelection.value;
    if (selection == null || selection.allSelectedItems.isEmpty) {
      Get.snackbar(
        'Aucun article',
        'Sélectionnez d\'abord un menu et des articles.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      );
      return;
    }

    final targets = selection.allSelectedItems
        .map(
          (item) => MenuMessageTarget(
            courseNumber: item.courseNumber,
            label: '1x ${item.name}',
          ),
        )
        .toList();

    MenuMessagePickerDialog.show(
      items: targets,
      onItemSelected: _showMessageTypingDialog,
    );
  }

  void _showMessageTypingDialog(MenuMessageTarget target) {
    final selection = activeSelection.value;
    if (selection == null) return;

    MenuMessageTypingDialog.show(
      itemLabel: target.label,
      initialMessage: selection.messageForCourse(target.courseNumber) ?? '',
      onSave: (message) => setItemMessage(
        courseNumber: target.courseNumber,
        message: message,
      ),
    );
  }

  void setItemMessage({
    required int courseNumber,
    required String message,
  }) {
    final selection = activeSelection.value;
    if (selection == null) return;

    activeSelection.value =
        selection.withMessage(courseNumber: courseNumber, message: message);
  }

  void _showChoiceNumberDialog(PresetMenu menu) {
    MenuChoiceNumberDialog.show(
      menuLabel: menu.label,
      onConfirm: (choiceNumber) => _openMenuPage(
        menu: menu,
        choiceNumber: choiceNumber,
      ),
    );
  }

  Future<void> _openMenuPage({
    required PresetMenu menu,
    required int choiceNumber,
    Map<int, MenuItem>? initialSelections,
    int? focusCourse,
  }) async {
    final result = await Get.toNamed(
      AppRoutes.menu,
      arguments: {
        'table': orderNumber,
        'presetMenu': menu.number,
        'choiceNumber': choiceNumber,
        'returnToSelection': true,
        if (initialSelections != null)
          'initialSelections': initialSelections,
        if (focusCourse != null) 'focusCourse': focusCourse,
      },
    );

    if (result is MenuActiveSelection) {
      _applyMenuSelectionResult(result);
    }
  }

  void _applyMenuSelectionResult(MenuActiveSelection result) {
    final current = activeSelection.value;
    activeSelection.value =
        current == null ? result : current.merge(result);
    selectedMenuIndex.value =
        menus.indexWhere((menu) => menu.number == result.menu.number);
  }

  /// Returns to the preset-menu list without leaving this screen.
  void dismissActiveSelection() {
    activeSelection.value = null;
  }

  void finalizeActiveSelection() {
    final selection = activeSelection.value;
    if (selection == null) return;

    if (!Get.isRegistered<SessionController>()) return;
    Get.find<SessionController>().addProductsToOrder(
      orderNumber,
      selection.allSelectedItems,
      messagesByCourse: selection.messagesByCourse,
    );

    Get.back();
  }
}
