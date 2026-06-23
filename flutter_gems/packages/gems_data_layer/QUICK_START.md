# Quick Start - gems_data_layer with Freezed

## 🎯 3-Step Setup with Freezed

### 1. Initialize Services (once in main.dart)
```dart
final prefs = await SharedPreferences.getInstance();
final apiConfig = ApiConfig(baseUrl: 'YOUR_API_URL');
final apiService = ApiService(apiConfig);
final cacheService = CacheService(prefs);
final databaseService = DatabaseService();
final syncService = SyncService(apiService, cacheService, Connectivity());
final authService = AuthService(apiService, prefs);

await databaseService.initialize();
await cacheService.initialize();
await syncService.initialize();
await authService.initialize();
```

### 2. Create Model with Freezed (No manual toJson/fromJson!)
```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gems_data_layer/gems_data_layer.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
class User with _$User implements BaseModel {
  const factory User({
    required String id,
    required String name,
    required String email,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
```

**Run code generation:**
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Create Repository & Controller (Minimal!)
```dart
// Repository - Just 1 line for fromJson!
class UserRepository extends BaseRepository<User> {
  UserRepository(...) : super(baseEndpoint: '/users');
  @override User fromJson(Map<String, dynamic> json) => User.fromJson(json);
}

// Controller - Just implement loadItems
class UserController extends BaseListController<User> {
  final UserRepository repo;
  UserController(this.repo);
  
  @override Future<void> loadItems() async {
    setLoading(true);
    final response = await repo.getAll();
    if (response.success && response.data != null) addItems(response.data!);
    setLoading(false);
  }
}
```

## ✅ Benefits of Freezed:
- ✅ **No manual toJson/fromJson** - Auto-generated!
- ✅ **Type-safe** - Compile-time checks
- ✅ **copyWith** - Built-in immutable updates
- ✅ **Equality** - Auto-generated == and hashCode
- ✅ **Union types** - Pattern matching support

## 🗄️ Hive Database Usage:
```dart
// Initialize
await databaseService.initialize();

// Save
await databaseService.save('user_1', user.toJson());

// Get
final userData = databaseService.get<Map>('user_1');
final user = User.fromJson(userData!);

// Register adapter (optional, for better performance)
databaseService.registerAdapter(UserAdapter());
```

## 🚀 Usage in UI
```dart
final controller = Get.put(UserController(repo));

Obx(() {
  if (controller.isLoading.value) return CircularProgressIndicator();
  return ListView.builder(
    itemCount: controller.items.length,
    itemBuilder: (_, i) {
      final user = controller.items[i];
      return ListTile(
        title: Text(user.name),
        subtitle: Text(user.email),
      );
    },
  );
});
```

## 📝 Freezed Model Example:
```dart
@freezed
class Todo with _$Todo implements BaseModel {
  const factory Todo({
    required String id,
    required String title,
    String? description,
    @Default(false) bool isCompleted,
    required DateTime createdAt,
  }) = _Todo;

  factory Todo.fromJson(Map<String, dynamic> json) => _$TodoFromJson(json);
}

// Usage:
final todo = Todo(id: '1', title: 'Task', createdAt: DateTime.now());
final updated = todo.copyWith(isCompleted: true); // Immutable update!
```

## 🎯 What You Get:
- ✅ Full CRUD (getAll, getById, create, update, delete)
- ✅ Automatic caching (Hive + SharedPreferences)
- ✅ Offline queue
- ✅ GetX reactive state
- ✅ Freezed code generation (no boilerplate!)
- ✅ Hive database support
