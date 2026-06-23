import 'package:get_it/get_it.dart';
import '../../controllers/search_controller.dart';

void setupSearchDomainServices() {
  final getIt = GetIt.instance;

  // Register ProductSearchController as singleton
  if (!getIt.isRegistered<ProductSearchController>()) {
    getIt.registerLazySingleton<ProductSearchController>(
      () => ProductSearchController(),
    );
  }
}
