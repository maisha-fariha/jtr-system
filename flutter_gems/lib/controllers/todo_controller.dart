import 'package:gems_data_layer/gems_data_layer.dart';
import 'package:gems_core/gems_core.dart';
import '../models/todo/todo_model.dart';
import '../repositories/todo_repository.dart';

class TodoController extends BaseListController<Todo> with BaseControllerMixin<Todo> {
  final TodoRepository repository;

  TodoController({
    required this.repository,
  }) {
    loadItems();
  }

  @override
  Future<void> loadItems() async {
    await handleListResult(() => repository.getAll());
  }

  Future<void> createTodo(String title, {int userId = 1}) async {
    // Validation
    final validation = FormValidator.validateField(
      value: title,
      rules: [
        StringValidators.required(),
        StringValidators.minLength(1),
        StringValidators.maxLength(200),
      ],
    );
    if (validation.isFailure) {
      setError(validation.error!.message);
      return;
    }

    // Create model
    final todo = Todo(
      id: UseCaseHelper.generateId(prefix: 'todo'),
      title: title.trim(),
      isCompleted: false,
      userId: userId,
    );

    await handleResult(
      () => repository.create(todo),
      onSuccess: (todo) => items.insert(0, todo),
      showSuccessMessage: true,
      successMessage: 'Todo created successfully',
    );
  }

  Future<void> updateTodo(Todo todo) async {
    await handleResult(
      () => repository.update(todo.id, todo),
      onSuccess: (todo) {
        final index = items.indexWhere((t) => t.id == todo.id);
        if (index != -1) items[index] = todo;
      },
      showSuccessMessage: true,
      successMessage: 'Todo updated successfully',
    );
  }

  Future<void> deleteTodo(String id) async {
    await handleResult(
      () => repository.delete(id),
      onSuccess: (_) => items.removeWhere((t) => t.id == id),
      showSuccessMessage: true,
      successMessage: 'Todo deleted successfully',
    );
  }

  void toggleTodo(Todo todo) async {
    // Optimistic update - update UI immediately
    final index = items.indexWhere((t) => t.id == todo.id);
    if (index == -1) return;
    
    // Toggle locally first (instant UI update)
    final toggledTodo = todo.copyWith(isCompleted: !todo.isCompleted);
    items[index] = toggledTodo;
    
    // Sync with repository in background (non-blocking)
    // Use toggleItem for better performance (we already have the item)
    // Pass the original todo so toggleItem can toggle it correctly
    await handleResult(
      () => repository.toggleItem(todo, 'completed'),
      onSuccess: (updatedTodo) {
        // Update with server response if different
        final updatedIndex = items.indexWhere((t) => t.id == updatedTodo.id);
        if (updatedIndex != -1) items[updatedIndex] = updatedTodo;
      },
      showSuccessMessage: false, // Don't show message for instant toggle
      onError: (error) {
        // Revert on error
        if (index != -1) items[index] = todo;
      },
    );
  }
}

