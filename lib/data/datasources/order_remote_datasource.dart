import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import '../models/api_envelope.dart';
import '../models/open_order_summary.dart';

class OrderRemoteDataSource {
  OrderRemoteDataSource(this._client);

  final ApiClient _client;

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

    return OpenOrdersData.fromJson(data);
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
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.tableSession(tableId),
      data: body,
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
  }

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> body) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.createOrder,
      data: body,
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
