import 'dart:async';

import '../../core/network/api_exception.dart';
import '../../models/session_order.dart';
import '../../services/connectivity_service.dart';
import '../datasources/session_datasource.dart';
import '../mappers/order_mapper.dart';
import '../models/active_day_info.dart';
import '../models/day_statistics_info.dart';
import '../models/realtime/pos_bootstrap_config.dart';
import '../models/sales_zone_info.dart';

class SessionRepository {
  SessionRepository({
    required SessionRemoteDataSource remote,
    required SessionLocalDataSource local,
    required ConnectivityService connectivity,
  })  : _remote = remote,
        _local = local,
        _connectivity = connectivity;

  final SessionRemoteDataSource _remote;
  final SessionLocalDataSource _local;
  final ConnectivityService _connectivity;

  /// Last successful network fetch — lets the session screen paint instantly
  /// right after the post-login sync screen, without waiting on Hive I/O.
  List<Map<String, dynamic>>? _openOrdersMemory;

  /// Bumped on page-1 fetch so a late page-2+ response cannot merge into it.
  int _openOrdersEpoch = 0;

  /// Already-mapped rows from the last connect preload (avoids empty flash).
  List<SessionOrder>? _preloadedSessionOrders;

  /// Bumped when a Reverb table-lock event is applied to the tables cache.
  /// Used so an in-flight REST tables refresh does not wipe fresher WS locks.
  int _tablesWireEpoch = 0;

  ActiveDayInfo? get cachedActiveDay => _local.readActiveDay();
  DayStatisticsInfo? get cachedDayStatistics => _local.readDayStatistics();
  List<Map<String, dynamic>> get cachedTables => _local.readTablesList();

  /// Rows prepared by [ConnectController] — prefer this over remapping cache.
  List<SessionOrder>? takePreloadedSessionOrders() {
    final rows = _preloadedSessionOrders;
    _preloadedSessionOrders = null;
    return rows;
  }

  void _rememberPreloadedOrders(List<SessionOrder> orders) {
    _preloadedSessionOrders = List<SessionOrder>.from(orders);
  }

  /// Instant session-list paint from memory or Hive (no network).
  List<SessionOrder> getCachedSessionOrders({int? waiterId}) {
    final cached = _openOrdersMemory ?? _local.readOpenOrdersList();
    if (cached.isEmpty) return const [];
    return OrderMapper.sessionOrdersFromOrdersList(
      cached,
      waiterId: waiterId,
      lightweight: true,
    );
  }

  Future<ActiveDayInfo> getActiveDay({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _local.readActiveDay();
      if (cached != null) {
        _refreshActiveDayInBackground();
        return cached;
      }
    }

    if (!await _connectivity.isOnline) {
      final cached = _local.readActiveDay();
      if (cached != null) return cached;
      return ActiveDayInfo.fallback();
    }

    final day = await _remote.fetchActiveDay();
    await _local.saveActiveDay(day);
    return day;
  }

  Future<void> _refreshActiveDayInBackground() async {
    try {
      if (!await _connectivity.isOnline) return;
      final day = await _remote.fetchActiveDay();
      await _local.saveActiveDay(day);
    } catch (_) {}
  }

  List<SalesZoneInfo> _salesZonesMemory = const [];

  List<SalesZoneInfo> get cachedSalesZones =>
      List<SalesZoneInfo>.unmodifiable(_salesZonesMemory);

  /// Loads [GET /api/sales-zones/shortlist]. Empty list on failure (safe fallback).
  Future<List<SalesZoneInfo>> getSalesZonesShortlist({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _salesZonesMemory.isNotEmpty) {
      return cachedSalesZones;
    }
    if (!await _connectivity.isOnline) {
      return cachedSalesZones;
    }
    try {
      final zones = await _remote.fetchSalesZonesShortlist();
      _salesZonesMemory = zones;
      return cachedSalesZones;
    } catch (_) {
      return cachedSalesZones;
    }
  }

  Future<DayStatisticsInfo> getDayStatistics({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _local.readDayStatistics();
      if (cached != null) {
        _refreshStatisticsInBackground();
        return cached;
      }
    }

    if (!await _connectivity.isOnline) {
      final cached = _local.readDayStatistics();
      if (cached != null) return cached;
      throw ApiException(
        message: 'Statistiques indisponibles hors ligne.',
      );
    }

    final stats = await _fetchStatisticsFromNetwork();
    await _local.saveDayStatistics(stats);
    return stats;
  }

