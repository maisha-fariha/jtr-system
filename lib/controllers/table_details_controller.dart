import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/network/api_exception.dart';
import '../data/mappers/order_mapper.dart';
import '../data/models/catalog/catalog_product_model.dart';
import '../data/models/catalog/category_tree_node.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/catalog_repository.dart';
import '../data/repositories/order_repository.dart';
import '../models/order_product.dart';
import '../models/order_display_entry.dart';
import '../models/session_order.dart';
import '../routes/app_pages.dart';
import '../utils/api_log.dart';
import '../widgets/api_debug_dialog.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/composed_product_picker_sheet.dart';
import '../widgets/table_number_dialog.dart';
import '../widgets/ticket_loading_dialog.dart';
import '../widgets/ticket_success_dialog.dart';
import 'session_controller.dart';

class TableDetailsController extends GetxController {
  TableDetailsController({
    required CatalogRepository catalogRepository,
    required OrderRepository orderRepository,
  })  : _catalogRepository = catalogRepository,
        _orderRepository = orderRepository;

  final CatalogRepository _catalogRepository;
  final OrderRepository _orderRepository;

  final selectedCategoryIndex = 0.obs;
  final isBottomPanelExpanded = true.obs;
  final showPaymentOptions = false.obs;
  final selectedProductId = RxnInt();
  final selectedOrderLineIndex = RxnInt();
  final activeToolbarIcon = Rx<IconData?>(Icons.grid_view);
  final isCatalogLoading = false.obs;
  final isAddingProduct = false.obs;
  final paymentModesLoading = false.obs;
  final paymentModesReady = false.obs;
  final paymentModesError = RxnString();
  String? lastPaymentModesLoadLog;
  final catalogError = RxnString();
  final categoryRoots = <CategoryTreeNode>[].obs;
  final categoryPath = <CategoryTreeNode>[].obs;
  final products = <CatalogProductModel>[].obs;

  late final String orderNumber;
  int? orderId;

  final collapsedSuivreSections = <int>{}.obs;
  final selectedSuivreSection = RxnInt();
  final suivreUiRevision = 0.obs;

  bool isSuivreSectionCollapsed(int sectionIndex) =>
      collapsedSuivreSections.contains(sectionIndex);

  bool isSuivreSectionSelected(int sectionIndex) =>
      selectedSuivreSection.value == sectionIndex;

  bool isSelectedSectionRequestable(List<OrderDisplayEntry> entries) {
    final sectionIndex = selectedSuivreSection.value;
    if (sectionIndex == null || sectionIndex <= 0) return false;

    for (final entry in entries) {
      if (entry.type == OrderDisplayEntryType.suivreSeparator &&
          entry.sectionIndex == sectionIndex) {
        return true;
      }
      if (entry.type == OrderDisplayEntryType.demandeSeparator &&
          entry.sectionIndex == sectionIndex) {
        return false;
      }
    }

    return false;
  }

  void selectSuivreSection(int sectionIndex) {
    selectedSuivreSection.value = sectionIndex;
    collapsedSuivreSections.remove(sectionIndex);
    collapsedSuivreSections.refresh();
    suivreUiRevision.value++;
  }

  void toggleSuivreSection(int sectionIndex) {
    if (collapsedSuivreSections.contains(sectionIndex)) {
      collapsedSuivreSections.remove(sectionIndex);
    } else {
      collapsedSuivreSections.add(sectionIndex);
    }
    collapsedSuivreSections.refresh();
    suivreUiRevision.value++;
  }

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    orderNumber = (args is Map ? args['orderNumber'] as String? : null) ?? '';
    final rawId = args is Map ? args['orderId'] : null;
    orderId = rawId is int ? rawId : (rawId is num ? rawId.toInt() : null);
    logOrderFlow(
      'TableDetailsController.onInit table=$orderNumber orderId=${orderId ?? 'none'}',
    );

