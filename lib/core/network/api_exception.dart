class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.responseBody,
  });

  final String message;
  final int? statusCode;
  final Object? responseBody;

  @override
  String toString() => message;
}
