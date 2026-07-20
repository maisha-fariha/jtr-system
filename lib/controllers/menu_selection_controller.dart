import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/network/api_exception.dart';
import '../data/mappers/menu_mapper.dart';
import '../data/repositories/catalog_repository.dart';
import '../data/repositories/order_repository.dart';
import '../models/menu_active_selection.dart';
import '../models/menu_item.dart';
import '../models/menu_message_target.dart';
import '../models/order_display_entry.dart';
import '../models/preset_menu.dart';
import '../routes/app_pages.dart';
import '../widgets/api_debug_dialog.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/menu_choice_number_dialog.dart';
import '../widgets/menu_message_picker_dialog.dart';
import '../widgets/menu_message_typing_dialog.dart';
import 'session_controller.dart';
import '../utils/app_snackbar.dart';

class MenuSelectionController extends GetxController {
  MenuSelectionController({
    required CatalogRepository catalogRepository,
    required OrderRepository orderRepository,
  }) : _catalogRepository = catalogRepository,
       _orderRepository = orderRepository;

  final CatalogRepository _catalogRepository;
  final OrderRepository _orderRepository;

  final selectedMenuIndex = RxnInt();
  final activeSelection = Rxn<MenuActiveSelection>();
  final menus = <PresetMenu>[].obs;
  final isLoadingMenus = false.obs;
  final isLoadingMenuDetail = false.obs;
  final isSaving = false.obs;
  final isSidebarExpanded = true.obs;
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

