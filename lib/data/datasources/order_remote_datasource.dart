import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import '../../utils/api_log.dart';
import '../models/api_envelope.dart';
import '../models/open_order_summary.dart';

class OrderRemoteDataSource {
  OrderRemoteDataSource(this._client);

  final ApiClient _client;

  /// Last request/response log from a mutating order call (for on-screen debug).
  String? lastApiLog;

  Future<OpenOrdersData> fetchOpenOrders() async {
    final response =
        await _client.get<Map<String, dynamic>>(ApiEndpoints.openOrders);
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data!,
      (json) => json as Map<String, dynamic>,
    );

    if (!envelope.success) {
      throw ApiException(
        message: envelope.message ?? 'Failed to load open orders.',
        statusCode: envelope.status,
      );
    }

    final data = envelope.data;
    if (data == null) {
      return const OpenOrdersData(
        hasOpenOrders: false,
        openOrdersCount: 0,
        openOrders: [],
      );
    }

    return _parseOpenOrdersData(data);
  }

  OpenOrdersData _parseOpenOrdersData(Map<String, dynamic> data) {
    final ordersRaw =
        data['openOrders'] ?? data['open_orders'] ?? data['orders'];
    final ordersList = _normalizeOpenOrdersList(ordersRaw);

    return OpenOrdersData(
      hasOpenOrders: _readBool(
        data,
        const ['hasOpenOrders', 'has_open_orders'],
        ordersList.isNotEmpty,
      ),
      openOrdersCount: _readInt(
        data,
        const ['openOrdersCount', 'open_orders_count'],
        ordersList.length,
      ),
      openOrders: ordersList,
    );
  }

  List<OpenOrderSummary> _normalizeOpenOrdersList(dynamic raw) {
    if (raw is! List) return const [];

    final summaries = <OpenOrderSummary>[];
    for (final entry in raw) {
      if (entry is! Map<String, dynamic>) continue;

      final id = _readOptionalInt(entry, const ['id', 'order_id']);
      if (id == null) continue;

      summaries.add(
        OpenOrderSummary(
          id: id,
          orderNumber: _readString(
            entry,
            const ['order_number', 'orderNumber'],
            '',
          ),
          tableId: _readOptionalInt(entry, const ['table_id', 'tableId']),
          tableNumber:
              _readOptionalInt(entry, const ['table_number', 'tableNumber']),
          status: _readString(entry, const ['status'], 'pending'),
          totalPrice: _readString(
            entry,
            const ['total_price', 'totalPrice'],
            '0',
          ),
          createdAt: _readString(
            entry,
            const ['created_at', 'createdAt'],
            null,
          ),
        ),
      );
    }

    return summaries;
  }

  bool _readBool(
    Map<String, dynamic> json,
    List<String> keys,
    bool fallback,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is bool) return value;
    }
    return fallback;
  }

  int _readInt(
    Map<String, dynamic> json,
    List<String> keys,
    int fallback,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return fallback;
  }

  int? _readOptionalInt(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  String _readString(
    Map<String, dynamic> json,
    List<String> keys,
    String? fallback,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value != null) return '$value';
    }
    return fallback ?? '';
  }

  Future<Map<String, dynamic>> fetchOrderDetail(int orderId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.orderById(orderId),
    );
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data!,
      (json) => json as Map<String, dynamic>,
    );

    if (!envelope.success || envelope.data == null) {
      throw ApiException(
        message: envelope.message ?? 'Failed to load order details.',
        statusCode: envelope.status,
      );
    }

    return envelope.data!;
  }

  Future<void> closeOrder(int orderId) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.closeOrder(orderId),
      data: const {},
    );
    final envelope = ApiEnvelope<dynamic>.fromJson(
      response.data!,
      (json) => json,
    );

    if (!envelope.success) {
      throw ApiException(
        message: envelope.message ?? 'Failed to close order.',
        statusCode: envelope.status,
      );
    }
  }

  Future<Map<String, dynamic>> updateOrder(
    int orderId,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.put<Map<String, dynamic>>(
      ApiEndpoints.orderById(orderId),
      data: body,
    );
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data!,
      (json) => json as Map<String, dynamic>,
    );

    if (!envelope.success) {
      throw ApiException(
        message: envelope.message ?? 'Failed to update order.',
        statusCode: envelope.status,
      );
    }

    return envelope.data ?? body;
  }

  Future<Map<String, dynamic>> startTableSession(
    int tableId,
    Map<String, dynamic> body,
  ) async {
    final path = ApiEndpoints.tableSession(tableId);
    try {
      final response = await _client.post<Map<String, dynamic>>(
        path,
        data: body,
      );
      _recordApiLog(
        method: 'POST',
        path: path,
        request: body,
        response: response.data,
        statusCode: response.statusCode,
      );

      final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
        response.data!,
        (json) => json as Map<String, dynamic>,
      );

      if (!envelope.success || envelope.data == null) {
        throw ApiException(
          message: envelope.message ?? 'Failed to start table session.',
          statusCode: envelope.status,
        );
      }

      return envelope.data!;
    } on ApiException catch (error) {
      _appendApiError(error);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> body) async {
    const path = ApiEndpoints.createOrder;
    try {
      final response = await _client.post<Map<String, dynamic>>(
        path,
        data: body,
      );
      _recordApiLog(
        method: 'POST',
        path: path,
        request: body,
        response: response.data,
        statusCode: response.statusCode,
      );

      final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
        response.data!,
        (json) => json as Map<String, dynamic>,
      );

      if (!envelope.success || envelope.data == null) {
        throw ApiException(
          message: envelope.message ?? 'Failed to create order.',
          statusCode: envelope.status,
        );
      }

      return envelope.data!;
    } on ApiException catch (error) {
      _appendApiError(error);
      rethrow;
    }
  }

  void _recordApiLog({
    required String method,
    required String path,
    Object? request,
    Object? response,
    int? statusCode,
    String? error,
  }) {
    final buffer = StringBuffer()
      ..writeln('$method $path'
          '${statusCode != null ? ' → $statusCode' : ''}');

    if (request != null) {
      buffer
        ..writeln()
        ..writeln('REQUEST:')
        ..writeln(formatApiPayload(request));
    }

    if (response != null) {
      buffer
        ..writeln()
        ..writeln('RESPONSE:')
        ..writeln(formatApiPayload(response));
    }

    if (error != null && error.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('ERROR:')
        ..writeln(error);
    }

    lastApiLog = buffer.toString();

    logApiCall(
      method: method,
      path: path,
      request: request,
      response: response,
      statusCode: statusCode,
      error: error,
    );
  }

  void _appendApiError(ApiException error) {
    final existing = lastApiLog;
    final errorLine = 'ERROR: ${error.message}'
        '${error.statusCode != null ? ' (HTTP ${error.statusCode})' : ''}';
    lastApiLog = existing == null ? errorLine : '$existing\n\n$errorLine';
  }

  Future<void> requestCourses(int orderId, List<int> courseIds) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.requestCourses(orderId),
      data: {'course_ids': courseIds},
    );
    final envelope = ApiEnvelope<dynamic>.fromJson(
      response.data!,
      (json) => json,
    );

    if (!envelope.success) {
      throw ApiException(
        message: envelope.message ?? 'Failed to request courses.',
        statusCode: envelope.status,
      );
    }
  }

  Future<void> markOrderPrinted(int orderId) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.markOrderPrinted,
      data: {'order_id': orderId},
    );
    final envelope = ApiEnvelope<dynamic>.fromJson(
      response.data!,
      (json) => json,
    );

    if (!envelope.success) {
      throw ApiException(
        message: envelope.message ?? 'Failed to mark order as printed.',
        statusCode: envelope.status,
      );
    }
  }
}
