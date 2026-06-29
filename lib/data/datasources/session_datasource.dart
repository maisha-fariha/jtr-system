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

    final data = envelope.data;
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    if (data is Map<String, dynamic>) {
      final tables = data['tables'] ?? data['data'];
      if (tables is List) {
        return tables.whereType<Map<String, dynamic>>().toList();
      }
    }

    return const [];
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
