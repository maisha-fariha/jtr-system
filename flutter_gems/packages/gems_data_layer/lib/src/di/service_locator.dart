import 'package:get_it/get_it.dart';
import 'package:gems_data_layer/gems_data_layer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service Locator instance for gems_data_layer
final getIt = GetIt.instance;

/// Initialize all gems_data_layer services with get_it
///
/// Usage:
/// ```dart
/// await setupDataLayerServices(
///   apiConfig: ApiConfig(baseUrl: 'https://api.example.com'),
/// );
/// ```
Future<void> setupDataLayerServices({
  required ApiConfig apiConfig,
  SharedPreferences? sharedPreferences,
  Connectivity? connectivity,
  String? databaseBoxName,
  PushNotificationProvider? pushNotificationProvider,
  PushNotificationConfig pushNotificationConfig =
      const PushNotificationConfig(),
}) async {
  // Register SharedPreferences (singleton)
  if (sharedPreferences != null) {
    getIt.registerSingleton<SharedPreferences>(sharedPreferences);
  } else {
    getIt.registerSingletonAsync<SharedPreferences>(
      () => SharedPreferences.getInstance(),
    );
    await getIt.allReady();
  }

  // Register Connectivity (singleton)
  if (connectivity != null) {
    getIt.registerSingleton<Connectivity>(connectivity);
  } else {
    getIt.registerSingleton<Connectivity>(Connectivity());
  }

  // Register ApiConfig (singleton)
  getIt.registerSingleton<ApiConfig>(apiConfig);

  // Register ApiService (singleton)
  getIt.registerSingleton<ApiService>(
    ApiService(apiConfig),
  );

  // Register DatabaseService (singleton)
  final databaseService = DatabaseService();
  await databaseService.initialize(boxName: databaseBoxName);
  getIt.registerSingleton<DatabaseService>(databaseService);

  // Register SyncService (singleton, depends on ApiService, DatabaseService, Connectivity)
  getIt.registerSingleton<SyncService>(
    SyncService(
      getIt<ApiService>(),
      getIt<DatabaseService>(),
      getIt<Connectivity>(),
    ),
  );
  await getIt<SyncService>().initialize();

  // Register AuthService (singleton, depends on ApiService, SharedPreferences)
  getIt.registerSingleton<AuthService>(
    AuthService(
      getIt<ApiService>(),
      getIt<SharedPreferences>(),
    ),
  );
  await getIt<AuthService>().initialize();

  // Register PushNotificationService when a provider is supplied.
  if (pushNotificationProvider != null) {
    getIt.registerSingleton<PushNotificationService>(
      PushNotificationService(
        pushNotificationProvider,
        getIt<SharedPreferences>(),
        config: pushNotificationConfig,
      ),
    );
    await getIt<PushNotificationService>().initialize();
  }
}

/// Reset all registered services (useful for testing)
Future<void> resetDataLayerServices() async {
  await getIt.reset();
}
