import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Trace logs for order create / add-item flow (always printed).
void logOrderFlow(String message) {
  final line = '[ORDER_FLOW] $message';
  print(line);
  debugPrint(line);
}

/// Logs POST /api/tables/open-by-number (always printed — table create flow).
void logOpenTableByNumber({
  required String phase,
  Object? request,
  Object? response,
  int? statusCode,
  String? error,
}) {
  final buffer = StringBuffer()
    ..writeln('════════ POST /api/tables/open-by-number [$phase]'
        '${statusCode != null ? ' → $statusCode' : ''} ════════');

  if (request != null) {
    buffer
      ..writeln('REQUEST:')
      ..writeln(_encode(request));
  }

  if (response != null) {
    buffer
      ..writeln('RESPONSE:')
      ..writeln(_encode(response));
  }

  if (error != null && error.isNotEmpty) {
    buffer
      ..writeln('ERROR:')
      ..writeln(error);
  }

  buffer.writeln('════════════════════════════════════════');

  final text = buffer.toString();
  print(text);
  debugPrint(text);
}

/// Logs POST /api/orders to the console (uses [print] so it always appears).
void logOrderPost({
  required String phase,
  Object? request,
  Object? response,
  int? statusCode,
  String? error,
}) {
  final buffer = StringBuffer()
    ..writeln('════════ POST /api/orders [$phase]'
        '${statusCode != null ? ' → $statusCode' : ''} ════════');

  if (request != null) {
    buffer
      ..writeln('REQUEST:')
      ..writeln(_encode(request));
  }

  if (response != null) {
    buffer
      ..writeln('RESPONSE:')
      ..writeln(_encode(response));
  }

  if (error != null && error.isNotEmpty) {
    buffer
      ..writeln('ERROR:')
      ..writeln(error);
  }

  buffer.writeln('════════════════════════════════════════');

  final text = buffer.toString();
  print(text);
  debugPrint(text);
}

/// Delete-item trace (cancel line / clear ticket) — always printed to console.
void logOrderDelete({
  required String phase,
  int? orderId,
  String? tableNumber,
  int? lineIndex,
  int? itemId,
  String? productName,
  bool clearingAll = false,
  String? apiTrace,
  String? error,
}) {
  final buffer = StringBuffer()
    ..writeln('════════ DELETE ITEM [$phase]'
        '${orderId != null ? ' order=$orderId' : ''} ════════');

  if (tableNumber != null && tableNumber.isNotEmpty) {
    buffer.writeln('table: $tableNumber');
  }
  if (productName != null && productName.isNotEmpty) {
    buffer.writeln('product: $productName');
  }
  if (lineIndex != null) {
    buffer.writeln('line_index: $lineIndex');
  }
  if (itemId != null && itemId > 0) {
    buffer.writeln('item_id: $itemId');
  }
  if (clearingAll) {
    buffer.writeln('clearing_all: true');
  }
  if (apiTrace != null && apiTrace.isNotEmpty) {
    buffer
      ..writeln('── API trace ──')
      ..writeln(apiTrace);
  }
  if (error != null && error.isNotEmpty) {
    buffer
      ..writeln('STATUS: ERREUR')
      ..writeln('ERROR:')
      ..writeln(error);
  } else if (phase == 'sync_ok' || phase == 'api_ok' || phase == 'tap') {
    buffer.writeln('STATUS: OK');
  }

  buffer.writeln('════════════════════════════════════════');

  final text = buffer.toString();
  print(text);
  debugPrint(text);
}

/// Ticket/receipt print trace (always printed — useful without a physical POS).
void logTicketPrint({
  required String phase,
  Object? request,
  Object? response,
  int? statusCode,
  String? error,
}) {
  final buffer = StringBuffer()
    ..writeln('════════ TICKET $phase'
        '${statusCode != null ? ' → $statusCode' : ''} ════════');

  if (request != null) {
    buffer
      ..writeln('REQUEST:')
      ..writeln(_encode(request));
  }

  if (response != null) {
    buffer
      ..writeln('RESPONSE:')
      ..writeln(_encode(response));
  }

  if (error != null && error.isNotEmpty) {
    buffer
      ..writeln('STATUS: ERREUR')
      ..writeln('ERROR:')
      ..writeln(error);
  } else if (response != null) {
    buffer.writeln('STATUS: OK');
  }

  buffer.writeln('════════════════════════════════════════');

  final text = buffer.toString();
  print(text);
  debugPrint(text);
}

/// Payment trace (POST /api/orders/:id/pay) — always printed to the console.
void logPaymentApi({
  required String method,
  required String path,
  Object? request,
  Object? response,
  int? statusCode,
  String? error,
}) {
  final buffer = StringBuffer()
    ..writeln('════════ PAYMENT $method $path'
        '${statusCode != null ? ' → $statusCode' : ''} ════════');

  if (request != null) {
    buffer
      ..writeln('REQUEST:')
      ..writeln(_encode(request));
  }

  if (response != null) {
    buffer
      ..writeln('RESPONSE:')
      ..writeln(_encode(response));
  }

  if (error != null && error.isNotEmpty) {
    buffer
      ..writeln('STATUS: ERREUR')
      ..writeln('ERROR:')
      ..writeln(error);
  } else if (response != null) {
    buffer.writeln('STATUS: OK');
  }

  buffer.writeln('════════════════════════════════════════');

  final text = buffer.toString();
  print(text);
  debugPrint(text);
}

