import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/network/api_exception.dart';
import '../data/models/catalog/catalog_product_model.dart';
import '../data/models/catalog/category_tree_node.dart';
import '../data/repositories/catalog_repository.dart';
import '../data/repositories/order_repository.dart';
import '../models/session_order.dart';
import '../routes/app_pages.dart';
import '../widgets/api_debug_dialog.dart';
import '../widgets/composed_product_picker_sheet.dart';
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
  final showQuantityKeypad = false.obs;
  final quantityInput = ''.obs;
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

  int get pendingQuantity {
    final parsed = int.tryParse(quantityInput.value);
    if (parsed != null && parsed > 0) return parsed;
    return 1;
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

    if (showQuantityKeypad.value) {
      toggleQuantityKeypad();
      return;
    }

    Get.back();
  }

  void toggleBottomPanel() {
    isBottomPanelExpanded.value = !isBottomPanelExpanded.value;
    if (isBottomPanelExpanded.value) {
      showPaymentOptions.value = false;
      activeToolbarIcon.value = Icons.grid_view;
    } else if (!showPaymentOptions.value && !showQuantityKeypad.value) {
      activeToolbarIcon.value = null;
    }
  }

  void togglePaymentOptions() {
    final show = !showPaymentOptions.value;
    showPaymentOptions.value = show;
    if (show) {
      isBottomPanelExpanded.value = false;
      showQuantityKeypad.value = false;
      quantityInput.value = '';
      activeToolbarIcon.value = Icons.payments_outlined;
    } else {
      isBottomPanelExpanded.value = true;
      activeToolbarIcon.value = Icons.grid_view;
    }
  }

  void toggleQuantityKeypad() {
    final show = !showQuantityKeypad.value;
    showQuantityKeypad.value = show;
    if (show) {
      showPaymentOptions.value = false;
      isBottomPanelExpanded.value = true;
      quantityInput.value = '';
      activeToolbarIcon.value = Icons.dialpad_outlined;
    } else {
      quantityInput.value = '';
      activeToolbarIcon.value = Icons.grid_view;
    }
  }

  void onToolbarIconTap(IconData icon) {
    if (icon == Icons.home_outlined) {
      Get.offAllNamed(AppRoutes.session);
      return;
    }

    if (icon == Icons.keyboard_return_outlined || icon == Icons.arrow_back) {
      navigateBackOrExitTable();
      return;
    }

    if (icon == Icons.dialpad_outlined) {
      toggleQuantityKeypad();
      return;
    }

    if (icon == Icons.payments_outlined) {
      togglePaymentOptions();
      return;
    }

    if (icon == Icons.grid_view || icon == Icons.restaurant) {
      showPaymentOptions.value = false;
      showQuantityKeypad.value = false;
      quantityInput.value = '';
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

  Future<void> onProductTap(CatalogProductModel product) async {
    if (isAddingProduct.value) return;

    final id = resolvedOrderId;
    if (id == null || id <= 0) {
      Get.snackbar('Erreur', 'Commande introuvable pour cette table.');
      return;
    }

    final qty = pendingQuantity;
    final hadCustomQty = quantityInput.value.isNotEmpty;

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
          qty: qty,
        );
        _syncOrderInSession(updated, orderNumber);
      }

      if (hadCustomQty) {
        quantityInput.value = '';
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

  void setProductMessage({
    required int productIndex,
    required String message,
  }) {
    if (!Get.isRegistered<SessionController>()) return;
    Get.find<SessionController>().setOrderProductMessage(
      orderNumber,
      productIndex,
      message,
    );
  }
}
