import 'package:get_it/get_it.dart';
import '../config/environment.dart';

/// Service Locator instance for gems_core
final coreGetIt = GetIt.instance;

/// Initialize gems_core services
/// 
/// Usage:
/// ```dart
/// await setupCoreServices(
///   environmentMode: EnvironmentMode.development,
///   config: AppConfig.development(),
/// );
/// ```
Future<void> setupCoreServices({
  required EnvironmentMode environmentMode,
  AppConfig? config,
}) async {
  // Initialize environment
  await Environment.instance.initialize(
    mode: environmentMode,
    config: config,
  );

  // Register environment as singleton
  coreGetIt.registerSingleton<Environment>(Environment.instance);
}

/// Reset core services (useful for testing)
Future<void> resetCoreServices() async {
  await coreGetIt.reset();
}

