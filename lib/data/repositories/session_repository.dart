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
    await _local.clearOpenOrdersList();
  }

  /// Open orders for the session screen — primary [GET /api/orders], not tables.
  ///
  /// Returns page 1 as soon as it arrives (~Postman latency). Remaining pages
  /// load in the background and are delivered via [onAllPagesLoaded].
  Future<List<SessionOrder>> getSessionOrders({
    bool forceRefresh = false,
    int? waiterId,
    void Function(List<SessionOrder> orders)? onAllPagesLoaded,
  }) async {
    if (!forceRefresh) {
      final cached = getCachedSessionOrders(waiterId: waiterId);
      if (cached.isNotEmpty) {
        return cached;
      }
    }

    try {
      return await _fetchSessionOrdersFromNetwork(
        waiterId: waiterId,
        onAllPagesLoaded: onAllPagesLoaded,
      );
    } catch (_) {
      final cached = getCachedSessionOrders(waiterId: waiterId);
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  /// Network refresh: page 1 first, then remaining pages in background.
  Future<List<SessionOrder>> refreshSessionOrdersFromNetwork({
    int? waiterId,
    void Function(List<SessionOrder> orders)? onAllPagesLoaded,
  }) async {
    try {
      return await _fetchSessionOrdersFromNetwork(
        waiterId: waiterId,
        onAllPagesLoaded: onAllPagesLoaded,
      );
    } catch (_) {
      final cached = getCachedSessionOrders(waiterId: waiterId);
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<List<SessionOrder>> _fetchSessionOrdersFromNetwork({
    int? waiterId,
    void Function(List<SessionOrder> orders)? onAllPagesLoaded,
  }) async {
    final scopedId = (waiterId != null && waiterId > 0) ? waiterId : null;

    final first = await _remote.fetchOrdersFirstPage(waiterId: scopedId);
    var pageMaps = first.orders;

    // Prefer waiter-scoped page 1; only fall back once (page 1), never full 14 pages twice.
    if (pageMaps.isEmpty && scopedId != null) {
      final unscoped = await _remote.fetchOrdersFirstPage();
      pageMaps = unscoped.orders;
      unawaited(_local.saveOpenOrdersList(pageMaps));
      final firstOrders = OrderMapper.sessionOrdersFromOrdersList(
        pageMaps,
        waiterId: scopedId,
        lightweight: true,
      );
      if (unscoped.lastPage > 1) {
        unawaited(
          _finishRemainingPages(
            page1: pageMaps,
            lastPage: unscoped.lastPage,
            waiterId: null,
            filterWaiterId: scopedId,
            onAllPagesLoaded: onAllPagesLoaded,
          ),
        );
      } else {
        onAllPagesLoaded?.call(firstOrders);
      }
      return firstOrders;
    }

    unawaited(_local.saveOpenOrdersList(pageMaps));
    final firstOrders = OrderMapper.sessionOrdersFromOrdersList(
      pageMaps,
      waiterId: scopedId,
      lightweight: true,
    );

    if (first.lastPage > 1) {
      unawaited(
        _finishRemainingPages(
          page1: pageMaps,
          lastPage: first.lastPage,
          waiterId: scopedId,
          filterWaiterId: scopedId,
          onAllPagesLoaded: onAllPagesLoaded,
        ),
      );
    } else {
      onAllPagesLoaded?.call(firstOrders);
    }

    return firstOrders;
  }

  Future<void> _finishRemainingPages({
    required List<Map<String, dynamic>> page1,
    required int lastPage,
    required int? waiterId,
    required int? filterWaiterId,
    void Function(List<SessionOrder> orders)? onAllPagesLoaded,
  }) async {
    try {
      final rest = await _remote.fetchOrdersRemainingPages(
        lastPage: lastPage,
        waiterId: waiterId,
      );
      final all = [...page1, ...rest];
      await _local.saveOpenOrdersList(all);
      onAllPagesLoaded?.call(
        OrderMapper.sessionOrdersFromOrdersList(
          all,
          waiterId: filterWaiterId,
          lightweight: true,
        ),
      );
    } catch (_) {
      // Keep page-1 list already on screen.
    }
  }
}
