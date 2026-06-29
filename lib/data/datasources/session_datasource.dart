import 'dart:convert';

import '../../core/constants/storage_constants.dart';
import '../../core/storage/hive_storage.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import '../models/active_day_info.dart';
import '../models/api_envelope.dart';
import '../models/day_statistics_info.dart';

class SessionRemoteDataSource {
  SessionRemoteDataSource(this._client);

  final ApiClient _client;

  Future<ActiveDayInfo> fetchActiveDay() async {
    final response =
        await _client.get<Map<String, dynamic>>(ApiEndpoints.activeDay);
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data!,
      (json) => json as Map<String, dynamic>,
    );

    if (!envelope.success || envelope.data == null) {
      throw ApiException(
        message: envelope.message ?? 'Failed to load active day.',
        statusCode: envelope.status,
      );
    }

    return ActiveDayInfo.fromJson(envelope.data!);
  }

  Future<DayStatisticsInfo> fetchActiveDayStatistics() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.activeDayStatistics,
    );
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data!,
      (json) => json as Map<String, dynamic>,
    );

    if (!envelope.success || envelope.data == null) {
      throw ApiException(
        message: envelope.message ?? 'Failed to load statistics.',
        statusCode: envelope.status,
      );
    }

    return DayStatisticsInfo.fromJson(envelope.data!);
  }

  Future<DayStatisticsInfo> fetchDayStatistics(int dayId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.dayStatistics(dayId),
    );
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data!,
      (json) => json as Map<String, dynamic>,
    );

    if (!envelope.success || envelope.data == null) {
      throw ApiException(
        message: envelope.message ?? 'Failed to load day statistics.',
        statusCode: envelope.status,
      );
    }

    return DayStatisticsInfo.fromJson(envelope.data!);
  }

  Future<List<Map<String, dynamic>>> fetchTablesList() async {
    try {
      return await _fetchPaginatedTables();
    } catch (_) {
      return _fetchLegacyTablesList();
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPaginatedTables() async {
    final allTables = <Map<String, dynamic>>[];
    var page = 1;
    var lastPage = 1;

    while (page <= lastPage && page <= 25) {
      final response = await _client.get<Map<String, dynamic>>(
        ApiEndpoints.tables,
        queryParameters: {'page': page},
      );
      final envelope = ApiEnvelope<dynamic>.fromJson(
        response.data!,
        (json) => json,
      );

      if (!envelope.success) {
        throw ApiException(
          message: envelope.message ?? 'Failed to load tables.',
          statusCode: envelope.status,
        );
      }

      final pageTables = _extractTablesFromPayload(envelope.data);
      allTables.addAll(pageTables);

      lastPage = _readLastPage(envelope.data);
      if (pageTables.isEmpty) break;
      page++;
    }

    if (allTables.isEmpty) {
      throw ApiException(message: 'Aucune table disponible.');
    }

    return allTables;
  }

  Future<List<Map<String, dynamic>>> _fetchLegacyTablesList() async {
    final response =
        await _client.get<Map<String, dynamic>>(ApiEndpoints.tablesList);
    final envelope = ApiEnvelope<dynamic>.fromJson(
      response.data!,
      (json) => json,
    );

    if (!envelope.success) {
      throw ApiException(
        message: envelope.message ?? 'Failed to load tables.',
        statusCode: envelope.status,
      );
    }

    final tables = _extractTablesFromPayload(envelope.data);
    return tables;
  }

  List<Map<String, dynamic>> _extractTablesFromPayload(dynamic data) {
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }

    if (data is! Map<String, dynamic>) return const [];

    final direct = data['data'];
    if (direct is List) {
      return direct.whereType<Map<String, dynamic>>().toList();
    }

    if (direct is Map<String, dynamic>) {
      final nested = direct['data'];
      if (nested is List) {
        return nested.whereType<Map<String, dynamic>>().toList();
      }
    }

    final tables = data['tables'];
    if (tables is List) {
      return tables.whereType<Map<String, dynamic>>().toList();
    }

    return const [];
  }

  int _readLastPage(dynamic data) {
    if (data is! Map<String, dynamic>) return 1;

    final meta = data['meta'];
    if (meta is Map<String, dynamic>) {
      final last = meta['last_page'];
      if (last is num) return last.toInt();
    }

    final directMeta = data['last_page'];
    if (directMeta is num) return directMeta.toInt();

    return 1;
  }
}

class SessionLocalDataSource {
  SessionLocalDataSource(this._storage);

  final HiveStorage _storage;

  Future<void> saveActiveDay(ActiveDayInfo day) async {
    await _storage.writeString(
      StorageConstants.activeDayKey,
      jsonEncode({
        'id': day.id,
        'displayDate': day.displayDate,
        'sessionNumber': day.sessionNumber,
        'salesZoneLabel': day.salesZoneLabel,
        'salesZoneId': day.salesZoneId,
      }),
    );
  }

  ActiveDayInfo? readActiveDay() {
    final raw = _storage.readString(StorageConstants.activeDayKey);
    if (raw == null || raw.isEmpty) return null;

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;

    return ActiveDayInfo(
      id: decoded['id'] as int? ?? 0,
      displayDate: decoded['displayDate'] as String? ?? '',
      sessionNumber: decoded['sessionNumber'] as String?,
      salesZoneLabel: decoded['salesZoneLabel'] as String? ?? 'SUR PLACE',
      salesZoneId: decoded['salesZoneId'] as int?,
    );
  }

  Future<void> saveDayStatistics(DayStatisticsInfo stats) async {
    await _storage.writeString(
      StorageConstants.dayStatisticsKey,
      jsonEncode(stats.raw ?? {}),
    );
  }

  DayStatisticsInfo? readDayStatistics() {
    final raw = _storage.readString(StorageConstants.dayStatisticsKey);
    if (raw == null || raw.isEmpty) return null;

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;

    return DayStatisticsInfo.fromJson(decoded);
  }

  Future<void> saveTablesList(List<Map<String, dynamic>> tables) async {
    await _storage.writeString(
      StorageConstants.tablesListKey,
      jsonEncode(tables),
    );
  }

  List<Map<String, dynamic>> readTablesList() {
    final raw = _storage.readString(StorageConstants.tablesListKey);
    if (raw == null || raw.isEmpty) return const [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    return decoded.whereType<Map<String, dynamic>>().toList();
  }
}
