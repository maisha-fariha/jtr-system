import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/order_display_entry.dart';
import '../models/session_order.dart';
import '../routes/app_pages.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/catalog_repository.dart';
import '../data/repositories/order_repository.dart';
import '../data/repositories/session_repository.dart';
import '../data/mappers/order_mapper.dart';
import '../data/order_optimistic_sync.dart';
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
import '../utils/app_snackbar.dart';

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

  OrderOptimisticSync _optimisticSyncFor(String orderNumber) =>
      _orderRepository.optimisticSyncFor(orderNumber.hashCode);

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
    final args = Get.arguments;
    final justPreloaded = args is Map && args['preloaded'] == true;

    // Prefer rows already mapped during connect preload (no empty remapping gap).
    final preloadedRows = justPreloaded
        ? _sessionRepository.takePreloadedSessionOrders()
        : null;
    if (preloadedRows != null && preloadedRows.isNotEmpty) {
      orders.assignAll(preloadedRows);
    } else {
      _hydrateOrdersFromCache();
    }

    unawaited(loadActiveDay(forceRefresh: !justPreloaded));

    if (justPreloaded) {
      if (orders.isEmpty) {
        // Preload missed rows — show loader, never flash "Aucune commande".
        unawaited(
          loadSessionOrders(
            forceRefresh: true,
            showLoading: true,
            enrichDetails: false,
          ),
        );
      }
      unawaited(_prefetchTables());
    } else {
      unawaited(
        loadSessionOrders(
          forceRefresh: orders.isEmpty,
          showLoading: orders.isEmpty,
          enrichDetails: false,
        ),
      );
      unawaited(_prefetchTables());
      unawaited(_prefetchCreateCatalog());
    }
  }

  /// Warm product cache + create seed so the first POST /api/orders is not
  /// blocked on a full paginated products download.
  Future<void> _prefetchCreateCatalog() async {
    try {
      final catalog = Get.find<CatalogRepository>();
      unawaited(catalog.getProducts());
      await catalog.resolveSeedProductForEmptyOrder();
    } catch (_) {}
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
    /// When false, page-1 updates merge in place (no reshuffle).
    bool replaceExistingList = true,
  }) async {
    if (showLoading && orders.isEmpty) {
      isLoadingOrders.value = true;
    }
    ordersError.value = null;

    try {
      // Don't re-fetch active day here — onInit already loads it.
      // Stale-while-revalidate: paint cache instantly, then refresh UI when
      // the full network fetch returns (no spinner if rows already visible).
      if (!forceRefresh) {
        final cached = _sessionRepository.getCachedSessionOrders(
          waiterId: _currentWaiterId,
        );
        if (cached.isNotEmpty) {
          _applySessionOrderSummaries(
            cached,
            retainOrders: retainOrders,
            enrichDetails: enrichDetails,
            replaceList: orders.isEmpty,
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

      // Every page is fetched before this returns — the list is applied once,
      // fully loaded, instead of appearing row-by-row.
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
        replaceList: replaceExistingList || orders.isEmpty,
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
      // Soft refresh: update fields in place — do not reshuffle the list.
      _applySessionOrderSummaries(
        summaries,
        retainOrders: retainOrders,
        enrichDetails: enrichDetails,
        replaceList: false,
        clearSuppressedMatches: true,
      );
    } catch (_) {
      // Keep the cached list already on screen.
    }
  }

  /// Pull-to-refresh / post-CRUD: keep list visible, soft-swap from light API.
  Future<void> refreshSessionOrders({
    Iterable<SessionOrder>? retainOrders,
  }) async {
    ordersError.value = null;
    unawaited(loadActiveDay(forceRefresh: true));
    try {
      final summaries =
          await _sessionRepository.refreshSessionOrdersFromNetwork(
        waiterId: _currentWaiterId,
      );
      _applySessionOrderSummaries(
        summaries,
        retainOrders: retainOrders,
        enrichDetails: false,
        replaceList: true,
        clearSuppressedMatches: true,
      );
    } catch (_) {
      if (orders.isEmpty) {
        ordersError.value = 'Impossible de charger les commandes.';
      }
    }
  }

  void _applySessionOrderSummaries(
    List<SessionOrder> summaries, {
    Iterable<SessionOrder>? retainOrders,
    bool enrichDetails = false,
    bool clearSuppressedMatches = false,
    /// When true, replace the visible list (page 1 / pull-to-refresh).
    /// When false, update in place + append only — avoids rows jumping.
    bool replaceList = true,
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

    if (replaceList || orders.isEmpty) {
      // Lightweight list API has no line items — keep any already-loaded detail.
      final previousById = <int, SessionOrder>{
        for (final order in orders)
          if (order.id > 0) order.id: order,
      };
      orders.assignAll([
        for (final order in filtered)
          _preferDetailedOrder(order, previousById[order.id]),
      ]);
    } else {
      _mergeSessionOrdersStable(filtered);
    }

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

  /// Updates existing rows in place and appends only new ids (no reshuffle).
  void _mergeSessionOrdersStable(List<SessionOrder> incoming) {
    final incomingById = <int, SessionOrder>{
      for (final order in incoming)
        if (order.id > 0) order.id: order,
    };

    for (var i = 0; i < orders.length; i++) {
      final current = orders[i];
      if (current.id <= 0) continue;
      final updated = incomingById[current.id];
      if (updated == null) continue;
      orders[i] = _preferDetailedOrder(updated, current);
    }

    final existingIds = <int>{
      for (final order in orders)
        if (order.id > 0) order.id,
    };
    for (final order in incoming) {
      if (order.id <= 0 || existingIds.contains(order.id)) continue;
      orders.add(order);
      existingIds.add(order.id);
    }
  }

  /// Session list summaries omit products; never wipe lines / totals already loaded.
  ///
  /// Table-details mutations must call [updateOrderRow] with
  /// `replaceDetail: true` so emptying the last line is not discarded here.
  SessionOrder _preferDetailedOrder(
    SessionOrder incoming,
    SessionOrder? previous,
  ) {
    if (previous == null) return incoming;

    // Intentional empty ticket after delete-all — keep empty until real lines arrive.
    if (previous.id > 0 &&
        _orderRepository.shouldDisplayAsEmptyCreateShell(previous.id)) {
      if (incoming.products.isNotEmpty || incoming.displayEntries.isNotEmpty) {
        _orderRepository.clearEmptyShellDisplay(previous.id);
        return incoming;
      }
      return previous.copyWith(
        products: const [],
        displayEntries: const [],
        itemCount: 0,
        total: OrderMapper.formatPrice('0'),
        impressionCount: incoming.impressionCount,
        impressionColor: incoming.impressionColor,
        poste: incoming.poste,
        profitCenter: incoming.profitCenter,
        couverts: incoming.couverts.isNotEmpty
            ? incoming.couverts
            : previous.couverts,
        waiterId: incoming.waiterId ?? previous.waiterId,
      );
    }

    final incomingLines = incoming.products.length;
    final previousLines = previous.products.length;
    final incomingDisplay = incoming.displayEntries.length;
    final previousDisplay = previous.displayEntries.length;

    final incomingSuivre =
        OrderMapper.suivreSeparatorCount(incoming.displayEntries);
    final previousSuivre =
        OrderMapper.suivreSeparatorCount(previous.displayEntries);
    final incomingDividers =
        OrderMapper.sectionDividerCount(incoming.displayEntries);
    final previousDividers =
        OrderMapper.sectionDividerCount(previous.displayEntries);
    // Pending À SUIVRE → DEMANDÉE is not a thinner ticket.
    final lostPendingSuivre = incomingSuivre < previousSuivre &&
        incomingDividers < previousDividers;

    // Lightweight / stale background rows must not demote a richer ticket.
    final incomingThinner = (incomingLines == 0 && previousLines > 0) ||
        (incomingLines > 0 &&
            previousLines > 0 &&
            incomingLines < previousLines) ||
        (incomingDisplay == 0 && previousDisplay > 0 && previousLines > 0) ||
        (lostPendingSuivre && previousLines > 0);

    if (incomingThinner) {
      final keptDisplay = lostPendingSuivre &&
              incoming.products.isNotEmpty &&
              incoming.products.length >= previous.products.length
          ? OrderMapper.reconcileSuivreDisplay(
              previous: previous.displayEntries,
              next: incoming.displayEntries,
            )
          : previous.displayEntries;
      return previous.copyWith(
        impressionCount: incoming.impressionCount,
        impressionColor: incoming.impressionColor,
        poste: incoming.poste,
        profitCenter: incoming.profitCenter,
        couverts: incoming.couverts.isNotEmpty
            ? incoming.couverts
            : previous.couverts,
        waiterId: incoming.waiterId ?? previous.waiterId,
        itemCount: previous.itemCount > 0
            ? previous.itemCount
            : (incoming.itemCount > 0
                ? incoming.itemCount
                : previous.products.length),
        products: incoming.products.length >= previous.products.length
            ? incoming.products
            : previous.products,
        displayEntries: keptDisplay.isNotEmpty
            ? keptDisplay
            : previous.displayEntries,
      );
    }

    // Lightweight row may carry an items_count hint — keep the higher count.
    if (incoming.products.isEmpty &&
        previous.itemCount > incoming.itemCount &&
        previous.itemCount > 0) {
      return incoming.copyWith(itemCount: previous.itemCount);
    }

    // Local delete in flight: never adopt a fatter API ticket.
    if (previous.id > 0 &&
        _orderRepository.hasPendingLocalDelete(previous.id) &&
        incomingLines > previousLines) {
      return OrderMapper.mergeLiveOptimisticDetail(
        server: incoming,
        live: previous,
        suppressItemIds: _orderRepository.suppressedItemIdsFor(previous.id),
      );
    }

    return incoming;
  }

  /// Reloads open orders for the session screen after create/edit on a table.
  ///
  /// When the list is already visible, merges in place so row order does not
  /// jump (e.g. after returning from table details).
  Future<void> refreshOrderList({
    SessionOrder? pinOrder,
    String? ensureOrderNumber,
    int? ensureOrderId,
    bool background = false,
    bool preserveSortOrder = true,
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

    final hadRows = orders.isNotEmpty;
    await loadSessionOrders(
      forceRefresh: true,
      retainOrders: pinned != null ? [pinned] : null,
      showLoading: !background,
      enrichDetails: false,
      // Keep current visual order when returning to an already-loaded list.
      replaceExistingList: !(preserveSortOrder && hadRows),
    );
  }

  /// Fills product lines from cache / network without blocking the list UI.
  ///
  /// Uses a detail-revision guard so a slow GET cannot overwrite a ticket the
  /// waiter just mutated (qty +/− / add) in table details.
  Future<void> _enrichOrdersInBackground(List<SessionOrder> summaries) async {
    final tasks = <Future<void>>[];

    for (final summary in summaries) {
      if (summary.id <= 0) continue;

      tasks.add(() async {
        try {
          final revisionAtStart =
              _orderRepository.detailRevision(summary.id);
          final previous = findOrder(orderId: summary.id);

          final cached = _orderRepository.cachedOrderDetail(summary.id);
          SessionOrder detail;
          if (cached != null) {
            detail = OrderMapper.fromOrderDetail(cached).copyWith(
              id: summary.id,
            );
          } else {
            detail = await _orderRepository.getOrderDetail(summary.id);
          }

          if (!_stillInList(summary.id)) return;
          if (revisionAtStart !=
              _orderRepository.detailRevision(summary.id)) {
            return;
          }
          // Empty-shell may replace a brief stale row — never wipe a ticket
          // that already shows waiter-added lines (add after delete-all).
          final emptyShellOverride =
              _orderRepository.shouldDisplayAsEmptyCreateShell(summary.id) &&
                  detail.products.isEmpty &&
                  (previous == null ||
                      (previous.products.isEmpty &&
                          previous.displayEntries.isEmpty));
          if (!emptyShellOverride &&
              _wouldDowngradeDetail(detail, previous)) {
            return;
          }

          _upsertOrderInList(detail);
        } catch (_) {}
      }());
    }

    if (tasks.isNotEmpty) {
      await Future.wait(tasks);
    }
  }

  bool _stillInList(int orderId) =>
      orders.any((order) => order.id == orderId);

  /// True when applying [incoming] would erase lines the UI already shows,
  /// or resurrect lines the waiter already deleted (suppress in flight).
  bool _wouldDowngradeDetail(SessionOrder incoming, SessionOrder? previous) {
    if (previous == null) return false;
    if (incoming.products.isEmpty && previous.products.isNotEmpty) {
      return true;
    }
    if (previous.products.isNotEmpty &&
        incoming.products.isNotEmpty &&
        incoming.products.length < previous.products.length) {
      return true;
    }
    if (incoming.displayEntries.isEmpty &&
        previous.displayEntries.isNotEmpty &&
        previous.products.isNotEmpty) {
      return true;
    }
    // Fatter server snapshot during local delete undo / cancel — keep thinner.
    if (previous.id > 0 &&
        _orderRepository.hasPendingLocalDelete(previous.id) &&
        OrderMapper.productEntryCount(incoming.displayEntries) >
            OrderMapper.productEntryCount(previous.displayEntries)) {
      return true;
    }
    return false;
  }

  bool _isOrderSuppressed(String orderNumber) {
    for (final suppressed in _suppressedTableNumbers) {
      if (_tableKeysMatch(orderNumber, suppressed)) return true;
    }
    return false;
  }

  bool _ordersContainTable(String tableNumber) {
    return orders.any((o) => _tableKeysMatch(o.number, tableNumber));
  }

  /// After delete we suppress that table briefly; recreating must clear it
  /// or the new order never appears in the list (and row sync is dropped).
  void _clearSuppressedTable(String tableNumber) {
    _suppressedTableNumbers.removeWhere(
      (suppressed) => _tableKeysMatch(suppressed, tableNumber),
    );
  }

  void _upsertOrderInList(
    SessionOrder order, {
    bool replaceDetail = false,
  }) {
    if (_isOrderSuppressed(order.number)) {
      orders.removeWhere((item) => _tableKeysMatch(item.number, order.number));
      orders.refresh();
      return;
    }

    var safeOrder = order;
    var forceReplace = replaceDetail;
    if (order.id > 0 &&
        _orderRepository.shouldDisplayAsEmptyCreateShell(order.id)) {
      if (order.products.isNotEmpty || order.displayEntries.isNotEmpty) {
        _orderRepository.clearEmptyShellDisplay(order.id);
      } else {
        forceReplace = true;
      }
    }

    SessionOrder merged(SessionOrder incoming, SessionOrder previous) {
      if (!forceReplace) {
        return _preferDetailedOrder(incoming, previous);
      }
      // Intentional empty ticket (last line deleted / empty shell).
      if (incoming.products.isEmpty && incoming.displayEntries.isEmpty) {
        return incoming;
      }
      // Forced replace is authoritative — suite/line deletes intentionally have
      // fewer À SUIVRE / products. Never reconcile previous suites back in.
      return incoming;
    }

    if (safeOrder.id <= 0) {
      final byNumber = orders.indexWhere(
        (item) => _tableKeysMatch(item.number, safeOrder.number),
      );
      if (byNumber >= 0) {
        orders[byNumber] = merged(safeOrder, orders[byNumber]);
        orders.refresh();
        return;
      }
      orders.insert(0, safeOrder);
      orders.refresh();
      return;
    }

    final idx = orders.indexWhere((item) => item.id == safeOrder.id);
    if (idx >= 0) {
      orders[idx] = merged(safeOrder, orders[idx]);
      orders.refresh();
      return;
    }

    final byNumber = orders.indexWhere(
      (item) => _tableKeysMatch(item.number, safeOrder.number),
    );
    if (byNumber >= 0) {
      orders[byNumber] = merged(safeOrder, orders[byNumber]);
      orders.refresh();
      return;
    }

    orders.insert(0, safeOrder);
    orders.refresh();
  }

  /// Table-details mutations must not be overwritten by [_preferDetailedOrder]
  /// (that helper keeps previous lines when the incoming ticket is empty —
  /// which broke deleting the last article).
  void updateOrderRow(SessionOrder order, {bool replaceDetail = false}) =>
      _upsertOrderInList(order, replaceDetail: replaceDetail);

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

    if (!forceRefresh && OrderMapper.sessionListDetailIsHydrated(existing)) return;

    if (loadingDetailOrderNumbers.contains(orderNumber)) return;

    loadingDetailOrderNumbers.add(orderNumber);
    loadingDetailOrderNumbers.refresh();

    try {
      final previous = orders[idx];
      // Prefer non-empty layout; otherwise let repository use Hive suivre hints.
      final layoutHints = OrderMapper.coalesceLayoutHints(
            previousDisplayEntries,
          ) ??
          OrderMapper.coalesceLayoutHints(previous.displayEntries);
      final detail = await _orderRepository.getOrderDetail(
        existing.id,
        previousDisplayEntries: layoutHints,
      );
      // Re-resolve the row by id — a background list refresh may have
      // mutated `orders` while this request was in flight, so the index
      // captured before the `await` can no longer be trusted (writing to
      // a stale index silently drops the fetched detail on the floor,
      // leaving the row showing its lightweight total with no items).
      final freshIdx = orders.indexWhere((order) => order.id == existing.id);
      if (freshIdx >= 0) {
        final live = orders[freshIdx];
        // Stale GET during delete undo must not flash removed lines back.
        orders[freshIdx] = OrderMapper.mergeLiveOptimisticDetail(
          server: detail,
          live: live,
          suppressItemIds: _orderRepository.suppressedItemIdsFor(existing.id),
        );
        orders.refresh();
      }
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

  void openTableDetails(
    String orderNumber, {
    int? orderId,
    bool deferDetailFetch = false,
    SessionOrder? seedOrder,
  }) {
    logOrderFlow(
      'openTableDetails table=$orderNumber orderId=${orderId ?? 'none'} '
      'deferDetailFetch=$deferDetailFetch hasSeed=${seedOrder != null}',
    );
    final resolvedId = orderId != null && orderId > 0
        ? orderId
        : (seedOrder != null && seedOrder.id > 0 ? seedOrder.id : null);
    Get.toNamed(
      AppRoutes.tableDetails,
      arguments: {
        'orderNumber': orderNumber,
        if (resolvedId != null) 'orderId': resolvedId,
        'deferDetailFetch': deferDetailFetch,
        if (seedOrder != null) 'seedOrder': seedOrder,
      },
    );
  }

  void _onTableNumberConfirmed(BuildContext context, String tableNumber) {
    TableNumberDialog.show(
      context: context,
      title: 'NOMBRE DE COUVERTS',
      integerOnly: true,
      maxDigits: 3,
      minValue: 1,
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
    final guests = int.tryParse(couverts.trim()) ?? 0;
    if (guests < 1) {
      logOrderFlow('_createTableAndOpenDetails ABORT guests must be > 0');
      _showSnack(
        'Couverts',
        'Le nombre de couverts doit être supérieur à 0.',
      );
      return;
    }
    final waiterId = _currentWaiterId;
    if (waiterId <= 0) {
      logOrderFlow('_createTableAndOpenDetails ABORT not logged in');
      _showSnack('Erreur', 'Utilisateur non connecté. Veuillez vous reconnecter.');
      return;
    }

    // Own open order already in this app's session list → reopen + optional guest PUT.
    final existingOwn = _findOwnOpenOrderForTable(tableNumber);
    if (existingOwn != null) {
      logOrderFlow(
        '_createTableAndOpenDetails SKIP open-by-number — '
        'own order already in list orderId=${existingOwn.id}',
      );
      await _reopenOwnOrderAndUpdateGuests(
        existing: existingOwn,
        guests: guests,
      );
      return;
    }

    // Delete suppress must not block the recreate upsert / details open.
    _clearSuppressedTable(tableNumber);

    isCreatingOrder.value = true;
    SessionOrder? created;
    var attemptedCreate = false;
    var blockRecovery = false;

    try {
      attemptedCreate = true;
      try {
        created = await _createTableOrderFromNumber(
          waiterId: waiterId,
          tableNumber: tableNumber,
          guests: guests,
          salesZoneId: activeDay.value.salesZoneId,
          waiterName: _currentUserFullName,
          context: context,
        );
        if (created == null) return;

        final opened = created!;
        _clearSuppressedTable(tableNumber);
        _clearSuppressedTable(opened.number);
        _upsertOrderInList(opened);
        isCreatingOrder.value = false;
        logOrderFlow(
          '_createTableAndOpenDetails OPEN table=${opened.number} '
          'orderId=${opened.id}',
        );
        openTableDetails(
          opened.number,
          orderId: opened.id,
          seedOrder: opened,
        );
        unawaited(
          refreshOrderList(
            pinOrder: opened,
            background: true,
          ),
        );
        return;
      } on ApiException catch (e) {
        final recovered = await _orderRepository.tryRecoverCreatedOrder(
          tableNumber: tableNumber,
        );
        created = recovered?.order;
        if (created != null) {
          final recoveredWaiter = created.waiterId;
          if (recoveredWaiter != null &&
              recoveredWaiter > 0 &&
              recoveredWaiter != waiterId) {
            created = null;
            blockRecovery = true;
            if (context.mounted) {
              await TableOccupiedDialog.show(
                context: context,
                userName: _currentUserDisplayName,
                tableNumber: tableNumber,
              );
            }
            return;
          }
        } else {
          if (OrderMapper.isTableOwnershipDeniedMessage(e.message)) {
            blockRecovery = true;
            if (context.mounted) {
              await TableOccupiedDialog.show(
                context: context,
                userName: _currentUserDisplayName,
                tableNumber: tableNumber,
              );
            }
          } else {
            _showSnack('Erreur', e.message);
          }
        }
      }
    } catch (_) {
      // Background refresh may still surface the order if the backend created it.
    } finally {
      isCreatingOrder.value = false;
      if (attemptedCreate && !blockRecovery) {
        if (created == null) {
          final resolved = await _orderRepository.resolveOrderIdForTableNumber(
            tableNumber,
          );
          if (resolved != null && resolved > 0) {
            try {
              created = await _orderRepository.openAsEmptyTableOrder(resolved);
            } catch (_) {
              created = null;
            }
          }
        }

        final usable = created;
        if (usable != null &&
            usable.id > 0 &&
            (usable.waiterId == null ||
                usable.waiterId == 0 ||
                usable.waiterId == waiterId)) {
          // Delete suppress is keyed by table number — clear so recreate shows.
          _clearSuppressedTable(tableNumber);
          _clearSuppressedTable(usable.number);
          _upsertOrderInList(usable);
          logOrderFlow(
            '_createTableAndOpenDetails OPEN table=${usable.number} orderId=${usable.id}',
          );
          openTableDetails(
            usable.number,
            orderId: usable.id,
            seedOrder: usable,
          );
          // Keep empty shell pinned if list soft-refresh races ahead of API.
          unawaited(
            refreshOrderList(
              pinOrder: usable,
              background: true,
            ),
          );
        } else if (usable != null &&
            usable.waiterId != null &&
            usable.waiterId != waiterId) {
          if (context.mounted) {
            await TableOccupiedDialog.show(
              context: context,
              userName: _currentUserDisplayName,
              tableNumber: tableNumber,
            );
          }
        }
      }
    }
  }

  Future<SessionOrder?> _createTableOrderFromNumber({
    required int waiterId,
    required String tableNumber,
    required int guests,
    required int? salesZoneId,
    required String? waiterName,
    required BuildContext context,
  }) async {
    final result = await _orderRepository.createTableOrder(
      waiterId: waiterId,
      tableNumber: tableNumber,
      numberOfGuests: guests,
      salesZoneId: salesZoneId,
      waiterName: waiterName,
    );
    final order = result.order;

    final createdWaiter = order.waiterId;
    if (createdWaiter != null &&
        createdWaiter > 0 &&
        createdWaiter != waiterId) {
      if (context.mounted) {
        await TableOccupiedDialog.show(
          context: context,
          userName: _currentUserDisplayName,
          tableNumber: tableNumber,
        );
      }
      return null;
    }
    return order;
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

    // List rows are lightweight (total only). Load full seat_orders before
    // opening table details so items are visible (same as tapping the list).
    if (target.id > 0 && target.products.isEmpty) {
      isCreatingOrder.value = true;
      try {
        target = await _orderRepository.getOrderDetail(target.id);
        _upsertOrderInList(target);
      } catch (_) {
        // Table details bootstrap will retry loadOrderDetails.
      } finally {
        isCreatingOrder.value = false;
      }
    }

    openTableDetails(
      target.number,
      orderId: target.id > 0 ? target.id : null,
      seedOrder: target,
    );
  }

  bool isTableOccupied(String tableNumber) {
    final normalized = tableNumber.trim();
    if (normalized.isEmpty) return false;

    // Own list order is reopened via nouvelle commande — not "occupied" for this waiter.
    if (_findOwnOpenOrderForTable(normalized) != null) return false;

    // Own orphan session (locked, no active_order) is reclaimable — not blocked.
    return OrderMapper.isTableOccupied(
      _sessionRepository.cachedTables,
      normalized,
      forWaiterId: _currentWaiterId,
    );
  }

  String get _currentUserDisplayName {
    final full = _currentUserFullName;
    if (full == null || full.isEmpty) return 'Utilisateur';
    return full.split(' ').first;
  }

  String? get _currentUserFullName {
    if (Get.isRegistered<AuthRepository>()) {
      final session = Get.find<AuthRepository>().cachedSession;
      final name = session?.user.name?.trim();
      if (name != null && name.isNotEmpty) return name;
    }

    if (Get.isRegistered<LoginController>()) {
      final login = Get.find<LoginController>();
      final selected = login.selectedUser.value;
      if (selected != null && selected.name.trim().isNotEmpty) {
        return selected.name.trim();
      }

      final identifiant = login.identifiantController.text.trim();
      if (identifiant.isNotEmpty) return identifiant;
    }

    return null;
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
      onConfirm: () {
        final orderId = order.id;
        final tableNumber = selected.orderNumber;
        final layoutSource = _layoutSourceForSessionDemande(order);
        final layoutHints = OrderMapper.coalesceLayoutHints(
          layoutSource.displayEntries,
        );
        final sectionIndex = layoutHints == null
            ? null
            : OrderMapper.firstPendingSuivreSectionIndex(layoutHints);
        final snapshot = OrderOptimisticSync.deepSnapshot(layoutSource);
        final demandeTimeLabel = _freshDemandeTimeLabel();
        SessionOrder? predicted;

        if (sectionIndex != null && sectionIndex > 0 && layoutHints != null) {
          predicted = OrderMapper.rebuildOrderAfterSuivreDemande(
            serverOrder: layoutSource,
            liveLayout: layoutHints,
            suivreSectionIndex: sectionIndex,
            demandeTimeLabel: demandeTimeLabel,
          );
          updateOrderRow(predicted, replaceDetail: true);
          _showSnack(
            'Suite demandée',
            'La suite a été envoyée pour la table $tableNumber.',
            context: context,
          );
        }

        final predictedLayout = predicted?.displayEntries;
        final syncKey = tableNumber.hashCode;
        final optimisticSync = _optimisticSyncFor(tableNumber);
        optimisticSync.enqueue(
          syncKey: syncKey,
          snapshot: snapshot,
          apply: (updated) {
            if (sectionIndex != null &&
                sectionIndex > 0 &&
                predictedLayout != null) {
              final merged = OrderMapper.rebuildOrderAfterSuivreDemande(
                serverOrder: updated,
                liveLayout: predictedLayout,
                suivreSectionIndex: sectionIndex,
                demandeTimeLabel: demandeTimeLabel,
              );
              updateOrderRow(merged, replaceDetail: true);
              return;
            }
            updateOrderRow(updated, replaceDetail: true);
            _showSnack(
              'Suite demandée',
              'La suite a été envoyée pour la table $tableNumber.',
              context: context,
            );
          },
          sync: () async {
            final live = findOrder(orderNumber: tableNumber) ?? layoutSource;
            var layoutForDemande = OrderMapper.coalesceLayoutHints(
                  live.displayEntries,
                ) ??
                OrderMapper.coalesceLayoutHints(layoutSource.displayEntries);

            return _orderRepository.requestNextCourses(
              orderId,
              previousDisplayEntries: layoutForDemande,
            );
          },
          recover: (snap) async {
            try {
              return await _orderRepository.getOrderDetail(
                orderId,
                previousDisplayEntries: snap.displayEntries,
              );
            } catch (_) {
              return snap;
            }
          },
          onError: (error) {
            updateOrderRow(snapshot, replaceDetail: true);
            if (error is ApiException) {
              _showSnack('Erreur', error.message, context: context);
              return;
            }
            _showSnack(
              'Erreur',
              'Impossible d\'envoyer la demande de suite.',
              context: context,
            );
          },
        );
      },
    );
  }

  SessionOrder _layoutSourceForSessionDemande(SessionOrder order) {
    if (OrderMapper.coalesceLayoutHints(order.displayEntries) != null) {
      return order;
    }
    if (order.id <= 0) return order;
    return _orderRepository.cachedSessionOrder(order.id) ?? order;
  }

  String _freshDemandeTimeLabel() {
    return OrderMapper.formatDemandeTime(
          DateTime.now().toUtc().toIso8601String(),
        ) ??
        '--:--:--';
  }

  void requestDeleteOrder(String orderNumber, {required BuildContext context}) {
    if (findOrder(orderNumber: orderNumber) == null) return;

    CancelTableDialog.show(
      context: context,
      title: 'Annulation Table',
      onConfirm: ({
        required String userOrId,
        required String passcode,
      }) async {
        await _authRepository.verifyCredentials(
          userOrId: userOrId,
          passcode: passcode,
        );

        // Open step 2 after step 1 closes (same old two-dialog flow).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          CancelTableNoteDialog.show(
            context: context,
            title: 'Annulation après édition\nnote',
            onConfirm: ({
              required String toWhom,
              required String note,
            }) async {
              await deleteOrder(
                orderNumber,
                cancelToWhom: toWhom,
                cancelNote: note,
              );
            },
          );
        });
      },
    );
  }

  Future<void> deleteOrder(
    String orderNumber, {
    String? cancelToWhom,
    String? cancelNote,
  }) async {
    final order = findOrder(orderNumber: orderNumber);
    if (order == null) return;

    _suppressedTableNumbers.add(order.number);

    try {
      if (order.isLocalOnly) {
        final tableId = -order.id;
        if (tableId > 0) {
          try {
            await _orderRepository.endTableSession(tableId);
          } on ApiException {
            // Order is local-only; still remove from the list even if release fails.
          }
        }
      } else {
        await _orderRepository.closeOrder(
          order.id,
          tableNumber: order.number,
          cancelToWhom: cancelToWhom,
          cancelNote: cancelNote,
        );
      }

      // Remove in place — do not reload / reshuffle the whole session list.
      orders.removeWhere((o) => _tableKeysMatch(o.number, order.number));
      orders.refresh();
      _clearUiStateForOrder(order.number);

      // Occupancy cache only; keep session row order stable. Clear suppress once
      // tables refresh so immediate recreate is not filtered out of the list.
      unawaited(() async {
        try {
          await _sessionRepository.getTablesList(forceRefresh: true);
        } catch (_) {}
        if (!_ordersContainTable(order.number)) {
          _clearSuppressedTable(order.number);
        }
      }());
    } on ApiException {
      _suppressedTableNumbers.removeWhere(
        (suppressed) => _tableKeysMatch(suppressed, order.number),
      );
      rethrow;
    } catch (_) {
      _suppressedTableNumbers.removeWhere(
        (suppressed) => _tableKeysMatch(suppressed, order.number),
      );
      throw ApiException(message: 'Impossible d\'annuler la table.');
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
    if (findOrder(orderNumber: orderNumber) == null) return;

    CancelTableDialog.show(
      context: context,
      title: 'Table Offerte',
      onConfirm: ({
        required String userOrId,
        required String passcode,
      }) async {
        await _authRepository.verifyCredentials(
          userOrId: userOrId,
          passcode: passcode,
        );
        await applyOffer(orderNumber);
      },
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
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(message: 'Impossible d\'appliquer l\'offre.');
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
    AppSnackbar.show(title, message, context: context);
  }
}
