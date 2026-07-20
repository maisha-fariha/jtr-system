import 'package:dio/dio.dart';

/// User-facing messages when the phone cannot reach a Windows POS on the LAN.
String lanPosConnectionUserMessage({
  required DioException error,
  String? targetHost,
}) {
  final host = (targetHost ?? '').trim();
  final hostHint = host.isEmpty ? 'le poste Windows' : host;
  final raw = '${error.message ?? ''} ${error.error ?? ''}'.toLowerCase();

  if (raw.contains('refused') ||
      raw.contains('connection refused') ||
      raw.contains('os error: connection refused')) {
    return 'Connexion refusée vers $hostHint.\n'
        'Le téléphone est sur le Wi‑Fi, mais l\'API de la caisse n\'accepte pas '
        'la connexion.\n'
        'Vérifiez : logiciel caisse ouvert, même Wi‑Fi, pare-feu Windows, '
        'et le port (ex. http://IP:8080/api si besoin).';
  }

  if (error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      raw.contains('timed out') ||
      raw.contains('timeout')) {
    return 'Délai dépassé vers $hostHint.\n'
        'Vérifiez l\'IP du poste et que le téléphone est sur le même Wi‑Fi.';
  }

  if (error.type == DioExceptionType.connectionError ||
      raw.contains('network is unreachable') ||
      raw.contains('failed host lookup') ||
      raw.contains('no route to host')) {
    return 'Impossible de joindre $hostHint.\n'
        'Vérifiez le Wi‑Fi (pas le réseau invité) et l\'adresse IP de la caisse.';
  }

  final fallback = error.message?.trim();
  if (fallback != null && fallback.isNotEmpty) {
    return 'Impossible de joindre $hostHint.\n$fallback';
  }
  return 'Impossible de joindre $hostHint. Vérifiez le réseau et la caisse.';
}

String? hostFromBaseUrl(String? baseUrl) {
  final raw = (baseUrl ?? '').trim();
  if (raw.isEmpty) return null;
  final uri = Uri.tryParse(raw.contains('://') ? raw : 'http://$raw');
  if (uri == null || uri.host.isEmpty) return raw;
  return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
}
