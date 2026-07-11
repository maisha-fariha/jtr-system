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

  ActiveDayInfo? get cachedActiveDay => _local.readActiveDay();
  DayStatisticsInfo? get cachedDayStatistics => _local.readDayStatistics();
  List<Map<String, dynamic>> get cachedTables => _local.readTablesList();

  /// Instant session-list paint from Hive (no network).
  List<SessionOrder> getCachedSessionOrders({int? waiterId}) {
    final cached = _local.readOpenOrdersList();
    if (cached.isEmpty) return const [];
    return OrderMapper.sessionOrdersFromOrdersList(
      cached,
      waiterId: waiterId,
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
    await _local.clearOpenOrdersList();
  }

  /// Open orders for the session screen — primary [GET /api/orders], not tables.
  ///
  /// Cache-first when [forceRefresh] is false. Network path uses the first
  /// page only so list paint / pull-to-refresh stay snappy; extra pages and
  /// the unscoped list warm the cache in the background.
  Future<List<SessionOrder>> getSessionOrders({
    bool forceRefresh = false,
    int? waiterId,
  }) async {
    if (!forceRefresh) {
      final cached = getCachedSessionOrders(waiterId: waiterId);
      if (cached.isNotEmpty) {
        return cached;
      }
    }

    try {
      return await _fetchSessionOrdersFromNetwork(waiterId: waiterId);
    } catch (_) {
      final cached = getCachedSessionOrders(waiterId: waiterId);
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  /// Network refresh used after cache paint / pull-to-refresh.
  Future<List<SessionOrder>> refreshSessionOrdersFromNetwork({
    int? waiterId,
  }) async {
    try {
      return await _fetchSessionOrdersFromNetwork(waiterId: waiterId);
    } catch (_) {
      final cached = getCachedSessionOrders(waiterId: waiterId);
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<List<SessionOrder>> _fetchSessionOrdersFromNetwork({
    int? waiterId,
  }) async {
    final orderMaps = await _loadOrderMapsFast(waiterId: waiterId);

    // Persist off the critical path — UI already has mapped rows.
    unawaited(_local.saveOpenOrdersList(orderMaps));

    return OrderMapper.sessionOrdersFromOrdersList(
      orderMaps,
      waiterId: waiterId,
    );
  }

  /// Single round-trip (page 1) for the session list; more pages in background.
  Future<List<Map<String, dynamic>>> _loadOrderMapsFast({
    int? waiterId,
  }) async {
    if (waiterId != null && waiterId > 0) {
      try {
        final scoped = await _remote.fetchOrdersList(
          waiterId: waiterId,
          firstPageOnly: true,
        );
        if (scoped.isNotEmpty) {
          unawaited(_completeOrdersCacheInBackground(waiterId: waiterId));
          return scoped;
        }
      } catch (_) {}
    }

    try {
      final all = await _remote.fetchOrdersList(firstPageOnly: true);
      unawaited(_completeOrdersCacheInBackground());
      return all;
    } catch (_) {
      // Last resort: compact open-orders endpoint (single request).
      try {
        return await _remote.fetchOpenOrdersList();
      } catch (_) {
        return const [];
      }
    }
  }

  Future<void> _completeOrdersCacheInBackground({int? waiterId}) async {
    try {
      final pages = await _remote.fetchOrdersList(waiterId: waiterId);
      final current = _local.readOpenOrdersList();
      var merged = OrderMapper.mergeOrderMapLists(current, pages);

      // Also merge unscoped list when we started waiter-scoped.
      if (waiterId != null && waiterId > 0) {
        try {
          final all = await _remote.fetchOrdersList();
          merged = OrderMapper.mergeOrderMapLists(merged, all);
        } catch (_) {}
      }

      await _local.saveOpenOrdersList(merged);
    } catch (_) {}
  }
}
