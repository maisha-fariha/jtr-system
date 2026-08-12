import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import '../../utils/api_log.dart';
import '../mappers/order_mapper.dart';
import '../models/api_envelope.dart';

class OrderRemoteDataSource {
  OrderRemoteDataSource(this._client);

  final ApiClient _client;

  /// Last request/response log from a mutating order call (for on-screen debug).
  String? lastApiLog;

  /// Runs [action] with a temporary Bearer (authorize-for-delete only).
  Future<T> withAuthTokenOverride<T>(
    String token,
    Future<T> Function() action,
  ) =>
      _client.withAuthTokenOverride(token, action);

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

    return OrderMapper.unwrapOrderDetail(envelope.data!);
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

  Future<void> endTableSession(int tableId) async {
    final path = ApiEndpoints.tableSession(tableId);
    final response = await _client.delete<Map<String, dynamic>>(path);
    final data = response.data;
    if (data is! Map<String, dynamic>) return;

    final envelope = ApiEnvelope<dynamic>.fromJson(
      data,
      (json) => json,
    );

    if (!envelope.success) {
      throw ApiException(
        message: envelope.message ?? 'Failed to end table session.',
        statusCode: envelope.status,
      );
    }
  }

  Future<Map<String, dynamic>> updateOrder(
    int orderId,
    Map<String, dynamic> body,
  ) async {
    final path = ApiEndpoints.orderById(orderId);
    try {
      final response = await _client.put<Map<String, dynamic>>(
        path,
        data: body,
      );
      _recordApiLog(
        method: 'PUT',
        path: path,
        request: body,
        response: response.data,
        statusCode: response.statusCode,
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

      final data = envelope.data ?? body;
      return OrderMapper.unwrapOrderDetail(data);
    } on ApiException catch (error) {
      _appendApiError(error);
      rethrow;
    }
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
        writeToConsole: false,
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
    logOrderFlow('OrderRemoteDataSource.createOrder CALLED');
    logOrderPost(phase: 'sending', request: body);

    try {
      final response = await _client.post<Map<String, dynamic>>(
        path,
        data: body,
      );

      logOrderPost(
        phase: 'response',
        request: body,
        response: response.data,
        statusCode: response.statusCode,
      );
      _recordApiLog(
        method: 'POST',
        path: path,
        request: body,
        response: response.data,
        statusCode: response.statusCode,
        writeToConsole: false,
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

      return OrderMapper.unwrapOrderDetail(envelope.data!);
    } on ApiException catch (error) {
      logOrderPost(
        phase: 'error',
        request: body,
        statusCode: error.statusCode,
        error: error.message,
      );
      _recordApiLog(
        method: 'POST',
        path: path,
        request: body,
        statusCode: error.statusCode,
        error: error.message,
        writeToConsole: false,
      );
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
    bool writeToConsole = true,
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

    if (writeToConsole) {
      logApiCall(
        method: method,
        path: path,
        request: request,
        response: response,
        statusCode: statusCode,
        error: error,
      );
    }
  }

  void _appendApiError(ApiException error) {
    final existing = lastApiLog;
    final errorLine = 'ERROR: ${error.message}'
        '${error.statusCode != null ? ' (HTTP ${error.statusCode})' : ''}';
    lastApiLog = existing == null ? errorLine : '$existing\n\n$errorLine';
  }

  Future<void> requestCourses(int orderId, List<int> courseIds) async {
    final path = ApiEndpoints.requestCourses(orderId);
    final body = {'course_ids': courseIds};

    try {
      final response = await _client.post<dynamic>(
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

      _ensureMutationSucceeded(
        statusCode: response.statusCode,
        data: response.data,
        fallbackMessage: 'Failed to request courses.',
      );
    } on ApiException catch (error) {
      _appendApiError(error);
      rethrow;
    }
  }

  Future<void> addSeatOrderItems({
    required int orderId,
    required int seatNumber,
    required Map<String, dynamic> body,
  }) async {
    final path = ApiEndpoints.orderSeatOrderItems(orderId, seatNumber);
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

      final envelope = ApiEnvelope<dynamic>.fromJson(
        response.data!,
        (json) => json,
      );

      if (!envelope.success) {
        throw ApiException(
          message: envelope.message ?? 'Failed to add seat order items.',
          statusCode: envelope.status,
        );
      }
    } on ApiException catch (error) {
      _appendApiError(error);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> generateReceipt(
    int orderId, {
    String type = 'preview',
  }) async {
    final body = {
      'order_id': orderId,
      'type': type,
      'mark_printed': true,
    };
    try {
      final response = await _client.post<Map<String, dynamic>>(
        ApiEndpoints.generateReceipt,
        data: body,
      );
      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        throw ApiException(
          message:
              'Réponse ticket invalide (HTTP ${response.statusCode}): $raw',
          statusCode: response.statusCode,
        );
      }

      final envelope = ApiEnvelope.parseResponse(raw);

      if (!envelope.success) {
        throw ApiException(
          message: envelope.message ?? 'Failed to generate receipt.',
          statusCode: envelope.status,
        );
      }

      _recordApiLog(
        method: 'POST',
        path: ApiEndpoints.generateReceipt,
        request: body,
        response: raw,
        statusCode: response.statusCode,
      );
      return raw;
    } on ApiException catch (error) {
      _recordApiLog(
        method: 'POST',
        path: ApiEndpoints.generateReceipt,
        request: body,
        statusCode: error.statusCode,
        error: error.message,
        writeToConsole: false,
      );
      rethrow;
    } catch (error) {
      _recordApiLog(
        method: 'POST',
        path: ApiEndpoints.generateReceipt,
        request: body,
        error: error.toString(),
        writeToConsole: false,
      );
      throw ApiException(message: 'Erreur ticket: $error');
    }
  }

  Future<Map<String, dynamic>> markOrderPrinted(int orderId) async {
    final body = {'order_id': orderId};
    try {
      final response = await _client.post<Map<String, dynamic>>(
        ApiEndpoints.markOrderPrinted,
        data: body,
      );
      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        throw ApiException(
          message:
              'Réponse mark-printed invalide (HTTP ${response.statusCode}): $raw',
          statusCode: response.statusCode,
        );
      }

      final envelope = ApiEnvelope.parseResponse(raw);

      if (!envelope.success) {
        throw ApiException(
          message: envelope.message ?? 'Failed to mark order as printed.',
          statusCode: envelope.status,
        );
      }

      _recordApiLog(
        method: 'POST',
        path: ApiEndpoints.markOrderPrinted,
        request: body,
        response: raw,
        statusCode: response.statusCode,
      );
      return raw;
    } on ApiException catch (error) {
      _recordApiLog(
        method: 'POST',
        path: ApiEndpoints.markOrderPrinted,
        request: body,
        statusCode: error.statusCode,
        error: error.message,
        writeToConsole: false,
      );
      rethrow;
    } catch (error) {
      _recordApiLog(
        method: 'POST',
        path: ApiEndpoints.markOrderPrinted,
        request: body,
        error: error.toString(),
        writeToConsole: false,
      );
      throw ApiException(message: 'Erreur mark-printed: $error');
    }
  }

  Future<void> payOrder({
    required int orderId,
    required double amount,
    required int paymentModeId,
  }) async {
    const path = ApiEndpoints.processPayment;
    final body = {
      'order_id': orderId,
      'amount': amount,
      'payment_mode_id': paymentModeId,
    };
    try {
      // Use dynamic: payment responses may be empty or envelope-shaped.
      final response = await _client.post<dynamic>(
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
      logPaymentApi(
        method: 'POST',
        path: path,
        request: body,
        response: response.data,
        statusCode: response.statusCode,
      );

      _ensureMutationSucceeded(
        statusCode: response.statusCode,
        data: response.data,
        fallbackMessage: 'Failed to pay order.',
      );
    } on ApiException catch (error) {
      logPaymentApi(
        method: 'POST',
        path: path,
        request: body,
        statusCode: error.statusCode,
        error: error.message,
      );
      _appendApiError(error);
      rethrow;
    } catch (error) {
      logPaymentApi(
        method: 'POST',
        path: path,
        request: body,
        error: error.toString(),
      );
      _recordApiLog(
        method: 'POST',
        path: path,
        request: body,
        error: error.toString(),
        writeToConsole: false,
      );
      throw ApiException(message: 'Erreur paiement: $error');
    }
  }

  /// Accepts empty/null HTTP 2xx bodies (common for payment process) and tolerant envelopes.
  void _ensureMutationSucceeded({
    required int? statusCode,
    required dynamic data,
    required String fallbackMessage,
  }) {
    final code = statusCode ?? 0;
    final raw = data;

    if (raw == null || raw == '' || (raw is Map && raw.isEmpty)) {
      if (code >= 200 && code < 300) return;
      throw ApiException(
        message: fallbackMessage,
        statusCode: code > 0 ? code : null,
      );
    }

    if (raw is! Map) {
      if (code >= 200 && code < 300) return;
      throw ApiException(
        message: fallbackMessage,
        statusCode: code > 0 ? code : null,
      );
    }

    final map = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw);

    // Only fail when the API explicitly reports failure.
    // (Some payment responses are 200 with a message but no `success` flag.)
    if (map.containsKey('success') && map['success'] == false) {
      final envelope = ApiEnvelope.parseResponse(map);
      throw ApiException(
        message: envelope.message ?? fallbackMessage,
        statusCode: envelope.status,
      );
    }

    if (code >= 200 && code < 300) return;

    final envelope = ApiEnvelope.parseResponse(map);
    throw ApiException(
      message: envelope.message ?? fallbackMessage,
      statusCode: envelope.status,
    );
  }

  Future<List<Map<String, dynamic>>> fetchPaymentModes() async {
    final errors = <String>[];
    final attempts = <String>[];

    for (final path in [
      ApiEndpoints.activePaymentModes,
      ApiEndpoints.paymentModesList,
      ApiEndpoints.paymentModesForCheckout,
    ]) {
      try {
        final response = await _client.get<dynamic>(path);
        _recordApiLog(
          method: 'GET',
          path: path,
          response: response.data,
          statusCode: response.statusCode,
        );

        final modes = OrderMapper.extractPaymentModes(response.data);
        attempts.add('$path → ${modes.length} mode(s)');
        if (modes.isNotEmpty) return modes;

        errors.add('$path: réponse vide ou format non reconnu.');
      } on ApiException catch (error) {
        attempts.add('$path → erreur');
        errors.add(
          '${error.message}${error.statusCode != null ? ' (HTTP ${error.statusCode})' : ''}',
        );
        _appendApiError(error);
      } catch (error) {
        attempts.add('$path → exception');
        errors.add('$path: $error');
      }
    }

    try {
      final settings = await fetchPaymentSettings();
      final fallback = OrderMapper.paymentModesFromSettings(settings);
      attempts.add(
        '${ApiEndpoints.paymentSettings} → ${fallback.length} mode(s)',
      );
      if (fallback.isNotEmpty) return fallback;
    } on ApiException catch (error) {
      errors.add(error.message);
    } catch (error) {
      errors.add('$error');
    }

    lastApiLog = [
      if (lastApiLog != null) lastApiLog,
      'Tentatives modes de paiement:',
      ...attempts,
      if (errors.isNotEmpty) 'Erreurs:',
      ...errors,
    ].join('\n');

    throw ApiException(
      message: errors.isEmpty
          ? 'Impossible de charger les modes de paiement.'
          : errors.last,
    );
  }

  Future<Map<String, dynamic>> fetchPaymentSettings() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.paymentSettings,
    );
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data!,
      (json) => json as Map<String, dynamic>,
    );

    if (!envelope.success || envelope.data == null) {
      throw ApiException(
        message: envelope.message ?? 'Failed to load payment settings.',
        statusCode: envelope.status,
      );
    }

    return envelope.data!;
  }
}
