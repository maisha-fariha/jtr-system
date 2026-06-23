import 'package:get_it/get_it.dart';
import 'package:gems_data_layer/gems_data_layer.dart';
import 'package:gems_core/gems_core.dart';
import '../../repositories/product_repository.dart';
import '../../controllers/product_controller.dart';

/// Setup Product domain services
/// Repository handles all CRUD operations directly
/// Controller uses repository directly
Future<void> setupProductDomainServices() async {
  final getIt = GetIt.instance;
  
  // Register repository
  DIHelper.registerRepository<ProductRepository>(
    factory: () => ProductRepository(
      apiService: getIt<ApiService>(),
      databaseService: getIt<DatabaseService>(),
      syncService: getIt<SyncService>(),
    ),
  );

  // Register controller
  DIHelper.registerController<ProductController>(
    factory: () => ProductController(
      repository: getIt<ProductRepository>(),
    ),
  );
}
