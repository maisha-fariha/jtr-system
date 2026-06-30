import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Trace logs for order create / add-item flow (always printed).
void logOrderFlow(String message) {
  final line = '[ORDER_FLOW] $message';
  print(line);
  debugPrint(line);
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