  List<OrderDisplayEntry>? _layoutHintsFromSession() {
    if (!Get.isRegistered<SessionController>()) return null;

    final sessionOrder = Get.find<SessionController>().findOrder(
      orderNumber: orderNumber,
      orderId: orderId,
    );
    final entries = sessionOrder?.displayEntries;
    if (entries == null || entries.isEmpty) return null;
    return entries;
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
          MenuMapper.thinPresetFromProduct(composed[i], badgeNumber: i + 1),
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

    if (hasActiveSelection &&
        activeSelection.value?.menu.number != menu.number) {
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
        AppSnackbar.show('Erreur', error.message);
        return;
      } catch (_) {
        AppSnackbar.show('Erreur', 'Impossible de charger le menu.');
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
      AppSnackbar.show(
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

  void openActiveMenuChoices() {
    final selection = activeSelection.value;
    if (selection == null) return;

    for (final category in selection.menu.categories) {
      if (!selection.isCourseComplete(category.number)) {
        openCourseChoice(category.number);
        return;
      }
    }

    if (selection.menu.categories.isNotEmpty) {
      openCourseChoice(selection.menu.categories.first.number);
    }
  }

  void showMessagePicker({required BuildContext context}) {
    final selection = activeSelection.value;
    if (selection == null || selection.allSelectedItems.isEmpty) {
      _showSnack(
        context,
        title: 'Aucun article',
        message: 'Sélectionnez d\'abord un menu et des articles.',
      );
      return;
    }

    // One message per CHOIX (course).
    final targets = selection.selectedItemsByCourse.entries
        .where((e) => e.value.isNotEmpty)
        .map(
          (e) => MenuMessageTarget(
            courseNumber: e.key,
            label: '${e.value.length}x ${e.value.first.name}',
          ),
        )
        .toList();

    MenuMessagePickerDialog.show(
      context: context,
      items: targets,
      onItemSelected: (target) => _showMessageTypingDialog(context, target),
    );
  }

  void _showMessageTypingDialog(
    BuildContext context,
    MenuMessageTarget target,
  ) {
    final selection = activeSelection.value;
    if (selection == null) return;

    MenuMessageTypingDialog.show(
      context: context,
      itemLabel: target.label,
      initialMessage: selection.messageForCourse(target.courseNumber) ?? '',
      onSave: (message) =>
          setItemMessage(courseNumber: target.courseNumber, message: message),
    );
  }

  void setItemMessage({required int courseNumber, required String message}) {
    final selection = activeSelection.value;
    if (selection == null) return;

    activeSelection.value = selection.withMessage(
      courseNumber: courseNumber,
      message: message,
    );
  }

  void _showChoiceNumberDialog(PresetMenu menu) {
    MenuChoiceNumberDialog.show(
      menuLabel: menu.label,
      onConfirm: (choiceNumber) =>
          _openMenuPage(menu: menu, choiceNumber: choiceNumber),
    );
  }

  Future<void> _openMenuPage({
    required PresetMenu menu,
    required int choiceNumber,
    Map<int, List<MenuItem>>? initialSelections,
    int? focusCourse,
  }) async {
    final result = await Get.toNamed(
      AppRoutes.menu,
      arguments: {
        'table': orderNumber,
        'presetMenu': menu,
        'choiceNumber': choiceNumber,
        'returnToSelection': true,
        if (initialSelections != null) 'initialSelections': initialSelections,
        if (focusCourse != null) 'focusCourse': focusCourse,
      },
    );

    if (result is MenuActiveSelection) {
      _applyMenuSelectionResult(result);
    }
  }

  void _applyMenuSelectionResult(MenuActiveSelection result) {
    final current = activeSelection.value;
    activeSelection.value = current == null ? result : current.merge(result);
    selectedMenuIndex.value = menus.indexWhere(
      (menu) => menu.number == result.menu.number,
    );
    // Ensure the sidebar content is visible after selecting a menu.
    isSidebarExpanded.value = true;
  }

  void dismissActiveSelection() {
    activeSelection.value = null;
    isSidebarExpanded.value = true;
  }

  void toggleSidebarExpanded() {
    isSidebarExpanded.value = !isSidebarExpanded.value;
  }

  void promptSelectMenuFirst(BuildContext context) {
    _showSnack(
      context,
      title: 'Sélection requise',
      message: 'Sélectionnez un menu pour commencer.',
    );
  }

  void editMessageForCourse({
    required BuildContext context,
    required int courseNumber,
  }) {
    final selection = activeSelection.value;
    if (selection == null) return;

    final items = selection.selectedItemsByCourse[courseNumber];
    if (items == null || items.isEmpty) return;

    _showMessageTypingDialog(
      context,
      MenuMessageTarget(
        courseNumber: courseNumber,
        label: '${items.length}x ${items.first.name}',
      ),
    );
  }

  Future<void> requestNextCourse({required BuildContext context}) async {
    _resolveOrderIdFromSession();

    final id = orderId;
    if (id == null || id <= 0) {
      _showSnack(
        context,
        title: 'Erreur',
        message: 'Commande introuvable pour cette table.',
      );
      return;
    }

    AppConfirmDialog.show(
      context: context,
      title: 'Demander la suite',
      message:
          'Envoyer la demande À SUIVRE pour la table $orderNumber ?\n'
          'La cuisine préparera la suite (ex. plats, desserts).',
      onConfirm: () async {
        isSaving.value = true;
        try {
          final updated = await _orderRepository.requestNextCourses(id);
          if (Get.isRegistered<SessionController>()) {
            Get.find<SessionController>().updateOrderRow(
              updated,
              replaceDetail: true,
            );
          }
          if (context.mounted) {
            _showSnack(
              context,
              title: 'Suite demandée',
              message: 'Demande envoyée pour la table $orderNumber.',
            );
          }
        } on ApiException catch (error) {
          if (context.mounted) {
            _showSnack(
              context,
              title: 'Erreur suite',
              message: error.message,
            );
          }
        } catch (_) {
          if (context.mounted) {
            _showSnack(
              context,
              title: 'Erreur',
              message: 'Impossible d\'envoyer la demande de suite.',
            );
          }
        } finally {
          isSaving.value = false;
        }
      },
    );
  }

  void _showSnack(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    AppSnackbar.show(title, message, context: context);
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
      AppSnackbar.show('Erreur', 'Commande introuvable pour cette table.');
      return;
    }

    final requestedPerCourse = selection.choiceNumber < 1
        ? 1
        : selection.choiceNumber;

    // For each CHOIX category, we require selecting exactly N items.
    for (final category in selection.menu.categories) {
      if (category.items.isEmpty) continue;

      final required = requestedPerCourse.clamp(0, category.items.length);
      final selectedCount =
          selection.selectedItemsByCourse[category.number]?.length ?? 0;

      if (selectedCount != required) {
        AppSnackbar.show(
          'Sélection incomplète',
          'Choisissez $required article(s) pour CHOIX ${category.number}.',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
        );
        return;
      }
    }

    final menuSelections = MenuMapper.menuSelectionsFromItems(
      selection.allSelectedItems,
    );
    if (menuSelections.isEmpty) {
      AppSnackbar.show('Erreur', 'Aucune sélection menu valide.');
      return;
    }

    final comment = selection.messagesByCourse.values
        .where((message) => message.trim().isNotEmpty)
        .join(' | ');

    final layoutHints = _layoutHintsFromSession();

    isSaving.value = true;
    try {
      final updated = await _orderRepository.addComposedProductToOrder(
        orderId: orderId!,
        productId: selection.menu.productId,
        basePrice: selection.menu.priceValue,
        menuSelections: menuSelections,
        comment: comment,
        layoutHints: layoutHints,
        tableNumber: orderNumber,
        waiterId: Get.isRegistered<SessionController>()
            ? Get.find<SessionController>()
                    .findOrder(orderNumber: orderNumber, orderId: orderId)
                    ?.waiterId
            : null,
      );
      orderId = updated.id;

      if (Get.isRegistered<SessionController>()) {
        Get.find<SessionController>().updateOrderRow(
          updated,
          replaceDetail: true,
        );
      }

      Get.back(result: true);
    } on ApiException catch (error) {
      debugPrint(_orderRepository.lastAddItemLog);
      ApiDebugDialog.show(title: 'Erreur ajout menu', body: error.message);
    } catch (error) {
      debugPrint(_orderRepository.lastAddItemLog ?? '$error');
      AppSnackbar.show('Erreur', 'Impossible d\'ajouter le menu à la commande.');
    } finally {
      isSaving.value = false;
    }
  }
}
