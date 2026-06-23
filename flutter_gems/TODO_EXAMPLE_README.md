# Todo App Example using gems_data_layer

This is a complete working example demonstrating how to use the `gems_data_layer` package in a real Flutter application.

## 📁 Project Structure

```
lib/
├── main.dart                    # App entry point, initializes services
├── services/
│   └── app_services.dart        # Service initialization singleton
├── models/
│   └── todo_model.dart         # Todo model extending BaseModel
├── repositories/
│   └── todo_repository.dart     # Todo repository extending BaseRepository
├── controllers/
│   └── todo_controller.dart    # Todo controller extending BaseListController
└── pages/
    └── todo_page.dart          # Todo UI page
```

## 🚀 Features Demonstrated

- ✅ **CRUD Operations** - Create, Read, Update, Delete todos
- ✅ **GetX State Management** - Reactive UI with GetX
- ✅ **Caching** - Automatic caching with 5-minute TTL
- ✅ **Offline Support** - Works offline, syncs when online
- ✅ **Error Handling** - Comprehensive error handling
- ✅ **Loading States** - Loading indicators and error messages

## 🔧 How It Works

### 1. Service Initialization (`main.dart`)
```dart
// Services are initialized once at app start
await AppServices.instance.initialize();
```

### 2. Model (`todo_model.dart`)
- Extends `BaseModel`
- Implements `toJson()` and `fromJson()`
- Simple data class for Todo items

### 3. Repository (`todo_repository.dart`)
- Extends `BaseRepository<Todo>`
- Only needs to implement `fromJson()` and `toJson()`
- All CRUD operations are inherited

### 4. Controller (`todo_controller.dart`)
- Extends `BaseListController<Todo>`
- Implements `loadItems()` method
- Adds business logic methods (create, update, delete)

### 5. UI (`todo_page.dart`)
- Uses GetX `Obx()` for reactive UI
- Shows loading, error, and data states
- Pull-to-refresh support
- Add/Edit/Delete functionality

## 📝 Usage

### Running the App

```bash
flutter run
```

### API Endpoint

The app uses JSONPlaceholder API for demo:
- Base URL: `https://jsonplaceholder.typicode.com`
- Endpoint: `/todos`

**Note:** JSONPlaceholder is a fake REST API, so changes won't persist. For a real app, replace with your own API.

### Testing Offline Mode

1. Turn off your internet connection
2. Create a new todo - it will be queued
3. Turn internet back on
4. The todo will sync automatically (or manually refresh)

## 🎯 Key Concepts Demonstrated

### Repository Pattern
```dart
class TodoRepository extends BaseRepository<Todo> {
  // Only implement fromJson and toJson
  // All CRUD operations are inherited!
}
```

### GetX Reactive State
```dart
Obx(() {
  // UI automatically rebuilds when state changes
  if (controller.isLoading.value) {
    return CircularProgressIndicator();
  }
  return ListView(...);
})
```

### Offline Queue
```dart
// Automatically queues when offline
await repository.create(todo, syncOffline: true);
```

### Caching
```dart
// Automatic caching with TTL
await repository.getAll(
  useCache: true,
  cacheTTL: Duration(minutes: 5),
);
```

## 🔄 Data Flow

```
User Action
    ↓
Controller Method
    ↓
Repository Method
    ↓
API Service / Cache
    ↓
Update State (GetX)
    ↓
UI Rebuilds (Obx)
```

## 📦 What You Need to Change for Your API

1. **Update API Config** (`services/app_services.dart`):
   ```dart
   final apiConfig = ApiConfig(
     baseUrl: 'YOUR_API_URL',  // Change this
     enableLogging: true,
   );
   ```

2. **Update Endpoint** (`repositories/todo_repository.dart`):
   ```dart
   super(baseEndpoint: '/your-endpoint');  // Change this
   ```

3. **Update Model** (`models/todo_model.dart`):
   - Adjust fields to match your API response
   - Update `fromJson()` to parse your API format

## 🎨 Customization

- **UI**: Modify `todo_page.dart` to match your design
- **Business Logic**: Add methods to `todo_controller.dart`
- **Validation**: Add validation in controller methods
- **Error Messages**: Customize error handling in controller

## 📚 Learn More

- See `packages/gems_data_layer/ARCHITECTURE.md` for detailed architecture
- See `packages/gems_data_layer/EXAMPLE.md` for more examples
- See `packages/gems_data_layer/README.md` for full documentation

