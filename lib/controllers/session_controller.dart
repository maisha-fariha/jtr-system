import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/menu_item.dart';
import '../models/order_product.dart';
import '../models/session_order.dart';
import '../routes/app_pages.dart';
import '../utils/app_theme.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/order_repository.dart';
import '../data/repositories/session_repository.dart';
import '../data/mappers/order_mapper.dart';
import '../data/models/active_day_info.dart';
import '../data/models/day_statistics_info.dart';
import '../core/network/api_exception.dart';
import '../controllers/login_controller.dart';
import '../widgets/api_debug_dialog.dart';
import '../widgets/cancel_table_dialog.dart';
import '../widgets/table_number_dialog.dart';
import '../widgets/table_occupied_dialog.dart';
import '../widgets/ticket_loading_dialog.dart';
import '../widgets/ticket_success_dialog.dart';

enum SessionAction {
  nouvelleCommande,
  demanderSuite,
  ticket,
  statistics,
}

class SessionRowSelection {
  const SessionRowSelection({
    required this.orderNumber,
    this.productIndex,
  });

  final String orderNumber;
  final int? productIndex;
}

class SessionTableUiState {
  const SessionTableUiState({
    this.expandedOrderNumber,
    this.selectedRow,
  });

  final String? expandedOrderNumber;
  final SessionRowSelection? selectedRow;

  SessionTableUiState copyWith({
    String? expandedOrderNumber,
    bool clearExpanded = false,
    SessionRowSelection? selectedRow,
    bool clearSelected = false,
  }) {
    return SessionTableUiState(
      expandedOrderNumber:
          clearExpanded ? null : expandedOrderNumber ?? this.expandedOrderNumber,
      selectedRow: clearSelected ? null : selectedRow ?? this.selectedRow,
    );
  }
}

class SessionController extends GetxController {
  SessionController({
    required OrderRepository orderRepository,
    required SessionRepository sessionRepository,
    required AuthRepository authRepository,
  })  : _orderRepository = orderRepository,
        _sessionRepository = sessionRepository,
        _authRepository = authRepository;

  final OrderRepository _orderRepository;
  final SessionRepository _sessionRepository;
  final AuthRepository _authRepository;

