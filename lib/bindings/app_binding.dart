import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

import '../core/network/api_client.dart';
import '../core/storage/device_secure_storage.dart';
import '../core/storage/hive_storage.dart';
import '../data/datasources/auth_local_datasource.dart';
import '../data/datasources/auth_remote_datasource.dart';
import '../data/datasources/catalog_local_datasource.dart';
import '../data/datasources/catalog_remote_datasource.dart';
import '../data/datasources/device_remote_datasource.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/catalog_repository.dart';
import '../data/repositories/device_repository.dart';
import '../data/repositories/order_repository.dart';
import '../data/datasources/order_local_datasource.dart';
import '../data/datasources/order_remote_datasource.dart';
import '../data/datasources/session_datasource.dart';
import '../data/repositories/session_repository.dart';
import '../services/connectivity_service.dart';
import '../controllers/theme_controller.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ThemeController>()) {
      Get.put(ThemeController(), permanent: true);
    }

    Get.lazyPut<Connectivity>(() => Connectivity(), fenix: true);
    Get.lazyPut<ConnectivityService>(
      () => ConnectivityService(Get.find<Connectivity>()),
      fenix: true,
    );
    Get.lazyPut<ApiClient>(() => ApiClient(), fenix: true);
    Get.lazyPut<HiveStorage>(() => HiveStorage(), fenix: true);
    Get.lazyPut<DeviceSecureStorage>(() => DeviceSecureStorage(), fenix: true);
    Get.lazyPut<DeviceRemoteDataSource>(
      () => DeviceRemoteDataSource(Get.find<ApiClient>()),
      fenix: true,
    );
    Get.lazyPut<DeviceRepository>(
      () => DeviceRepository(
        remote: Get.find<DeviceRemoteDataSource>(),
        secureStorage: Get.find<DeviceSecureStorage>(),
        apiClient: Get.find<ApiClient>(),
      ),
      fenix: true,
    );
    Get.lazyPut<AuthLocalDataSource>(
      () => AuthLocalDataSource(Get.find<HiveStorage>()),
      fenix: true,
    );
    Get.lazyPut<AuthRemoteDataSource>(
      () => AuthRemoteDataSource(Get.find<ApiClient>()),
      fenix: true,
    );
    Get.lazyPut<AuthRepository>(
      () => AuthRepository(
        remote: Get.find<AuthRemoteDataSource>(),
        local: Get.find<AuthLocalDataSource>(),
        connectivity: Get.find<ConnectivityService>(),
        apiClient: Get.find<ApiClient>(),
      ),
      fenix: true,
    );
    Get.lazyPut<OrderLocalDataSource>(
      () => OrderLocalDataSource(Get.find<HiveStorage>()),
      fenix: true,
    );
    Get.lazyPut<OrderRemoteDataSource>(
      () => OrderRemoteDataSource(Get.find<ApiClient>()),
      fenix: true,
    );
    Get.lazyPut<SessionRemoteDataSource>(
      () => SessionRemoteDataSource(Get.find<ApiClient>()),
      fenix: true,
    );
    Get.lazyPut<SessionLocalDataSource>(
      () => SessionLocalDataSource(Get.find<HiveStorage>()),
      fenix: true,
    );
    Get.lazyPut<CatalogLocalDataSource>(
      () => CatalogLocalDataSource(Get.find<HiveStorage>()),
      fenix: true,
    );
    Get.lazyPut<CatalogRemoteDataSource>(
      () => CatalogRemoteDataSource(Get.find<ApiClient>()),
      fenix: true,
    );
    Get.lazyPut<CatalogRepository>(
      () => CatalogRepository(
        remote: Get.find<CatalogRemoteDataSource>(),
        local: Get.find<CatalogLocalDataSource>(),
        connectivity: Get.find<ConnectivityService>(),
      ),
      fenix: true,
    );
    Get.lazyPut<OrderRepository>(
      () => OrderRepository(
        remote: Get.find<OrderRemoteDataSource>(),
        local: Get.find<OrderLocalDataSource>(),
        sessionRemote: Get.find<SessionRemoteDataSource>(),
        sessionLocal: Get.find<SessionLocalDataSource>(),
        connectivity: Get.find<ConnectivityService>(),
        catalog: Get.find<CatalogRepository>(),
      ),
      fenix: true,
    );
    Get.lazyPut<SessionRepository>(
      () => SessionRepository(
        remote: Get.find<SessionRemoteDataSource>(),
        local: Get.find<SessionLocalDataSource>(),
        connectivity: Get.find<ConnectivityService>(),
      ),
      fenix: true,
    );
  }
}
