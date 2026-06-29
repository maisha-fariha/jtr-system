import 'dart:convert';

import 'package:flutter/foundation.dart';

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
