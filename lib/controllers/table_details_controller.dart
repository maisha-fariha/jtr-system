import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/network/api_exception.dart';
import '../data/mappers/order_mapper.dart';
import '../data/models/catalog/catalog_product_model.dart';
import '../data/models/catalog/category_tree_node.dart';
import '../data/order_optimistic_sync.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/catalog_repository.dart';
import '../data/repositories/order_repository.dart';
import '../data/mappers/menu_mapper.dart';
import '../models/order_product.dart';
import '../models/order_display_entry.dart';
import '../models/session_order.dart';
import '../models/menu_active_selection.dart';
import '../routes/app_pages.dart';
import '../utils/api_log.dart';
import '../widgets/api_debug_dialog.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/menu_message_typing_dialog.dart';
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
  final OrderOptimisticSync _optimisticSync = OrderOptimisticSync();

  final selectedCategoryIndex = 0.obs;
  final isBottomPanelExpanded = true.obs;
  final showPaymentOptions = false.obs;
  final selectedProductId = RxnInt();
  final selectedOrderLineIndex = RxnInt();
  final activeToolbarIcon = Rx<IconData?>(Icons.grid_view);
  final isCatalogLoading = false.obs;
  final isAddingProduct = false.obs;
  /// `true` = cash payment in progress, `false` = card, `null` = idle.
  final payingIsCash = Rxn<bool>();
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

  /// When true (fresh empty create), skip blocking GET detail on open.
  bool _deferDetailFetch = false;

  /// Snapshot from navigation — avoids empty flashes and keeps latest total.
  SessionOrder? seedOrder;

  final collapsedSuivreSections = <int>{}.obs;
  final expandedMenuLineIndices = <int>{}.obs;
  final selectedSuivreSection = RxnInt();
  final suivreUiRevision = 0.obs;
  final orderUiRevision = 0.obs;

  /// Undo banner after a line delete, e.g. `1 PIZZA TONNO supprimé(e)`.
  final undoDeleteLabel = RxnString();
  Timer? _pendingDeleteTimer;
  SessionOrder? _pendingDeleteSnapshot;
  int? _pendingDeleteLineIndex;
  int _pendingDeleteGeneration = 0;

  static const _undoDeleteDuration = Duration(seconds: 5);

  bool isSuivreSectionCollapsed(int sectionIndex) =>
      collapsedSuivreSections.contains(sectionIndex);

  bool isMenuLineExpanded(int lineIndex) =>
      expandedMenuLineIndices.contains(lineIndex);

  void toggleMenuLineExpansion(int lineIndex) {
    if (expandedMenuLineIndices.contains(lineIndex)) {
      expandedMenuLineIndices.remove(lineIndex);
    } else {
      expandedMenuLineIndices.add(lineIndex);
    }
    expandedMenuLineIndices.refresh();
    orderUiRevision.value++;
  }

  /// Tap on a product row: select it, and toggle menu choices expand/collapse.
  void onOrderLineRowTap(int lineIndex, OrderProduct product) {
    selectOrderLine(lineIndex, product);
    if (product.hasMenuItems) {
      toggleMenuLineExpansion(lineIndex);
    }
  }

  Future<void> editOrderLineComment(
    int lineIndex, {
    BuildContext? context,
  }) async {
    final current = order;
    if (current == null ||
        lineIndex < 0 ||
        lineIndex >= current.products.length) {
      return;
    }

    final product = current.products[lineIndex];
    await MenuMessageTypingDialog.show(
      context: context,
      itemLabel: product.name,
      initialMessage: product.message ?? '',
      onSave: (message) => unawaited(
        _saveOrderLineComment(lineIndex: lineIndex, comment: message),
      ),
    );
  }

  Future<void> _saveOrderLineComment({
    required int lineIndex,
    required String comment,
  }) async {
    final id = resolvedOrderId;
    final current = order;
    if (id == null || id <= 0 || current == null) return;
    if (lineIndex < 0 || lineIndex >= current.products.length) return;

    final trimmed = comment.trim();
    final snapshot = OrderOptimisticSync.deepSnapshot(current);
    final updatedProducts = [...current.products];
    updatedProducts[lineIndex] = current.products[lineIndex].copyWith(
      message: trimmed.isEmpty ? null : trimmed,
      clearMessage: trimmed.isEmpty,
    );
    final updatedEntries = [
      for (final entry in current.displayEntries)
        if (entry.type == OrderDisplayEntryType.product &&
            entry.lineIndex == lineIndex &&
            entry.product != null)
          OrderDisplayEntry.product(
            product: entry.product!.copyWith(
              message: trimmed.isEmpty ? null : trimmed,
              clearMessage: trimmed.isEmpty,
            ),
            lineIndex: lineIndex,
            sectionIndex: entry.sectionIndex ?? 0,
            courseNumber: entry.courseNumber,
          )
        else
          entry,
    ];
    _syncOrderInSession(
      current.copyWith(
        products: updatedProducts,
        displayEntries: updatedEntries,
      ),
      orderNumber,
      displayEntriesOverride: updatedEntries,
    );

    _optimisticSync.enqueue(
      syncKey: _optimisticSyncKey,
      snapshot: snapshot,
      apply: (updated) {
        if (updated.id > 0) orderId = updated.id;
        _syncOrderInSession(updated, orderNumber);
      },
      sync: () async {
        final updated = await _orderRepository.updateOrderLineCommentAtIndex(
          orderId: id,
          lineIndex: lineIndex,
          comment: trimmed,
        );
        if (updated.id > 0) orderId = updated.id;
        return updated;
      },
      recover: (snap) async {
        try {
          return await _orderRepository.getOrderDetail(
            id,
            previousDisplayEntries: snap.displayEntries,
          );
        } catch (_) {
          return snap;
        }
      },
      onError: (error) =>
          _showOptimisticMutationError('enregistrer le message', error),
    );
  }

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
    _deferDetailFetch = args is Map && args['deferDetailFetch'] == true;
    final rawSeed = args is Map ? args['seedOrder'] : null;
    if (rawSeed is SessionOrder) {
      seedOrder = rawSeed;
      if ((orderId == null || orderId! <= 0) && rawSeed.id > 0) {
        orderId = rawSeed.id;
      }
      if (orderNumber.isEmpty) {
        orderNumber = rawSeed.number;
      }
    }
    logOrderFlow(
      'TableDetailsController.onInit table=$orderNumber '
      'orderId=${orderId ?? 'none'} deferDetailFetch=$_deferDetailFetch '
      'hasSeed=${seedOrder != null}',
    );

    _loadCatalog();
    unawaited(_bootstrapOrder());
  }

  Future<void> _bootstrapOrder() async {
    // Fresh empty create already has a local shell — open immediately.
    if (_deferDetailFetch && orderId != null && orderId! > 0) {
      return;
    }
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

  Future<void> _refreshOrder({
    List<OrderDisplayEntry>? layoutBeforeNav,
  }) async {
    if (_optimisticSync.hasPending(_optimisticSyncKey)) return;
    if (!Get.isRegistered<SessionController>()) return;

    final current = order;
    // Local-only shell has no remote detail yet.
    if (current != null && current.isLocalOnly) return;

    if (current != null && current.id > 0) {
      orderId = current.id;
    }

    // Session list rows are lightweight (total only, no lines). Always fetch
    // GET /api/orders/:id so table details can show seat_orders items.
    await Get.find<SessionController>().loadOrderDetails(
      orderNumber,
      orderId: orderId,
      forceRefresh: true,
      previousDisplayEntries: layoutBeforeNav ?? order?.displayEntries,
    );
  }

  SessionOrder? get order {
    if (!Get.isRegistered<SessionController>()) return seedOrder;
    return Get.find<SessionController>().findOrder(
          orderNumber: orderNumber,
          orderId: orderId,
        ) ??
        seedOrder;
  }

  int? get resolvedOrderId {
    if (orderId != null && orderId! > 0) return orderId;
    final current = order;
    if (current != null && current.id > 0) return current.id;
    return null;
  }

  /// Cached API order id — no network verification (hot path for optimistic UI).
  int? get _fastResolvedOrderId => resolvedOrderId;

  int get _optimisticSyncKey => orderNumber.hashCode;

  int get _parsedTableNumber {
    final normalized = orderNumber.replaceFirst(RegExp(r'^T'), '').trim();
    return int.tryParse(normalized) ?? 0;
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
      await _orderRepository.getOrderDetail(
        id,
        previousDisplayEntries: order?.displayEntries,
      );
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
    final layoutBeforeNav = order?.displayEntries == null
        ? null
        : List<OrderDisplayEntry>.from(order!.displayEntries);
    final id = await _ensureResolvedOrderId();

    final menuAdded = await Get.toNamed(
      AppRoutes.menuSelection,
      arguments: {
        'orderNumber': orderNumber,
        if (id != null && id > 0) 'orderId': id,
      },
    );

    if (menuAdded == true) {
      orderUiRevision.value++;
      return;
    }

    _restoreDisplayLayoutIfNeeded(layoutBeforeNav);
    orderUiRevision.value++;
  }

  void _restoreDisplayLayoutIfNeeded(List<OrderDisplayEntry>? layout) {
    if (layout == null || layout.isEmpty) return;

    final current = order;
    if (current == null) return;

    final currentSuivreCount =
        OrderMapper.suivreSeparatorCount(current.displayEntries);
    final savedSuivreCount = OrderMapper.suivreSeparatorCount(layout);
    if (savedSuivreCount <= currentSuivreCount) return;

    _syncOrderInSession(
      current.copyWith(displayEntries: layout),
      orderNumber,
      displayEntriesOverride: layout,
    );
  }

  Future<void> navigateBackOrExitTable() async {
    if (canNavigateCategoryBack) {
      navigateCategoryBack();
      activeToolbarIcon.value = Icons.grid_view;
      return;
    }

    final currentOrder = order;
    if (Get.isRegistered<SessionController>() && currentOrder != null) {
      // Sync this table's row only — do not force-refresh the whole session
      // list (that re-sorts and moves rows when returning from details).
      Get.find<SessionController>().updateOrderRow(currentOrder);
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

  bool get isPaying => payingIsCash.value != null;

  bool get isPayingCash => payingIsCash.value == true;

  bool get isPayingCard => payingIsCash.value == false;

  bool get canPay =>
      resolvedOrderId != null &&
      (order?.products.isNotEmpty ?? false) &&
      !isPaying &&
      !paymentModesLoading.value;

  bool get canSendToKitchen {
    final currentOrder = order;
    if (currentOrder == null) return false;
    if (currentOrder.products.isEmpty) return false;
    if (resolvedOrderId == null || resolvedOrderId! <= 0) return false;
    if (isAddingProduct.value) return false;
    return true;
  }

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
    if (!isToolbarIconEnabled(icon)) {
      if (icon == Icons.send_outlined) {
        Get.snackbar(
          'Envoi indisponible',
          'Ajoutez des articles à une commande active avant l\'envoi.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.all(16),
        );
      }
      return;
    }

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

  bool isToolbarIconEnabled(IconData icon) {
    if (icon == Icons.send_outlined) {
      return canSendToKitchen;
    }
    return true;
  }

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
    final id = await _ensureResolvedOrderId();
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
          // requestAllCourses already prints the raw request/response log,
          // but we mirror it here so it is visible even if logs are filtered.
          if (_orderRepository.lastKitchenSendLog != null) {
            debugPrint(_orderRepository.lastKitchenSendLog);
          }
          Get.snackbar(
            'Envoyé',
            'La commande a été envoyée en cuisine.',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.all(16),
          );
        } on ApiException catch (e) {
          if (_orderRepository.lastKitchenSendLog != null) {
            debugPrint(_orderRepository.lastKitchenSendLog);
          }
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

  Future<bool> _orderNeedsKitchenSendBeforePayment(int orderId) async {
    try {
      final cached = _orderRepository.cachedOrderDetail(orderId);
      if (cached != null) {
        return OrderMapper.requiresKitchenSendBeforePayment(cached);
      }
      await _orderRepository.getOrderDetail(orderId);
      final detail = _orderRepository.cachedOrderDetail(orderId);
      return detail != null &&
          OrderMapper.requiresKitchenSendBeforePayment(detail);
    } catch (_) {
      return false;
    }
  }

  Future<void> payOrder({required BuildContext context, required bool isCash}) async {
    final id = resolvedOrderId;
    if (id == null || id <= 0) {
      Get.snackbar('Erreur', 'Commande introuvable pour cette table.');
      return;
    }

    final currentOrder = order;
    if (currentOrder == null || currentOrder.products.isEmpty) {
      Get.snackbar(
        'Paiement indisponible',
        'Aucun article à encaisser sur cette commande.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
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
    final needsKitchenSend = await _orderNeedsKitchenSendBeforePayment(id);
    final sendNotice = needsKitchenSend
        ? '\n\nLes articles non envoyés seront transmis en cuisine avant l\'encaissement.'
        : '';
    AppConfirmDialog.show(
      context: context,
      title: 'Paiement',
      message:
          'Encaisser $amountLabel pour la table $orderNumber en $label ?$sendNotice',
      onConfirm: () async {
        payingIsCash.value = isCash;
        try {
          final updated = await _orderRepository.payOrder(
            orderId: id,
            isCash: isCash,
            previousDisplayEntries: currentOrder.displayEntries,
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
          Get.snackbar(
            'Erreur paiement',
            e.message,
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 4),
            margin: const EdgeInsets.all(16),
          );
          debugPrint(_orderRepository.lastPaymentLog);
        } catch (e) {
          Get.snackbar(
            'Erreur',
            'Impossible d\'enregistrer le paiement.',
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(16),
          );
          debugPrint(_orderRepository.lastPaymentLog);
          debugPrint('payOrder unexpected: $e');
        } finally {
          payingIsCash.value = null;
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
    // À SUIVRE divider stores the "course above" number used to route new
    // items into the next course. When user taps Demande for that divider,
    // we must request the follow-up service (= courseNumber + 1).
    final demandeCourseNumber = courseNumber != null ? courseNumber + 1 : null;

    if (demandeCourseNumber == null || demandeCourseNumber <= 0) {
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
          'Envoyer en cuisine le service sélectionné (course $demandeCourseNumber) ?',
      onConfirm: () async {
        isAddingProduct.value = true;
        try {
          final orderSnapshot = order;
          final updated = await _orderRepository.requestCourseForSuivreSection(
            id,
            courseNumber: demandeCourseNumber,
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

  void onProductTap(CatalogProductModel product) {
    logOrderFlow(
      'onProductTap product=${product.id} ${product.name} table=$orderNumber',
    );

    selectedProductId.value = product.id;

    if (product.isComposed) {
      unawaited(_handleComposedProductTap(product));
      return;
    }

    final rollbackSnapshot =
        order != null ? OrderOptimisticSync.deepSnapshot(order!) : null;

    _applyAddSimpleProductToUi(product);
    unawaited(
      _syncAddSimpleProductInBackground(
        product: product,
        rollbackSnapshot: rollbackSnapshot,
      ),
    );
  }

  Future<void> _handleComposedProductTap(CatalogProductModel product) async {
    try {
      final layoutHints = order?.displayEntries;
      final detail = await _catalogRepository.getProductDetail(product.id);
      final presetMenu = MenuMapper.presetFromProduct(
        detail,
        badgeNumber: 1,
      );

      final result = await Get.toNamed(
        AppRoutes.menu,
        arguments: {
          'table': orderNumber,
          'presetMenu': presetMenu,
          'choiceNumber': 1,
          'returnToSelection': false,
        },
      );

      if (result is! MenuActiveSelection) return;

      final menuSelections = MenuMapper.menuSelectionsFromItems(
        result.allSelectedItems,
      );
      if (menuSelections.isEmpty) return;

      final rollbackSnapshot =
          order != null ? OrderOptimisticSync.deepSnapshot(order!) : null;

      _applyAddComposedProductToUi(
        product: detail,
        menuSelections: menuSelections,
        layoutHints: layoutHints,
      );
      unawaited(
        _syncAddComposedProductInBackground(
          product: detail,
          menuSelections: menuSelections,
          rollbackSnapshot: rollbackSnapshot,
          layoutHints: layoutHints,
        ),
      );
    } on ApiException catch (e) {
      debugPrint(_orderRepository.lastAddItemLog);
      ApiDebugDialog.show(title: 'Erreur ajout article', body: e.message);
    } catch (_) {
      Get.snackbar('Erreur', 'Impossible d\'ajouter l\'article.');
    }
  }

  void _applyAddSimpleProductToUi(CatalogProductModel product) {
    var current = order;
    if (current == null) {
      current = OrderMapper.buildSessionPlaceholderOrder(
        tableNumber: _parsedTableNumber,
        numberOfGuests: 1,
      );
    }

    final layoutHints = current.displayEntries;
    final suivreCount = OrderMapper.suivreSeparatorCount(layoutHints);
    final suivreSplits = OrderMapper.suivreSplitPositions(layoutHints);
    final fastId = _fastResolvedOrderId;
    final cached =
        fastId != null ? _orderRepository.cachedOrderDetail(fastId) : null;

    final predicted = OrderMapper.predictAfterAppendSimpleProduct(
      current: current,
      cachedDetail: cached,
      productId: product.id,
      productName: product.name,
      unitPrice: product.unitPrice,
      suivreSectionCount: suivreCount,
      suivreSplitHints: suivreSplits,
    );
    _syncOrderInSession(predicted, orderNumber);
  }

  void _applyAddComposedProductToUi({
    required CatalogProductModel product,
    required List<Map<String, dynamic>> menuSelections,
    List<OrderDisplayEntry>? layoutHints,
  }) {
    var current = order;
    if (current == null) {
      current = OrderMapper.buildSessionPlaceholderOrder(
        tableNumber: _parsedTableNumber,
        numberOfGuests: 1,
      );
    }

    final hints = layoutHints ?? current.displayEntries;
    final suivreCount = OrderMapper.suivreSeparatorCount(hints);
    final suivreSplits = OrderMapper.suivreSplitPositions(hints);
    final fastId = _fastResolvedOrderId;
    final cached =
        fastId != null ? _orderRepository.cachedOrderDetail(fastId) : null;

    final predicted = OrderMapper.predictAfterAppendComposedProduct(
      current: current,
      cachedDetail: cached,
      productId: product.id,
      productName: product.name,
      basePrice: product.unitPrice,
      menuSelections: menuSelections,
      suivreSectionCount: suivreCount,
      suivreSplitHints: suivreSplits,
      layoutHints: hints,
    );
    _syncOrderInSession(predicted, orderNumber);
    if (predicted.products.isNotEmpty) {
      final newLineIndex = predicted.products.length - 1;
      expandedMenuLineIndices.add(newLineIndex);
      expandedMenuLineIndices.refresh();
      orderUiRevision.value++;
    }
  }

  Future<void> _syncAddComposedProductInBackground({
    required CatalogProductModel product,
    required List<Map<String, dynamic>> menuSelections,
    SessionOrder? rollbackSnapshot,
    List<OrderDisplayEntry>? layoutHints,
  }) async {
    final snapshot = rollbackSnapshot ??
        order ??
        OrderMapper.buildSessionPlaceholderOrder(
          tableNumber: _parsedTableNumber,
          numberOfGuests: 1,
        );
    final effectiveLayoutHints = layoutHints ?? snapshot.displayEntries;

    _optimisticSync.enqueue(
      syncKey: _optimisticSyncKey,
      snapshot: snapshot,
      apply: (updated) {
        orderId = updated.id > 0 ? updated.id : orderId;
        _syncOrderInSession(updated, orderNumber);
      },
      sync: () async {
        final id = await _resolveOrderIdForBackgroundSync();
        if (id == null || id <= 0) {
          final created =
              await _orderRepository.createOrderWithFirstComposedProduct(
            tableNumber: orderNumber,
            waiterId: _currentWaiterId,
            productId: product.id,
            basePrice: product.unitPrice,
            menuSelections: menuSelections,
            numberOfGuests: int.tryParse(snapshot.couverts),
          );
          orderId = created.id;
          return created;
        }

        orderId = id;
        final updated = await _orderRepository.addComposedProductToOrder(
          orderId: id,
          productId: product.id,
          basePrice: product.unitPrice,
          menuSelections: menuSelections,
          layoutHints: effectiveLayoutHints,
          tableNumber: orderNumber,
          waiterId: _currentWaiterId,
          expectEmptyShell: snapshot.products.isEmpty,
        );
        orderId = updated.id;
        return updated;
      },
      recover: (snap) async {
        final id = _fastResolvedOrderId;
        if (id != null && id > 0) {
          return _orderRepository.getOrderDetail(
            id,
            previousDisplayEntries: snap.displayEntries,
          );
        }
        return snap;
      },
      onError: (error) =>
          _showOptimisticMutationError('ajouter le menu', error),
    );
  }

  Future<void> _syncAddSimpleProductInBackground({
    required CatalogProductModel product,
    SessionOrder? rollbackSnapshot,
  }) async {
    final snapshot = rollbackSnapshot ??
        order ??
        OrderMapper.buildSessionPlaceholderOrder(
          tableNumber: _parsedTableNumber,
          numberOfGuests: 1,
        );

    _optimisticSync.enqueue(
      syncKey: _optimisticSyncKey,
      snapshot: snapshot,
      apply: (updated) {
        orderId = updated.id > 0 ? updated.id : orderId;
        _syncOrderInSession(updated, orderNumber);
      },
      sync: () async {
        final id = await _resolveOrderIdForBackgroundSync();
        // Keep the tap-time layout as source of truth so open À SUIVRE sections
        // don't get lost when background responses arrive out of order.
        final layoutHints = snapshot.displayEntries;

        if (id == null || id <= 0) {
          final created =
              await _orderRepository.createOrderWithFirstSimpleProduct(
            tableNumber: orderNumber,
            waiterId: _currentWaiterId,
            productId: product.id,
            unitPrice: product.unitPrice,
            qty: 1,
            numberOfGuests: int.tryParse(snapshot.couverts),
          );
          orderId = created.id;
          return created;
        }

        // Empty UI shell may still point at a backend order that was auto
        // closed/paid when the last item was cancelled — recreate if needed.
        orderId = id;
        final updated = await _orderRepository.addSimpleProductToOrder(
          orderId: id,
          productId: product.id,
          unitPrice: product.unitPrice,
          qty: 1,
          layoutHints: layoutHints,
          tableNumber: orderNumber,
          waiterId: _currentWaiterId,
          expectEmptyShell: snapshot.products.isEmpty,
        );
        orderId = updated.id;
        return updated;
      },
      recover: (snap) async {
        final id = _fastResolvedOrderId;
        if (id != null && id > 0) {
          return _orderRepository.getOrderDetail(
            id,
            previousDisplayEntries: snap.displayEntries,
          );
        }
        return snap;
      },
      onError: (error) => _showOptimisticMutationError('ajouter l\'article', error),
    );
  }

  Future<int?> _resolveOrderIdForBackgroundSync() async {
    final fast = _fastResolvedOrderId;
    if (fast != null && fast > 0) return fast;

    // Local session-only shell (id <= 0): create with the first selected item
    // instead of attaching whatever order the table list might still reference.
    final current = order;
    if (orderId == null || orderId! <= 0) {
      if (current == null || current.isLocalOnly) {
        return null;
      }
    }

    final resolved =
        await _orderRepository.resolveOrderIdForTableNumber(orderNumber);
    if (resolved != null && resolved > 0) {
      orderId = resolved;
      return resolved;
    }

    // Prefer the id we already opened with (create / seedOrder) when tables
    // list has not yet published the new active order.
    if (orderId != null && orderId! > 0) return orderId;
    if (current != null && current.id > 0 && !current.isLocalOnly) {
      return current.id;
    }
    return null;
  }

  Future<void> _setOrderLineQuantity(int lineIndex, int qty) async {
    final id = resolvedOrderId;
    if (id == null || id <= 0) return;

    final current = order;
    if (current == null) return;

    await _optimisticSetLineQuantity(
      orderId: id,
      current: current,
      lineIndex: lineIndex,
      qty: qty,
    );
  }

  void _syncOrderInSession(
    SessionOrder updated,
    String displayNumber, {
    List<OrderDisplayEntry>? displayEntriesOverride,
  }) {
    if (!Get.isRegistered<SessionController>()) return;

    var displayEntries = displayEntriesOverride ?? updated.displayEntries;
    final synced = updated.copyWith(
      displayEntries: displayEntries,
    );

    // Keep seed in sync so back-navigation always has the latest total.
    if (seedOrder != null &&
        (seedOrder!.id == synced.id ||
            seedOrder!.number == synced.number ||
            seedOrder!.number == displayNumber)) {
      seedOrder = synced;
    }

    Get.find<SessionController>().updateOrderRow(synced);
    orderUiRevision.value++;

    final id = synced.id;
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
      debugPrint(_orderRepository.lastAddItemLog);
      ApiDebugDialog.show(title: 'Erreur offre', body: e.message);
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
        cancelOrderLine(productIndex);
        return;
      }
    }

    await _optimisticAdjustLineQuantity(
      orderId: id,
      current: currentOrder,
      lineIndex: productIndex,
      delta: delta,
    );
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
        if (updated.id > 0) orderId = updated.id;
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
      debugPrint(_orderRepository.lastAddItemLog);
      ApiDebugDialog.show(title: 'Erreur annulation', body: e.message);
    } catch (_) {
      Get.snackbar('Erreur', 'Impossible d\'annuler cette suite.');
    } finally {
      isAddingProduct.value = false;
    }
  }

  void cancelOrderLine(int productIndex) {
    unawaited(_cancelOrderLine(productIndex));
  }

  Future<void> _cancelOrderLine(int productIndex) async {
    // Finish any previous deferred delete before starting a new one.
    await _commitPendingDeleteIfAny();

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

    final snapshot = OrderOptimisticSync.deepSnapshot(currentOrder);
    final predicted = OrderMapper.predictAfterCancelLineAtIndex(
      currentOrder,
      productIndex,
    );
    _syncOrderInSession(predicted, orderNumber);

    final qtyLabel = line.quantity.trim().isEmpty ? '1' : line.quantity.trim();
    undoDeleteLabel.value =
        '$qtyLabel ${line.name.trim().toUpperCase()} supprimé(e)';

    _pendingDeleteSnapshot = snapshot;
    _pendingDeleteLineIndex = productIndex;
    final generation = ++_pendingDeleteGeneration;
    _pendingDeleteTimer?.cancel();
    _pendingDeleteTimer = Timer(_undoDeleteDuration, () {
      if (generation != _pendingDeleteGeneration) return;
      unawaited(_commitPendingDeleteIfAny());
    });
  }

  void undoPendingDelete() {
    final snapshot = _pendingDeleteSnapshot;
    if (snapshot == null) return;

    _pendingDeleteTimer?.cancel();
    _pendingDeleteTimer = null;
    _pendingDeleteSnapshot = null;
    _pendingDeleteLineIndex = null;
    _pendingDeleteGeneration++;
    undoDeleteLabel.value = null;

    _syncOrderInSession(snapshot, orderNumber);
  }

  Future<void> _commitPendingDeleteIfAny() async {
    final lineIndex = _pendingDeleteLineIndex;
    final snapshot = _pendingDeleteSnapshot;
    if (lineIndex == null || snapshot == null) return;

    _pendingDeleteTimer?.cancel();
    _pendingDeleteTimer = null;
    _pendingDeleteLineIndex = null;
    _pendingDeleteSnapshot = null;
    undoDeleteLabel.value = null;

    await _syncCancelLineInBackground(
      lineIndex: lineIndex,
      rollbackSnapshot: snapshot,
    );
  }

  @override
  void onClose() {
    _pendingDeleteTimer?.cancel();
    // Persist the delete if the waiter leaves before the undo window ends.
    final lineIndex = _pendingDeleteLineIndex;
    final snapshot = _pendingDeleteSnapshot;
    _pendingDeleteLineIndex = null;
    _pendingDeleteSnapshot = null;
    undoDeleteLabel.value = null;
    if (lineIndex != null && snapshot != null) {
      unawaited(
        _syncCancelLineInBackground(
          lineIndex: lineIndex,
          rollbackSnapshot: snapshot,
        ),
      );
    }
    super.onClose();
  }

  Future<void> _syncCancelLineInBackground({
    required int lineIndex,
    required SessionOrder rollbackSnapshot,
  }) async {
    _optimisticSync.enqueue(
      syncKey: _optimisticSyncKey,
      snapshot: rollbackSnapshot,
      apply: (updated) {
        // Emptying may replace a closed/paid shell with a new remote order id.
        if (updated.id > 0) orderId = updated.id;
        _syncOrderInSession(updated, orderNumber);
      },
      sync: () async {
        final id = await _resolveOrderIdForBackgroundSync();
        if (id == null || id <= 0) {
          return order ?? rollbackSnapshot;
        }

        orderId = id;
        final updated = await _orderRepository.cancelOrderLineAtIndex(
          orderId: id,
          lineIndex: lineIndex,
        );
        if (updated.id > 0) orderId = updated.id;
        return updated;
      },
      recover: (snap) async {
        final id = _fastResolvedOrderId;
        if (id != null && id > 0) {
          return _orderRepository.getOrderDetail(
            id,
            previousDisplayEntries: snap.displayEntries,
          );
        }
        return snap;
      },
      onError: (error) =>
          _showOptimisticMutationError('annuler l\'article', error),
    );
  }

  Future<void> _optimisticAdjustLineQuantity({
    required int orderId,
    required SessionOrder current,
    required int lineIndex,
    required int delta,
  }) async {
    final snapshot = OrderOptimisticSync.deepSnapshot(current);

    final predicted = OrderMapper.predictAfterAdjustLineQuantityAtIndex(
      current: current,
      lineIndex: lineIndex,
      delta: delta,
    );
    _syncOrderInSession(predicted, orderNumber);

    _optimisticSync.enqueue(
      syncKey: _optimisticSyncKey,
      snapshot: snapshot,
      apply: (updated) {
        if (updated.id > 0) this.orderId = updated.id;
        _syncOrderInSession(updated, orderNumber);
      },
      sync: () async {
        final updated = await _orderRepository.adjustOrderLineQuantityAtIndex(
          orderId: orderId,
          lineIndex: lineIndex,
          delta: delta,
        );
        if (updated.id > 0) this.orderId = updated.id;
        return updated;
      },
      recover: (snap) => _orderRepository.getOrderDetail(
        this.orderId ?? orderId,
        previousDisplayEntries: snap.displayEntries,
      ),
      onError: (error) => _showOptimisticMutationError('modifier la quantité', error),
    );
  }

  Future<void> _optimisticSetLineQuantity({
    required int orderId,
    required SessionOrder current,
    required int lineIndex,
    required int qty,
  }) async {
    final snapshot = OrderOptimisticSync.deepSnapshot(current);

    final predicted = OrderMapper.predictAfterSetLineQuantityAtIndex(
      current: current,
      lineIndex: lineIndex,
      qty: qty,
    );
    _syncOrderInSession(predicted, orderNumber);

    _optimisticSync.enqueue(
      syncKey: _optimisticSyncKey,
      snapshot: snapshot,
      apply: (updated) {
        if (updated.id > 0) this.orderId = updated.id;
        _syncOrderInSession(updated, orderNumber);
      },
      sync: () async {
        final updated = await _orderRepository.setOrderLineQuantityAtIndex(
          orderId: orderId,
          lineIndex: lineIndex,
          qty: qty,
        );
        if (updated.id > 0) this.orderId = updated.id;
        return updated;
      },
      recover: (snap) => _orderRepository.getOrderDetail(
        this.orderId ?? orderId,
        previousDisplayEntries: snap.displayEntries,
      ),
      onError: (error) => _showOptimisticMutationError('modifier la quantité', error),
    );
  }

  void _showOptimisticMutationError(String action, Object error) {
    if (error is ApiException) {
      debugPrint(_orderRepository.lastAddItemLog);
      ApiDebugDialog.show(title: 'Erreur', body: error.message);
      return;
    }
    Get.snackbar('Erreur', 'Impossible de $action.');
  }
}
