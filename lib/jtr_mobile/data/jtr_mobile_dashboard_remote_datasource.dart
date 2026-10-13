import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/api_envelope.dart';
import 'jtr_mobile_dashboard_filters.dart';

/// Dashboard API client — always hits the network (no local cache).
class JtrMobileDashboardRemoteDataSource {
  JtrMobileDashboardRemoteDataSource(this._client);

  final ApiClient _client;

  static const _noCacheHeaders = {
    'Cache-Control': 'no-cache, no-store, must-revalidate',
    'Pragma': 'no-cache',
  };

  Options _freshOptions() => Options(headers: _noCacheHeaders);

  void _logRequest(String path, Map<String, dynamic>? queryParameters) {
    final buffer = StringBuffer()
      ..writeln('════════ JTR MOBILE DASHBOARD REQUEST ════════')
      ..writeln('METHOD: GET')
      ..writeln('PATH: $path')
      ..writeln('QUERY / FILTERS:')
      ..writeln(queryParameters ?? {});
    final line = buffer.toString();
    // ignore: avoid_print
    print(line);
    debugPrint(line);
  }

  Future<Map<String, dynamic>> fetchActiveDay() async {
    final params = {'_': DateTime.now().millisecondsSinceEpoch};
    _logRequest(ApiEndpoints.activeDay, params);
    return _getMap(
      ApiEndpoints.activeDay,
      queryParameters: params,
    );
  }

  Future<Map<String, dynamic>> fetchOrderSummary(
    JtrMobileDashboardFilters filters,
  ) async {
    final params = filters.toQueryParams();
    params['include_cashier_indicators'] = 1;
    params['include_period_comparison'] = 1;
    _logRequest(ApiEndpoints.dashboardOrderSummary, params);
    return _getMap(ApiEndpoints.dashboardOrderSummary, queryParameters: params);
  }

  Future<Map<String, dynamic>> fetchRevenueByHour(
    JtrMobileDashboardFilters filters,
  ) async {
    final params = filters.toQueryParams();
    params['with_peak'] = 1;
    _logRequest(ApiEndpoints.dashboardRevenueByHour, params);
    return _getMap(ApiEndpoints.dashboardRevenueByHour, queryParameters: params);
  }

  Future<List<Map<String, dynamic>>> fetchRevenueBySalesZone(
    JtrMobileDashboardFilters filters,
  ) async {
    final params = filters.toQueryParams();
    _logRequest(ApiEndpoints.dashboardRevenueBySalesZone, params);
    return _getList(
      ApiEndpoints.dashboardRevenueBySalesZone,
      queryParameters: params,
    );
  }

  Future<Map<String, dynamic>> fetchProductFamilySummary(
    JtrMobileDashboardFilters filters, {
    String metric = 'ventes',
  }) async {
    final params = filters.toQueryParams();
    params['metric'] = metric;
    _logRequest(ApiEndpoints.dashboardProductFamilySummary, params);
    return _getMap(
      ApiEndpoints.dashboardProductFamilySummary,
      queryParameters: params,
    );
  }

  Future<Map<String, dynamic>> fetchEventList(
    JtrMobileDashboardFilters filters, {
    required String type,
    int limit = 20,
    int offset = 0,
  }) async {
    final params = filters.toQueryParams();
    params['type'] = type;
    params['limit'] = limit;
    params['offset'] = offset;
    _logRequest(ApiEndpoints.dashboardEventList, params);
    return _getMap(ApiEndpoints.dashboardEventList, queryParameters: params);
  }

  Future<Map<String, dynamic>> _getMap(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      path,
      queryParameters: queryParameters,
      options: _freshOptions(),
    );
    return _unwrapData(response.data);
  }

  Future<List<Map<String, dynamic>>> _getList(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      path,
      queryParameters: queryParameters,
      options: _freshOptions(),
    );
    final data = _unwrapRaw(response.data);
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data is Map<String, dynamic>) return [data];
    return const [];
  }

  Map<String, dynamic> _unwrapData(Map<String, dynamic>? json) {
    final raw = _unwrapRaw(json);
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const {};
  }

  dynamic _unwrapRaw(Map<String, dynamic>? json) {
    if (json == null) {
      throw ApiException(message: 'Réponse serveur vide.');
    }
    final envelope = ApiEnvelope<dynamic>.fromJson(json, (v) => v);
    if (!envelope.success) {
      throw ApiException(
        message: envelope.message ?? 'Erreur lors du chargement du tableau de bord.',
        statusCode: envelope.status,
      );
    }
    return envelope.data;
  }
}
