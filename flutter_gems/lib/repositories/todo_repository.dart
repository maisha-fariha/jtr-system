import 'package:gems_data_layer/gems_data_layer.dart';
import '../models/todo/todo_model.dart';
import '../utils/api_endpoints.dart';

/// TodoRepository - Just extends BaseRepository with fromJson
/// All CRUD operations are handled by BaseRepository
class TodoRepository extends BaseRepository<Todo> {
  TodoRepository({
    required super.apiService,
    required super.databaseService,
    required super.syncService,
  }) : super(baseEndpoint: ApiEndpoints.todos);

  @override
  Todo fromJson(Map<String, dynamic> json) => Todo.fromJson(json);
}

