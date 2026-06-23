/// API Configuration class
class ApiConfig {
  final String baseUrl;
  final Map<String, String> defaultHeaders;
  final Duration timeout;
  final bool enableLogging;

  const ApiConfig({
    required this.baseUrl,
    this.defaultHeaders = const {},
    this.timeout = const Duration(seconds: 30),
    this.enableLogging = false,
  });

  ApiConfig copyWith({
    String? baseUrl,
    Map<String, String>? defaultHeaders,
    Duration? timeout,
    bool? enableLogging,
  }) {
    return ApiConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      defaultHeaders: defaultHeaders ?? this.defaultHeaders,
      timeout: timeout ?? this.timeout,
      enableLogging: enableLogging ?? this.enableLogging,
    );
  }
}