  final selectedAction = SessionAction.nouvelleCommande.obs;
  final tableUiState = const SessionTableUiState().obs;
  final orders = <SessionOrder>[].obs;
  final isLoadingOrders = false.obs;
  final loadingDetailOrderNumbers = <String>{}.obs;
  final ordersError = RxnString();
  final activeDay = ActiveDayInfo.fallback().obs;
  final dayStatistics = Rxn<DayStatisticsInfo>();
  final isLoadingStatistics = false.obs;
  final isCreatingOrder = false.obs;
  final isPrintingTicket = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadActiveDay();
    loadOpenOrders();
    _prefetchTables();
  }

  Future<void> loadActiveDay({bool forceRefresh = false}) async {
    try {
      activeDay.value =
          await _sessionRepository.getActiveDay(forceRefresh: forceRefresh);
    } catch (_) {
      activeDay.value =
          _sessionRepository.cachedActiveDay ?? ActiveDayInfo.fallback();
    }
  }

  Future<void> _prefetchTables() async {
    try {
      await _sessionRepository.getTablesList();
    } catch (_) {}
  }

  Future<void> loadDayStatistics({bool forceRefresh = false}) async {
    isLoadingStatistics.value = true;
    try {
      dayStatistics.value = await _sessionRepository.getDayStatistics(
        forceRefresh: forceRefresh,
      );
    } on ApiException catch (e) {
      _showSnack('Erreur', e.message);
    } catch (_) {
      dayStatistics.value = _sessionRepository.cachedDayStatistics;
    } finally {
      isLoadingStatistics.value = false;
    }
  }

  Future<void> openStatistics() async {
    selectAction(SessionAction.statistics);
    await loadDayStatistics();
    await Get.toNamed(AppRoutes.statistics);
  }

  Future<void> loadOpenOrders({bool forceRefresh = false}) async {
    isLoadingOrders.value = true;
    ordersError.value = null;

    try {
      if (forceRefresh) {
        await loadActiveDay(forceRefresh: true);
      }
      final loaded = await _orderRepository.getOpenOrders(
        forceRefresh: forceRefresh,
      );
      orders.assignAll(loaded);
      unawaited(_enrichMissingOrderDetails());
    } on ApiException catch (e) {
      ordersError.value = e.message;
      if (orders.isEmpty) {
        _showSnack('Erreur', e.message);
      }
    } catch (_) {
      ordersError.value = 'Impossible de charger les commandes.';
      if (orders.isEmpty) {
        _showSnack('Erreur', ordersError.value!);
      }
    } finally {
      isLoadingOrders.value = false;
    }
  }

  void _upsertOrderInList(SessionOrder order) {
    final idx = orders.indexWhere((item) => item.id == order.id);
    if (idx >= 0) {
      orders[idx] = order;
      return;
    }

    final byNumber = orders.indexWhere(
      (item) => _tableKeysMatch(item.number, order.number),
    );
    if (byNumber >= 0) {
      orders[byNumber] = order;
      return;
    }

    orders.insert(0, order);
  }

  static String normalizeTableKey(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.replaceFirst(RegExp(r'^T'), '');
  }

  static bool _tableKeysMatch(String a, String b) {
    if (a == b) return true;
    return normalizeTableKey(a) == normalizeTableKey(b);
  }

  SessionOrder? findOrder({String? orderNumber, int? orderId}) {
    if (orderId != null && orderId > 0) {
      for (final order in orders) {
        if (order.id == orderId) return order;
      }
    }

    if (orderNumber == null || orderNumber.isEmpty) return null;

    for (final order in orders) {
      if (order.number == orderNumber) return order;
    }

    for (final order in orders) {
      if (_tableKeysMatch(order.number, orderNumber)) return order;
    }

    return null;
  }

  Future<void> _enrichMissingOrderDetails() async {
    await _orderRepository.enrichMissingOrderDetails((enriched) {
      final idx = orders.indexWhere((order) => order.id == enriched.id);
      if (idx < 0) return;
      orders[idx] = enriched.copyWith(number: orders[idx].number);
    });
  }

  void selectAction(SessionAction action) {
    selectedAction.value = action;
  }

  void toggleOrderExpansion(String orderNumber) {
    final current = tableUiState.value.expandedOrderNumber;
    final willExpand = current != orderNumber;
    tableUiState.value = tableUiState.value.copyWith(
      expandedOrderNumber: willExpand ? orderNumber : null,
      clearExpanded: !willExpand,
    );
    if (willExpand) {
      loadOrderDetails(orderNumber);
    }
  }

  bool isOrderExpanded(String orderNumber) {
    return tableUiState.value.expandedOrderNumber == orderNumber;
  }

  bool isLoadingOrderDetail(String orderNumber) {
    return loadingDetailOrderNumbers.contains(orderNumber);
  }

  void selectRow({
    required String orderNumber,
    int? productIndex,
    bool expandOnNumberTap = false,
  }) {
    final current = tableUiState.value;
    final isExpanded = current.expandedOrderNumber == orderNumber;
    final willExpand = expandOnNumberTap && !isExpanded;

    tableUiState.value = SessionTableUiState(
      expandedOrderNumber: expandOnNumberTap
          ? (isExpanded ? null : orderNumber)
          : current.expandedOrderNumber,
      selectedRow: SessionRowSelection(
        orderNumber: orderNumber,
        productIndex: productIndex,
      ),
    );

    if (willExpand) {
      loadOrderDetails(orderNumber);
    }
  }

  Future<void> loadOrderDetails(
    String orderNumber, {
    bool forceRefresh = false,
    int? orderId,
  }) async {
    final existing = findOrder(orderNumber: orderNumber, orderId: orderId);
    if (existing == null) return;

    final idx = orders.indexWhere((order) => order.id == existing.id);
    if (idx < 0) return;
    if (existing.isLocalOnly) return;

    if (!forceRefresh && existing.products.isNotEmpty) return;

    if (loadingDetailOrderNumbers.contains(orderNumber)) return;

    loadingDetailOrderNumbers.add(orderNumber);
    loadingDetailOrderNumbers.refresh();

    try {
      final detail = await _orderRepository.getOrderDetail(existing.id);
      orders[idx] = detail.copyWith(number: existing.number);
    } on ApiException catch (e) {
      _showSnack('Erreur', e.message);
    } catch (_) {
      _showSnack('Erreur', 'Impossible de charger les produits.');
    } finally {
      loadingDetailOrderNumbers.remove(orderNumber);
      loadingDetailOrderNumbers.refresh();
    }
  }

  bool isRowSelected({
    required String orderNumber,
    int? productIndex,
  }) {
    final selected = tableUiState.value.selectedRow;
    return selected?.orderNumber == orderNumber &&
        selected?.productIndex == productIndex;
  }

  bool get hasTableSelected {
    final selected = tableUiState.value.selectedRow;
    return selected != null && selected.productIndex == null;
  }

  void showTableNumberDialog() {
    selectAction(SessionAction.nouvelleCommande);
    TableNumberDialog.show(onConfirm: _onTableNumberConfirmed);
  }

  void openTableDetails(String orderNumber, {int? orderId}) {
    Get.toNamed(
      AppRoutes.tableDetails,
      arguments: {
        'orderNumber': orderNumber,
        if (orderId != null) 'orderId': orderId,
      },
    );
  }

  void _onTableNumberConfirmed(String tableNumber) {
    unawaited(_onTableNumberConfirmedAsync(tableNumber));
  }

  Future<void> _onTableNumberConfirmedAsync(String tableNumber) async {
    try {
      final tables = await _sessionRepository.getTablesList(forceRefresh: true);
      final existingOrderId =
          OrderMapper.activeOrderIdForTableNumber(tables, tableNumber);
      if (existingOrderId != null || isTableOccupied(tableNumber)) {
        TableOccupiedDialog.show(
          userName: _currentUserDisplayName,
          tableNumber: tableNumber,
        );
        return;
      }
    } catch (_) {
      if (isTableOccupied(tableNumber)) {
        TableOccupiedDialog.show(
          userName: _currentUserDisplayName,
          tableNumber: tableNumber,
        );
        return;
      }
    }

    Future.microtask(() {
      TableNumberDialog.show(
        title: 'NOMBRE DE COUVERTS',
        onConfirm: (couverts) {
          unawaited(_createTableAndOpenDetails(
            tableNumber: tableNumber,
            couverts: couverts,
          ));
        },
      );
    });
  }

  Future<void> _createTableAndOpenDetails({
    required String tableNumber,
    required String couverts,
  }) async {
    final guests = int.tryParse(couverts.trim()) ?? 1;
    final waiterId = _currentWaiterId;
    if (waiterId <= 0) {
      _showCreateOrderError('Utilisateur non connecté. Veuillez vous reconnecter.');
      return;
    }

    isCreatingOrder.value = true;
    try {
      await loadActiveDay(forceRefresh: true);
      final tables = await _sessionRepository.getTablesList(forceRefresh: true);
      final result = await _orderRepository.createTableOrder(
        waiterId: waiterId,
        tableNumber: tableNumber,
        numberOfGuests: guests,
        tables: tables,
        salesZoneId: activeDay.value.salesZoneId,
      );
      final created = result.order;
      final orderToShow = created;

      final loaded = await _orderRepository.refreshOpenOrdersEnsuring(
        created.id,
        fallbackTableNumber: int.tryParse(tableNumber.trim()),
      );
      orders.assignAll(loaded);
      _upsertOrderInList(orderToShow);

      openTableDetails(orderToShow.number, orderId: created.id);
      unawaited(
        loadOrderDetails(
          orderToShow.number,
          orderId: created.id,
          forceRefresh: true,
        ),
      );
    } on ApiException catch (e) {
      _showCreateOrderError(e.message, apiLog: _orderRepository.lastCreateOrderLog);
    } catch (e) {
      _showCreateOrderError(
        'Impossible de créer la commande.',
        apiLog: _orderRepository.lastCreateOrderLog,
        detail: '$e',
      );
    } finally {
      isCreatingOrder.value = false;
    }
  }

  void _showCreateOrderError(
    String message, {
    String? apiLog,
    String? detail,
  }) {
    final log = apiLog?.trim();
    if (log != null && log.isNotEmpty) {
      ApiDebugDialog.show(
        title: 'Erreur création commande — API',
        body: detail == null ? '$log\n\nMESSAGE: $message' : '$log\n\nMESSAGE: $message\n\n$detail',
      );
    }
    _showSnack('Erreur', message);
  }

  bool isTableOccupied(String tableNumber) {
    final normalized = tableNumber.trim();
    if (normalized.isEmpty) return false;

    return orders.any((order) {
      final orderTable = order.number.replaceFirst(RegExp(r'^T'), '');
      return orderTable == normalized || order.number == 'T$normalized';
    });
  }

  String get _currentUserDisplayName {
    if (Get.isRegistered<AuthRepository>()) {
      final session = Get.find<AuthRepository>().cachedSession;
      final name = session?.user.name;
      if (name != null && name.isNotEmpty) {
        return name.split(' ').first;
      }
    }

    if (Get.isRegistered<LoginController>()) {
      final login = Get.find<LoginController>();
      final selected = login.selectedUser.value;
      if (selected != null) {
        return selected.name.split(' ').first;
      }

      final identifiant = login.identifiantController.text.trim();
      if (identifiant.isNotEmpty) {
        return identifiant.split(' ').first.toUpperCase();
      }
    }

    return 'Utilisateur';
  }

  int get _currentWaiterId {
    final session = _authRepository.cachedSession;
    if (session != null) return session.user.id;
    return 0;
  }

  SessionOrder? _orderByNumber(String orderNumber) {
    for (final order in orders) {
      if (order.number == orderNumber) return order;
    }
    return null;
  }

  Future<void> requestNextCourse() async {
    selectAction(SessionAction.demanderSuite);
    final selected = tableUiState.value.selectedRow;
    if (selected == null || selected.productIndex != null) {
      Get.snackbar(
        'Sélection requise',
        'Veuillez sélectionner une table avant de demander la suite.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      );
      return;
    }

    final order = _orderByNumber(selected.orderNumber);
    if (order == null || order.isLocalOnly) {
      _showSnack('Erreur', 'Commande introuvable pour cette table.');
      return;
    }

    Get.defaultDialog(
      title: 'Demander la suite',
      middleText:
          'Envoyer la demande de suite pour la table ${selected.orderNumber} ?',
      textConfirm: 'Envoyer',
      textCancel: 'Annuler',
      confirmTextColor: Colors.white,
      buttonColor: AppTheme.primary,
      onConfirm: () async {
        Get.back();
        try {
          await _orderRepository.requestNextCourses(order.id);
          _showSnack(
            'Suite demandée',
            'La suite a été envoyée pour la table ${selected.orderNumber}.',
          );
        } on ApiException catch (e) {
          _showSnack('Erreur', e.message);
        } catch (_) {
          _showSnack('Erreur', 'Impossible d\'envoyer la demande de suite.');
        }
      },
    );
  }

  void addProductsToOrder(
    String tableNumber,
    List<MenuItem> items, {
    Map<int, String>? messagesByCourse,
  }) {
    if (items.isEmpty) return;

    final newProducts = items
        .map(
          (item) => OrderProduct(
            quantity: '1',
            name: item.name,
            price: item.formattedPrice,
            message: messagesByCourse?[item.courseNumber],
          ),
        )
        .toList();

    final idx = orders.indexWhere((o) => o.number == tableNumber);
    if (idx >= 0) {
      final existing = orders[idx];
      final newTotal =
          _parseTotalString(existing.total) + _sumProducts(newProducts);
      orders[idx] = existing.copyWith(
        total: _formatTotal(newTotal),
        products: [...existing.products, ...newProducts],
      );
    } else {
      final total = _sumProducts(newProducts);
      orders.add(SessionOrder(
        id: 0,
        number: tableNumber,
        numberColor: AppTheme.primary,
        group: '1',
        poste: 'POC1',
        profitCenter: 'SUR PLACE',
        couverts: '0',
        impressionCount: 0,
        impressionColor: const Color(0xFFE74C3C),
        total: _formatTotal(total),
        products: newProducts,
      ));
    }
  }

  double _sumProducts(List<OrderProduct> products) {
    return products.fold(0, (sum, p) {
      return sum + (_parsePriceString(p.price));
    });
  }

  double _parseTotalString(String total) {
    return double.tryParse(
          total.replaceAll(' €', '').replaceAll(',', '.'),
        ) ??
        0;
  }

  double _parsePriceString(String price) {
    return double.tryParse(
          price.replaceAll(' €', '').replaceAll(',', '.'),
        ) ??
        0;
  }

  String _formatTotal(double value) {
    final formatted = value.toStringAsFixed(2).replaceAll('.', ',');
    return '$formatted €';
  }

  void addTableMenuItemToOrder(
    String orderNumber,
    String itemName,
    double unitPrice,
  ) {
    final idx = orders.indexWhere((o) => o.number == orderNumber);
    if (idx < 0) return;

    final existing = orders[idx];
    final products = List<OrderProduct>.from(existing.products);
    final normalizedName = itemName.toUpperCase();
    final productIdx = products.indexWhere(
      (p) => p.name.toUpperCase() == normalizedName,
    );

    if (productIdx >= 0) {
      final current = products[productIdx];
      final qty = int.tryParse(current.quantity) ?? 1;
      final lineUnitPrice = _parsePriceString(current.price) / qty;
      final newQty = qty + 1;
      products[productIdx] = current.copyWith(
        quantity: '$newQty',
        price: _formatTotal(lineUnitPrice * newQty),
      );
    } else {
      products.add(
        OrderProduct(
          quantity: '1',
          name: normalizedName,
          price: _formatTotal(unitPrice),
        ),
      );
    }

    _replaceOrderProducts(existing, products, idx);
  }

  void removeTableMenuItemFromOrder(String orderNumber, String itemName) {
    final idx = orders.indexWhere((o) => o.number == orderNumber);
    if (idx < 0) return;

    final existing = orders[idx];
    final products = List<OrderProduct>.from(existing.products);
    final normalizedName = itemName.toUpperCase();
    final productIdx = products.indexWhere(
      (p) => p.name.toUpperCase() == normalizedName,
    );
    if (productIdx < 0) return;

    final current = products[productIdx];
    final qty = int.tryParse(current.quantity) ?? 1;
    if (qty <= 1) {
      products.removeAt(productIdx);
    } else {
      final lineUnitPrice = _parsePriceString(current.price) / qty;
      final newQty = qty - 1;
      products[productIdx] = current.copyWith(
        quantity: '$newQty',
        price: _formatTotal(lineUnitPrice * newQty),
      );
    }

    _replaceOrderProducts(existing, products, idx);
  }

  void _replaceOrderProducts(
    SessionOrder existing,
    List<OrderProduct> products,
    int idx,
  ) {
    final newTotal = products.fold<double>(
      0,
      (sum, product) => sum + _parsePriceString(product.price),
    );

    orders[idx] = existing.copyWith(
      total: _formatTotal(newTotal),
      products: products,
    );
  }

  void adjustOrderProductQuantity(
    String orderNumber,
    int productIndex,
    int delta,
  ) {
    final idx = orders.indexWhere((o) => o.number == orderNumber);
    if (idx < 0) return;

    final products = List<OrderProduct>.from(orders[idx].products);
    if (productIndex < 0 || productIndex >= products.length) return;

    final current = products[productIndex];
    final qty = int.tryParse(current.quantity) ?? 1;
    final unitPrice = _parsePriceString(current.price) / qty;
    final newQty = qty + delta;

    if (newQty <= 0) {
      products.removeAt(productIndex);
    } else {
      products[productIndex] = current.copyWith(
        quantity: '$newQty',
        price: _formatTotal(unitPrice * newQty),
      );
    }

    _replaceOrderProducts(orders[idx], products, idx);
  }

  void applyOfferToOrderProduct(String orderNumber, int productIndex) {
    final idx = orders.indexWhere((o) => o.number == orderNumber);
    if (idx < 0) return;

    final products = List<OrderProduct>.from(orders[idx].products);
    if (productIndex < 0 || productIndex >= products.length) return;

    final current = products[productIndex];
    products[productIndex] = current.copyWith(price: '0,00 €');

    _replaceOrderProducts(orders[idx], products, idx);

    Get.snackbar(
      'Offert',
      '${current.name} a été offert.',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    );
  }

  void setOrderProductMessage(
    String orderNumber,
    int productIndex,
    String message,
  ) {
    final idx = orders.indexWhere((o) => o.number == orderNumber);
    if (idx < 0) return;

    final products = List<OrderProduct>.from(orders[idx].products);
    if (productIndex < 0 || productIndex >= products.length) return;

    final trimmed = message.trim();
    products[productIndex] = products[productIndex].copyWith(
      message: trimmed.isEmpty ? null : trimmed,
      clearMessage: trimmed.isEmpty,
    );

    _replaceOrderProducts(orders[idx], products, idx);
  }

  void requestDeleteOrder(String orderNumber) {
    CancelTableDialog.show(
      title: 'Annulation Table',
      onConfirm: () => CancelTableDialog.show(
        title: 'Annulation après édition\nnote',
        onConfirm: () => deleteOrder(orderNumber),
      ),
    );
  }

  Future<void> deleteOrder(String orderNumber) async {
    final idx = orders.indexWhere((order) => order.number == orderNumber);
    if (idx < 0) return;

    final order = orders[idx];

    try {
      if (!order.isLocalOnly) {
        await _orderRepository.closeOrder(order.id);
        await loadOpenOrders(forceRefresh: true);
      } else {
        orders.removeAt(idx);
      }

      _clearUiStateForOrder(orderNumber);
    } on ApiException catch (e) {
      _showSnack('Erreur', e.message);
    } catch (_) {
      _showSnack('Erreur', 'Impossible d\'annuler la table.');
    }
  }

  void _clearUiStateForOrder(String orderNumber) {
    final state = tableUiState.value;
    var nextState = state;

    if (state.selectedRow?.orderNumber == orderNumber) {
      nextState = nextState.copyWith(clearSelected: true);
    }
    if (state.expandedOrderNumber == orderNumber) {
      nextState = nextState.copyWith(clearExpanded: true);
    }

    tableUiState.value = nextState;
  }

  void requestApplyOffer(String orderNumber) {
    CancelTableDialog.show(
      title: 'Table Offerte',
      onConfirm: () => applyOffer(orderNumber),
    );
  }

  Future<void> applyOffer(String orderNumber) async {
    final idx = orders.indexWhere((order) => order.number == orderNumber);
    if (idx < 0) return;

    final order = orders[idx];

    try {
      if (order.isLocalOnly) {
        final offeredProducts = order.products
            .map((product) => product.copyWith(price: '0,00 €'))
            .toList();
        orders[idx] = order.copyWith(
          total: '0,00 €',
          products: offeredProducts,
        );
      } else {
        await _orderRepository.applyTableOffer(order.id);
        await loadOpenOrders(forceRefresh: true);
      }

      _showSnack(
        'Offre',
        'Offre appliquée sur la table $orderNumber.',
      );
    } on ApiException catch (e) {
      _showSnack('Erreur', e.message);
    } catch (_) {
      _showSnack('Erreur', 'Impossible d\'appliquer l\'offre.');
    }
  }

  Future<void> printTicket() async {
    if (!hasTableSelected) {
      Get.snackbar(
        'Sélection requise',
        'Veuillez sélectionner une table avant d\'imprimer le ticket.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      );
      return;
    }

    final selected = tableUiState.value.selectedRow!;
    final order = _orderByNumber(selected.orderNumber);
    if (order == null || order.isLocalOnly) {
      _showSnack('Erreur', 'Commande introuvable pour cette table.');
      return;
    }

    selectAction(SessionAction.ticket);
    isPrintingTicket.value = true;

    Get.dialog(
      const TicketLoadingDialog(),
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
    );

    try {
      final updated = await _orderRepository.markOrderPrinted(order.id);
      final idx = orders.indexWhere((item) => item.id == order.id);
      if (idx >= 0) {
        orders[idx] = updated.copyWith(number: order.number);
      }

      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      await Get.dialog(
        const TicketSuccessDialog(),
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.45),
      );
    } on ApiException catch (e) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      _showSnack('Erreur', e.message);
    } catch (_) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      _showSnack('Erreur', 'Impossible d\'imprimer le ticket.');
    } finally {
      isPrintingTicket.value = false;
    }
  }

  void _showSnack(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    );
  }
}
