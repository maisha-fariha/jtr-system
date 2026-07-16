import 'dart:async';

import '../../core/network/api_exception.dart';
import '../../models/session_order.dart';
import '../../services/connectivity_service.dart';
import '../datasources/session_datasource.dart';
import '../mappers/order_mapper.dart';
import '../models/active_day_info.dart';
import '../models/day_statistics_info.dart';

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

  /// Already-mapped rows from the last connect preload (avoids empty flash).
  List<SessionOrder>? _preloadedSessionOrders;

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

  Future<void> _refreshTablesInBackground() async {
    try {
      if (!await _connectivity.isOnline) return;
      final tables = await _remote.fetchTablesList();
      await _local.saveTablesList(tables);
    } catch (_) {}
  }

  Future<void> clearOpenOrdersCache() async {
    _openOrdersMemory = null;
    _preloadedSessionOrders = null;
    await _local.clearOpenOrdersList();
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
        onProgress: onProgress,
      );
    } catch (_) {
      final cached = getCachedSessionOrders(waiterId: waiterId);
      if (cached.isNotEmpty) {
        onProgress?.call(1.0);
        return cached;
      }
      rethrow;
    }
  }

  /// Network refresh: fetches every page before returning (see [getSessionOrders]).
  Future<List<SessionOrder>> refreshSessionOrdersFromNetwork({
    int? waiterId,
    void Function(double fraction)? onProgress,
  }) async {
    try {
      return await _fetchSessionOrdersFromNetwork(
        waiterId: waiterId,
        onProgress: onProgress,
      );
    } catch (_) {
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
    void Function(double fraction)? onProgress,
  }) async {
    final scopedId = (waiterId != null && waiterId > 0) ? waiterId : null;

    onProgress?.call(0.02);
    final first = await _remote.fetchOrdersFirstPage(waiterId: scopedId);
    var pageMaps = first.orders;
    var lastPage = first.lastPage;
    var effectiveWaiterId = scopedId;

    // Prefer waiter-scoped page 1; only fall back once (page 1).
    if (pageMaps.isEmpty && scopedId != null) {
      final unscoped = await _remote.fetchOrdersFirstPage();
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

    if (lastPage > 1) {
      final extraMaps = await _remote.fetchOrdersRemainingPages(
        lastPage: lastPage,
        waiterId: effectiveWaiterId,
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
