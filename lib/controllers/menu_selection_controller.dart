import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/network/api_exception.dart';
import '../data/mappers/menu_mapper.dart';
import '../data/repositories/catalog_repository.dart';
import '../data/repositories/order_repository.dart';
import '../models/menu_active_selection.dart';
import '../models/menu_item.dart';
import '../models/menu_message_target.dart';
import '../models/preset_menu.dart';
import '../routes/app_pages.dart';
import '../widgets/api_debug_dialog.dart';
import '../widgets/menu_choice_number_dialog.dart';
import '../widgets/menu_message_picker_dialog.dart';
import '../widgets/menu_message_typing_dialog.dart';
import 'session_controller.dart';

class MenuSelectionController extends GetxController {
  MenuSelectionController({
    required CatalogRepository catalogRepository,
    required OrderRepository orderRepository,
  })  : _catalogRepository = catalogRepository,
        _orderRepository = orderRepository;

  final CatalogRepository _catalogRepository;
  final OrderRepository _orderRepository;

  final selectedMenuIndex = RxnInt();
  final activeSelection = Rxn<MenuActiveSelection>();
  final menus = <PresetMenu>[].obs;
  final isLoadingMenus = false.obs;
  final isLoadingMenuDetail = false.obs;
  final isSaving = false.obs;
  final menusError = RxnString();

  late final String orderNumber;
  int? orderId;

  static const successGreen = Color(0xFF27AE60);

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
    final rawId = args is Map ? args['orderId'] : null;
    orderId = rawId is int ? rawId : (rawId is num ? rawId.toInt() : null);
    _resolveOrderIdFromSession();
    _loadMenus();
  }

  void _resolveOrderIdFromSession() {
    if (orderId != null && orderId! > 0) return;
    if (!Get.isRegistered<SessionController>()) return;

    final sessionOrder = Get.find<SessionController>().findOrder(
      orderNumber: orderNumber,
      orderId: orderId,
    );
    if (sessionOrder != null && sessionOrder.id > 0) {
      orderId = sessionOrder.id;
    }
  }

  Future<void> _loadMenus() async {
    isLoadingMenus.value = true;
    menusError.value = null;

    try {
      final products = await _catalogRepository.getProducts();
      final composed = products.where((product) => product.isComposed).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      menus.assignAll([
        for (var i = 0; i < composed.length; i++)
          MenuMapper.thinPresetFromProduct(
            composed[i],
            badgeNumber: i + 1,
          ),
      ]);
    } on ApiException catch (error) {
      menusError.value = error.message;
    } catch (_) {
      menusError.value = 'Impossible de charger les menus.';
    } finally {
      isLoadingMenus.value = false;
    }
  }

  Future<void> selectMenu(int index) async {
    if (isLoadingMenuDetail.value || index < 0 || index >= menus.length) {
      return;
    }

    selectedMenuIndex.value = index;
    var menu = menus[index];

    if (hasActiveSelection && activeSelection.value?.menu.number != menu.number) {
      activeSelection.value = null;
    }

    if (menu.categories.isEmpty) {
      try {
        isLoadingMenuDetail.value = true;
        final product = await _catalogRepository.getProductDetail(menu.number);
        menu = MenuMapper.presetFromProduct(
          product,
          badgeNumber: menu.badgeNumber,
        );
        menus[index] = menu;
      } on ApiException catch (error) {
        Get.snackbar('Erreur', error.message);
        return;
      } catch (_) {
        Get.snackbar('Erreur', 'Impossible de charger le menu.');
        return;
      } finally {
        isLoadingMenuDetail.value = false;
      }
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

    selectMenu(selectedMenuIndex.value!);
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
        'presetMenu': menu,
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

  void dismissActiveSelection() {
    activeSelection.value = null;
  }

  Future<void> finalizeActiveSelection() async {
    if (isSaving.value) return;

    final selection = activeSelection.value;
    if (selection == null) return;

    _resolveOrderIdFromSession();

    if (orderId == null || orderId! <= 0) {
      final diagnostic = StringBuffer()
        ..writeln('orderNumber=$orderNumber')
        ..writeln('orderId=$orderId')
        ..writeln()
        ..writeln('Aucune commande active trouvée pour cette table.');
      debugPrint(diagnostic.toString());
      ApiDebugDialog.show(
        title: 'Commande introuvable',
        body: diagnostic.toString(),
      );
      Get.snackbar('Erreur', 'Commande introuvable pour cette table.');
      return;
    }

    final requiredCategories = selection.menu.categories
        .where((category) => category.items.isNotEmpty)
        .length;
    if (selection.selectedItemsByCourse.length < requiredCategories) {
      Get.snackbar(
        'Sélection incomplète',
        'Choisissez un article pour chaque choix du menu.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    final menuSelections =
        MenuMapper.menuSelectionsFromItems(selection.allSelectedItems);
    if (menuSelections.isEmpty) {
      Get.snackbar('Erreur', 'Aucune sélection menu valide.');
      return;
    }

    final comment = selection.messagesByCourse.values
        .where((message) => message.trim().isNotEmpty)
        .join(' | ');

    isSaving.value = true;
    try {
      final updated = await _orderRepository.addComposedProductToOrder(
        orderId: orderId!,
        productId: selection.menu.productId,
        basePrice: selection.menu.priceValue,
        menuSelections: menuSelections,
        comment: comment,
      );

      if (Get.isRegistered<SessionController>()) {
        Get.find<SessionController>().updateOrderRow(
          updated.copyWith(number: orderNumber),
        );
      }

      Get.back();
    } on ApiException catch (error) {
      final logBody =
          '${_orderRepository.lastAddItemLog ?? ''}\n\nMESSAGE: ${error.message}';
      debugPrint(logBody);
      ApiDebugDialog.show(
        title: 'Erreur ajout menu',
        body: logBody,
      );
    } catch (error) {
      final logBody = _orderRepository.lastAddItemLog ??
          'Erreur inconnue: $error';
      debugPrint(logBody);
      ApiDebugDialog.show(
        title: 'Erreur ajout menu',
        body: logBody,
      );
      Get.snackbar('Erreur', 'Impossible d\'ajouter le menu à la commande.');
    } finally {
      isSaving.value = false;
    }
  }
}
