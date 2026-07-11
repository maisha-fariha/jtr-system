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

  /// Open orders for the active business day only ([active_day]=true).
  ///
  /// When [firstPageOnly] is true, returns after page 1 so the session list
  /// can paint without waiting on further pagination.
  Future<List<Map<String, dynamic>>> fetchOrdersList({
    int? waiterId,
    bool firstPageOnly = false,
  }) async {
    final first = await fetchOrdersFirstPage(waiterId: waiterId);
    if (firstPageOnly || first.lastPage <= 1) {
      return first.orders;
    }

    final rest = await fetchOrdersRemainingPages(
      lastPage: first.lastPage,
      waiterId: waiterId,
    );
    return [...first.orders, ...rest];
  }

  /// Page 1 only — same cost as a single Postman request.
  Future<({List<Map<String, dynamic>> orders, int lastPage})>
      fetchOrdersFirstPage({int? waiterId}) {
    return _fetchOrdersPage(page: 1, waiterId: waiterId);
  }

  /// Pages 2..[lastPage] in parallel (capped).
  Future<List<Map<String, dynamic>>> fetchOrdersRemainingPages({
    required int lastPage,
    int? waiterId,
  }) async {
    if (lastPage <= 1) return const [];

    final remainingPages = <int>[
      for (var p = 2; p <= lastPage && p <= 50; p++) p,
    ];
    if (remainingPages.isEmpty) return const [];

    // Small batches avoid slamming the API (13+ concurrent often >3s).
    const batchSize = 4;
    final orders = <Map<String, dynamic>>[];
    for (var i = 0; i < remainingPages.length; i += batchSize) {
      final batch = remainingPages.skip(i).take(batchSize).toList();
      final pages = await Future.wait(
        batch.map((page) => _fetchOrdersPage(page: page, waiterId: waiterId)),
      );
      for (final page in pages) {
        orders.addAll(page.orders);
      }
    }
    return orders;
  }

  Future<({List<Map<String, dynamic>> orders, int lastPage})> _fetchOrdersPage({
    required int page,
    int? waiterId,
  }) async {
    final queryParameters = <String, dynamic>{
      'active_day': true,
      'per_page': 10,
      'page': page,
    };
    if (waiterId != null && waiterId > 0) {
      queryParameters['waiter_id'] = waiterId;
    }

    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.orders,
      queryParameters: queryParameters,
    );
    final envelope = ApiEnvelope<dynamic>.fromJson(
      response.data!,
      (json) => json,
    );

    if (!envelope.success) {
      throw ApiException(
        message: envelope.message ?? 'Failed to load orders.',
        statusCode: envelope.status,
      );
    }

    return (
      orders: _extractOrdersFromPayload(envelope.data),
      lastPage: _readLastPage(envelope.data),
    );
  }

  /// Fallback when [fetchOrdersList] returns nothing ([GET /api/days/open-orders]).
  Future<List<Map<String, dynamic>>> fetchOpenOrdersList() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.openOrders,
    );
    final envelope = ApiEnvelope<dynamic>.fromJson(
      response.data!,
      (json) => json,
    );

    if (!envelope.success) {
      throw ApiException(
        message: envelope.message ?? 'Failed to load open orders.',
        statusCode: envelope.status,
      );
    }

    return _extractOpenOrdersFromPayload(envelope.data);
  }

  Future<List<Map<String, dynamic>>> fetchTablesList() async {
    try {
      return await _fetchTablesListEndpoint();
    } catch (_) {
      return await _fetchPaginatedTables();
    }
  }

  Future<List<Map<String, dynamic>>> _fetchTablesListEndpoint() async {
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
    if (tables.isEmpty) {
      throw ApiException(message: 'Aucune table disponible.');
    }

    return tables;
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

  List<Map<String, dynamic>> _extractTablesFromPayload(dynamic data) {
    if (data is List) {
      return _flattenTablesList(data);
    }

    if (data is! Map<String, dynamic>) return const [];

    final direct = data['data'];
    if (direct is List) {
      return _flattenTablesList(direct);
    }

    if (direct is Map<String, dynamic>) {
      final nested = direct['data'];
      if (nested is List) {
        return _flattenTablesList(nested);
      }

      final floorTables = direct['tables'];
      if (floorTables is List) {
        return floorTables.whereType<Map<String, dynamic>>().toList();
      }
    }

    final tables = data['tables'];
    if (tables is List) {
      return tables.whereType<Map<String, dynamic>>().toList();
    }

    return const [];
  }

  List<Map<String, dynamic>> _flattenTablesList(List<dynamic> list) {
    final flat = <Map<String, dynamic>>[];

    for (final entry in list) {
      if (entry is! Map<String, dynamic>) continue;

      final nestedTables = entry['tables'];
      if (nestedTables is List && nestedTables.isNotEmpty) {
        flat.addAll(nestedTables.whereType<Map<String, dynamic>>());
        continue;
      }

      if (entry.containsKey('table_number') || entry.containsKey('id')) {
        flat.add(entry);
      }
    }

    if (flat.isNotEmpty) return flat;

    return list.whereType<Map<String, dynamic>>().toList();
  }

  /// Reads Laravel-style pagination from:
  /// `data: { data: [...], meta: { last_page, per_page, total, ... } }`
  int _readLastPage(dynamic data) {
    if (data is! Map<String, dynamic>) return 1;

    final meta = data['meta'];
    if (meta is Map<String, dynamic>) {
      final last = meta['last_page'];
      if (last is num && last.toInt() > 0) return last.toInt();

      final total = meta['total'];
      final perPage = meta['per_page'];
      if (total is num && perPage is num && perPage > 0) {
        final computed = (total.toInt() + perPage.toInt() - 1) ~/ perPage.toInt();
        if (computed > 0) return computed;
      }
    }

    final directMeta = data['last_page'];
    if (directMeta is num && directMeta.toInt() > 0) return directMeta.toInt();

    final total = data['total'];
    final perPage = data['per_page'];
    if (total is num && perPage is num && perPage > 0) {
      final computed = (total.toInt() + perPage.toInt() - 1) ~/ perPage.toInt();
      if (computed > 0) return computed;
    }

    return 1;
  }

  List<Map<String, dynamic>> _extractOrdersFromPayload(dynamic data) {
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

    return const [];
  }

  List<Map<String, dynamic>> _extractOpenOrdersFromPayload(dynamic data) {
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }

    if (data is! Map<String, dynamic>) return const [];

    final openOrders = data['openOrders'] ?? data['open_orders'];
    if (openOrders is List) {
      return openOrders.whereType<Map<String, dynamic>>().toList();
    }

    return _extractOrdersFromPayload(data);
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

  Future<void> saveOpenOrdersList(List<Map<String, dynamic>> orders) async {
    await _storage.writeString(
      StorageConstants.openOrdersKey,
      jsonEncode(orders),
    );
  }

  Future<void> upsertOpenOrderInList(Map<String, dynamic> order) async {
    final orderId = (order['id'] as num?)?.toInt() ?? 0;
    if (orderId <= 0) return;

    final current = readOpenOrdersList();
    final updated = [
      order,
      ...current.where((entry) => (entry['id'] as num?)?.toInt() != orderId),
    ];
    await saveOpenOrdersList(updated);
  }

  Future<void> removeOpenOrderFromList(int orderId) async {
    if (orderId <= 0) return;

    final current = readOpenOrdersList();
    final updated = current
        .where((entry) => (entry['id'] as num?)?.toInt() != orderId)
        .toList(growable: false);
    await saveOpenOrdersList(updated);
  }

  List<Map<String, dynamic>> readOpenOrdersList() {
    final raw = _storage.readString(StorageConstants.openOrdersKey);
    if (raw == null || raw.isEmpty) return const [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    return decoded.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> clearOpenOrdersList() async {
    await _storage.delete(StorageConstants.openOrdersKey);
  }
}
