# How to Use Flutter Gems Packages in a New Project

This guide shows you how to use all Flutter Gems packages (`gems_responsive`, `gems_core`, `gems_data_layer`) in a new Flutter project.

## 📦 Available Packages

1. **gems_responsive** - Responsive UI widgets and helpers (25+ widgets)
2. **gems_core** - Core utilities (Result types, error handling, validation)
3. **gems_data_layer** - Data layer (REST API, CRUD, Auth, Cache, Offline sync)

---

## 🚀 Method 1: Local Path Dependency (Development)

Use this when developing locally or when packages are in the same repository.

### Step 1: Create New Flutter Project

```bash
flutter create my_new_app
cd my_new_app
```

### Step 2: Copy Packages Folder

Copy the entire `packages` folder from your Flutter Gems project to your new project:

```
my_new_app/
├── lib/
├── packages/          # Copy this folder
│   ├── gems_responsive/
│   ├── gems_core/
│   └── gems_data_layer/
└── pubspec.yaml
```

### Step 3: Update `pubspec.yaml`

Add all packages to your `pubspec.yaml`:

```yaml
name: my_new_app
description: A Flutter app using Flutter Gems packages

dependencies:
  flutter:
    sdk: flutter

  # Flutter Gems Packages
  gems_responsive:
    path: packages/gems_responsive
  gems_core:
    path: packages/gems_core
  gems_data_layer:
    path: packages/gems_data_layer

  # Required Dependencies
  flutter_screenutil: ^5.9.0
  get: ^4.6.6
  get_it: ^7.7.0
  shared_preferences: ^2.2.2
  connectivity_plus: ^5.0.2
  
  # For gems_data_layer
  http: ^1.2.0
  dio: ^5.4.0
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  
  # For gems_core
  dartz: ^0.10.1
  package_info_plus: ^5.0.1
  
  # Code Generation (if using Freezed)
  freezed_annotation: ^2.4.1
  json_annotation: ^4.9.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  
  # Code Generation
  build_runner: ^2.4.7
  freezed: ^2.4.7
  json_serializable: ^6.7.1
  hive_generator: ^2.0.1
```

### Step 4: Install Dependencies

```bash
flutter pub get
```

---

## 🌐 Method 2: Git Repository (Recommended)

Use this when your packages are in a Git repository (GitHub, GitLab, etc.).

### Step 1: Push Packages to Git

If not already done, push your packages to a Git repository:

```bash
# In your Flutter Gems project
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/yourusername/flutter_gems.git
git push -u origin main
```

### Step 2: Create New Project

```bash
flutter create my_new_app
cd my_new_app
```

### Step 3: Update `pubspec.yaml`

```yaml
name: my_new_app
description: A Flutter app using Flutter Gems packages

dependencies:
  flutter:
    sdk: flutter

  # Flutter Gems Packages from Git
  gems_responsive:
    git:
      url: https://github.com/yourusername/flutter_gems.git
      path: packages/gems_responsive
      ref: main  # or specific tag like v1.0.0
  
  gems_core:
    git:
      url: https://github.com/yourusername/flutter_gems.git
      path: packages/gems_core
      ref: main
  
  gems_data_layer:
    git:
      url: https://github.com/yourusername/flutter_gems.git
      path: packages/gems_data_layer
      ref: main

  # Required Dependencies (same as Method 1)
  flutter_screenutil: ^5.9.0
  get: ^4.6.6
  get_it: ^7.7.0
  # ... (all other dependencies from Method 1)
```

### Step 4: Install Dependencies

```bash
flutter pub get
```

**Note:** For private repositories, use SSH:
```yaml
gems_responsive:
  git:
    url: git@github.com:yourusername/flutter_gems.git
    path: packages/gems_responsive
    ref: main
```

---

## 📚 Method 3: Individual Git Repositories

If each package is in its own Git repository:

```yaml
dependencies:
  gems_responsive:
    git:
      url: https://github.com/yourusername/gems_responsive.git
      ref: main
  
  gems_core:
    git:
      url: https://github.com/yourusername/gems_core.git
      ref: main
  
  gems_data_layer:
    git:
      url: https://github.com/yourusername/gems_data_layer.git
      ref: main
```

---

## 📦 Method 4: pub.dev (After Publishing)

After publishing each package to pub.dev:

```yaml
dependencies:
  gems_responsive: ^1.0.0
  gems_core: ^1.0.0
  gems_data_layer: ^1.0.0
```

---

## 🎯 Complete Setup Example

### 1. Initialize ScreenUtil (Required for gems_responsive)

In your `main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gems_responsive/gems_responsive.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812), // Base design size
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'My App',
          theme: ThemeData(
            primarySwatch: Colors.blue,
          ),
          home: HomePage(),
        );
      },
    );
  }
}
```

### 2. Setup Dependency Injection (For gems_core and gems_data_layer)

Create `lib/di/app_di.dart`:

