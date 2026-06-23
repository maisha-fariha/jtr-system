import 'package:package_info_plus/package_info_plus.dart';

/// Environment configuration for the application
class Environment {
  static Environment? _instance;
  static Environment get instance => _instance ??= Environment._();

  Environment._();

  /// Current environment mode
  EnvironmentMode _mode = EnvironmentMode.development;
  EnvironmentMode get mode => _mode;

  /// App configuration
  AppConfig? _config;
  AppConfig get config => _config ??= _getDefaultConfig();

  /// Package info
  PackageInfo? _packageInfo;
  PackageInfo? get packageInfo => _packageInfo;

  /// Initialize environment
  Future<void> initialize({
    required EnvironmentMode mode,
    AppConfig? config,
  }) async {
    _mode = mode;
    _config = config ?? _getDefaultConfig();
    _packageInfo = await PackageInfo.fromPlatform();
  }

  /// Get default configuration based on environment
  AppConfig _getDefaultConfig() {
    switch (_mode) {
      case EnvironmentMode.development:
        return AppConfig.development();
      case EnvironmentMode.staging:
        return AppConfig.staging();
      case EnvironmentMode.production:
        return AppConfig.production();
    }
  }

  /// Check if in development mode
  bool get isDevelopment => _mode == EnvironmentMode.development;

  /// Check if in staging mode
  bool get isStaging => _mode == EnvironmentMode.staging;

  /// Check if in production mode
  bool get isProduction => _mode == EnvironmentMode.production;

  /// Get API base URL
  String get apiBaseUrl => config.apiBaseUrl;

  /// Get API timeout
  Duration get apiTimeout => config.apiTimeout;

  /// Get enable logging
  bool get enableLogging => config.enableLogging;

  /// Get app version
  String get appVersion => _packageInfo?.version ?? '1.0.0';

  /// Get build number
  String get buildNumber => _packageInfo?.buildNumber ?? '1';
}

/// Environment modes
enum EnvironmentMode {
  development,
  staging,
  production,
}

/// Application configuration
class AppConfig {
  final String apiBaseUrl;
  final Duration apiTimeout;
  final bool enableLogging;
  final Map<String, dynamic> additionalConfig;

  const AppConfig({
    required this.apiBaseUrl,
    this.apiTimeout = const Duration(seconds: 30),
    this.enableLogging = false,
    this.additionalConfig = const {},
  });

  /// Development configuration
  factory AppConfig.development() {
    return const AppConfig(
      apiBaseUrl: 'https://jsonplaceholder.typicode.com',
      apiTimeout: Duration(seconds: 30),
      enableLogging: true,
    );
  }

  /// Staging configuration
  factory AppConfig.staging() {
    return const AppConfig(
      apiBaseUrl: 'https://api-staging.example.com',
      apiTimeout: Duration(seconds: 30),
      enableLogging: true,
    );
  }

  /// Production configuration
  factory AppConfig.production() {
    return const AppConfig(
      apiBaseUrl: 'https://api.example.com',
      apiTimeout: Duration(seconds: 30),
      enableLogging: false,
    );
  }

  /// Get additional config value
  T? getAdditionalConfig<T>(String key) {
    return additionalConfig[key] as T?;
  }

  /// Copy with new values
  AppConfig copyWith({
    String? apiBaseUrl,
    Duration? apiTimeout,
    bool? enableLogging,
    Map<String, dynamic>? additionalConfig,
  }) {
    return AppConfig(
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      apiTimeout: apiTimeout ?? this.apiTimeout,
      enableLogging: enableLogging ?? this.enableLogging,
      additionalConfig: additionalConfig ?? this.additionalConfig,
    );
  }
}

