# gems_data_layer

A comprehensive data layer package for Flutter with REST API, CRUD operations, authentication, GetX state management, Hive database, and offline/online support with background sync.

📖 **[See Architecture & Flow Overview →](ARCHITECTURE.md)**

## Features

- ✅ **REST API Client** - Full CRUD operations (GET, POST, PUT, PATCH, DELETE)
- ✅ **Authentication** - Login, register, token refresh with automatic token management
- ✅ **Push Notifications** - Unified setup for Firebase or custom provider
- ✅ **GetX Integration** - Base controllers and repositories ready to use
- ✅ **Hive Database** - Local NoSQL database for offline data storage
- ✅ **Offline Support** - Automatic caching and sync queue
- ✅ **Background Sync** - Syncs data when connection is restored
- ✅ **Cache Management** - Smart caching with TTL support
- ✅ **Error Handling** - Comprehensive error handling and response wrapping

## Author

**Md. Adnan Ullah**
- Email: saadnanullah@gmail.com
- GitHub: [md-adnan-ullah](https://github.com/md-adnan-ullah)

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  gems_data_layer: ^0.1.0
```

Then run:

```bash
flutter pub get
```

## Quick Start

### 1. Initialize Services

```dart
import 'package:gems_data_layer/gems_data_layer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  final prefs = await SharedPreferences.getInstance();
  final apiConfig = ApiConfig(
    baseUrl: 'https://api.example.com',
    enableLogging: true,
  );
  
  final apiService = ApiService(apiConfig);
  final cacheService = CacheService(prefs);
  final syncService = SyncService(apiService, cacheService, Connectivity());
  final authService = AuthService(apiService, prefs);
  
  // Initialize cache and sync
  await cacheService.initialize();
  await syncService.initialize();
  await authService.initialize();
  
  runApp(MyApp());
}
```

### 2. Create Your Model

```dart
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
```

### 3. Create Your Repository

```dart
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
```

### 4. Create Your Controller

```dart
class UserController extends BaseListController<User> {
  final UserRepository repository;

  UserController(this.repository);

  @override
  Future<void> loadItems() async {
    setLoading(true);
    final response = await repository.getAll();
    handleResponse(response, (data) => data);
    if (response.success && response.data != null) {
      addItems(response.data!);
    }
    setLoading(false);
  }

  Future<void> createUser(User user) async {
    setLoading(true);
    final response = await repository.create(user);
    handleResponse(response, (data) => data);
    if (response.success && response.data != null) {
      items.insert(0, response.data!);
    }
    setLoading(false);
  }
}
```

### 5. Use in Your App

```dart
class UsersPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.put(UserController(
      UserRepository(
        apiService: apiService,
        cacheService: cacheService,
        syncService: syncService,
      ),
    ));

    return Scaffold(
      appBar: AppBar(title: Text('Users')),
      body: Obx(() {
        if (controller.isLoading.value) {
          return Center(child: CircularProgressIndicator());
        }
        
        if (controller.errorMessage.value.isNotEmpty) {
          return Center(child: Text(controller.errorMessage.value));
        }

        return ListView.builder(
          itemCount: controller.items.length,
          itemBuilder: (context, index) {
            final user = controller.items[index];
            return ListTile(
              title: Text(user.name),
              subtitle: Text(user.email),
            );
          },
        );
      }),
    );
  }
}
```

## Authentication

```dart
// Login
final authResponse = await authService.login(
  email: 'user@example.com',
  password: 'password',
);

if (authResponse.success) {
  // User is logged in, token is automatically saved
  print('Logged in: ${authResponse.data?.accessToken}');
}

// Check if authenticated
final isAuth = await authService.isAuthenticated();

// Logout
await authService.logout();
```

## Push Notifications

### Firebase provider

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:gems_data_layer/gems_data_layer.dart';

await Firebase.initializeApp();
final messaging = FirebaseMessaging.instance;

await setupDataLayerServices(
  apiConfig: ApiConfig(baseUrl: 'https://api.example.com'),
  pushNotificationProvider: FirebasePushNotificationProvider(
    permissionHandler: () async {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: true,
      );

      switch (settings.authorizationStatus) {
        case AuthorizationStatus.authorized:
          return NotificationPermissionStatus.granted;
        case AuthorizationStatus.denied:
          return NotificationPermissionStatus.denied;
        case AuthorizationStatus.provisional:
          return NotificationPermissionStatus.provisional;
        case AuthorizationStatus.notDetermined:
          return NotificationPermissionStatus.notDetermined;
      }
    },
    tokenHandler: () => messaging.getToken(),
    tokenRefreshStream: messaging.onTokenRefresh,
    messageStream: FirebaseMessaging.onMessage.map(
      (message) => PushMessage(
        id: message.messageId,
        title: message.notification?.title,
        body: message.notification?.body,
        data: message.data,
        source: NotificationSource.foreground,
      ),
    ),
    messageOpenedStream: FirebaseMessaging.onMessageOpenedApp.map(
      (message) => PushMessage(
        id: message.messageId,
        title: message.notification?.title,
        body: message.notification?.body,
        data: message.data,
        source: NotificationSource.openedApp,
      ),
    ),
    initialMessageHandler: () async {
      final message = await messaging.getInitialMessage();
      if (message == null) return null;
      return PushMessage(
        id: message.messageId,
        title: message.notification?.title,
        body: message.notification?.body,
        data: message.data,
        source: NotificationSource.initialMessage,
      );
    },
    subscribeHandler: messaging.subscribeToTopic,
    unsubscribeHandler: messaging.unsubscribeFromTopic,
    deleteTokenHandler: messaging.deleteToken,
  ),
);

final pushService = getIt<PushNotificationService>();

pushService.messages.listen((message) {
  print('Push message: ${message.title} / ${message.body}');
});
```

