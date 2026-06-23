import 'package:get_it/get_it.dart';
import '../../controllers/favorites_controller.dart';

void setupFavoritesDomainServices() {
  final getIt = GetIt.instance;

  // Register FavoritesController as singleton
  if (!getIt.isRegistered<FavoritesController>()) {
    getIt.registerLazySingleton<FavoritesController>(
      () => FavoritesController(),
    );
  }
}
