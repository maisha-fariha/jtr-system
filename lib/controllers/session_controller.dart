import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/order_display_entry.dart';
import '../models/session_order.dart';
import '../routes/app_pages.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/order_repository.dart';
import '../data/repositories/session_repository.dart';
import '../data/mappers/order_mapper.dart';
import '../data/models/active_day_info.dart';
import '../data/models/day_statistics_info.dart';
import '../core/network/api_exception.dart';
import '../controllers/login_controller.dart';
import '../utils/api_log.dart';
import '../widgets/app_confirm_dialog.dart';
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

  /// When deleting an order we optimistically remove it from [orders],
  /// but a subsequent forced refresh may temporarily still return the
  /// deleted row (backend eventual consistency).
  /// We suppress re-adding those orders until the server list stops
  /// containing them.
  final Set<String> _suppressedTableNumbers = <String>{};

  @override
  void onInit() {
    super.onInit();
    // Paint cached rows immediately so the session screen is not blank.
    _hydrateOrdersFromCache();
    unawaited(loadActiveDay());
    // Cache-first: if Hive had rows, soft-refresh in background.
    // Cold start (empty cache) still awaits the fast first-page network fetch.
    unawaited(
      loadSessionOrders(
        forceRefresh: orders.isEmpty,
        showLoading: orders.isEmpty,
        enrichDetails: false,
      ),
    );
    unawaited(_prefetchTables());
  }

  void _hydrateOrdersFromCache() {
    try {
      final cached = _sessionRepository.getCachedSessionOrders(
        waiterId: _currentWaiterId,
      );
      if (cached.isNotEmpty) {
        orders.assignAll(cached);
      }
    } catch (_) {}
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

  Future<void> loadSessionOrders({
    bool forceRefresh = false,
    Iterable<SessionOrder>? retainOrders,
    bool showLoading = true,
    bool enrichDetails = false,
  }) async {
    if (showLoading && orders.isEmpty) {
      isLoadingOrders.value = true;
    }
    ordersError.value = null;

    try {
      if (forceRefresh) {
        unawaited(loadActiveDay(forceRefresh: true));
      }

      // Stale-while-revalidate: paint cache instantly, then refresh UI when
      // the first network page returns (no spinner if rows already visible).
      if (!forceRefresh) {
        final cached = _sessionRepository.getCachedSessionOrders(
          waiterId: _currentWaiterId,
        );
        if (cached.isNotEmpty) {
          _applySessionOrderSummaries(
            cached,
            retainOrders: retainOrders,
            enrichDetails: enrichDetails,
          );
          if (showLoading) {
            isLoadingOrders.value = false;
          }
          unawaited(_softRefreshSessionOrders(
            retainOrders: retainOrders,
            enrichDetails: enrichDetails,
          ));
          return;
        }
      }

      final summaries = forceRefresh
          ? await _sessionRepository.refreshSessionOrdersFromNetwork(
              waiterId: _currentWaiterId,
            )
          : await _sessionRepository.getSessionOrders(
              forceRefresh: true,
              waiterId: _currentWaiterId,
            );

      _applySessionOrderSummaries(
        summaries,
        retainOrders: retainOrders,
        enrichDetails: enrichDetails,
        clearSuppressedMatches: forceRefresh,
      );
    } on ApiException catch (e) {
      ordersError.value = e.message;
      if (orders.isEmpty && showLoading) {
        _showSnack('Erreur', e.message);
      }
    } catch (_) {
      ordersError.value = 'Impossible de charger les commandes.';
      if (orders.isEmpty && showLoading) {
        _showSnack('Erreur', ordersError.value!);
      }
    } finally {
      if (showLoading) {
        isLoadingOrders.value = false;
      }
    }
  }

  Future<void> _softRefreshSessionOrders({
    Iterable<SessionOrder>? retainOrders,
    bool enrichDetails = false,
  }) async {
    try {
      final summaries =
          await _sessionRepository.refreshSessionOrdersFromNetwork(
        waiterId: _currentWaiterId,
      );
      _applySessionOrderSummaries(
        summaries,
        retainOrders: retainOrders,
        enrichDetails: enrichDetails,
        clearSuppressedMatches: true,
      );
    } catch (_) {
      // Keep the cached list already on screen.
    }
  }

  void _applySessionOrderSummaries(
    List<SessionOrder> summaries, {
    Iterable<SessionOrder>? retainOrders,
    bool enrichDetails = false,
    bool clearSuppressedMatches = false,
  }) {
    // Empty orders must stay until the delete icon closes them. List APIs often
    // drop empty / auto-closed shells after the last item is cancelled.
    final emptyShellsToKeep = <SessionOrder>[
      for (final order in orders)
        if (order.products.isEmpty && !_isOrderSuppressed(order.number)) order,
    ];

    final filtered = summaries.where((o) {
      for (final suppressed in _suppressedTableNumbers) {
        if (_tableKeysMatch(o.number, suppressed)) return false;
      }
      return true;
    }).toList();

    orders.assignAll(filtered);
    if (retainOrders != null) {
      for (final order in retainOrders) {
        _upsertOrderInList(order);
      }
    }
    for (final empty in emptyShellsToKeep) {
      final stillPresent = orders.any(
        (o) =>
            (empty.id > 0 && o.id == empty.id) ||
            _tableKeysMatch(o.number, empty.number),
      );
      if (!stillPresent) {
        _upsertOrderInList(empty);
      }
    }
    orders.refresh();

    if (clearSuppressedMatches && _suppressedTableNumbers.isNotEmpty) {
      _suppressedTableNumbers.removeWhere(
        (suppressed) =>
            !filtered.any((o) => _tableKeysMatch(o.number, suppressed)) &&
            !orders.any((o) => _tableKeysMatch(o.number, suppressed)),
      );
    }

    if (enrichDetails) {
      unawaited(_enrichOrdersInBackground(filtered));
    }
  }

  /// Reloads open orders for the session screen after create/edit on a table.
  Future<void> refreshOrderList({
    SessionOrder? pinOrder,
    String? ensureOrderNumber,
    int? ensureOrderId,
    bool background = false,
  }) async {
    SessionOrder? pinned = pinOrder;

    if (pinned == null && ensureOrderId != null && ensureOrderId > 0) {
      try {
        pinned = await _orderRepository.getOrderDetail(ensureOrderId);
      } catch (_) {
        pinned = findOrder(
          orderNumber: ensureOrderNumber,
          orderId: ensureOrderId,
        );
      }
    }

    await loadSessionOrders(
      forceRefresh: true,
      retainOrders: pinned != null ? [pinned] : null,
      showLoading: !background,
      enrichDetails: false,
    );
  }

  /// Fills product lines from cache / network without blocking the list UI.
  Future<void> _enrichOrdersInBackground(List<SessionOrder> summaries) async {
    final tasks = <Future<void>>[];

    for (final summary in summaries) {
      if (summary.id <= 0) continue;

      tasks.add(() async {
        try {
          final cached = _orderRepository.cachedOrderDetail(summary.id);
          if (cached != null) {
            final detail = OrderMapper.fromOrderDetail(cached).copyWith(
              id: summary.id,
            );
            if (_stillInList(summary.id)) {
              _upsertOrderInList(detail);
            }
            return;
          }

          final detail = await _orderRepository.getOrderDetail(summary.id);
          if (_stillInList(summary.id)) {
            _upsertOrderInList(detail);
          }
        } catch (_) {}
      }());
    }

    if (tasks.isNotEmpty) {
      await Future.wait(tasks);
    }
  }

  bool _stillInList(int orderId) =>
      orders.any((order) => order.id == orderId);

  bool _isOrderSuppressed(String orderNumber) {
    for (final suppressed in _suppressedTableNumbers) {
      if (_tableKeysMatch(orderNumber, suppressed)) return true;
    }
    return false;
  }

  void _upsertOrderInList(SessionOrder order) {
    if (_isOrderSuppressed(order.number)) {
      orders.removeWhere((item) => _tableKeysMatch(item.number, order.number));
      orders.refresh();
      return;
    }

    if (order.id <= 0) {
      final byNumber = orders.indexWhere(
        (item) => _tableKeysMatch(item.number, order.number),
      );
      if (byNumber >= 0) {
        orders[byNumber] = order;
        orders.refresh();
        return;
      }
      orders.insert(0, order);
      orders.refresh();
      return;
    }

    final idx = orders.indexWhere((item) => item.id == order.id);
    if (idx >= 0) {
      orders[idx] = order;
      orders.refresh();
      return;
    }

    final byNumber = orders.indexWhere(
      (item) => _tableKeysMatch(item.number, order.number),
    );
    if (byNumber >= 0) {
      orders[byNumber] = order;
      orders.refresh();
      return;
    }

    orders.insert(0, order);
    orders.refresh();
  }

  void updateOrderRow(SessionOrder order) => _upsertOrderInList(order);

  static String normalizeTableKey(String value) =>
      OrderMapper.normalizeTableKey(value);

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
    List<OrderDisplayEntry>? previousDisplayEntries,
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
      final previous = orders[idx];
      final layoutHints =
          previousDisplayEntries ?? previous.displayEntries;
      final detail = await _orderRepository.getOrderDetail(
        existing.id,
        previousDisplayEntries: layoutHints,
      );
      orders[idx] = detail;
      orders.refresh();
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

  void showTableNumberDialog({required BuildContext context}) {
    selectAction(SessionAction.nouvelleCommande);
    TableNumberDialog.show(
      context: context,
      integerOnly: true,
      maxDigits: 4,
      onConfirm: (tableNumber) => _onTableNumberConfirmed(context, tableNumber),
    );
  }

  void openTableDetails(String orderNumber, {int? orderId}) {
    logOrderFlow(
      'openTableDetails table=$orderNumber orderId=${orderId ?? 'none'}',
    );
    final resolvedId = orderId != null && orderId > 0 ? orderId : null;
    Get.toNamed(
      AppRoutes.tableDetails,
      arguments: {
        'orderNumber': orderNumber,
        if (resolvedId != null) 'orderId': resolvedId,
      },
    );
  }

  void _onTableNumberConfirmed(BuildContext context, String tableNumber) {
    TableNumberDialog.show(
      context: context,
      title: 'NOMBRE DE COUVERTS',
      integerOnly: true,
      maxDigits: 3,
      onConfirm: (couverts) {
        unawaited(_createTableAndOpenDetails(
          context: context,
          tableNumber: tableNumber,
          couverts: couverts,
        ));
      },
    );
  }

  Future<void> _createTableAndOpenDetails({
    required BuildContext context,
    required String tableNumber,
    required String couverts,
  }) async {
    logOrderFlow('_createTableAndOpenDetails START table=$tableNumber couverts=$couverts');
    final guests = int.tryParse(couverts.trim()) ?? 1;
    final waiterId = _currentWaiterId;
    if (waiterId <= 0) {
      logOrderFlow('_createTableAndOpenDetails ABORT not logged in');
      _showSnack('Erreur', 'Utilisateur non connecté. Veuillez vous reconnecter.');
      return;
    }

    // Own open order already in this app's session list → reopen + optional guest PUT.
    final existingOwn = _findOwnOpenOrderForTable(tableNumber);
    if (existingOwn != null) {
      await _reopenOwnOrderAndUpdateGuests(
        existing: existingOwn,
        guests: guests,
      );
      return;
    }

    isCreatingOrder.value = true;
    SessionOrder? created;
    var attemptedCreate = false;

    try {
      final tables = await _sessionRepository.getTablesList();
      logOrderFlow(
        OrderMapper.buildTablesPostOrderAvailabilityLog(
          tables,
          targetTableNumber: tableNumber,
        ),
      );
      final target = OrderMapper.resolveTableForNewOrder(tables, tableNumber);
      if (target == null) {
        logOrderFlow('_createTableAndOpenDetails ABORT table not found');
        _showSnack('Erreur', 'Table $tableNumber introuvable.');
        return;
      }
      if (OrderMapper.isTableInUse(tables, tableNumber)) {
        // Table in use by another waiter / session — not in our list.
        logOrderFlow('_createTableAndOpenDetails ABORT table occupied (other)');
        if (context.mounted) {
          TableOccupiedDialog.show(
            context: context,
            userName: _currentUserDisplayName,
            tableNumber: tableNumber,
          );
        }
        return;
      }

      final salesZoneId = OrderMapper.inferSalesZoneId(
        tables,
        preferred: activeDay.value.salesZoneId,
        table: target,
      );

      attemptedCreate = true;
      try {
        final result = await _orderRepository.createTableOrder(
          waiterId: waiterId,
          tableNumber: tableNumber,
          numberOfGuests: guests,
          tables: tables,
          salesZoneId: salesZoneId,
        );
        created = result.order;
      } on ApiException {
        final recovered = await _orderRepository.tryRecoverCreatedOrder(
          tableNumber: tableNumber,
        );
        created = recovered?.order;
      }
    } catch (_) {
      // Background refresh may still surface the order if the backend created it.
    } finally {
      isCreatingOrder.value = false;
      if (attemptedCreate) {
        if (created != null && created.id <= 0) {
          final resolved = await _orderRepository.resolveOrderIdForTableNumber(
            tableNumber,
          );
          if (resolved != null && resolved > 0) {
            try {
              final detail = await _orderRepository.getOrderDetail(resolved);
              created = detail.id > 0
                  ? detail
                  : detail.copyWith(id: resolved);
            } catch (_) {
              // Keep session placeholder — order will be POSTed on first item.
            }
          }
        }

        if (created == null) {
          final resolved = await _orderRepository.resolveOrderIdForTableNumber(
            tableNumber,
          );
          if (resolved != null && resolved > 0) {
            try {
              final detail = await _orderRepository.getOrderDetail(resolved);
              created = detail.id > 0
                  ? detail
                  : detail.copyWith(id: resolved);
            } catch (_) {}
          }
        }

        if (created != null) {
          if (created.id > 0) {
            _upsertOrderInList(created);
          }
          logOrderFlow(
            '_createTableAndOpenDetails OPEN table=${created.number} orderId=${created.id}',
          );
          openTableDetails(
            created.number,
            orderId: created.id > 0 ? created.id : null,
          );
        }
        unawaited(
          refreshOrderList(
            pinOrder: created != null && created.id > 0 ? created : null,
            background: true,
          ),
        );
      }
    }
  }

  /// Finds an open order for [tableNumber] already shown in this waiter's list.
  SessionOrder? _findOwnOpenOrderForTable(String tableNumber) {
    final normalized = OrderMapper.normalizeTableKey(tableNumber);
    if (normalized.isEmpty) return null;

    for (final order in orders) {
      if (_tableKeysMatch(order.number, normalized) ||
          _tableKeysMatch(order.number, OrderMapper.tableDisplayNumber(normalized))) {
        return order;
      }
    }
    return null;
  }

  Future<void> _reopenOwnOrderAndUpdateGuests({
    required SessionOrder existing,
    required int guests,
  }) async {
    logOrderFlow(
      '_reopenOwnOrderAndUpdateGuests table=${existing.number} orderId=${existing.id} guests=$guests',
    );

    var target = existing;
    final currentGuests = int.tryParse(existing.couverts.trim()) ?? 0;
    final nextGuests = guests < 1 ? 1 : guests;

    if (existing.id > 0 && currentGuests != nextGuests) {
      isCreatingOrder.value = true;
      try {
        target = await _orderRepository.updateOrderGuestCount(
          orderId: existing.id,
          numberOfGuests: nextGuests,
        );
        _upsertOrderInList(target);
      } on ApiException catch (e) {
        _showSnack('Erreur', e.message);
        // Still open details with local guest count so waiter can continue.
        target = existing.copyWith(couverts: '$nextGuests');
        _upsertOrderInList(target);
      } catch (_) {
        _showSnack('Erreur', 'Impossible de mettre à jour les couverts.');
        target = existing.copyWith(couverts: '$nextGuests');
        _upsertOrderInList(target);
      } finally {
        isCreatingOrder.value = false;
      }
    } else if (currentGuests != nextGuests) {
      target = existing.copyWith(couverts: '$nextGuests');
      _upsertOrderInList(target);
    }

    openTableDetails(
      target.number,
      orderId: target.id > 0 ? target.id : null,
    );
    unawaited(
      refreshOrderList(
        pinOrder: target.id > 0 ? target : null,
        background: true,
      ),
    );
  }

  bool isTableOccupied(String tableNumber) {
    final normalized = tableNumber.trim();
    if (normalized.isEmpty) return false;

    // Own list order is reopened via nouvelle commande — not "occupied" for this waiter.
    if (_findOwnOpenOrderForTable(normalized) != null) return false;

    if (OrderMapper.isTableInUse(
      _sessionRepository.cachedTables,
      normalized,
    )) {
      return true;
    }

    return false;
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

  Future<void> requestNextCourse({required BuildContext context}) async {
    selectAction(SessionAction.demanderSuite);
    final selected = tableUiState.value.selectedRow;
    if (selected == null || selected.productIndex != null) {
      _showSnack(
        'Sélection requise',
        'Veuillez sélectionner une table avant de demander la suite.',
        context: context,
      );
      return;
    }
    final order = _orderByNumber(selected.orderNumber);
    if (order == null || order.isLocalOnly) {
      _showSnack(
        'Erreur',
        'Commande introuvable pour cette table.',
        context: context,
      );
      return;
    }

    AppConfirmDialog.show(
      context: context,
      title: 'Demander la suite',
      message:
          'Envoyer la demande de suite pour la table ${selected.orderNumber} ?',
      onConfirm: () async {
        try {
          final updated = await _orderRepository.requestNextCourses(order.id);
          _upsertOrderInList(updated);
          if (context.mounted) {
            _showSnack(
              'Suite demandée',
              'La suite a été envoyée pour la table ${selected.orderNumber}.',
              context: context,
            );
          }
        } on ApiException catch (e) {
          if (context.mounted) {
            _showSnack('Erreur', e.message, context: context);
          }
        } catch (_) {
          if (context.mounted) {
            _showSnack(
              'Erreur',
              'Impossible d\'envoyer la demande de suite.',
              context: context,
            );
          }
        }
      },
    );
  }

  void requestDeleteOrder(String orderNumber, {required BuildContext context}) {
    CancelTableDialog.show(
      context: context,
      title: 'Annulation Table',
      onConfirm: () => CancelTableDialog.show(
        context: context,
        title: 'Annulation après édition\nnote',
        onConfirm: () => deleteOrder(orderNumber),
      ),
    );
  }

  Future<void> deleteOrder(String orderNumber) async {
    final order = findOrder(orderNumber: orderNumber);
    if (order == null) return;

    _suppressedTableNumbers.add(order.number);

    try {
      if (order.isLocalOnly) {
        final tableId = -order.id;
        if (tableId > 0) {
          await _orderRepository.endTableSession(tableId);
        }
      } else {
        await _orderRepository.closeOrder(
          order.id,
          tableNumber: order.number,
        );
      }

      orders.removeWhere((o) => _tableKeysMatch(o.number, order.number));
      _clearUiStateForOrder(order.number);

      unawaited(_sessionRepository.getTablesList(forceRefresh: true));
      // Reload without showing loading indicator; the suppression filter
      // prevents the deleted order from reappearing during eventual
      // consistency window.
      unawaited(loadSessionOrders(
        forceRefresh: true,
        showLoading: false,
      ));
    } on ApiException catch (e) {
      _suppressedTableNumbers.removeWhere(
        (suppressed) => _tableKeysMatch(suppressed, order.number),
      );
      _showSnack('Erreur', e.message);
    } catch (_) {
      _suppressedTableNumbers.removeWhere(
        (suppressed) => _tableKeysMatch(suppressed, order.number),
      );
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

  void requestApplyOffer(String orderNumber, {required BuildContext context}) {
    CancelTableDialog.show(
      context: context,
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
        final updated = await _orderRepository.applyTableOffer(order.id);
        _upsertOrderInList(updated);
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

  Future<void> printTicket({required BuildContext context}) async {
    if (!hasTableSelected) {
      _showSnack(
        'Sélection requise',
        'Veuillez sélectionner une table avant d\'imprimer le ticket.',
        context: context,
      );
      return;
    }

    final selected = tableUiState.value.selectedRow!;
    final order = _orderByNumber(selected.orderNumber);
    if (order == null || order.isLocalOnly) {
      _showSnack(
        'Erreur',
        'Commande introuvable pour cette table.',
        context: context,
      );
      return;
    }

    selectAction(SessionAction.ticket);
    isPrintingTicket.value = true;

    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => const TicketLoadingDialog(),
    );

    try {
      final updated = await _orderRepository.markOrderPrinted(order.id);
      _upsertOrderInList(updated);

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
        _showSnack('Erreur', e.message, context: context);
      }
    } catch (_) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showSnack(
          'Erreur',
          'Impossible d\'imprimer le ticket.',
          context: context,
        );
      }
    } finally {
      isPrintingTicket.value = false;
    }
  }

  void _showSnack(
    String title,
    String message, {
    BuildContext? context,
  }) {
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title — $message'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    );
  }
}
