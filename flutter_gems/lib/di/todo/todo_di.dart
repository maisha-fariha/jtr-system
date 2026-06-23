import 'package:get_it/get_it.dart';
import 'package:gems_data_layer/gems_data_layer.dart';
import 'package:gems_core/gems_core.dart';
import '../../repositories/todo_repository.dart';
import '../../controllers/todo_controller.dart';

/// Setup Todo domain services
/// Repository handles all CRUD operations directly
/// Controller uses repository directly
Future<void> setupTodoDomainServices() async {
  final getIt = GetIt.instance;
  
  // Register repository
  DIHelper.registerRepository<TodoRepository>(
    factory: () => TodoRepository(
      apiService: getIt<ApiService>(),
      databaseService: getIt<DatabaseService>(),
      syncService: getIt<SyncService>(),
    ),
  );

  // Register controller
  DIHelper.registerController<TodoController>(
    factory: () => TodoController(
      repository: getIt<TodoRepository>(),
    ),
  );
}

