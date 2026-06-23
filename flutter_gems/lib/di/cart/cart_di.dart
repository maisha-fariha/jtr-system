import 'package:get_it/get_it.dart';
import 'package:gems_data_layer/gems_data_layer.dart';
import 'package:gems_core/gems_core.dart';
import '../../repositories/cart_repository.dart';
import '../../controllers/cart_controller.dart';

/// Setup Cart domain services
/// Repository handles all CRUD operations directly
/// Controller uses repository directly
Future<void> setupCartDomainServices() async {
  final getIt = GetIt.instance;
  
  // Register repository
  DIHelper.registerRepository<CartRepository>(
    factory: () => CartRepository(
      apiService: getIt<ApiService>(),
      databaseService: getIt<DatabaseService>(),
      syncService: getIt<SyncService>(),
    ),
  );

  // Register controller
  DIHelper.registerController<CartController>(
    factory: () => CartController(
      repository: getIt<CartRepository>(),
    ),
  );
}
