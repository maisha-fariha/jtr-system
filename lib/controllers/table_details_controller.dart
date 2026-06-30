import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/network/api_exception.dart';
import '../data/models/catalog/catalog_product_model.dart';
import '../data/models/catalog/category_tree_node.dart';
import '../data/repositories/catalog_repository.dart';
import '../data/repositories/order_repository.dart';
import '../models/order_product.dart';
import '../models/session_order.dart';
import '../routes/app_pages.dart';
import '../widgets/api_debug_dialog.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/composed_product_picker_sheet.dart';
import '../widgets/table_number_dialog.dart';
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
  final activeToolbarIcon = Rx<IconData?>(Icons.grid_view);
  final isCatalogLoading = false.obs;
  final isAddingProduct = false.obs;
  final catalogError = RxnString();
  final categoryRoots = <CategoryTreeNode>[].obs;
  final categoryPath = <CategoryTreeNode>[].obs;
  final products = <CatalogProductModel>[].obs;

  late final String orderNumber;
  int? orderId;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    orderNumber = (args is Map ? args['orderNumber'] as String? : null) ?? '';
    final rawId = args is Map ? args['orderId'] : null;
    orderId = rawId is int ? rawId : (rawId is num ? rawId.toInt() : null);

    _loadCatalog();
    _refreshOrder();
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

  int productQuantityInOrder(CatalogProductModel product) {
    final currentOrder = order;
    if (currentOrder == null) return 0;
    final normalized = product.name.toUpperCase();
    for (final line in currentOrder.products) {
      if (line.name.toUpperCase() == normalized) {
        return int.tryParse(line.quantity) ?? 0;
      }
    }
    return 0;
  }

  bool isProductSelected(CatalogProductModel product) =>
      selectedProductId.value == product.id;

  bool isOrderLineSelected(OrderProduct line) {
    final catalog = catalogProductByName(line.name);
    return catalog != null && selectedProductId.value == catalog.id;
  }

  void selectOrderLine(OrderProduct line) {
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
  }

  void selectCatalogProduct(CatalogProductModel product) {
    selectedProductId.value = product.id;
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
  void navigateBackOrExitTable() {
    if (canNavigateCategoryBack) {
      navigateCategoryBack();
      activeToolbarIcon.value = Icons.grid_view;
      return;
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
    } else {
      isBottomPanelExpanded.value = true;
      activeToolbarIcon.value = Icons.grid_view;
    }
  }

  void showQuantityDialog({required BuildContext context}) {
    final product = selectedCatalogProduct;
    if (product == null) {
      isBottomPanelExpanded.value = true;
      showPaymentOptions.value = false;
      Get.snackbar(
        'Sélectionnez un produit',
        'Touchez un article dans la commande ou la grille avant le clavier.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    if (product.isComposed) {
      Get.snackbar(
        'Produit composé',
        'Ce produit se configure via le sélecteur de menu.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    final currentQty = productQuantityInOrder(product);

    TableNumberDialog.show(
      context: context,
      title: product.name.toUpperCase(),
      initialValue: currentQty > 0 ? '$currentQty' : null,
      integerOnly: true,
      maxDigits: 3,
      onConfirm: (value) {
        final selected = selectedCatalogProduct;
        if (selected == null) return;

        final parsed = int.tryParse(value.trim());
        if (parsed == null || parsed < 0) return;

        unawaited(_setProductQuantity(selected, parsed));
      },
    );
  }

  void onToolbarIconTap(IconData icon, {required BuildContext context}) {
    if (icon == Icons.home_outlined) {
      Get.offAllNamed(AppRoutes.session);
      return;
    }

    if (icon == Icons.keyboard_return_outlined) {
      navigateBackOrExitTable();
      return;
    }

    if (icon == Icons.grid_view) {
      showPaymentOptions.value = false;
      isBottomPanelExpanded.value = true;
      activeToolbarIcon.value = Icons.grid_view;
      showQuantityDialog(context: context);
      return;
    }

    if (icon == Icons.arrow_forward) {
      requestNextCourse(context: context);
      return;
    }

    if (icon == Icons.payments_outlined) {
      togglePaymentOptions();
      return;
    }

    if (icon == Icons.restaurant) {
      showPaymentOptions.value = false;
      isBottomPanelExpanded.value = true;
      activeToolbarIcon.value = icon;
      return;
    }

    if (icon == Icons.restaurant_menu) {
      final id = resolvedOrderId;
      if (id == null || id <= 0) {
        Get.snackbar('Erreur', 'Commande introuvable pour cette table.');
        return;
      }
      Get.toNamed(
        AppRoutes.menuSelection,
        arguments: {
          'orderNumber': orderNumber,
          'orderId': id,
        },
      );
      return;
    }

    activeToolbarIcon.value = icon;
  }

  bool isToolbarIconActive(IconData icon) => activeToolbarIcon.value == icon;

  bool isToolbarIconEnabled(IconData icon) => true;

  Future<void> requestNextCourse({BuildContext? context}) async {
    final id = resolvedOrderId;
    if (id == null || id <= 0) {
      Get.snackbar('Erreur', 'Commande introuvable pour cette table.');
      return;
    }

    AppConfirmDialog.show(
      context: context,
      title: 'Demander la suite',
      message:
          'Envoyer la demande À SUIVRE pour les articles de cette table ?\n'
          'Les prochains articles seront ajoutés à la suite suivante.',
      onConfirm: () async {
        isAddingProduct.value = true;
        try {
          final updated = await _orderRepository.requestNextCourses(id);
          _syncOrderInSession(updated, orderNumber);
          Get.snackbar(
            'Suite demandée',
            'La demande À SUIVRE a été envoyée.',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.all(16),
          );
        } on ApiException catch (e) {
          ApiDebugDialog.show(
            title: 'Erreur suite',
            body: e.message,
          );
        } catch (_) {
          Get.snackbar(
            'Erreur',
            'Impossible d\'envoyer la demande de suite.',
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
    if (isAddingProduct.value) return;

    final id = resolvedOrderId;
    if (id == null || id <= 0) {
      Get.snackbar('Erreur', 'Commande introuvable pour cette table.');
      return;
    }

    final wasAlreadySelected = selectedProductId.value == product.id;
    selectedProductId.value = product.id;

    if (wasAlreadySelected) return;

    isAddingProduct.value = true;
    try {
      if (product.isComposed) {
        final detail = await _catalogRepository.getProductDetail(product.id);
        await ComposedProductPickerSheet.show(
          product: detail,
          onConfirm: (selections) => _addComposedProduct(
            orderId: id,
            product: detail,
            menuSelections: selections,
            displayNumber: orderNumber,
          ),
        );
      } else {
        final updated = await _orderRepository.addSimpleProductToOrder(
          orderId: id,
          productId: product.id,
          unitPrice: product.unitPrice,
          qty: 1,
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
    } finally {
      isAddingProduct.value = false;
    }
  }

  Future<void> _setProductQuantity(
    CatalogProductModel product,
    int qty,
  ) async {
    final id = resolvedOrderId;
    if (id == null || id <= 0) return;

    isAddingProduct.value = true;
    try {
      final updated = await _orderRepository.setProductQuantityInOrder(
        orderId: id,
        productId: product.id,
        qty: qty,
        unitPrice: product.unitPrice,
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

  void _syncOrderInSession(SessionOrder updated, String displayNumber) {
    if (!Get.isRegistered<SessionController>()) return;
    Get.find<SessionController>().updateOrderRow(
      updated.copyWith(number: displayNumber),
    );
  }

  bool isProductInOrder(CatalogProductModel product) {
    final currentOrder = order;
    if (currentOrder == null) return false;
    final normalized = product.name.toUpperCase();
    return currentOrder.products.any(
      (line) => line.name.toUpperCase() == normalized,
    );
  }

  void incrementProduct(int productIndex) {
    if (!Get.isRegistered<SessionController>()) return;
    Get.find<SessionController>()
        .adjustOrderProductQuantity(orderNumber, productIndex, 1);
  }

  void decrementProduct(int productIndex) {
    if (!Get.isRegistered<SessionController>()) return;
    Get.find<SessionController>()
        .adjustOrderProductQuantity(orderNumber, productIndex, -1);
  }

  void offerProduct(int productIndex) {
    if (!Get.isRegistered<SessionController>()) return;
    Get.find<SessionController>()
        .applyOfferToOrderProduct(orderNumber, productIndex);
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