### Custom provider

```dart
import 'package:gems_data_layer/gems_data_layer.dart';

final customProvider = CustomPushNotificationProvider(
  tokenHandler: () async => 'my-custom-token',
  messageStream: myForegroundMessageStream,
  messageOpenedStream: myOpenedMessageStream,
  subscribeHandler: (topic) async {
    await myCustomNotificationSdk.subscribe(topic);
  },
);

await setupDataLayerServices(
  apiConfig: ApiConfig(baseUrl: 'https://api.example.com'),
  pushNotificationProvider: customProvider,
);
```

### PushNotificationService API

- `initialize()` - Initializes provider and token handling
- `getToken()` - Gets latest provider token and stores locally
- `getStoredToken()` - Gets last saved token from local storage
- `messages` - Unified stream for foreground/open/initial message events
- `tokenChanges` - Stream of token refresh events
- `subscribeToTopic(topic)` - Topic subscription
- `unsubscribeFromTopic(topic)` - Topic unsubscription
- `clearToken()` - Deletes provider token and local token

## Offline Support

The package automatically handles offline scenarios:

1. **Caching**: API responses are cached automatically
2. **Sync Queue**: Failed requests are queued when offline
3. **Background Sync**: Queue is synced when connection is restored
4. **Cache TTL**: Set time-to-live for cached data

```dart
// Get with cache (works offline)
final response = await repository.getAll(useCache: true);

// Create with offline sync
final response = await repository.create(
  user,
  syncOffline: true, // Adds to sync queue if offline
);
```

## API Reference

### ApiService

- `get<T>(endpoint, ...)` - GET request
- `post<T>(endpoint, ...)` - POST request
- `put<T>(endpoint, ...)` - PUT request
- `patch<T>(endpoint, ...)` - PATCH request
- `delete<T>(endpoint, ...)` - DELETE request
- `setAuthToken(token)` - Set authentication token

### AuthService

- `login({email, password})` - Login user
- `register({data})` - Register user
- `refreshToken()` - Refresh access token
- `logout()` - Logout user
- `isAuthenticated()` - Check authentication status
- `initialize()` - Initialize auth (call on app start)

### CacheService

- `save(key, data, {ttl})` - Save to cache
- `get<T>(key, fromJson)` - Get from cache
- `delete(key)` - Delete from cache
- `clear()` - Clear all cache
- `exists(key)` - Check if key exists

### SyncService

- `addToQueue(item)` - Add item to sync queue
- `syncQueue()` - Sync queued items
- `getQueue()` - Get sync queue
- `clearQueue()` - Clear sync queue
- `initialize()` - Initialize background sync

### BaseRepository

- `getAll({queryParameters, useCache, cacheTTL})` - Get all items
- `getById(id, {useCache, cacheTTL})` - Get item by ID
- `create(model, {syncOffline})` - Create item
- `update(id, model, {syncOffline})` - Update item
- `delete(id, {syncOffline})` - Delete item

### BaseController

- `setLoading(bool)` - Set loading state
- `setError(String)` - Set error message
- `setSuccess(T)` - Set success data
- `handleResponse(ApiResponse, mapper)` - Handle API response

### DatabaseService

- `initialize({boxName})` - Initialize Hive database
- `openBox(boxName)` - Open a named Hive box
- `save(key, value, {boxName})` - Save data to database
- `get<T>(key, {boxName})` - Get data from database
- `getAll({boxName})` - Get all entries as map
- `delete(key, {boxName})` - Delete data from database
- `clear({boxName})` - Clear all data in a box
- `registerAdapter<T>(adapter)` - Register Hive adapter for custom types

## Database Usage Example

```dart
// Initialize database
final databaseService = DatabaseService();
await databaseService.initialize();

// Register adapter for custom types (optional)
databaseService.registerAdapter(UserAdapter());

// Save data
await databaseService.save('user_1', user.toJson());

// Get data
final userData = databaseService.get<Map>('user_1');
final user = User.fromJson(userData!);

// Get all users
final allUsers = databaseService.getAll();
```

## License

MIT License - see LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