```dart
import 'package:get_it/get_it.dart';
import 'package:gems_core/gems_core.dart';
import 'package:gems_data_layer/gems_data_layer.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  // Register services
  DIHelper.registerService<ApiService>(
    factory: () => ApiService(
      baseUrl: 'https://api.example.com',
    ),
  );
  
  DIHelper.registerService<DatabaseService>(
    factory: () => DatabaseService(),
  );
  
  DIHelper.registerService<SyncService>(
    factory: () => SyncService(
      apiService: getIt<ApiService>(),
      databaseService: getIt<DatabaseService>(),
    ),
  );
  
  // Initialize Hive (for gems_data_layer)
  await Hive.initFlutter();
}
```

Update `main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'di/app_di.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDependencies(); // Initialize DI
  runApp(MyApp());
}
```

### 3. Use All Packages Together

Example `HomePage` using all packages:

```dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gems_responsive/gems_responsive.dart';
import 'package:gems_core/gems_core.dart';
import 'package:gems_data_layer/gems_data_layer.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // gems_responsive: Responsive App Bar
      appBar: ResponsiveAppBar(
        titleText: 'My App',
        actions: [
          GemsAnimatedIcon(
            icon: Icons.settings,
            animationType: AnimationType.scale,
            onTap: () {},
          ),
        ],
      ),
      
      body: Padding(
        // gems_responsive: Responsive padding
        padding: ResponsiveHelper.getResponsivePadding(context, all: 16),
        child: Column(
          children: [
            // gems_responsive: Responsive text
            ResponsiveText(
              'Welcome!',
              style: ResponsiveTextStyle.headlineLarge,
            ),
            
            ResponsiveSpacing.md(context),
            
            // gems_responsive: Responsive grid
            ResponsiveGrid(
              children: [
                Card(child: Text('Item 1')),
                Card(child: Text('Item 2')),
                Card(child: Text('Item 3')),
              ],
            ),
            
            ResponsiveSpacing.lg(context),
            
            // gems_core: Result type example
            ElevatedButton(
              onPressed: () async {
                final result = await someAsyncOperation();
                result.when(
                  success: (data) => print('Success: $data'),
                  failure: (error) => print('Error: ${error.message}'),
                );
              },
              child: Text('Test Result Type'),
            ),
          ],
        ),
      ),
    );
  }
  
  // gems_core: Example using Result type
  Future<Result<String>> someAsyncOperation() async {
    try {
      // Simulate async operation
      await Future.delayed(Duration(seconds: 1));
      return Result.success('Operation completed');
    } catch (e) {
      return Result.failure(NetworkError(message: e.toString()));
    }
  }
}
```

### 4. Create Repository (Using gems_data_layer)

Example repository:

```dart
import 'package:gems_data_layer/gems_data_layer.dart';
import 'package:gems_core/gems_core.dart';

class UserRepository extends BaseRepository<User> {
  UserRepository({
    required super.apiService,
    required super.databaseService,
    required super.syncService,
  }) : super(baseEndpoint: '/users');

  @override
  User fromJson(Map<String, dynamic> json) => User.fromJson(json);
}
```

---

## 📋 Quick Checklist

- [ ] Choose a method (Path, Git, or pub.dev)
- [ ] Add all packages to `pubspec.yaml`
- [ ] Add required dependencies
- [ ] Run `flutter pub get`
- [ ] Initialize `ScreenUtilInit` in `main.dart`
- [ ] Setup dependency injection (if using gems_core/gems_data_layer)
- [ ] Initialize Hive (if using gems_data_layer)
- [ ] Import packages and start using!

---

## 🔗 Package Dependencies

**gems_responsive** depends on:
- `flutter_screenutil`
- `get`
- `get_it`

**gems_core** depends on:
- `get_it`
- `dartz`
- `package_info_plus`
- `get`
- `gems_data_layer` (for BaseListController)

**gems_data_layer** depends on:
- `get`
- `get_it`
- `http`
- `dio`
- `connectivity_plus`
- `shared_preferences`
- `hive`
- `hive_flutter`

---

## 💡 Tips

1. **For Development:** Use Method 1 (path) for easy iteration
2. **For Production:** Use Method 2 (Git) with version tags
3. **For Public Distribution:** Publish to pub.dev (Method 4)
4. **Version Management:** Use semantic versioning and Git tags
5. **Monorepo:** Keep all packages together for easier management

---

## ❓ Troubleshooting

### Issue: Package not found
**Solution:** Check path or Git URL is correct

### Issue: Dependency conflicts
**Solution:** Ensure all packages use compatible dependency versions

### Issue: ScreenUtil not initialized
**Solution:** Wrap app with `ScreenUtilInit` in `main.dart`

### Issue: Hive not initialized
**Solution:** Call `await Hive.initFlutter()` before using gems_data_layer

---

## 📖 Additional Resources

- **gems_responsive:** See `packages/gems_responsive/README.md`
- **gems_core:** See `packages/gems_core/README.md`
- **gems_data_layer:** See `packages/gems_data_layer/README.md`

Happy coding! 🎉
