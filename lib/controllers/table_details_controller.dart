import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/network/api_exception.dart';
import '../data/models/catalog/catalog_product_model.dart';
import '../data/models/catalog/leaf_category_model.dart';
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
  final activeToolbarIcon = Rx<IconData?>(Icons.grid_view);
  final isCatalogLoading = false.obs;
  final isAddingProduct = false.obs;
  final catalogError = RxnString();
  final categories = <LeafCategoryModel>[].obs;
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
      final loadedCategories = await _catalogRepository.getLeafCategories();
      final loadedProducts = await _catalogRepository.getProducts();
      categories.assignAll(loadedCategories);
      products.assignAll(loadedProducts);
      if (selectedCategoryIndex.value >= categories.length) {
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

  List<CatalogProductModel> get currentProducts {
    if (categories.isEmpty) return const [];
    final category = categories[selectedCategoryIndex.value];
    return _catalogRepository.productsForCategory(products, category.id);
  }

  LeafCategoryModel? get currentCategory {
    if (categories.isEmpty) return null;
    return categories[selectedCategoryIndex.value];
  }

  void selectCategory(int index) => selectedCategoryIndex.value = index;

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

  void onToolbarIconTap(IconData icon) {
    if (icon == Icons.home_outlined) {
      Get.offAllNamed(AppRoutes.session);
      return;
    }

    if (icon == Icons.keyboard_return_outlined) {
      Get.back();
      return;
    }

    if (icon == Icons.payments_outlined) {
      togglePaymentOptions();
      return;
    }

    if (icon == Icons.grid_view || icon == Icons.restaurant) {
      showPaymentOptions.value = false;
      isBottomPanelExpanded.value = true;
      activeToolbarIcon.value = icon;
      return;
    }

    if (icon == Icons.restaurant_menu) {
      Get.toNamed(
        AppRoutes.menuSelection,
        arguments: {'orderNumber': orderNumber},
      );
      return;
    }

    activeToolbarIcon.value = icon;
  }

  bool isToolbarIconActive(IconData icon) => activeToolbarIcon.value == icon;

  Future<void> onProductTap(CatalogProductModel product) async {
    if (isAddingProduct.value) return;

    final currentOrder = order;
    if (currentOrder == null || currentOrder.id <= 0) {
      Get.snackbar('Erreur', 'Commande introuvable pour cette table.');
      return;
    }

    isAddingProduct.value = true;
    try {
      if (product.isComposed) {
        final detail = await _catalogRepository.getProductDetail(product.id);
        await ComposedProductPickerSheet.show(
          product: detail,
          onConfirm: (selections) => _addComposedProduct(
            orderId: currentOrder.id,
            product: detail,
            menuSelections: selections,
            displayNumber: currentOrder.number,
          ),
        );
      } else {
        final updated = await _orderRepository.addSimpleProductToOrder(
          orderId: currentOrder.id,
          productId: product.id,
          unitPrice: product.unitPrice,
        );
        _syncOrderInSession(updated, currentOrder.number);
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
