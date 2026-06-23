# gems_core

Core utilities for Flutter apps - Result types, error handling, environment configuration, input validation, extensions, and helpers.

## Features

- ✅ **Result Types** - Type-safe error handling with `Result<T>`
- ✅ **Error Handling** - Comprehensive error types (Network, API, Validation, etc.)
- ✅ **Environment Configuration** - Easy environment management (dev/staging/prod)
- ✅ **Input Validation** - Reusable validation rules and form validation
- ✅ **Extensions** - Result and String extensions for common operations
- ✅ **Helpers** - UseCaseHelper, DIHelper for faster development
- ✅ **Base Classes** - BaseUseCase, ValidationMixin for use cases
- ✅ **get_it Integration** - Service locator support

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  gems_core:
    path: packages/gems_core
```

## Usage

### Result Types

```dart
import 'package:gems_core/gems_core.dart';

Result<String> fetchData() {
  try {
    return Result.success('Data loaded');
  } catch (e) {
    return Result.failure(
      UnknownError(message: e.toString()),
    );
  }
}

// Use the result
final result = fetchData();
result.when(
  success: (data) => print('Success: $data'),
  failure: (error) => print('Error: ${error.message}'),
);
```

### Environment Configuration

```dart
import 'package:gems_core/gems_core.dart';

// Initialize in main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await setupCoreServices(
    environmentMode: EnvironmentMode.development,
    config: AppConfig.development(),
  );
  
  runApp(MyApp());
}

// Use environment
final apiUrl = Environment.instance.apiBaseUrl;
final isDev = Environment.instance.isDevelopment;
```

### Input Validation

```dart
import 'package:gems_core/gems_core.dart';

// Validate single field
final emailResult = FormValidator.validateField(
  value: 'user@example.com',
  rules: [
    StringValidators.required(),
    StringValidators.email(),
  ],
);

// Validate form
final formResult = FormValidator.validateForm(
  values: {
    'email': 'user@example.com',
    'password': 'password123',
  },
  rules: {
    'email': [
      StringValidators.required(),
      StringValidators.email(),
    ],
    'password': [
      StringValidators.required(),
      StringValidators.minLength(8),
    ],
  },
);
```

## Extensions

### Result Extensions
```dart
final result = await useCase();
result.handle(
  onSuccess: (data) => print(data),
  onFailure: (error) => print(error.message),
);

// Get value or null
final value = result.getOrNull();

// Get value or default
final value = result.getOrElse(defaultValue);
```

### String Extensions
```dart
'user@example.com'.isValidEmail; // true
'https://example.com'.isValidUrl; // true
'hello world'.capitalize; // 'Hello world'
'long text'.truncate(10); // 'long text...'
'  '.isBlank; // true
```

## Helpers

### UseCaseHelper
```dart
// Validate fields easily
final validation = UseCaseHelper.validateStringField(
  title,
  fieldName: 'Title',
  minLength: 1,
  maxLength: 200,
);

// Generate unique IDs
final id = UseCaseHelper.generateId(prefix: 'todo');
```

### DIHelper
```dart
// Register repository
DIHelper.registerRepository<ITodoRepository>(
  factory: () => TodoRepository(...),
);

// Register use case
DIHelper.registerUseCase<GetTodosUseCase, ITodoRepository>(
  factory: (repo) => GetTodosUseCase(repo),
);
```

## Base Classes

### BaseUseCase & ValidationMixin
```dart
class CreateTodoUseCase with ValidationMixin {
  final ITodoRepository repository;
  CreateTodoUseCase(this.repository);
  
  Future<Result<Todo>> call({required String title}) async {
    // Use validation mixin
    final validation = validateString(
      title,
      fieldName: 'Title',
      minLength: 1,
    );
    if (validation.isFailure) return Result.failure(validation.error!);
    // ...
  }
}
```

## API Reference

### Result Types
- `Result<T>` - Generic result type
- `Result.success(T)` - Create success result
- `Result.failure(AppError)` - Create failure result

### Error Types
- `AppError` - Base error class
- `NetworkError` - Network related errors
- `ApiError` - API related errors
- `ValidationError` - Validation errors
- `AuthError` - Authentication errors
- `StorageError` - Storage/Database errors

### Validators
- `StringValidators` - String validation rules
- `NumberValidators` - Number validation rules
- `FormValidator` - Form validation utilities

### Extensions
- `ResultExtensions<T>` - Result type extensions
- `StringExtensions` - String utility extensions

### Helpers
- `UseCaseHelper` - Common use case patterns
- `DIHelper` - Dependency injection helpers

## Author

**Md. Adnan Ullah**
- Email: saadnanullah@gmail.com
- GitHub: [md-adnan-ullah](https://github.com/md-adnan-ullah)

## License

MIT License - see LICENSE file for details