/// Device activation APIs (GET session / POST activate) — console only.
void logDeviceApi({
  required String method,
  required String path,
  String? baseUrl,
  Object? request,
  Object? response,
  int? statusCode,
  String? error,
}) {
  final fullUrl = _joinBaseAndPath(baseUrl, path);
  final buffer = StringBuffer()
    ..writeln('════════ DEVICE $method $path'
        '${statusCode != null ? ' → $statusCode' : ''} ════════')
    ..writeln('API: $method $fullUrl');

  if (request != null) {
    buffer
      ..writeln('REQUEST:')
      ..writeln(_encode(_redactSecrets(request)));
  }

  if (response != null) {
    buffer
      ..writeln('RESPONSE:')
      ..writeln(_encode(_redactSecrets(response)));
  }

  if (error != null && error.isNotEmpty) {
    buffer
      ..writeln('STATUS: ERREUR')
      ..writeln('ERROR:')
      ..writeln(error);
  } else if (response != null) {
    buffer.writeln('STATUS: OK');
  }

  buffer.writeln('════════════════════════════════════════');

  final text = buffer.toString();
  print(text);
  debugPrint(text);
}

String _joinBaseAndPath(String? baseUrl, String path) {
  final base = (baseUrl ?? '').trim();
  if (base.isEmpty) return path;
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  final normalizedBase =
      base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  final normalizedPath = path.startsWith('/') ? path : '/$path';
  return '$normalizedBase$normalizedPath';
}

/// QR / activation flow: always print POS URL + payload (never log device_token).
void logDeviceActivation({
  required String phase,
  String? posUrl,
  Object? qrPayload,
  Object? request,
  Object? response,
  String? error,
}) {
  final buffer = StringBuffer()
    ..writeln('════════ DEVICE ACTIVATION [$phase] ════════');

  if (posUrl != null && posUrl.isNotEmpty) {
    buffer
      ..writeln('POS_URL / api_base_url:')
      ..writeln(posUrl);
  }

  if (qrPayload != null) {
    buffer
      ..writeln('QR_PAYLOAD:')
      ..writeln(_encode(_redactSecrets(qrPayload)));
  }

  if (request != null) {
    buffer
      ..writeln('REQUEST:')
      ..writeln(_encode(_redactSecrets(request)));
  }

  if (response != null) {
    buffer
      ..writeln('RESPONSE:')
      ..writeln(_encode(_redactSecrets(response)));
  }

  if (error != null && error.isNotEmpty) {
    buffer
      ..writeln('STATUS: ERREUR')
      ..writeln('ERROR:')
      ..writeln(error);
  } else if (response != null || posUrl != null) {
    buffer.writeln('STATUS: OK');
  }

  buffer.writeln('════════════════════════════════════════');

  final text = buffer.toString();
  print(text);
  debugPrint(text);
}

Object _redactSecrets(Object value) {
  if (value is! Map) return value;
  final copy = Map<String, dynamic>.from(value);
  for (final key in copy.keys.toList()) {
    final lower = key.toLowerCase();
    if (lower.contains('token') ||
        lower.contains('secret') ||
        lower.contains('password')) {
      final raw = copy[key]?.toString() ?? '';
      copy[key] = raw.isEmpty ? '***' : '***${raw.length}ch';
    } else if (copy[key] is Map) {
      copy[key] = _redactSecrets(copy[key] as Map);
    }
  }
  return copy;
}

/// Logs API request/response to the debug console (visible in `flutter run`).
void logApiCall({
  required String method,
  required String path,
  Object? request,
  Object? response,
  int? statusCode,
  String? error,
}) {
  final buffer = StringBuffer()
    ..writeln('════════ API $method $path'
        '${statusCode != null ? ' → $statusCode' : ''} ════════');

  if (request != null) {
    buffer
      ..writeln('REQUEST:')
      ..writeln(_encode(request));
  }

  if (response != null) {
    buffer
      ..writeln('RESPONSE:')
      ..writeln(_encode(response));
  }

  if (error != null && error.isNotEmpty) {
    buffer
      ..writeln('ERROR:')
      ..writeln(error);
  }

  buffer.writeln('════════════════════════════════════════');

  final text = buffer.toString();
  debugPrint(text);
}

/// Logs the bearer token to the debug console (login / session restore).
void logAuthToken(String token, {required String source}) {
  debugPrint('════════ AUTH TOKEN ($source) ════════');
  debugPrint(token);
  debugPrint('Authorization: Bearer $token');
  debugPrint('════════════════════════════════════════');
}

void logAuthTokenCleared({required String source}) {
  debugPrint('════════ AUTH TOKEN cleared ($source) ════════');
}

String formatApiPayload(Object? value) => _encode(value);

String _encode(Object? value) {
  if (value == null) return '(null)';
  try {
    if (value is Map || value is List) {
      return const JsonEncoder.withIndent('  ').convert(value);
    }
    return value.toString();
  } catch (_) {
    return value.toString();
  }
}