  Future<DayStatisticsInfo> _fetchStatisticsFromNetwork() async {
    try {
      return await _remote.fetchActiveDayStatistics();
    } catch (_) {
      final day = await _remote.fetchActiveDay();
      await _local.saveActiveDay(day);
      if (day.id > 0) {
        return await _remote.fetchDayStatistics(day.id);
      }
      rethrow;
    }
  }

  Future<void> _refreshStatisticsInBackground() async {
    try {
      if (!await _connectivity.isOnline) return;
      final stats = await _fetchStatisticsFromNetwork();
      await _local.saveDayStatistics(stats);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getTablesList({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _local.readTablesList().isNotEmpty) {
      _refreshTablesInBackground();
      return _local.readTablesList();
    }

    if (!await _connectivity.isOnline) {
      final cached = _local.readTablesList();
      if (cached.isNotEmpty) return cached;
      throw ApiException(message: 'Liste des tables indisponible hors ligne.');
    }

    final tables = await _remote.fetchTablesList();
    await _local.saveTablesList(tables);
    return tables;
  }

  /// Unscoped open tickets for occupancy / Skip (all waiters).
  ///
  /// Prefer [GET /api/days/open-orders]; fall back to unfiltered orders page 1.
  List<Map<String, dynamic>> _occupancyOpenOrders = const [];

  /// Last occupancy snapshot (may be empty before first warm).
  List<Map<String, dynamic>> get cachedOccupancyOpenOrders =>
      List<Map<String, dynamic>>.unmodifiable(_occupancyOpenOrders);

  Future<List<Map<String, dynamic>>> fetchOpenOrdersForOccupancy({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _occupancyOpenOrders.isNotEmpty) {
      unawaited(_refreshOccupancyOpenOrdersInBackground());
      return _occupancyOpenOrders;
    }
    return _loadOccupancyOpenOrders();
  }

  /// Force-refresh tables + open orders into memory (for Skip / New Order).
  Future<void> warmOccupancyCaches() async {
    await Future.wait<void>([
      getTablesList(forceRefresh: true).then((_) {}),
      _loadOccupancyOpenOrders().then((_) {}),
    ]);
  }

  Future<List<Map<String, dynamic>>> _loadOccupancyOpenOrders() async {
    if (!await _connectivity.isOnline) return _occupancyOpenOrders;
    try {
      final open = await _remote.fetchOpenOrdersList();
      if (open.isNotEmpty) {
        _occupancyOpenOrders = open;
        return _occupancyOpenOrders;
      }
    } catch (_) {}
    try {
      final first = await _remote.fetchOrdersFirstPage();
      _occupancyOpenOrders = first.orders;
      return _occupancyOpenOrders;
    } catch (_) {
      return _occupancyOpenOrders;
    }
  }

  Future<void> _refreshOccupancyOpenOrdersInBackground() async {
    try {
      await _loadOccupancyOpenOrders();
    } catch (_) {}
  }

  Future<void> _refreshTablesInBackground() async {
    try {
      if (!await _connectivity.isOnline) return;
      final epochBefore = _tablesWireEpoch;
      final tables = await _remote.fetchTablesList();
      if (_tablesWireEpoch != epochBefore) {
        // A wire lock landed during this fetch — keep those lock fields.
        final merged = _mergeTableLockFieldsFromCache(
          remoteTables: tables,
          cacheTables: _local.readTablesList(),
        );
        await _local.saveTablesList(merged);
        return;
      }
      await _local.saveTablesList(tables);
    } catch (_) {}
  }

  /// Apply live Reverb `TableSessionStarted` / `TableSessionEnded` onto the
  /// tables cache so occupancy / lock checks stay fresh without a full refetch.
  Future<void> applyTableSessionWireEvent(TableSessionWireEvent event) async {
    if (event.tableId <= 0) return;

    final current = List<Map<String, dynamic>>.from(_local.readTablesList());
    final patch = event.toTablePatch();
    var found = false;

    for (var i = 0; i < current.length; i++) {
      final row = current[i];
      if (_rowTableId(row) != event.tableId) continue;
      found = true;
      final sessionPatch = <String, dynamic>{
        'locked_by': event.lockedBy,
        'locked_at': event.lockedAt,
        'is_locked': event.isLocked,
        'session_waiter_name': event.sessionWaiterName,
        'session_owner_id': event.lockedBy,
        if (event.status != null) 'status': event.status,
      };
      current[i] = {
        ...row,
        ...patch,
        if (row['session'] is Map)
          'session': {
            ...Map<String, dynamic>.from(row['session'] as Map),
            ...sessionPatch,
          },
        if (row['table'] is Map)
          'table': {
            ...Map<String, dynamic>.from(row['table'] as Map),
            ...patch,
          },
      };
      break;
    }

    if (!found) {
      // Do not invent incomplete rows (id ≠ table number). Cache stays as-is;
      // next REST tables refresh will reconcile. Avoids occupancy false positives.
      return;
    }

    await _local.saveTablesList(current);
    _tablesWireEpoch++;
  }

  static int? _rowTableId(Map<String, dynamic> row) {
    final direct = row['id'];
    if (direct is num) return direct.toInt();
    final parsed = int.tryParse(direct?.toString() ?? '');
    if (parsed != null) return parsed;
    final nested = row['table'];
    if (nested is Map) {
      final nestedId = nested['id'];
      if (nestedId is num) return nestedId.toInt();
      return int.tryParse(nestedId?.toString() ?? '');
    }
    return null;
  }

  /// Overlay lock/session fields from [cacheTables] onto [remoteTables] by id.
  static List<Map<String, dynamic>> _mergeTableLockFieldsFromCache({
    required List<Map<String, dynamic>> remoteTables,
    required List<Map<String, dynamic>> cacheTables,
  }) {
    if (cacheTables.isEmpty) return remoteTables;

    final byId = <int, Map<String, dynamic>>{};
    for (final row in cacheTables) {
      final id = _rowTableId(row);
      if (id != null && id > 0) byId[id] = row;
    }
    if (byId.isEmpty) return remoteTables;

    const lockKeys = <String>{
      'locked_by',
      'locked_at',
      'is_locked',
      'status',
      'session_waiter_name',
      'session_owner_id',
      'session',
    };

    return remoteTables.map((remote) {
      final id = _rowTableId(remote);
      if (id == null) return remote;
      final cached = byId[id];
      if (cached == null) return remote;

      final merged = Map<String, dynamic>.from(remote);
      for (final key in lockKeys) {
        if (cached.containsKey(key)) merged[key] = cached[key];
      }
      if (remote['table'] is Map && cached['table'] is Map) {
        final remoteNested = Map<String, dynamic>.from(remote['table'] as Map);
        final cachedNested = Map<String, dynamic>.from(cached['table'] as Map);
        for (final key in lockKeys) {
          if (key == 'session') continue;
          if (cachedNested.containsKey(key)) {
            remoteNested[key] = cachedNested[key];
          }
        }
        merged['table'] = remoteNested;
      }
      return merged;
    }).toList();
  }

  Future<void> clearOpenOrdersCache() async {
    _openOrdersMemory = null;
    _preloadedSessionOrders = null;
    await _local.clearOpenOrdersList();
    await _local.clearPaidOrdersList();
  }

  /// Persist a completed+paid ticket for the statistics paid-orders list.
  Future<void> rememberPaidOrder(Map<String, dynamic> orderDetail) async {
    if (!OrderMapper.isActiveDayPaidOrder(orderDetail)) return;
    await _local.upsertPaidOrderInList(
      OrderMapper.withLocalPaidAt(orderDetail),
    );
  }

  List<SessionOrder> getCachedPaidOrders({int? waiterId}) {
    final cached = _local.readPaidOrdersList();
    if (cached.isEmpty) return const [];
    return OrderMapper.sessionOrdersFromPaidOrdersList(
      cached,
      waiterId: waiterId,
    );
  }

  Future<List<SessionOrder>> getPaidOrders({
    bool forceRefresh = false,
    int? waiterId,
  }) async {
    if (!forceRefresh) {
      final cached = getCachedPaidOrders(waiterId: waiterId);
      if (cached.isNotEmpty) return cached;
    }

    if (!await _connectivity.isOnline) {
      return getCachedPaidOrders(waiterId: waiterId);
    }

    try {
      final maps = await _remote.fetchPaidOrdersList(waiterId: waiterId);
      // Keep local just-paid rows that are completed+paid and fresher.
      final local = _local
          .readPaidOrdersList()
          .where(OrderMapper.isActiveDayPaidOrder);
      final byId = <int, Map<String, dynamic>>{};
      for (final row in maps) {
        if (!OrderMapper.isActiveDayPaidOrder(row)) continue;
        final id = OrderMapper.orderIdFromDetail(row);
        if (id <= 0) continue;
        byId[id] = row;
      }
      for (final row in local) {
        final id = OrderMapper.orderIdFromDetail(row);
        if (id <= 0) continue;
        final existing = byId[id];
        if (existing == null) {
          byId[id] = row;
          continue;
        }
        if (OrderMapper.paidOrderSortMillis(row) >=
            OrderMapper.paidOrderSortMillis(existing)) {
          final merged = Map<String, dynamic>.from(existing);
          if (row['paid_at_local'] != null) {
            merged['paid_at_local'] = row['paid_at_local'];
          }
          byId[id] = merged;
        }
      }
      final merged = byId.values.toList()
        ..sort(
          (a, b) => OrderMapper.paidOrderSortMillis(b)
              .compareTo(OrderMapper.paidOrderSortMillis(a)),
        );
      await _local.savePaidOrdersList(merged);
      return OrderMapper.sessionOrdersFromPaidOrdersList(
        merged,
        waiterId: waiterId,
      );
    } catch (_) {
      return getCachedPaidOrders(waiterId: waiterId);
    }
  }

  /// Open orders for the session screen — primary [GET /api/orders], not tables.
  ///
  /// Loads every page (page 1 + remaining, remaining fetched in parallel
  /// batches) before returning, so the caller shows one loader and then
  /// paints the complete list at once — no row-by-row drip-feed.
  ///
  /// [onProgress] reports 0.0–1.0 for this fetch only (page batches).
  Future<List<SessionOrder>> getSessionOrders({
    bool forceRefresh = false,
    int? waiterId,
    int? salesZoneId,
    bool firstPageOnly = false,
    void Function(double fraction)? onProgress,
  }) async {
    if (!forceRefresh) {
      final cached = getCachedSessionOrders(waiterId: waiterId);
      if (cached.isNotEmpty) {
        onProgress?.call(1.0);
        return cached;
      }
    }

    try {
      return await _fetchSessionOrdersFromNetwork(
        waiterId: waiterId,
        salesZoneId: salesZoneId,
        firstPageOnly: firstPageOnly,
        onProgress: onProgress,
      );
    } catch (_) {
      if (salesZoneId != null && salesZoneId > 0) {
        rethrow;
      }
      final cached = getCachedSessionOrders(waiterId: waiterId);
      if (cached.isNotEmpty) {
        onProgress?.call(1.0);
        return cached;
      }
      rethrow;
    }
  }

  /// One page of open orders (`per_page` 20). Session UI loads page 1, then
  /// later pages on scroll.
  Future<SessionOrdersPageResult> fetchSessionOrdersPage({
    required int page,
    int? waiterId,
    int? salesZoneId,
  }) async {
    final scopedId = (waiterId != null && waiterId > 0) ? waiterId : null;
    final zoneId = (salesZoneId != null && salesZoneId > 0) ? salesZoneId : null;
    final epochAtStart = page == 1 ? ++_openOrdersEpoch : _openOrdersEpoch;

    final raw = await _remote.fetchOrdersPage(
      page: page,
      waiterId: scopedId,
      salesZoneId: zoneId,
    );

    if (epochAtStart != _openOrdersEpoch) {
      return SessionOrdersPageResult(
        orders: OrderMapper.sessionOrdersFromOrdersList(
          raw.orders,
          waiterId: scopedId,
          lightweight: true,
        ),
        page: page,
        lastPage: raw.lastPage < 1 ? 1 : raw.lastPage,
      );
    }

    if (page == 1) {
      _openOrdersMemory = List<Map<String, dynamic>>.from(raw.orders);
    } else {
      final current = _openOrdersMemory ?? const <Map<String, dynamic>>[];
      final seen = <int>{
        for (final row in current) OrderMapper.orderIdFromDetail(row),
      };
      final merged = List<Map<String, dynamic>>.from(current);
      for (final row in raw.orders) {
        final id = OrderMapper.orderIdFromDetail(row);
        if (id > 0 && seen.contains(id)) continue;
        merged.add(row);
        if (id > 0) seen.add(id);
      }
      _openOrdersMemory = merged;
    }
    final snapshot = _openOrdersMemory ?? raw.orders;
    unawaited(_local.saveOpenOrdersList(snapshot));

    final mapped = OrderMapper.sessionOrdersFromOrdersList(
      raw.orders,
      waiterId: scopedId,
      lightweight: true,
    );
    if (page == 1) {
      _rememberPreloadedOrders(mapped);
    }

    return SessionOrdersPageResult(
      orders: mapped,
      page: page,
      lastPage: raw.lastPage < 1 ? 1 : raw.lastPage,
    );
  }

  /// Network refresh: fetches every page before returning (see [getSessionOrders]).
  Future<List<SessionOrder>> refreshSessionOrdersFromNetwork({
    int? waiterId,
    int? salesZoneId,
    void Function(double fraction)? onProgress,
  }) async {
    try {
      return await _fetchSessionOrdersFromNetwork(
        waiterId: waiterId,
        salesZoneId: salesZoneId,
        onProgress: onProgress,
      );
    } catch (_) {
      // Never fall back to an unscoped disk cache when a zone was requested —
      // that would flash every zone's orders after login / zone switch.
      if (salesZoneId != null && salesZoneId > 0) {
        rethrow;
      }
      final cached = getCachedSessionOrders(waiterId: waiterId);
      if (cached.isNotEmpty) {
        onProgress?.call(1.0);
        return cached;
      }
      rethrow;
    }
  }

  Future<List<SessionOrder>> _fetchSessionOrdersFromNetwork({
    int? waiterId,
    int? salesZoneId,
    bool firstPageOnly = false,
    void Function(double fraction)? onProgress,
  }) async {
    final scopedId = (waiterId != null && waiterId > 0) ? waiterId : null;
    final zoneId = (salesZoneId != null && salesZoneId > 0) ? salesZoneId : null;

    onProgress?.call(0.02);
    final first = await _remote.fetchOrdersFirstPage(
      waiterId: scopedId,
      salesZoneId: zoneId,
    );
    var pageMaps = first.orders;
    var lastPage = first.lastPage;
    var effectiveWaiterId = scopedId;

    // Prefer waiter-scoped page 1; only fall back once (page 1).
    if (pageMaps.isEmpty && scopedId != null) {
      final unscoped = await _remote.fetchOrdersFirstPage(salesZoneId: zoneId);
      pageMaps = unscoped.orders;
      lastPage = unscoped.lastPage;
      effectiveWaiterId = null;
    }

    void reportPages(int loaded, int total) {
      if (total <= 0) {
        onProgress?.call(1.0);
        return;
      }
      onProgress?.call((loaded / total).clamp(0.0, 1.0));
    }

    reportPages(1, lastPage < 1 ? 1 : lastPage);

    if (!firstPageOnly && lastPage > 1) {
      final extraMaps = await _remote.fetchOrdersRemainingPages(
        lastPage: lastPage,
        waiterId: effectiveWaiterId,
        salesZoneId: zoneId,
        onPagesLoaded: reportPages,
      );
      pageMaps = [...pageMaps, ...extraMaps];
    }

    onProgress?.call(0.95);
    _openOrdersMemory = pageMaps;
    await _local.saveOpenOrdersList(pageMaps);
    final mapped = OrderMapper.sessionOrdersFromOrdersList(
      pageMaps,
      waiterId: scopedId,
      lightweight: true,
    );
    _rememberPreloadedOrders(mapped);
    onProgress?.call(1.0);
    return mapped;
  }
}

/// One `GET /api/orders` page after waiter/zone mapping.
class SessionOrdersPageResult {
  const SessionOrdersPageResult({
    required this.orders,
    required this.page,
    required this.lastPage,
  });

  final List<SessionOrder> orders;
  final int page;
  final int lastPage;
}
