# gems_core - Usage Examples

## Result Types

```dart
import 'package:gems_core/gems_core.dart';

// Example: API call with Result
Future<Result<List<Todo>>> fetchTodos() async {
  try {
    final response = await apiService.get('/todos');
    final todos = (response.data as List)
        .map((json) => Todo.fromJson(json))
        .toList();
    return Result.success(todos);
  } on NetworkError catch (e) {
    return Result.failure(
      NetworkError(message: 'Failed to fetch todos', originalError: e),
    );
  } catch (e, stackTrace) {
    return Result.failure(
      UnknownError(message: e.toString(), stackTrace: stackTrace),
    );
  }
}

// Using the result
final result = await fetchTodos();
result.when(
  success: (todos) {
    print('Loaded ${todos.length} todos');
    // Update UI
  },
  failure: (error) {
    print('Error: ${error.message}');
    // Show error message
  },
);
```

## Environment Configuration

```dart
import 'package:gems_core/gems_core.dart';

// In main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize environment
  await setupCoreServices(
    environmentMode: EnvironmentMode.development, // or .staging, .production
    config: AppConfig(
      apiBaseUrl: 'https://api.example.com',
      enableLogging: true,
      apiTimeout: Duration(seconds: 30),
    ),
  );
  
  runApp(MyApp());
}

// Use environment anywhere
final apiUrl = Environment.instance.apiBaseUrl;
final isDev = Environment.instance.isDevelopment;
final appVersion = Environment.instance.appVersion;
```

## Input Validation

```dart
import 'package:gems_core/gems_core.dart';

// Validate email
final emailResult = FormValidator.validateField(
  value: emailController.text,
  rules: [
    StringValidators.required(message: 'Email is required'),
    StringValidators.email(message: 'Invalid email format'),
  ],
);

emailResult.when(
  success: (email) {
    // Email is valid
    print('Valid email: $email');
  },
  failure: (error) {
    if (error is ValidationError) {
      print('Validation error: ${error.message}');
    }
  },
);

// Validate form
final formResult = FormValidator.validateForm(
  values: {
    'email': emailController.text,
    'password': passwordController.text,
    'age': int.parse(ageController.text),
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
    'age': [
      NumberValidators.required(),
      NumberValidators.range(18, 100),
    ],
  },
);

formResult.when(
  success: (values) {
    // Form is valid, proceed
    print('Form valid: $values');
  },
  failure: (error) {
    if (error is ValidationError && error.fieldErrors != null) {
      // Show field-specific errors
      error.fieldErrors!.forEach((field, errors) {
        print('$field: ${errors.join(", ")}');
      });
    }
  },
);
```

## Integration with gems_data_layer

```dart
import 'package:gems_core/gems_core.dart';
import 'package:gems_data_layer/gems_data_layer.dart';

// Use Result in repository
class TodoRepository extends BaseRepository<Todo> {
  @override
  Future<Result<List<Todo>>> getAll() async {
    try {
      final response = await apiService.get('/todos');
      if (response.success && response.data != null) {
        final todos = (response.data as List)
            .map((json) => fromJson(json))
            .toList();
        return Result.success(todos);
      } else {
        return Result.failure(
          ApiError(message: response.message ?? 'Failed to load todos'),
        );
      }
    } catch (e, stackTrace) {
      return Result.failure(
        NetworkError.fromException(e, stackTrace),
      );
    }
  }
}
```

