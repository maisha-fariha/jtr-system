# Complete Example Usage

## Author

**Md. Adnan Ullah**
- Email: saadnanullah@gmail.com
- GitHub: [md-adnan-ullah](https://github.com/md-adnan-ullah)

---

## Full Setup Example

```dart
import 'package:flutter/material.dart';
import 'package:gems_data_layer/gems_data_layer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

// 1. Initialize Services (in main.dart)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  
  // Configure API
  final apiConfig = ApiConfig(
    baseUrl: 'https://api.example.com',
    enableLogging: true,
  );
  
  // Create services
  final apiService = ApiService(apiConfig);
  final cacheService = CacheService(prefs);
  final connectivity = Connectivity();
  final syncService = SyncService(apiService, cacheService, connectivity);
  final authService = AuthService(apiService, prefs);
  
  // Initialize
  await cacheService.initialize();
  await syncService.initialize();
  await authService.initialize();
  
  // Store services in GetX for dependency injection
  Get.put(apiService);
  Get.put(cacheService);
  Get.put(syncService);
  Get.put(authService);
  
  runApp(MyApp());
}

// 2. Create Your Model
class User extends BaseModel {
  final String id;
  final String name;
  final String email;

  User({
    required this.id,
    required this.name,
    required this.email,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
    );
  }
}

// 3. Create Your Repository
class UserRepository extends BaseRepository<User> {
  UserRepository({
    required super.apiService,
    required super.cacheService,
    required super.syncService,
  }) : super(baseEndpoint: '/users');

  @override
  User fromJson(Map<String, dynamic> json) => User.fromJson(json);

  @override
  Map<String, dynamic> toJson(User model) => model.toJson();
}

// 4. Create Your Controller
class UserController extends BaseListController<User> {
  final UserRepository repository;

  UserController(this.repository);

  @override
  Future<void> loadItems() async {
    setLoading(true);
    final response = await repository.getAll(useCache: true);
    if (response.success && response.data != null) {
      addItems(response.data!);
    } else {
      setError(response.message ?? 'Failed to load users');
    }
    setLoading(false);
  }

  Future<void> createUser(String name, String email) async {
    setLoading(true);
    final user = User(id: '', name: name, email: email);
    final response = await repository.create(user, syncOffline: true);
    if (response.success && response.data != null) {
      items.insert(0, response.data!);
    } else {
      setError(response.message ?? 'Failed to create user');
    }
    setLoading(false);
  }

  Future<void> updateUser(User user) async {
    setLoading(true);
    final response = await repository.update(user.id, user, syncOffline: true);
    if (response.success && response.data != null) {
      final index = items.indexWhere((u) => u.id == user.id);
      if (index != -1) {
        items[index] = response.data!;
      }
    } else {
      setError(response.message ?? 'Failed to update user');
    }
    setLoading(false);
  }

  Future<void> deleteUser(String id) async {
    setLoading(true);
    final response = await repository.delete(id, syncOffline: true);
    if (response.success) {
      items.removeWhere((u) => u.id == id);
    } else {
      setError(response.message ?? 'Failed to delete user');
    }
    setLoading(false);
  }
}

// 5. Use in Your UI
class UsersPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final apiService = Get.find<ApiService>();
    final cacheService = Get.find<CacheService>();
    final syncService = Get.find<SyncService>();
    
    final controller = Get.put(UserController(
      UserRepository(
        apiService: apiService,
        cacheService: cacheService,
        syncService: syncService,
      ),
    ));

    return Scaffold(
      appBar: AppBar(
        title: Text('Users'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => controller.refresh(),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.items.isEmpty) {
          return Center(child: CircularProgressIndicator());
        }
        
        if (controller.errorMessage.value.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(controller.errorMessage.value),
                ElevatedButton(
                  onPressed: () => controller.loadItems(),
                  child: Text('Retry'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => controller.refresh(),
          child: ListView.builder(
            itemCount: controller.items.length,
            itemBuilder: (context, index) {
              final user = controller.items[index];
              return ListTile(
                title: Text(user.name),
                subtitle: Text(user.email),
                trailing: IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () => controller.deleteUser(user.id),
                ),
                onTap: () {
                  // Navigate to edit page
                },
              );
            },
          ),
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Show create user dialog
          _showCreateDialog(context, controller);
        },
        child: Icon(Icons.add),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, UserController controller) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              controller.createUser(
                nameController.text,
                emailController.text,
              );
              Navigator.pop(context);
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
  }
}

// 6. Authentication Example
class LoginPage extends StatelessWidget {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final authService = Get.find<AuthService>();
    final isLoading = false.obs;

    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 24),
            Obx(() => ElevatedButton(
              onPressed: isLoading.value
                  ? null
                  : () async {
                      isLoading.value = true;
                      final response = await authService.login(
                        email: emailController.text,
                        password: passwordController.text,
                      );
                      isLoading.value = false;

                      if (response.success) {
                        Get.offAll(UsersPage());
                      } else {
                        Get.snackbar(
                          'Error',
                          response.message ?? 'Login failed',
                        );
                      }
                    },
              child: isLoading.value
                  ? CircularProgressIndicator()
                  : Text('Login'),
            )),
          ],
        ),
      ),
    );
  }
}
```

## Key Points

1. **Services are initialized once** in `main.dart`
2. **Models extend BaseModel** and implement `toJson()` and `fromJson()`
3. **Repositories extend BaseRepository** and implement `fromJson()` and `toJson()`
4. **Controllers extend BaseListController** or `BaseController`
5. **Offline support is automatic** - just set `syncOffline: true`
6. **Caching is automatic** - set `useCache: true` in repository methods
7. **Background sync** runs automatically every 15 minutes when online

