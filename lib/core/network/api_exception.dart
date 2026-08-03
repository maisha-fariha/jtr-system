class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.responseBody,
  });

  final String message;
  final int? statusCode;
  final Object? responseBody;

  /// True for HTTP 401 or API messages like "Unauthenticated".
  bool get isUnauthenticated {
    if (statusCode == 401) return true;
    return isUnauthenticatedMessage(message);
  }

  static bool isUnauthenticatedMessage(String? raw) {
    if (raw == null) return false;
    final text = raw.trim().toLowerCase();
    if (text.isEmpty) return false;
    return text.contains('unauthenticated') ||
        text.contains('non authentifi') ||
        text.contains('non-authentifi') ||
        text == 'unauthorized' ||
        text.contains('token expired') ||
        text.contains('token invalide') ||
        text.contains('invalid token');
  }

  @override
  String toString() => message;
}
