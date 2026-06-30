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
  Future<List<SessionOrder>> getSessionOrders({
    bool forceRefresh = false,
    int? waiterId,
  }) async {
    if (!forceRefresh && _local.readOpenOrdersList().isNotEmpty) {
      _refreshSessionOrdersInBackground(waiterId: waiterId);
      return _sessionOrdersFromCache(waiterId: waiterId);
    }

    if (!await _connectivity.isOnline) {
      final cachedOrders = _local.readOpenOrdersList();
      if (cachedOrders.isEmpty) {
        throw ApiException(
          message: 'Liste des commandes indisponible hors ligne.',
        );
      }
      return _sessionOrdersFromCache(waiterId: waiterId);
    }

    return _fetchSessionOrdersFromNetwork(waiterId: waiterId);
  }

  List<SessionOrder> _sessionOrdersFromCache({int? waiterId}) {
    var orders = OrderMapper.sessionOrdersFromOrdersList(
      _local.readOpenOrdersList(),
      waiterId: waiterId,
    );
    final tables = _local.readTablesList();
    if (tables.isNotEmpty) {
      orders = OrderMapper.mergeOrdersWithOpenTableSessions(orders, tables);
      if (waiterId != null && waiterId > 0) {
        orders = orders
            .where(
              (order) =>
                  order.id > 0 ||
                  order.waiterId == null ||
                  order.waiterId == waiterId,
            )
            .toList(growable: false);
      }
    }
    return orders;
  }

  Future<List<SessionOrder>> _fetchSessionOrdersFromNetwork({
    int? waiterId,
  }) async {
    final orderMaps = await _loadOrderMaps(waiterId: waiterId);
    final mergedMaps = OrderMapper.mergeOrderMapLists(
      _local.readOpenOrdersList(),
      orderMaps,
    );

    await _local.saveOpenOrdersList(mergedMaps);
    var orders = OrderMapper.sessionOrdersFromOrdersList(
      mergedMaps,
      waiterId: waiterId,
    );

    try {
      final tables = await _remote.fetchTablesList();
      await _local.saveTablesList(tables);
      orders = OrderMapper.mergeOrdersWithOpenTableSessions(orders, tables);
    } catch (_) {
      final tables = _local.readTablesList();
      if (tables.isNotEmpty) {
        orders = OrderMapper.mergeOrdersWithOpenTableSessions(orders, tables);
      }
    }

    if (waiterId != null && waiterId > 0) {
      orders = orders
          .where(
            (order) =>
                order.id > 0 ||
                order.waiterId == null ||
                order.waiterId == waiterId,
          )
          .toList(growable: false);
    }

    return orders;
  }

  Future<List<Map<String, dynamic>>> _loadOrderMaps({int? waiterId}) async {
    var scoped = <Map<String, dynamic>>[];

    if (waiterId != null && waiterId > 0) {
      try {
        scoped = await _remote.fetchOrdersList(waiterId: waiterId);
      } catch (_) {}
    }

    try {
      final all = await _remote.fetchOrdersList();
      final merged = OrderMapper.mergeOrderMapLists(scoped, all);
      if (merged.isNotEmpty) return merged;
    } catch (_) {}

    if (scoped.isNotEmpty) return scoped;

    try {
      return await _remote.fetchOpenOrdersList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _refreshSessionOrdersInBackground({int? waiterId}) async {
    try {
      if (!await _connectivity.isOnline) return;
      await _fetchSessionOrdersFromNetwork(waiterId: waiterId);
    } catch (_) {}
  }
}
