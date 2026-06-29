import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import '../../utils/api_log.dart';
import '../models/api_envelope.dart';

class OrderRemoteDataSource {
  OrderRemoteDataSource(this._client);

  final ApiClient _client;

  /// Last request/response log from a mutating order call (for on-screen debug).
  String? lastApiLog;

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

  Future<void> addSeatOrderItems({
    required int orderId,
    required int seatNumber,
    required Map<String, dynamic> body,
  }) async {
    final path = ApiEndpoints.addSeatOrderItems(orderId, seatNumber);
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

      final raw = response.data;
      if (raw is Map<String, dynamic>) {
        final envelope = ApiEnvelope<dynamic>.fromJson(raw, (json) => json);
        if (!envelope.success) {
          throw ApiException(
            message: envelope.message ?? 'Impossible d\'ajouter l\'article.',
            statusCode: envelope.status,
          );
        }
      }
    } on ApiException catch (error) {
      _appendApiError(error);
      rethrow;
    }
  }
}
