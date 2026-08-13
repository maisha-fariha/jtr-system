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
import '../services/reverb_realtime_service.dart';
import '../data/mappers/order_mapper.dart';
import '../data/order_optimistic_sync.dart';
import '../data/models/active_day_info.dart';
import '../data/models/day_statistics_info.dart';
import '../data/models/sales_zone_info.dart';
import '../core/network/api_exception.dart';
import '../core/auth/pos_permissions.dart';
import '../controllers/login_controller.dart';
import '../controllers/table_details_controller.dart';
import '../utils/api_log.dart';
import '../utils/app_theme.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/cancel_table_dialog.dart';
import '../widgets/customer_cardex_dialog.dart';
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
  final isLoadingMoreOrders = false.obs;
  final loadingDetailOrderNumbers = <String>{}.obs;
  final ordersError = RxnString();
  final activeDay = ActiveDayInfo.fallback().obs;
  final dayStatistics = Rxn<DayStatisticsInfo>();
  final isLoadingStatistics = false.obs;
  final paidOrders = <SessionOrder>[].obs;
  final isLoadingPaidOrders = false.obs;
  final isCreatingOrder = false.obs;
  final isPrintingTicket = false.obs;

  /// Sales zones from shortlist (empty = legacy single-flow fallback).
  final salesZones = <SalesZoneInfo>[].obs;
  final selectedSalesZone = Rxn<SalesZoneInfo>();

  /// Bumped when the session list should jump to the top (e.g. after Send).
  final listScrollSignal = 0.obs;

  /// Mirrors Reverb table-lock revisions so occupancy checks see fresh cache.
  final tablesLockRevision = 0.obs;

  Worker? _tablesLockWorker;

  /// When deleting an order we optimistically remove it from [orders],
  /// but a subsequent forced refresh may temporarily still return the
  /// deleted row (backend eventual consistency).
  /// We suppress re-adding those orders until the server list stops
  /// containing them.
  final Set<String> _suppressedTableNumbers = <String>{};

  /// Stable free-zone labels: server tickets use `C{orderId}`.
  final Map<int, String> _freeTicketByOrderId = <int, String>{};

  /// Bumped on each list fetch so a late unscoped response cannot overwrite
  /// a newer zone-scoped list.
  int _ordersFetchGeneration = 0;

  int _sessionOrdersLastPage = 1;
  int _sessionOrdersNextPage = 2;

  bool get hasMoreSessionOrders =>
      _sessionOrdersNextPage <= _sessionOrdersLastPage;

  /// After page-1 replace (first load / swipe refresh), jump the list to top
  /// so a leftover scroll offset cannot auto-fetch the next pages.
  final resetSessionListToTop = false.obs;

  @override
  void onInit() {
    super.onInit();
    _bindTablesLockRevision();
    final args = Get.arguments;
    final justPreloaded = args is Map && args['preloaded'] == true;
    unawaited(_bootstrapSession(justPreloaded: justPreloaded));
  }

  /// Resolve sales zone first, then load orders — never paint an unscoped
  /// list when a zone is available (first login used to show every zone).
  Future<void> _bootstrapSession({required bool justPreloaded}) async {
    unawaited(loadActiveDay(forceRefresh: !justPreloaded));

    // Wait for shortlist (often already warm from Connect) before any list I/O.
    await loadSalesZones(
      forceRefresh: !justPreloaded,
      reloadOrdersIfChanged: false,
    );

    final zoneId = selectedSalesZoneId;
    final preloadedRows = justPreloaded
        ? _sessionRepository.takePreloadedSessionOrders()
        : null;

    if (zoneId != null) {
      // Zone known: never hydrate/paint a possibly-unscoped cache as final.
      if (preloadedRows != null && preloadedRows.isNotEmpty) {
        orders.assignAll(preloadedRows);
      }
      await loadSessionOrders(
        forceRefresh: true,
        showLoading: orders.isEmpty,
        enrichDetails: false,
        replaceExistingList: true,
      );
    } else if (preloadedRows != null && preloadedRows.isNotEmpty) {
      // No shortlist → legacy Sur place (all open orders for waiter/day).
      orders.assignAll(preloadedRows);
    } else {
      _hydrateOrdersFromCache();
      await loadSessionOrders(
        forceRefresh: orders.isEmpty,
        showLoading: orders.isEmpty,
        enrichDetails: false,
      );
    }

    unawaited(_prefetchTables());
    if (!justPreloaded) {
      unawaited(_prefetchCreateCatalog());
    }
  }

  void _bindTablesLockRevision() {
    if (!Get.isRegistered<ReverbRealtimeService>()) return;
    final reverb = Get.find<ReverbRealtimeService>();
    tablesLockRevision.value = reverb.tablesLockRevision.value;
    _tablesLockWorker = ever<int>(reverb.tablesLockRevision, (rev) {
      tablesLockRevision.value = rev;
      // Lock changed — refresh occupancy caches in bg for the next Skip check.
      _startOccupancyWarmInBackground();
    });
  }

  @override
  void onClose() {
    _tablesLockWorker?.dispose();
    _tablesLockWorker = null;
    super.onClose();
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
        waiterId: _ordersListWaiterFilter,
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
    _subscribeActiveFloorChannel();
  }

  /// Loads shortlist and selects default zone. Safe no-op if API unavailable.
  Future<void> loadSalesZones({
    bool forceRefresh = false,
    bool reloadOrdersIfChanged = true,
  }) async {
    final previousId = selectedSalesZone.value?.id;
    final zones = await _sessionRepository.getSalesZonesShortlist(
      forceRefresh: forceRefresh,
    );
    salesZones.assignAll(zones);
    if (zones.isEmpty) {
      selectedSalesZone.value = null;
      return;
    }

    final current = selectedSalesZone.value;
    if (current != null) {
      final match = zones.where((z) => z.id == current.id).toList();
      if (match.isNotEmpty) {
        selectedSalesZone.value = match.first;
      } else {
        selectedSalesZone.value = SalesZoneInfo.pickDefault(zones);
      }
    } else {
      selectedSalesZone.value = SalesZoneInfo.pickDefault(zones);
    }

    final nextId = selectedSalesZone.value?.id;
    if (nextId != null && nextId > 0) {
      _subscribeActiveFloorChannel();
    }
    // First time we get a zone (or zone changed) — reload list scoped to it.
    // Bootstrap passes [reloadOrdersIfChanged]: false to avoid a race with its
    // own single zone-scoped fetch.
    if (reloadOrdersIfChanged &&
        nextId != null &&
        nextId > 0 &&
        nextId != previousId) {
      unawaited(
        loadSessionOrders(
          forceRefresh: true,
          showLoading: orders.isEmpty,
          replaceExistingList: true,
        ),
      );
    }
  }

  int? get selectedSalesZoneId {
    final id = selectedSalesZone.value?.id;
    if (id != null && id > 0) return id;
    final fromDay = activeDay.value.salesZoneId;
    if (fromDay != null && fromDay > 0) return fromDay;
    return null;
  }

  String get selectedSalesZoneLabel {
    final zone = selectedSalesZone.value;
    if (zone != null) return zone.displayLabel;
    return activeDay.value.salesZoneLabel;
  }

  bool get selectedZoneUsesTableFlow {
    final zone = selectedSalesZone.value;
    // No shortlist → keep legacy table flow (Sur place).
    if (zone == null) return true;
    return zone.usesTableFlow;
  }

  Future<void> selectSalesZone(SalesZoneInfo zone) async {
    if (selectedSalesZone.value?.id == zone.id) return;
    selectedSalesZone.value = zone;
    // New zone → drop prior free-zone label cache for that zone's tickets.
    _freeTicketByOrderId.clear();
    // Drop previous zone rows immediately so the session list shows a loader
    // while the zone-scoped fetch completes (not a stale mix of zones).
    orders.clear();
    ordersError.value = null;
    isLoadingOrders.value = true;
    await loadSessionOrders(
      forceRefresh: true,
      showLoading: true,
      replaceExistingList: true,
    );
    _subscribeActiveFloorChannel();
  }

  /// Docs: subscribe `private-tables.floor.{id}` while on that floor/zone.
  void _subscribeActiveFloorChannel() {
    final floorId = selectedSalesZoneId ?? activeDay.value.salesZoneId;
    if (floorId == null || floorId <= 0) return;
    if (!Get.isRegistered<ReverbRealtimeService>()) return;
    unawaited(Get.find<ReverbRealtimeService>().subscribeFloor(floorId));
  }

  Future<void> _prefetchTables() async {
    try {
      await _sessionRepository.warmOccupancyCaches();
      _debugLogAssignedTablesOnSessionOpen();
      if (Get.isRegistered<ReverbRealtimeService>()) {
        Get.find<ReverbRealtimeService>().resyncSubscriptions();
      }
    } catch (_) {}
  }

  /// In-flight occupancy warm — never awaited on table confirm (bg only).
  Future<void>? _occupancyWarmInFlight;

  /// Refresh tables + open-orders in background. Safe to call often.
  void _startOccupancyWarmInBackground() {
    if (_occupancyWarmInFlight != null) return;
    _occupancyWarmInFlight = () async {
      try {
        await _sessionRepository.warmOccupancyCaches();
      } catch (_) {
      } finally {
        _occupancyWarmInFlight = null;
      }
    }();
  }

  void _debugLogAssignedTablesOnSessionOpen() {
    final tables = _sessionRepository.cachedTables;
    final myWaiterId = _currentWaiterId;

    debugPrint(
      '[Session:OPEN] myWaiterId=$myWaiterId tables=${tables.length}',
    );

    var assignedCount = 0;

    for (final t in tables) {
      final tableNoRaw =
          t['table_number'] ?? t['number'] ?? t['name'] ?? t['id'];
      final tableNo = tableNoRaw?.toString().trim() ?? '';
      if (tableNo.isEmpty) continue;

      final activeOrder = t['active_order'];
      int? activeOrderWaiterId;
      int? activeOrderUserId;
      String? activeOrderWaiterName;

      if (activeOrder is Map<String, dynamic>) {
        activeOrderWaiterId = OrderMapper.waiterIdFromOrderMap(activeOrder);
        activeOrderUserId = (activeOrder['user_id'] as num?)?.toInt();
        final waiter = activeOrder['waiter'];
        if (waiter is Map<String, dynamic>) {
          final n = waiter['name'];
          if (n is String && n.isNotEmpty) activeOrderWaiterName = n;
        }
      }

      final sessionOwnerId =
          (t['session_owner_id'] as num?)?.toInt() ??
          (t['locked_by'] as num?)?.toInt();

      final isLocked = t['is_locked'] == true;
      final status = t['status'] ?? '—';

      // Only log tables that look assigned (occupied/locked/open session).
      final hasAssignment = activeOrderWaiterId != null ||
          activeOrderUserId != null ||
          (sessionOwnerId != null && sessionOwnerId > 0) ||
          isLocked ||
          status == 'open';

      if (!hasAssignment) continue;
      assignedCount++;

      final id = (t['id'] as num?)?.toInt();
      debugPrint(
        '[Session:OPEN] ASSIGNED T$tableNo (rowId=${id ?? '—'}) '
        'owner(waiterId=${activeOrderWaiterId ?? '—'} '
        'userId=${activeOrderUserId ?? '—'} '
        'waiterName=${activeOrderWaiterName ?? '—'}) '
        'sessionOwner/lockedBy=${sessionOwnerId ?? '—'} '
        'status=$status is_locked=$isLocked',
      );
    }

    debugPrint('[Session:OPEN] assignedTablesCount=$assignedCount');
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
    if (!canAccessStatistics) return;
    selectAction(SessionAction.statistics);
    await loadDayStatistics();
    // Warm paid-orders cache while the user views KPIs (non-blocking).
    _prefetchPaidOrdersInBackground();
    await Get.toNamed(AppRoutes.statistics);
  }

  /// Remove a fully paid table from the open session list.
  void removePaidOrderFromOpenList(SessionOrder order) {
    _suppressedTableNumbers.add(order.number);
    orders.removeWhere(
      (o) =>
          (order.id > 0 && o.id == order.id) ||
          _tableKeysMatch(o.number, order.number),
    );
    orders.refresh();
    _clearUiStateForOrder(order.number);
    unawaited(() async {
      try {
        await _sessionRepository.getTablesList(forceRefresh: true);
      } catch (_) {}
      // Allow a new order on the same table number after pay.
      Future<void>.delayed(const Duration(seconds: 2), () {
        _suppressedTableNumbers.removeWhere(
          (s) => _tableKeysMatch(s, order.number),
        );
      });
    }());
  }

  /// Instant local snapshot for the paid-orders list (no network).
  void _applyCachedPaidOrders() {
    paidOrders.assignAll(
      _sessionRepository.getCachedPaidOrders(waiterId: _ordersListWaiterFilter),
    );
  }

  /// Prefetch while on Statistics so "Commandes payées" opens instantly.
  void _prefetchPaidOrdersInBackground() {
    if (isLoadingPaidOrders.value) return;
    final cached = _sessionRepository.getCachedPaidOrders(
      waiterId: _ordersListWaiterFilter,
    );
    if (cached.isNotEmpty) {
      paidOrders.assignAll(cached);
      return;
    }
    unawaited(loadPaidOrders(forceRefresh: false));
  }

  Future<void> loadPaidOrders({bool forceRefresh = false}) async {
    if (isLoadingPaidOrders.value) return;
    isLoadingPaidOrders.value = true;
    try {
      final rows = await _sessionRepository.getPaidOrders(
        forceRefresh: forceRefresh,
        waiterId: _ordersListWaiterFilter,
      );
      paidOrders.assignAll(rows);
    } on ApiException catch (e) {
      _showSnack('Erreur', e.message);
      _applyCachedPaidOrders();
    } catch (_) {
      _applyCachedPaidOrders();
    } finally {
      isLoadingPaidOrders.value = false;
    }
  }

  /// Opens paid orders immediately from cache; refreshes on the list page.
  Future<void> openPaidOrders() async {
    if (Get.currentRoute == AppRoutes.paidOrders) return;

    // Show disk cache right away — do not block navigation on the API.
    _applyCachedPaidOrders();

    final navigation = Get.toNamed(AppRoutes.paidOrders);
    // Network refresh while the user already sees the page (or a spinner).
    unawaited(loadPaidOrders(forceRefresh: true));
    await navigation;
  }

  Future<void> loadSessionOrders({
    bool forceRefresh = false,
    Iterable<SessionOrder>? retainOrders,
    bool showLoading = true,
    bool enrichDetails = false,
    /// When false, page-1 updates merge in place (no reshuffle).
    bool replaceExistingList = true,
  }) async {
    final fetchGen = ++_ordersFetchGeneration;
    if (showLoading && orders.isEmpty) {
      isLoadingOrders.value = true;
    }
    ordersError.value = null;

    try {
      // Don't re-fetch active day here — onInit already loads it.
      // Stale-while-revalidate: paint cache instantly, then refresh UI when
      // the full network fetch returns (no spinner if rows already visible).
      // Never use unscoped disk cache when a sales zone is selected.
      if (!forceRefresh && selectedSalesZoneId == null) {
        final cached = _sessionRepository.getCachedSessionOrders(
          waiterId: _ordersListWaiterFilter,
        );
        if (cached.isNotEmpty) {
          if (fetchGen != _ordersFetchGeneration) return;
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

      // Page 1 only (`per_page` 20). Further pages load on scroll.
      await _loadSessionOrdersPage1(
        fetchGen: fetchGen,
        retainOrders: retainOrders,
        enrichDetails: enrichDetails,
        replaceExistingList: replaceExistingList,
        forceRefresh: forceRefresh,
      );
    } on ApiException catch (e) {
      if (fetchGen != _ordersFetchGeneration) return;
      ordersError.value = e.message;
      if (orders.isEmpty && showLoading) {
        _showSnack('Erreur', e.message);
      }
    } catch (_) {
      if (fetchGen != _ordersFetchGeneration) return;
      ordersError.value = 'Impossible de charger les commandes.';
      if (orders.isEmpty && showLoading) {
        _showSnack('Erreur', ordersError.value!);
      }
    } finally {
      if (showLoading && fetchGen == _ordersFetchGeneration) {
        isLoadingOrders.value = false;
      }
    }
  }

  Future<void> _softRefreshSessionOrders({
    Iterable<SessionOrder>? retainOrders,
    bool enrichDetails = false,
  }) async {
    final fetchGen = ++_ordersFetchGeneration;
    try {
      await _loadSessionOrdersPage1(
        fetchGen: fetchGen,
        retainOrders: retainOrders,
        enrichDetails: enrichDetails,
        replaceExistingList: true,
        forceRefresh: true,
      );
    } catch (_) {
      // Keep the cached list already on screen.
    }
  }

  /// Pull-to-refresh / post-CRUD: keep list visible, soft-swap from light API.
  Future<void> refreshSessionOrders({
    Iterable<SessionOrder>? retainOrders,
  }) async {
    final fetchGen = ++_ordersFetchGeneration;
    ordersError.value = null;
    unawaited(loadActiveDay(forceRefresh: true));
    try {
      await _loadSessionOrdersPage1(
        fetchGen: fetchGen,
        retainOrders: retainOrders,
        enrichDetails: false,
        replaceExistingList: true,
        forceRefresh: true,
      );
    } catch (_) {
      if (fetchGen != _ordersFetchGeneration) return;
      if (orders.isEmpty) {
        ordersError.value = 'Impossible de charger les commandes.';
      }
    }
  }

  Future<void> _loadSessionOrdersPage1({
    required int fetchGen,
    Iterable<SessionOrder>? retainOrders,
    required bool enrichDetails,
    required bool replaceExistingList,
    required bool forceRefresh,
  }) async {
    isLoadingMoreOrders.value = false;
    // Same as first load: only page 1 is valid until the user scrolls.
    _sessionOrdersLastPage = 1;
    _sessionOrdersNextPage = 2;

    final first = await _sessionRepository.fetchSessionOrdersPage(
      page: 1,
      waiterId: _ordersListWaiterFilter,
      salesZoneId: selectedSalesZoneId,
    );
    if (fetchGen != _ordersFetchGeneration) return;

    _sessionOrdersLastPage = first.lastPage;
    _sessionOrdersNextPage = 2;

    final replace = replaceExistingList || orders.isEmpty;
    _applySessionOrderSummaries(
      first.orders,
      retainOrders: retainOrders,
      enrichDetails: enrichDetails,
      replaceList: replace,
      clearSuppressedMatches: forceRefresh,
    );
    if (replace) {
      resetSessionListToTop.value = true;
    }
  }

  /// Next page when the session list is scrolled near the bottom.
  Future<void> loadMoreSessionOrders() async {
    if (isLoadingMoreOrders.value) return;
    if (_sessionOrdersNextPage > _sessionOrdersLastPage) return;

    final fetchGen = _ordersFetchGeneration;
    isLoadingMoreOrders.value = true;
    try {
      final pageNum = _sessionOrdersNextPage;
      final result = await _sessionRepository.fetchSessionOrdersPage(
        page: pageNum,
        waiterId: _ordersListWaiterFilter,
        salesZoneId: selectedSalesZoneId,
      );
      if (fetchGen != _ordersFetchGeneration) return;

      _sessionOrdersLastPage = result.lastPage;
      _sessionOrdersNextPage = pageNum + 1;
      _applySessionOrderSummaries(
        result.orders,
        enrichDetails: false,
        replaceList: false,
      );
    } catch (_) {
      // Keep the pages already on screen.
    } finally {
      if (fetchGen == _ordersFetchGeneration) {
        isLoadingMoreOrders.value = false;
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
      // Keep unsent local drafts (id <= 0) that the API list does not include yet.
      final localDrafts = <SessionOrder>[
        for (final order in orders)
          if (order.id <= 0 && !_isOrderSuppressed(order.number)) order,
      ];
      final serverRows = [
        for (final order in filtered)
          _preferDetailedOrder(order, previousById[order.id]),
      ];
      // Drop local drafts whose table already appears on the server list.
      final serverTables = <String>{
        for (final order in serverRows) normalizeTableKey(order.number),
      };
      orders.assignAll([
        ...serverRows,
        for (final draft in localDrafts)
          if (!serverTables.contains(normalizeTableKey(draft.number))) draft,
      ]);
    } else {
      _mergeSessionOrdersStable(filtered);
    }

    if (retainOrders != null) {
      for (final order in retainOrders) {
        _upsertOrderInList(order);
      }
    }
    // Page-1 replace must not glue previous pages back. Lightweight list
    // rows have empty `products`, so they would look like empty shells.
    if (!replaceList) {
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
    }
    _dedupeOrdersByTableKeyInPlace();
    _relabelFreeZoneOrdersInPlace();
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
  ///
  /// Local drafts use `id <= 0` (e.g. `-tableId`). When the server order for
  /// the same table arrives, replace that draft — never keep both rows.
  void _mergeSessionOrdersStable(List<SessionOrder> incoming) {
    final incomingById = <int, SessionOrder>{
      for (final order in incoming)
        if (order.id > 0) order.id: order,
    };

    // 1) Refresh rows that already have a real server id.
    for (var i = 0; i < orders.length; i++) {
      final current = orders[i];
      if (current.id <= 0) continue;
      final updated = incomingById[current.id];
      if (updated == null) continue;
      orders[i] = _preferDetailedOrder(updated, current);
    }

    // 2) Adopt server rows that are new by id — folding any same-table draft.
    final existingIds = <int>{
      for (final order in orders)
        if (order.id > 0) order.id,
    };
    for (final order in incoming) {
      if (order.id <= 0 || existingIds.contains(order.id)) continue;

      final draftIdx = orders.indexWhere(
        (item) =>
            item.id <= 0 && _tableKeysMatch(item.number, order.number),
      );
      if (draftIdx >= 0) {
        orders[draftIdx] = _preferDetailedOrder(order, orders[draftIdx]);
      } else {
        // Same table may already have another positive id (rare race) — replace.
        final sameTableIdx = orders.indexWhere(
          (item) => _tableKeysMatch(item.number, order.number),
        );
        if (sameTableIdx >= 0) {
          orders[sameTableIdx] =
              _preferDetailedOrder(order, orders[sameTableIdx]);
        } else {
          orders.add(order);
        }
      }
      existingIds.add(order.id);
    }
  }

  /// One visible row per table — prefer real server id, then richer detail.
  void _dedupeOrdersByTableKeyInPlace() {
    final bestByTable = <String, SessionOrder>{};
    final orderOfKeys = <String>[];

    for (final order in orders) {
      final key = normalizeTableKey(order.number);
      if (key.isEmpty) continue;
      final existing = bestByTable[key];
      if (existing == null) {
        bestByTable[key] = order;
        orderOfKeys.add(key);
        continue;
      }
      bestByTable[key] = _shouldPreferOrderOver(order, existing)
          ? order
          : existing;
    }

    if (bestByTable.length == orders.length) return;

    orders.assignAll([
      for (final key in orderOfKeys) bestByTable[key]!,
    ]);
  }

  bool _shouldPreferOrderOver(SessionOrder candidate, SessionOrder current) {
    // Real server id beats local draft (-tableId).
    if (candidate.id > 0 && current.id <= 0) return true;
    if (candidate.id <= 0 && current.id > 0) return false;
    final candidateLines = candidate.products.length;
    final currentLines = current.products.length;
    if (candidateLines != currentLines) return candidateLines > currentLines;
    final candidateDisplay = candidate.displayEntries.length;
    final currentDisplay = current.displayEntries.length;
    if (candidateDisplay != currentDisplay) {
      return candidateDisplay > currentDisplay;
    }
    // Prefer the higher (newer) server id when both are remote.
    if (candidate.id > 0 && current.id > 0 && candidate.id != current.id) {
      return candidate.id > current.id;
    }
    return false;
  }

  /// Session list summaries omit products; never wipe lines / totals already loaded.
  ///
  /// Free-zone list: sent tickets are `C{orderId}`; local drafts are `CL1`, `CL2`.
  void _relabelFreeZoneOrdersInPlace() {
    if (selectedZoneUsesTableFlow) return;

    for (var i = 0; i < orders.length; i++) {
      final order = orders[i];
      if (order.id > 0) {
        final label = OrderMapper.freeZoneTicketLabelForOrderId(order.id);
        _freeTicketByOrderId[order.id] = label;
        if (order.number != label) {
          orders[i] = order.copyWith(number: label);
        }
        continue;
      }
      if (!OrderMapper.isLocalFreeZoneTicketLabel(order.number)) {
        orders[i] = order.copyWith(number: _nextLocalClLabel());
      }
    }

    // Keep API / mapper order for remote tickets (updated_at). Only float
    // unsent local drafts above them.
    final remotes = <SessionOrder>[];
    final locals = <SessionOrder>[];
    for (final order in orders) {
      if (order.id <= 0) {
        locals.add(order);
      } else {
        remotes.add(order);
      }
    }
    locals.sort(
      (a, b) => OrderMapper.localClSequence(b.number)
          .compareTo(OrderMapper.localClSequence(a.number)),
    );
    orders.assignAll([...locals, ...remotes]);
  }

  String _nextLocalClLabel() {
    return OrderMapper.nextLocalClLabel([
      for (final order in orders)
        if (order.id <= 0) order.number,
    ]);
  }

  SessionOrder _withFreeZoneDisplayNumber(SessionOrder order) {
    if (selectedZoneUsesTableFlow) return order;

    if (order.id > 0) {
      final label = OrderMapper.freeZoneTicketLabelForOrderId(order.id);
      _freeTicketByOrderId[order.id] = label;
      return order.copyWith(number: label);
    }
    if (OrderMapper.isLocalFreeZoneTicketLabel(order.number)) return order;
    return order.copyWith(number: _nextLocalClLabel());
  }

  /// Table-details mutations must call [updateOrderRow] with
  /// `replaceDetail: true` so emptying the last line is not discarded here.
  SessionOrder _preferDetailedOrder(
    SessionOrder incoming,
    SessionOrder? previous,
  ) {
    var resolved = _preferDetailedOrderCore(incoming, previous);
    final prevCustomer = previous?.customerId;
    if ((resolved.customerId == null || resolved.customerId! <= 0) &&
        prevCustomer != null &&
        prevCustomer > 0) {
      resolved = resolved.copyWith(customerId: prevCustomer);
    }
    if (!selectedZoneUsesTableFlow) {
      if (resolved.id > 0) {
        final label = OrderMapper.freeZoneTicketLabelForOrderId(resolved.id);
        _freeTicketByOrderId[resolved.id] = label;
        return resolved.copyWith(number: label);
      }
      final keepLocal = OrderMapper.isLocalFreeZoneTicketLabel(previous?.number)
          ? previous!.number
          : (OrderMapper.isLocalFreeZoneTicketLabel(resolved.number)
              ? resolved.number
              : null);
      if (keepLocal != null) {
        return resolved.copyWith(number: keepLocal);
      }
      return _withFreeZoneDisplayNumber(resolved);
    }
    return resolved;
  }

  SessionOrder _preferDetailedOrderCore(
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
        isPartiallyPaid: incoming.isPartiallyPaid || previous.isPartiallyPaid,
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
        isPartiallyPaid: incoming.isPartiallyPaid || previous.isPartiallyPaid,
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
      return incoming.copyWith(
        itemCount: previous.itemCount,
        isPartiallyPaid: incoming.isPartiallyPaid || previous.isPartiallyPaid,
      );
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

    return incoming.isPartiallyPaid || !previous.isPartiallyPaid
        ? incoming
        : incoming.copyWith(isPartiallyPaid: true);
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
  void clearSuppressedTable(String tableNumber) =>
      _clearSuppressedTable(tableNumber);

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
    if (!selectedZoneUsesTableFlow) {
      if (order.id > 0) {
        final label = OrderMapper.freeZoneTicketLabelForOrderId(order.id);
        _freeTicketByOrderId[order.id] = label;
        safeOrder = order.copyWith(number: label);
      } else {
        safeOrder = _withFreeZoneDisplayNumber(order);
      }
    }
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
        _removeOtherRowsForTable(safeOrder.number, keepIndex: byNumber);
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
      // Drop any other same-table row (stale local draft after Send).
      _removeOtherRowsForTable(safeOrder.number, keepIndex: idx);
      orders.refresh();
      return;
    }

    final byNumber = orders.indexWhere(
      (item) => _tableKeysMatch(item.number, safeOrder.number),
    );
    if (byNumber >= 0) {
      orders[byNumber] = merged(safeOrder, orders[byNumber]);
      _removeOtherRowsForTable(safeOrder.number, keepIndex: byNumber);
      orders.refresh();
      return;
    }

    orders.insert(0, safeOrder);
    orders.refresh();
  }

  void _removeOtherRowsForTable(String tableNumber, {required int keepIndex}) {
    for (var i = orders.length - 1; i >= 0; i--) {
      if (i == keepIndex) continue;
      if (_tableKeysMatch(orders[i].number, tableNumber)) {
        orders.removeAt(i);
      }
    }
  }

  /// Table-details mutations must not be overwritten by [_preferDetailedOrder]
  /// (that helper keeps previous lines when the incoming ticket is empty —
  /// which broke deleting the last article).
  void updateOrderRow(SessionOrder order, {bool replaceDetail = false}) =>
      _upsertOrderInList(order, replaceDetail: replaceDetail);

  /// Moves [order] to the top of the session list and asks the UI to scroll up.
  ///
  /// Used after Send All so the waiter sees the newly created/updated table
  /// without manually scrolling.
  ///
  /// [replaceLocalDraftNumber] — free-zone: drop the pre-Send `C#` row when the
  /// ticket becomes `C{orderId}`.
  ///
  /// [selectForActions] — select the row so Ticket / suite work immediately
  /// after Send (no wait for a post-send refresh lock).
  void promoteOrderToTop(
    SessionOrder order, {
    bool replaceDetail = true,
    String? replaceLocalDraftNumber,
    bool selectForActions = false,
  }) {
    clearSuppressedTable(order.number);
    if (replaceLocalDraftNumber != null &&
        replaceLocalDraftNumber.isNotEmpty &&
        !_tableKeysMatch(replaceLocalDraftNumber, order.number)) {
      clearSuppressedTable(replaceLocalDraftNumber);
      orders.removeWhere(
        (o) => _tableKeysMatch(o.number, replaceLocalDraftNumber),
      );
    }
    _upsertOrderInList(order, replaceDetail: replaceDetail);

    final idx = orders.indexWhere((item) {
      if (order.id > 0 && item.id == order.id) return true;
      return _tableKeysMatch(item.number, order.number);
    });
    if (idx > 0) {
      final row = orders.removeAt(idx);
      orders.insert(0, row);
      orders.refresh();
    }
    listScrollSignal.value++;

    if (selectForActions) {
      tableUiState.value = tableUiState.value.copyWith(
        selectedRow: SessionRowSelection(orderNumber: order.number),
      );
    } else if (replaceLocalDraftNumber != null &&
        replaceLocalDraftNumber.isNotEmpty) {
      // Free-zone rename: keep Ticket selection if it still pointed at CLn.
      final selected = tableUiState.value.selectedRow;
      if (selected != null &&
          _tableKeysMatch(selected.orderNumber, replaceLocalDraftNumber)) {
        tableUiState.value = tableUiState.value.copyWith(
          selectedRow: SessionRowSelection(
            orderNumber: order.number,
            productIndex: selected.productIndex,
          ),
        );
      }
    }
  }

  /// After Send: quietly re-fetch that order and patch the session row.
  /// Does **not** lock the table (Ticket / reopen stay available immediately).
  Future<void> refreshSentOrderFromApi({
    required String tableNumber,
    required Future<int?> orderIdFuture,
  }) async {
    final key = OrderMapper.normalizeTableKey(tableNumber);
    if (key.isEmpty) return;

    try {
      final orderId = await orderIdFuture;
      if (orderId == null || orderId <= 0) return;

      var detail = await _orderRepository.getOrderDetail(orderId);
      if (!selectedZoneUsesTableFlow) {
        final label = OrderMapper.freeZoneTicketLabelForOrderId(orderId);
        _freeTicketByOrderId[orderId] = label;
        detail = detail.copyWith(number: label);
      }
      promoteOrderToTop(
        detail,
        replaceDetail: true,
        replaceLocalDraftNumber: tableNumber,
        selectForActions: true,
      );
    } catch (_) {
      // Keep optimistic row from Send.
    }
  }

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

  /// `access-print-button` — session / table-details Ticket actions.
  bool get canPrintTicket => PosPermissions.canPrintTicket(
        _authRepository.cachedSession?.user,
      );

  /// `access-dashboard` — Statistics section.
  bool get canAccessStatistics => PosPermissions.canAccessStatistics(
        _authRepository.cachedSession?.user,
      );

  /// `access-offert` — table / line offer actions.
  bool get canAccessOffert => PosPermissions.canAccessOffert(
        _authRepository.cachedSession?.user,
      );

  void showTableNumberDialog({required BuildContext context}) {
    selectAction(SessionAction.nouvelleCommande);

    // Zones without tables: skip table number (desktop free-order flow).
    if (!selectedZoneUsesTableFlow) {
      if (selectedSalesZone.value?.hasClientCardex == true) {
        // Docs: resolve/create customer before creating the order.
        unawaited(
          CustomerCardexDialog.show(
            context: context,
            onSelected: (customer) {
              _promptFreeZoneCovers(
                context: context,
                customerId: customer.id,
              );
            },
          ),
        );
        return;
      }
      _promptFreeZoneCovers(context: context);
      return;
    }

    // Warm tables + open-orders while the waiter types — confirm stays instant.
    _startOccupancyWarmInBackground();
    TableNumberDialog.show(
      context: context,
      integerOnly: true,
      maxDigits: 4,
      onConfirm: (tableNumber) {
        unawaited(_onTableNumberConfirmed(context, tableNumber));
      },
    );
  }

  void _promptFreeZoneCovers({
    required BuildContext context,
    int? customerId,
  }) {
    TableNumberDialog.show(
      context: context,
      title: 'NOMBRE DE COUVERTS',
      integerOnly: true,
      maxDigits: 3,
      minValue: 1,
      onConfirm: (couverts) {
        unawaited(
          _createFreeZoneOrderAndOpenDetails(
            context: context,
            couverts: couverts,
            customerId: customerId,
          ),
        );
      },
    );
  }

  /// Takeaway / delivery style: no table. Local drafts are `CL1`, `CL2`, …
  /// After Send they become `C{orderId}`.
  Future<void> _createFreeZoneOrderAndOpenDetails({
    required BuildContext context,
    required String couverts,
    int? customerId,
  }) async {
    final guests = int.tryParse(couverts.trim()) ?? 0;
    if (guests < 1) {
      _showSnack(
        'Couverts',
        'Le nombre de couverts doit être supérieur à 0.',
      );
      return;
    }
    if (selectedSalesZone.value?.hasClientCardex == true &&
        (customerId == null || customerId <= 0)) {
      _showSnack(
        'Client requis',
        'Sélectionnez un client (cardex) pour cette zone.',
      );
      return;
    }
    final waiterId = _currentWaiterId;
    if (waiterId <= 0) {
      _showSnack('Erreur', 'Utilisateur non connecté. Veuillez vous reconnecter.');
      return;
    }

    final ticketKey = _nextLocalClLabel();
    final zone = selectedSalesZone.value;
    final name = _currentUserDisplayName;
    final placeholder = SessionOrder(
      id: 0,
      number: ticketKey,
      numberColor: AppTheme.primary,
      group: '1',
      poste: name.split(' ').first,
      profitCenter: zone?.displayLabel ?? selectedSalesZoneLabel,
      couverts: '$guests',
      impressionCount: 0,
      impressionColor: OrderMapper.impressionColorFor(0),
      total: OrderMapper.formatPrice('0'),
      products: const [],
      customerId: customerId,
    );

    _upsertOrderInList(placeholder);
    logOrderFlow(
      '_createFreeZoneOrder LOCAL DRAFT ticket=$ticketKey '
      'zone=${zone?.id} guests=$guests customerId=${customerId ?? 'none'}',
    );
    openTableDetails(
      placeholder.number,
      deferDetailFetch: true,
      seedOrder: placeholder,
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

  Future<void> _onTableNumberConfirmed(
    BuildContext context,
    String tableNumber,
  ) async {
    final normalized = tableNumber.trim();
    if (normalized.isEmpty) return;

    final waiterId = _currentWaiterId;
    if (waiterId <= 0) {
      _showSnack('Erreur', 'Utilisateur non connecté. Veuillez vous reconnecter.');
      return;
    }

    // Fast path: own order already in session list — no tables API wait.
    final existingOwn = _findOwnOpenOrderForTable(normalized);
    if (existingOwn != null) {
      _reopenOwnOrderWithoutGuestPrompt(existingOwn);
      return;
    }

    if (await _shouldShowSkipForTable(normalized, waiterId)) {
      logOrderFlow('[Skip] showing TableOccupiedDialog table=$normalized');
      if (context.mounted) {
        await TableOccupiedDialog.show(
          context: context,
          userName: _currentUserDisplayName,
          tableNumber: normalized,
        );
      }
      return;
    }

    final tables = _sessionRepository.cachedTables;
    final ownActiveOrderId = OrderMapper.ownReusableActiveOrderId(
      tables,
      normalized,
      waiterId: waiterId,
    );
    if (ownActiveOrderId != null && ownActiveOrderId > 0) {
      _reopenServerOwnedOrderWithoutGuestPrompt(
        orderId: ownActiveOrderId,
        tableNumber: normalized,
      );
      return;
    }

    if (!context.mounted) return;
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

  /// Fast Skip for new-order:
  /// - No order id / already non-pending in memory → available **immediately**
  ///   (guest dialog), lists refresh in background.
  /// - Memory says pending (or status unknown with an id) → one live GET
  ///   (API status, not cache) before Skip or guest dialog.
  Future<bool> _shouldShowSkipForTable(String tableNumber, int waiterId) async {
    tablesLockRevision.value;

    logOrderFlow(
      '[Skip] START table=$tableNumber waiterId=$waiterId — fast path',
    );
    _logSkipTableSnapshot(tableNumber, waiterId);

    final cachedStatus = OrderMapper.activeOrderStatus(
      _sessionRepository.cachedTables,
      tableNumber,
    );
    final orderId = _candidateSkipOrderId(tableNumber, waiterId);
    logOrderFlow(
      '[Skip] memory orderId=$orderId cachedStatus=$cachedStatus',
    );

    // Instant free: nothing to verify, or cache already shows not open.
    if (orderId == null || orderId <= 0) {
      _startOccupancyWarmInBackground();
      logOrderFlow(
        '[Skip] RESULT=false (no order id — available immediately, bg refresh)',
      );
      return false;
    }
    if (cachedStatus != null &&
        cachedStatus.isNotEmpty &&
        cachedStatus != 'pending') {
      _startOccupancyWarmInBackground();
      logOrderFlow(
        '[Skip] RESULT=false (cached status="$cachedStatus" not open — '
        'available immediately, bg refresh)',
      );
      return false;
    }

    // Pending or unknown status — confirm with live API (not cache).
    _startOccupancyWarmInBackground();
    logOrderFlow('[Skip] verifying live status for orderId=$orderId');

    try {
      final detail =
          await _orderRepository.fetchOrderMapForOccupancy(orderId);
      final status = detail['status']?.toString();
      final owner = OrderMapper.waiterIdFromOrderMap(detail);
      final isOpen = OrderMapper.isPendingOrderStatus(detail);
      logOrderFlow(
        '[Skip] live GET order=$orderId status=$status '
        'waiter_id=$owner isOpen/pending=$isOpen (API)',
      );

      if (!isOpen) {
        logOrderFlow(
          '[Skip] RESULT=false (order not open, status="$status" — available)',
        );
        return false;
      }
      if (owner != null && owner > 0 && owner == waiterId) {
        logOrderFlow(
          '[Skip] RESULT=false (open order is own waiterId=$owner)',
        );
        return false;
      }
      logOrderFlow(
        '[Skip] RESULT=true (open foreign/unknown order owner=$owner)',
      );
      return true;
    } catch (e) {
      logOrderFlow('[Skip] live GET FAILED: $e → RESULT=true (fail-safe)');
      return true;
    }
  }

  /// Best-effort order id from current memory (tables active_order / open-orders).
  int? _candidateSkipOrderId(String tableNumber, int waiterId) {
    return OrderMapper.activeOrderIdOnTable(
          _sessionRepository.cachedTables,
          tableNumber,
        ) ??
        OrderMapper.foreignPendingOpenOrderId(
          _sessionRepository.cachedOccupancyOpenOrders,
          tableNumber,
          waiterId: waiterId,
        );
  }

  void _logSkipTableSnapshot(String tableNumber, int waiterId) {
    final tables = _sessionRepository.cachedTables;
    final status = OrderMapper.activeOrderStatus(tables, tableNumber);
    final activeId = OrderMapper.activeOrderIdOnTable(tables, tableNumber);
    final owner = OrderMapper.activeOrderOwnerId(tables, tableNumber);
    final assigned = OrderMapper.isAssignedToOtherWaiter(
      tables,
      tableNumber,
      waiterId: waiterId,
    );
    logOrderFlow(
      '[Skip] snapshot table=$tableNumber myWaiter=$waiterId '
      'activeOrderId=$activeId activeStatus=$status '
      'pendingOwner=$owner assignedOther=$assigned',
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

    // Local-first create never calls open-by-number — re-check occupancy here.
    if (await _shouldShowSkipForTable(tableNumber.trim(), waiterId)) {
      if (context.mounted) {
        await TableOccupiedDialog.show(
          context: context,
          userName: _currentUserDisplayName,
          tableNumber: tableNumber.trim(),
        );
      }
      return;
    }

    _clearSuppressedTable(tableNumber);

    final parsedTableNumber =
        OrderMapper.parseTableNumberForOpenByNumber(tableNumber) ??
            int.tryParse(tableNumber.replaceFirst(RegExp(r'^T'), '').trim()) ??
            0;
    if (parsedTableNumber < 1) {
      _showSnack('Erreur', 'Numéro de table invalide.');
      return;
    }

    // Local-first: no POST /api/orders until Send All — items stay on-device.
    final placeholder = OrderMapper.buildSessionPlaceholderOrder(
      tableNumber: parsedTableNumber,
      numberOfGuests: guests,
    );

    _upsertOrderInList(placeholder);
    logOrderFlow(
      '_createTableAndOpenDetails LOCAL DRAFT table=$parsedTableNumber '
      'guests=$guests',
    );
    openTableDetails(
      placeholder.number,
      deferDetailFetch: true,
      seedOrder: placeholder,
    );
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

  void _reopenOwnOrderWithoutGuestPrompt(SessionOrder existing) {
    logOrderFlow(
      '_reopenOwnOrderWithoutGuestPrompt '
      'table=${existing.number} orderId=${existing.id}',
    );

    // Prefer cached detail for instant paint; table-details loads the rest.
    var target = existing;
    if (target.id > 0 && target.products.isEmpty) {
      final cached = _orderRepository.cachedOrderDetail(target.id);
      if (cached != null) {
        target = OrderMapper.fromOrderDetail(cached).copyWith(id: target.id);
        _upsertOrderInList(target);
      }
    }

    openTableDetails(
      target.number,
      orderId: target.id > 0 ? target.id : null,
      deferDetailFetch: target.isLocalOnly,
      seedOrder: target,
    );
  }

  void _reopenServerOwnedOrderWithoutGuestPrompt({
    required int orderId,
    required String tableNumber,
  }) {
    logOrderFlow(
      '_reopenServerOwnedOrderWithoutGuestPrompt '
      'table=$tableNumber orderId=$orderId',
    );

    // Open immediately with cache/seed; details page fetches if needed.
    SessionOrder seed;
    final cached = _orderRepository.cachedOrderDetail(orderId);
    if (cached != null) {
      seed = OrderMapper.fromOrderDetail(cached).copyWith(id: orderId);
    } else {
      final parsed =
          OrderMapper.parseTableNumberForOpenByNumber(tableNumber) ??
              int.tryParse(tableNumber.replaceFirst(RegExp(r'^T'), '').trim()) ??
              0;
      seed = OrderMapper.buildSessionPlaceholderOrder(
        tableNumber: parsed > 0 ? parsed : 1,
        numberOfGuests: 1,
      ).copyWith(id: orderId);
    }

    _clearSuppressedTable(seed.number);
    _upsertOrderInList(seed);
    openTableDetails(
      seed.number,
      orderId: orderId,
      deferDetailFetch: false,
      seedOrder: seed,
    );
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
      deferDetailFetch: target.isLocalOnly,
      seedOrder: target,
    );
  }

  bool isTableOccupied(String tableNumber) {
    final normalized = tableNumber.trim();
    if (normalized.isEmpty) return false;

    // Depend on Reverb lock revision when called from Obx.
    tablesLockRevision.value;

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

  /// Waiter filter for the open/paid order lists.
  ///
  /// `null` = manager/cashier/admin see every waiter's orders.
  int? get _ordersListWaiterFilter {
    final user = _authRepository.cachedSession?.user;
    if (PosPermissions.canViewAllOpenOrders(user)) return null;
    final id = _currentWaiterId;
    return id > 0 ? id : null;
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

    final layoutSourcePreview = _layoutSourceForSessionDemande(order);
    final layoutHintsPreview = OrderMapper.coalesceLayoutHints(
      layoutSourcePreview.displayEntries,
    );
    if (layoutHintsPreview != null) {
      final pendingEmpty = layoutHintsPreview.any((entry) {
        if (entry.type != OrderDisplayEntryType.suivreSeparator) return false;
        final sectionIndex = entry.sectionIndex ?? 0;
        if (sectionIndex <= 0) return false;
        return OrderMapper.productEntriesUnderSection(
          layoutHintsPreview,
          sectionIndex,
        ).isEmpty;
      });
      final requestableSection =
          OrderMapper.firstPendingSuivreSectionIndex(layoutHintsPreview);
      if (pendingEmpty && requestableSection == null) {
        _showSnack(
          'Articles requis',
          'Ajoutez au moins un article sous le À SUIVRE avant de demander.',
          context: context,
        );
        return;
      }
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
        // Capture pre-demande layout — live row is flipped optimistically before sync.
        final layoutBeforeDemande = List<OrderDisplayEntry>.from(
          layoutHints ?? snapshot.displayEntries,
        );
        final demandSectionIndex = sectionIndex;
        optimisticSync.enqueue(
          syncKey: syncKey,
          snapshot: snapshot,
          apply: (updated) {
            if (demandSectionIndex != null &&
                demandSectionIndex > 0 &&
                predictedLayout != null) {
              final merged = OrderMapper.rebuildOrderAfterSuivreDemande(
                serverOrder: updated,
                liveLayout: predictedLayout,
                suivreSectionIndex: demandSectionIndex,
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
            final layoutForDemande = OrderMapper.coalesceLayoutHints(
                  layoutBeforeDemande,
                ) ??
                OrderMapper.coalesceLayoutHints(snapshot.displayEntries);

            // Same path as table-details Demande: ensure suite on a writable
            // course then request-courses (session "next" path skipped ensure
            // when live layout was already flipped to DEMANDÉE).
            if (demandSectionIndex != null &&
                demandSectionIndex > 0 &&
                layoutForDemande != null) {
              var preferred = demandSectionIndex + 1;
              for (final entry in layoutForDemande) {
                if (entry.type != OrderDisplayEntryType.suivreSeparator) {
                  continue;
                }
                if (entry.sectionIndex != demandSectionIndex) continue;
                final above = entry.courseNumber ?? demandSectionIndex;
                preferred =
                    above > 0 ? above + 1 : demandSectionIndex + 1;
                break;
              }
              return _orderRepository.requestCourseForSuivreSection(
                orderId,
                courseNumber: preferred,
                previousDisplayEntries: layoutForDemande,
                suivreSectionIndex: demandSectionIndex,
              );
            }

            if (layoutForDemande != null &&
                OrderMapper.hasEmptyPendingSuivreSection(layoutForDemande)) {
              throw ApiException(
                message:
                    'Ajoutez au moins un article sous le À SUIVRE avant de demander.',
              );
            }

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
        final authorizer = await _authRepository.verifyCredentials(
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
                authorizerToken: authorizer.token,
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
    String? authorizerToken,
  }) async {
    final order = findOrder(orderNumber: orderNumber);
    if (order == null) return;

    _suppressedTableNumbers.add(order.number);

    try {
      if (order.isLocalOnly) {
        final tableId = -order.id;
        if (tableId > 0) {
          try {
            await _orderRepository.endTableSession(
              tableId,
              authorizerToken: authorizerToken,
            );
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
          authorizerToken: authorizerToken,
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
    if (!canAccessOffert) return;
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

  void _applyLocalTableOfferAt(int idx, SessionOrder order) {
    final offeredProducts = order.products
        .map(
          (product) => product.copyWith(
            price: '0,00 €',
            isOffered: true,
          ),
        )
        .toList();
    final offeredEntries = [
      for (final entry in order.displayEntries)
        if (entry.type == OrderDisplayEntryType.product &&
            entry.product != null)
          OrderDisplayEntry.product(
            product: entry.product!.copyWith(
              price: '0,00 €',
              isOffered: true,
            ),
            lineIndex: entry.lineIndex ?? 0,
            sectionIndex: entry.sectionIndex ?? 0,
            courseNumber: entry.courseNumber,
            itemId: entry.itemId,
          )
        else
          entry,
    ];
    orders[idx] = order.copyWith(
      total: '0,00 €',
      products: offeredProducts,
      displayEntries: offeredEntries.isNotEmpty
          ? offeredEntries
          : order.displayEntries,
    );
    orders.refresh();
    if (order.id > 0) {
      unawaited(_orderRepository.markOrderOfferedLocally(order.id));
    }
  }

  void _notifyTableDetailsOfferedLock() {
    if (!Get.isRegistered<TableDetailsController>()) return;
    Get.find<TableDetailsController>().refreshOfferedLock();
  }

  bool _isOrderIdNotFoundError(ApiException error) {
    final msg = error.message.toLowerCase();
    return error.statusCode == 404 ||
        msg.contains('order id not found') ||
        msg.contains('the order id not found') ||
        msg.contains('commande introuvable') ||
        (msg.contains('order') && msg.contains('not found')) ||
        (msg.contains('order') && msg.contains('introuvable'));
  }

  Future<void> applyOffer(String orderNumber) async {
    final idx = orders.indexWhere((order) => order.number == orderNumber);
    if (idx < 0) return;

    final order = orders[idx];

    try {
      if (order.isLocalOnly) {
        _applyLocalTableOfferAt(idx, order);
      } else {
        try {
          final updated = await _orderRepository.applyTableOffer(order.id);
          _upsertOrderInList(updated);
        } on ApiException catch (e) {
          // Fresh create / retired offered shell — apply locally, no error toast.
          if (_isOrderIdNotFoundError(e)) {
            _applyLocalTableOfferAt(idx, order);
          } else {
            rethrow;
          }
        }
      }

      _notifyTableDetailsOfferedLock();
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
    if (!canPrintTicket) return;
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
      _upsertOrderInList(updated, replaceDetail: true);

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
