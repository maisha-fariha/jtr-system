import 'package:flutter/material.dart';
import '../utils/app_snackbar.dart';

/// User-facing error helper. Logs stay in the console only — no debug popup.
class ApiDebugDialog {
  ApiDebugDialog._();

  static void show({
    required String title,
    required String body,
  }) {
    debugPrint('[$title]\n$body');
    final message = _userFacingMessage(body);
    AppSnackbar.show(
      title,
      message,
      duration: const Duration(seconds: 3),
    );
  }

  static String _userFacingMessage(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return 'Une erreur est survenue. Réessayez.';
    }

    const marker = 'MESSAGE:';
    final idx = trimmed.lastIndexOf(marker);
    if (idx >= 0) {
      final message = trimmed.substring(idx + marker.length).trim();
      if (message.isNotEmpty) return message;
    }

    // Full API logs must never be shown to waiters.
    if (trimmed.contains('──') ||
        trimmed.contains('POST /') ||
        trimmed.contains('PUT /') ||
        trimmed.contains('GET /') ||
        trimmed.length > 180) {
      return 'Une erreur est survenue. Réessayez.';
    }

    return trimmed;
  }
}