    _loadCatalog();
    unawaited(_bootstrapOrder());
  }

  Future<void> _bootstrapOrder() async {
    await _ensureResolvedOrderId();
    await _refreshOrder();
  }

  Future<void> _loadCatalog() async {
    isCatalogLoading.value = true;
    catalogError.value = null;

    try {
      final loadedTree = await _catalogRepository.getCategoryTree();
      final loadedProducts = await _catalogRepository.getProducts();
      categoryRoots.assignAll(loadedTree);
      products.assignAll(loadedProducts);
      categoryPath.clear();
      if (selectedCategoryIndex.value >= currentLevelCategories.length) {
        selectedCategoryIndex.value = 0;
      }
    } on ApiException catch (e) {
      catalogError.value = e.message;
    } catch (_) {
      catalogError.value = 'Impossible de charger le menu.';
    } finally {
      isCatalogLoading.value = false;
    }
  }

  Future<void> _refreshOrder() async {
    if (!Get.isRegistered<SessionController>()) return;
    await Get.find<SessionController>().loadOrderDetails(
      orderNumber,
      orderId: orderId,
      forceRefresh: true,
    );
  }

  SessionOrder? get order {
    if (!Get.isRegistered<SessionController>()) return null;
    return Get.find<SessionController>().findOrder(
      orderNumber: orderNumber,
      orderId: orderId,
    );
  }

  int? get resolvedOrderId {
    if (orderId != null && orderId! > 0) return orderId;
    final current = order;
    if (current != null && current.id > 0) return current.id;
    return null;
  }

  int get _currentWaiterId {
    if (Get.isRegistered<AuthRepository>()) {
      return Get.find<AuthRepository>().cachedSession?.user.id ?? 0;
    }
    return 0;
  }

  Future<int?> _ensureResolvedOrderId() async {
    if (orderId != null && orderId! > 0) {
      if (await _verifyOrderExists(orderId!)) return orderId;
      orderId = null;
    }

    final current = order;
    if (current != null && current.id > 0) {
      if (await _verifyOrderExists(current.id)) {
        orderId = current.id;
        return orderId;
      }
    }

    final resolved =
        await _orderRepository.resolveOrderIdForTableNumber(orderNumber);
    if (resolved == null || resolved <= 0) return null;

    try {
      final previous = order;
      final detail = await _orderRepository.getOrderDetail(
        resolved,
        previousDisplayEntries: previous?.displayEntries,
      );
      orderId = resolved;
      _syncOrderInSession(detail, detail.number);
      return orderId;
    } catch (_) {
      orderId = null;
      return null;
    }
  }

  Future<bool> _verifyOrderExists(int id) async {
    try {
      await _orderRepository.getOrderDetail(id);
      return true;
    } catch (_) {
      return false;
    }
  }

  List<CategoryTreeNode> get currentLevelCategories {
    if (categoryPath.isEmpty) return categoryRoots;
    return categoryPath.last.children;
  }

  CategoryTreeNode? get selectedCategory {
    final level = currentLevelCategories;
    if (level.isEmpty) return null;
    final index = selectedCategoryIndex.value;
    if (index < 0 || index >= level.length) return level.first;
    return level[index];
  }

  bool get canNavigateCategoryBack {
    if (categoryPath.isNotEmpty) return true;
    final selected = selectedCategory;
    if (selected == null) return false;
    return _findAncestorChain(selected.id).isNotEmpty;
  }

  List<CategoryTreeNode> _findAncestorChain(int categoryId) {
    List<CategoryTreeNode>? search(
      List<CategoryTreeNode> nodes,
      List<CategoryTreeNode> ancestors,
    ) {
      for (final node in nodes) {
        if (node.id == categoryId) return ancestors;
        if (node.children.isEmpty) continue;
        final found = search(node.children, [...ancestors, node]);
        if (found != null) return found;
      }
      return null;
    }

    return search(categoryRoots.toList(), const []) ?? const [];
  }

  void _applyCategoryLevel({
    required List<CategoryTreeNode> path,
    required CategoryTreeNode selected,
  }) {
    categoryPath.assignAll(path);
    final siblings = path.isEmpty ? categoryRoots : path.last.children;
    final index = siblings.indexWhere((node) => node.id == selected.id);
    selectedCategoryIndex.value = index >= 0 ? index : 0;
  }

  bool get showingChildCategories {
    final category = selectedCategory;
    return category != null && category.hasChildren;
  }

  List<CategoryTreeNode> get childCategoriesForGrid {
    final category = selectedCategory;
    if (category == null || !category.hasChildren) return const [];
    return category.children;
  }

  List<CatalogProductModel> get currentProducts {
    final category = selectedCategory;
    if (category == null || category.hasChildren) return const [];
    return _catalogRepository.productsForCategory(products, category.id);
  }

  CatalogProductModel? catalogProductByName(String orderLineName) {
    final normalized = orderLineName.trim().toUpperCase();
    if (normalized.isEmpty) return null;

    for (final product in products) {
      if (product.name.trim().toUpperCase() == normalized) return product;
    }
    return null;
  }

  CatalogProductModel? get selectedCatalogProduct {
    final id = selectedProductId.value;
    if (id == null) return null;
    for (final product in products) {
      if (product.id == id) return product;
    }
    return null;
  }

  int productQuantityInOrder(
    CatalogProductModel product, {
    SessionOrder? source,
  }) {
    final currentOrder = source ?? order;
    if (currentOrder == null) return 0;
    final normalized = product.name.toUpperCase();
    var total = 0;
    for (final line in currentOrder.products) {
      if (line.name.toUpperCase() == normalized) {
        total += int.tryParse(line.quantity) ?? 0;
      }
    }
    return total;
  }

  bool isProductSelected(CatalogProductModel product) =>
      selectedProductId.value == product.id;

  bool isOrderLineSelected(int lineIndex) =>
      selectedOrderLineIndex.value == lineIndex;

  void selectOrderLine(int lineIndex, OrderProduct line) {
    final catalog = catalogProductByName(line.name);
    if (catalog == null) {
      Get.snackbar(
        'Article non sélectionnable',
        'Cet article ne peut pas être modifié via le clavier.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
      return;
    }
    selectedProductId.value = catalog.id;
    selectedOrderLineIndex.value = lineIndex;
  }

  void selectCatalogProduct(CatalogProductModel product) {
    selectedProductId.value = product.id;
    selectedOrderLineIndex.value = null;
  }

  void selectCategory(int index) {
    if (index < 0 || index >= currentLevelCategories.length) return;
    selectedCategoryIndex.value = index;
  }

  void openChildCategory(CategoryTreeNode child) {
    final parent = selectedCategory;
    if (parent == null) return;

    _applyCategoryLevel(
      path: [...categoryPath, parent],
      selected: child,
    );
  }

  void navigateCategoryBack() {
    if (categoryPath.isNotEmpty) {
      final parent = categoryPath.removeLast();
      _applyCategoryLevel(path: categoryPath.toList(), selected: parent);
      return;
    }

    final selected = selectedCategory;
    if (selected == null) return;

    final ancestors = _findAncestorChain(selected.id);
    if (ancestors.isEmpty) return;

    final parent = ancestors.last;
    _applyCategoryLevel(
      path: ancestors.sublist(0, ancestors.length - 1),
      selected: parent,
    );
  }

  /// Category hierarchy first; only leaves the table when already at root.
  Future<void> openMenuSelection() async {
    showPaymentOptions.value = false;
    final id = await _ensureResolvedOrderId();

    await Get.toNamed(
      AppRoutes.menuSelection,
      arguments: {
        'orderNumber': orderNumber,
        if (id != null && id > 0) 'orderId': id,
      },
    );

    await _refreshOrder();
  }

  Future<void> navigateBackOrExitTable() async {
    if (canNavigateCategoryBack) {
      navigateCategoryBack();
      activeToolbarIcon.value = Icons.grid_view;
      return;
    }

    final orderNumber = this.orderNumber;
    final orderId = this.orderId;
    if (Get.isRegistered<SessionController>()) {
      await Get.find<SessionController>().refreshOrderList(
        ensureOrderNumber: orderNumber,
        ensureOrderId: orderId,
      );
    }
    Get.back();
  }

  void toggleBottomPanel() {
    isBottomPanelExpanded.value = !isBottomPanelExpanded.value;
    if (isBottomPanelExpanded.value) {
      showPaymentOptions.value = false;
      activeToolbarIcon.value = Icons.grid_view;
    } else if (!showPaymentOptions.value) {
      activeToolbarIcon.value = null;
    }
  }

  void togglePaymentOptions() {
    final show = !showPaymentOptions.value;
    showPaymentOptions.value = show;
    if (show) {
      isBottomPanelExpanded.value = false;
      activeToolbarIcon.value = Icons.payments_outlined;
      unawaited(_loadPaymentModes());
    } else {
      isBottomPanelExpanded.value = true;
      activeToolbarIcon.value = Icons.grid_view;
    }
  }

  Future<void> _loadPaymentModes({bool forceRefresh = false}) async {
    paymentModesLoading.value = true;
    paymentModesError.value = null;
    try {
      final modes = await _orderRepository.getPaymentModes(
        forceRefresh: forceRefresh,
      );
      paymentModesReady.value = modes.isNotEmpty;
      if (modes.isEmpty) {
        paymentModesError.value = 'Aucun mode de paiement configuré.';
      }
    } on ApiException catch (e) {
      paymentModesReady.value = false;
      paymentModesError.value = e.message;
      lastPaymentModesLoadLog = _orderRepository.lastPaymentModesLog;
    } catch (e) {
      paymentModesReady.value = false;
      paymentModesError.value =
          'Impossible de charger les modes de paiement.';
      lastPaymentModesLoadLog =
          '${_orderRepository.lastPaymentModesLog ?? ''}\n$e';
    } finally {
      paymentModesLoading.value = false;
    }
  }

  Future<void> reloadPaymentModes() =>
      _loadPaymentModes(forceRefresh: true);

  String get payableTotalLabel => order?.total ?? '—';

  bool get canPay =>
      resolvedOrderId != null &&
      paymentModesReady.value &&
      !paymentModesLoading.value &&
      !isAddingProduct.value;

  OrderProduct? get selectedOrderLine {
    final currentOrder = order;
    final lineIndex = selectedOrderLineIndex.value;
    if (currentOrder == null || lineIndex == null) return null;
    if (lineIndex < 0 || lineIndex >= currentOrder.products.length) return null;
    return currentOrder.products[lineIndex];
  }

  void showQuantityDialog({required BuildContext context}) {
    final line = selectedOrderLine;
    if (line == null) {
      isBottomPanelExpanded.value = true;
      showPaymentOptions.value = false;
      Get.snackbar(
        'Sélectionnez une ligne',
        'Touchez une ligne dans la commande avant le clavier.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    final product = catalogProductByName(line.name);
    if (product?.isComposed == true) {
      Get.snackbar(
        'Produit composé',
        'Ce produit se configure via le sélecteur de menu.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    final currentQty = int.tryParse(line.quantity) ?? 0;

    TableNumberDialog.show(
      context: context,
      title: line.name.toUpperCase(),
      initialValue: currentQty > 0 ? '$currentQty' : null,
      integerOnly: true,
      maxDigits: 3,
      onConfirm: (value) {
        final parsed = int.tryParse(value.trim());
        if (parsed == null || parsed < 0) return;

        final selectedLineIndex = selectedOrderLineIndex.value;
        if (selectedLineIndex == null) return;

        unawaited(_setOrderLineQuantity(selectedLineIndex, parsed));
      },
    );
  }

  void onToolbarIconTap(IconData icon, {required BuildContext context}) {
    if (icon == Icons.keyboard_return_outlined) {
      unawaited(navigateBackOrExitTable());
      return;
    }

    if (icon == Icons.grid_view) {
      showPaymentOptions.value = false;
      isBottomPanelExpanded.value = true;
      activeToolbarIcon.value = Icons.grid_view;
      showQuantityDialog(context: context);
      return;
    }

    if (icon == Icons.menu_book) {
      activeToolbarIcon.value = Icons.menu_book;
      unawaited(openMenuSelection());
      return;
    }

    if (icon == Icons.restaurant) {
      activeToolbarIcon.value = Icons.restaurant;
      unawaited(addSuivreAfterLatestItems());
      return;
    }

    if (icon == Icons.restaurant_menu) {
      activeToolbarIcon.value = Icons.restaurant_menu;
      requestNextCourse(context: context);
      return;
    }

    if (icon == Icons.receipt_long_outlined) {
      printTicket(context: context);
      return;
    }

    if (icon == Icons.send_outlined) {
      sendToKitchen(context: context);
      return;
    }

    if (icon == Icons.payments_outlined) {
      togglePaymentOptions();
      return;
    }

    activeToolbarIcon.value = icon;
  }

  bool isToolbarIconActive(IconData icon) => activeToolbarIcon.value == icon;

  bool isToolbarIconEnabled(IconData icon) => true;

  Future<void> printTicket({required BuildContext context}) async {
    final id = await _ensureResolvedOrderId();
    if (id == null || id <= 0) {
      Get.snackbar('Erreur', 'Commande introuvable pour cette table.');
      return;
    }

    activeToolbarIcon.value = Icons.receipt_long_outlined;
    showPaymentOptions.value = false;

    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => const TicketLoadingDialog(),
    );

    try {
      final updated = await _orderRepository.markOrderPrinted(
        id,
        previousDisplayEntries: order?.displayEntries,
      );
      _syncOrderInSession(updated, orderNumber);

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        await showDialog<void>(
          context: context,
          useRootNavigator: true,
          barrierDismissible: false,
          barrierColor: Colors.black.withValues(alpha: 0.45),
          builder: (_) => const TicketSuccessDialog(),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      Get.snackbar('Erreur', e.message);
    } catch (_) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      Get.snackbar('Erreur', 'Impossible d\'imprimer le ticket.');
    }
  }

  Future<void> sendToKitchen({required BuildContext context}) async {
    final id = resolvedOrderId;
    if (id == null || id <= 0) {
      Get.snackbar('Erreur', 'Commande introuvable pour cette table.');
      return;
    }

    AppConfirmDialog.show(
      context: context,
      title: 'Envoyer en cuisine',
      message:
          'Envoyer toutes les commandes en attente pour la table $orderNumber ?',
      onConfirm: () async {
        activeToolbarIcon.value = Icons.send_outlined;
        showPaymentOptions.value = false;
        isAddingProduct.value = true;
        try {
          final updated = await _orderRepository.requestAllCourses(id);
          _syncOrderInSession(updated, orderNumber);
          Get.snackbar(
            'Envoyé',
            'La commande a été envoyée en cuisine.',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.all(16),
          );
        } on ApiException catch (e) {
          ApiDebugDialog.show(title: 'Erreur envoi', body: e.message);
        } catch (_) {
          Get.snackbar(
            'Erreur',
            'Impossible d\'envoyer la commande en cuisine.',
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(16),
          );
        } finally {
          isAddingProduct.value = false;
        }
      },
    );
  }

  Future<void> payOrder({required BuildContext context, required bool isCash}) async {
    final id = resolvedOrderId;
    if (id == null || id <= 0) {
      Get.snackbar('Erreur', 'Commande introuvable pour cette table.');
      return;
    }

    if (!paymentModesReady.value) {
      await _loadPaymentModes();
      if (!paymentModesReady.value) {
        Get.snackbar(
          'Paiement indisponible',
          paymentModesError.value ??
              'Les modes de paiement ne sont pas chargés.',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
        );
        return;
      }
    }

    if (!context.mounted) return;

    final label = isCash ? 'espèces' : 'carte de crédit';
    final amountLabel = payableTotalLabel;
    AppConfirmDialog.show(
      context: context,
      title: 'Paiement',
      message:
          'Encaisser $amountLabel pour la table $orderNumber en $label ?',
      onConfirm: () async {
        isAddingProduct.value = true;
        try {
          final updated = await _orderRepository.payOrder(
            orderId: id,
            isCash: isCash,
          );
          _syncOrderInSession(updated, orderNumber);
          showPaymentOptions.value = false;
          isBottomPanelExpanded.value = true;
          activeToolbarIcon.value = Icons.grid_view;
          Get.snackbar(
            'Paiement enregistré',
            'Le paiement en $label a été enregistré.',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.all(16),
          );
        } on ApiException catch (e) {
          ApiDebugDialog.show(
            title: 'Erreur paiement',
            body: '${_orderRepository.lastPaymentLog ?? ''}\n\n${e.message}',
          );
        } catch (_) {
          Get.snackbar(
            'Erreur',
            'Impossible d\'enregistrer le paiement.',
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(16),
          );
        } finally {
          isAddingProduct.value = false;
        }
      },
    );
  }

  Future<void> addSuivreAfterLatestItems() async {
    final currentOrder = order;
    if (currentOrder == null) {
      Get.snackbar('Erreur', 'Commande introuvable pour cette table.');
      return;
    }

    if (currentOrder.products.isEmpty) {
      Get.snackbar(
        'À SUIVRE',
        'Ajoutez d\'abord un article avant d\'ouvrir la suite.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    final beforeCount =
        OrderMapper.suivreSeparatorCount(currentOrder.displayEntries);
    final displayEntries = OrderMapper.appendSuivreSeparatorAfterRequest(
      currentOrder.displayEntries,
    );
    final afterCount = OrderMapper.suivreSeparatorCount(displayEntries);

    if (afterCount <= beforeCount) {
      Get.snackbar(
        'À SUIVRE',
        'La suite est déjà ouverte.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    final suivreEntry = displayEntries.lastWhere(
      (entry) => entry.type == OrderDisplayEntryType.suivreSeparator,
    );
    final sectionIndex = suivreEntry.sectionIndex ?? 0;

    collapsedSuivreSections.remove(sectionIndex);
    collapsedSuivreSections.refresh();
    suivreUiRevision.value++;
    showPaymentOptions.value = false;
    isBottomPanelExpanded.value = true;
    activeToolbarIcon.value = Icons.restaurant;
    selectedSuivreSection.value = sectionIndex;

    final id = resolvedOrderId;
    if (id != null && id > 0) {
      await _orderRepository.persistSuivreLayoutHints(id, displayEntries);
    }

    _syncOrderInSession(
      currentOrder.copyWith(displayEntries: displayEntries),
      orderNumber,
      displayEntriesOverride: displayEntries,
    );
  }

  Future<void> requestNextCourse({BuildContext? context}) async {
    final id = resolvedOrderId;
    if (id == null || id <= 0) {
      Get.snackbar('Erreur', 'Commande introuvable pour cette table.');
      return;
    }

    final sectionIndex = selectedSuivreSection.value;
    if (sectionIndex == null || sectionIndex <= 0) {
      Get.snackbar(
        'Sélection requise',
        'Sélectionnez un À SUIVRE avant de demander.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    final currentOrder = order;
    if (currentOrder != null &&
        !isSelectedSectionRequestable(currentOrder.displayEntries)) {
      selectedSuivreSection.value = null;
      Get.snackbar(
        'Sélection invalide',
        'Ce service est déjà demandé. Sélectionnez un À SUIVRE ouvert.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    final courseNumber = currentOrder == null
        ? null
        : OrderMapper.resolveCourseNumberForSuivreSection(
            currentOrder.displayEntries,
            sectionIndex,
          );
    if (courseNumber == null || courseNumber <= 0) {
      Get.snackbar(
        'Erreur',
        'Impossible d\'identifier le service à demander.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    AppConfirmDialog.show(
      context: context,
      title: 'Demande',
      message:
          'Envoyer en cuisine le service sélectionné (course $courseNumber) ?',
      onConfirm: () async {
        isAddingProduct.value = true;
        try {
          final orderSnapshot = order;
          final updated = await _orderRepository.requestCourseForSuivreSection(
            id,
            courseNumber: courseNumber,
            previousDisplayEntries: orderSnapshot?.displayEntries,
          );
          _syncOrderInSession(updated, orderNumber);
          await _refreshOrder();
          if (selectedSuivreSection.value == sectionIndex) {
            selectedSuivreSection.value = null;
          }
          Get.snackbar(
            'Demande envoyée',
            'Le service a été envoyé en cuisine.',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.all(16),
          );
        } on ApiException catch (e) {
          ApiDebugDialog.show(
            title: 'Erreur demande',
            body: e.message,
          );
        } catch (_) {
          Get.snackbar(
            'Erreur',
            'Impossible d\'envoyer la demande.',
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(16),
          );
        } finally {
          isAddingProduct.value = false;
        }
      },
    );
  }

  Future<void> onProductTap(CatalogProductModel product) async {
    logOrderFlow(
      'onProductTap product=${product.id} ${product.name} table=$orderNumber',
    );

    var id = await _ensureResolvedOrderId();
    logOrderFlow('onProductTap resolvedOrderId=${id ?? 'none'}');

    selectedProductId.value = product.id;

    try {
      if (product.isComposed) {
        final detail = await _catalogRepository.getProductDetail(product.id);
        List<Map<String, dynamic>>? selections;
        await ComposedProductPickerSheet.show(
          product: detail,
          onConfirm: (picked) => selections = picked,
        );
        if (selections == null) return;

        id = await _ensureResolvedOrderId();
        if (id == null || id <= 0) {
          final created =
              await _orderRepository.createOrderWithFirstComposedProduct(
            tableNumber: orderNumber,
            waiterId: _currentWaiterId,
            productId: detail.id,
            basePrice: detail.unitPrice,
            menuSelections: selections!,
          );
          orderId = created.id;
          _syncOrderInSession(created, orderNumber);
        } else {
          await _addComposedProduct(
            orderId: id,
            product: detail,
            menuSelections: selections!,
            displayNumber: orderNumber,
          );
        }
      } else if (id == null || id <= 0) {
        if (kDebugMode) {
          print('ORDER POST: no order id — creating with first item ${product.id}');
        }
        final created = await _orderRepository.createOrderWithFirstSimpleProduct(
          tableNumber: orderNumber,
          waiterId: _currentWaiterId,
          productId: product.id,
          unitPrice: product.unitPrice,
          qty: 1,
        );
        orderId = created.id;
        _syncOrderInSession(created, orderNumber);
      } else {
        if (kDebugMode) {
          print('ORDER PUT: adding item to existing order $id');
        }
        final updated = await _orderRepository.addSimpleProductToOrder(
          orderId: id,
          productId: product.id,
          unitPrice: product.unitPrice,
          qty: 1,
          layoutHints: order?.displayEntries,
        );
        _syncOrderInSession(updated, orderNumber);
      }
    } on ApiException catch (e) {
      ApiDebugDialog.show(
        title: 'Erreur ajout article',
        body: '${_orderRepository.lastAddItemLog ?? ''}\n\nMESSAGE: ${e.message}',
      );
    } catch (_) {
      Get.snackbar('Erreur', 'Impossible d\'ajouter l\'article.');
    }
  }

  Future<void> _setOrderLineQuantity(int lineIndex, int qty) async {
    final id = resolvedOrderId;
    if (id == null || id <= 0) return;

    isAddingProduct.value = true;
    try {
      final updated = await _orderRepository.setOrderLineQuantityAtIndex(
        orderId: id,
        lineIndex: lineIndex,
        qty: qty,
      );
      _syncOrderInSession(updated, orderNumber);
    } on ApiException catch (e) {
      ApiDebugDialog.show(
        title: 'Erreur quantité',
        body: '${_orderRepository.lastAddItemLog ?? ''}\n\nMESSAGE: ${e.message}',
      );
    } catch (_) {
      Get.snackbar('Erreur', 'Impossible de modifier la quantité.');
    } finally {
      isAddingProduct.value = false;
    }
  }

  Future<void> _addComposedProduct({
    required int orderId,
    required CatalogProductModel product,
    required List<Map<String, dynamic>> menuSelections,
    required String displayNumber,
  }) async {
    isAddingProduct.value = true;
    try {
      final updated = await _orderRepository.addComposedProductToOrder(
        orderId: orderId,
        productId: product.id,
        basePrice: product.unitPrice,
        menuSelections: menuSelections,
        layoutHints: order?.displayEntries,
      );
      _syncOrderInSession(updated, displayNumber);
    } on ApiException catch (e) {
      ApiDebugDialog.show(
        title: 'Erreur ajout menu',
        body: '${_orderRepository.lastAddItemLog ?? ''}\n\nMESSAGE: ${e.message}',
      );
    } finally {
      isAddingProduct.value = false;
    }
  }

  void _syncOrderInSession(
    SessionOrder updated,
    String displayNumber, {
    List<OrderDisplayEntry>? displayEntriesOverride,
  }) {
    if (!Get.isRegistered<SessionController>()) return;

    var displayEntries = displayEntriesOverride ?? updated.displayEntries;

    Get.find<SessionController>().updateOrderRow(
      updated.copyWith(
        displayEntries: displayEntries,
      ),
    );

    final id = updated.id;
    if (id > 0 && Get.isRegistered<OrderRepository>()) {
      unawaited(
        Get.find<OrderRepository>().persistSuivreLayoutHints(
          id,
          displayEntries,
        ),
      );
    }
  }

  bool isProductInOrder(
    CatalogProductModel product, {
    SessionOrder? source,
  }) {
    return productQuantityInOrder(product, source: source) > 0;
  }

  Future<void> incrementProduct(int productIndex) async {
    await _mutateLineQuantity(productIndex, 1);
  }

  Future<void> decrementProduct(int productIndex) async {
    await _mutateLineQuantity(productIndex, -1);
  }

  Future<void> offerProduct(int productIndex) async {
    final id = resolvedOrderId;
    if (id == null || id <= 0) {
      Get.snackbar('Erreur', 'Commande introuvable pour cette table.');
      return;
    }

    final currentOrder = order;
    if (currentOrder == null ||
        productIndex < 0 ||
        productIndex >= currentOrder.products.length) {
      return;
    }

    isAddingProduct.value = true;
    try {
      final updated = await _orderRepository.applyOfferAtLineIndex(
        orderId: id,
        lineIndex: productIndex,
      );
      _syncOrderInSession(updated, orderNumber);
      Get.snackbar(
        'Offert',
        '${currentOrder.products[productIndex].name} a été offert.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      );
    } on ApiException catch (e) {
      ApiDebugDialog.show(
        title: 'Erreur offre',
        body: '${_orderRepository.lastAddItemLog ?? ''}\n\nMESSAGE: ${e.message}',
      );
    } catch (_) {
      Get.snackbar('Erreur', 'Impossible d\'offrir l\'article.');
    } finally {
      isAddingProduct.value = false;
    }
  }

  Future<void> _mutateLineQuantity(int productIndex, int delta) async {
    final id = resolvedOrderId;
    if (id == null || id <= 0) {
      Get.snackbar('Erreur', 'Commande introuvable pour cette table.');
      return;
    }

    final currentOrder = order;
    if (currentOrder == null ||
        productIndex < 0 ||
        productIndex >= currentOrder.products.length) {
      return;
    }

    final line = currentOrder.products[productIndex];
    if (delta < 0) {
      final qty = int.tryParse(line.quantity) ?? 1;
      if (qty <= 1) {
        await cancelOrderLine(productIndex);
        return;
      }
    }

    isAddingProduct.value = true;
    try {
      final updated = await _orderRepository.adjustOrderLineQuantityAtIndex(
        orderId: id,
        lineIndex: productIndex,
        delta: delta,
      );
      _syncOrderInSession(updated, orderNumber);
    } on ApiException catch (e) {
      ApiDebugDialog.show(
        title: 'Erreur quantité',
        body: '${_orderRepository.lastAddItemLog ?? ''}\n\nMESSAGE: ${e.message}',
      );
    } catch (_) {
      Get.snackbar('Erreur', 'Impossible de modifier la quantité.');
    } finally {
      isAddingProduct.value = false;
    }
  }

  Future<void> cancelSuivreSection(int sectionIndex) async {
    final id = resolvedOrderId;
    if (id == null || id <= 0) {
      Get.snackbar('Erreur', 'Commande introuvable pour cette table.');
      return;
    }

    final currentOrder = order;
    if (currentOrder == null) return;

    final lineIndices = OrderMapper.productLineIndicesForSection(
      currentOrder.displayEntries,
      sectionIndex,
    );
    final trimmedDisplay = OrderMapper.removeSuivreSectionFromDisplay(
      currentOrder.displayEntries,
      sectionIndex,
    );

    collapsedSuivreSections.remove(sectionIndex);
    collapsedSuivreSections.refresh();
    suivreUiRevision.value++;
    if (selectedOrderLineIndex.value != null &&
        lineIndices.contains(selectedOrderLineIndex.value)) {
      selectedOrderLineIndex.value = null;
    }

    isAddingProduct.value = true;
    try {
      if (lineIndices.isNotEmpty) {
        final updated = await _orderRepository.cancelOrderLinesAtIndices(
          orderId: id,
          lineIndices: lineIndices,
          previousDisplayEntries: trimmedDisplay,
        );
        _syncOrderInSession(
          updated,
          orderNumber,
          displayEntriesOverride: updated.displayEntries,
        );
        return;
      }

      final refreshed = await _orderRepository.syncDisplayFromTrimmedLayout(
        id,
        trimmedDisplay: trimmedDisplay,
      );
      _syncOrderInSession(
        refreshed,
        orderNumber,
        displayEntriesOverride: refreshed.displayEntries,
      );
    } on ApiException catch (e) {
      ApiDebugDialog.show(
        title: 'Erreur annulation',
        body: '${_orderRepository.lastAddItemLog ?? ''}\n\nMESSAGE: ${e.message}',
      );
    } catch (_) {
      Get.snackbar('Erreur', 'Impossible d\'annuler cette suite.');
    } finally {
      isAddingProduct.value = false;
    }
  }

  Future<void> cancelOrderLine(int productIndex) async {
    final id = resolvedOrderId;
    if (id == null || id <= 0) {
      Get.snackbar('Erreur', 'Commande introuvable pour cette table.');
      return;
    }

    final currentOrder = order;
    if (currentOrder == null ||
        productIndex < 0 ||
        productIndex >= currentOrder.products.length) {
      return;
    }

    final line = currentOrder.products[productIndex];
    final catalog = catalogProductByName(line.name);
    if (catalog != null && selectedProductId.value == catalog.id) {
      selectedProductId.value = null;
    }
    if (selectedOrderLineIndex.value == productIndex) {
      selectedOrderLineIndex.value = null;
    }

    isAddingProduct.value = true;
    try {
      final updated = await _orderRepository.cancelOrderLineAtIndex(
        orderId: id,
        lineIndex: productIndex,
      );
      _syncOrderInSession(updated, orderNumber);
    } on ApiException catch (e) {
      ApiDebugDialog.show(
        title: 'Erreur annulation',
        body: '${_orderRepository.lastAddItemLog ?? ''}\n\nMESSAGE: ${e.message}',
      );
    } catch (_) {
      Get.snackbar('Erreur', 'Impossible d\'annuler l\'article.');
    } finally {
      isAddingProduct.value = false;
    }
  }
}
