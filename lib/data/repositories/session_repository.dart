import '../../core/network/api_exception.dart';
import '../../services/connectivity_service.dart';
import '../datasources/session_datasource.dart';
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
}
