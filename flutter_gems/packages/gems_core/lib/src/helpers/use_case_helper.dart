import '../result/result.dart';
import '../result/app_error.dart';
import '../validation/validators.dart';

/// Helper class for common use case patterns
class UseCaseHelper {
  /// Validate string field
  static Result<String> validateStringField(
    String value, {
    String fieldName = 'Field',
    int? minLength,
    int? maxLength,
    bool required = true,
  }) {
    final rules = <ValidationRule<String>>[];

    if (required) {
      rules.add(StringValidators.required(message: '$fieldName is required'));
    }

    if (minLength != null) {
      rules.add(StringValidators.minLength(
        minLength,
        message: '$fieldName must be at least $minLength characters',
      ));
    }

    if (maxLength != null) {
      rules.add(StringValidators.maxLength(
        maxLength,
        message: '$fieldName must be at most $maxLength characters',
      ));
    }

    return FormValidator.validateField(value: value, rules: rules);
  }

  /// Generate unique ID
  static String generateId({String? prefix}) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return prefix != null ? '${prefix}_$timestamp$random' : '$timestamp$random';
  }

  /// Handle repository result with common error handling
  static Result<T> handleRepositoryResult<T>({
    required bool success,
    T? data,
    String? message,
    String defaultError = 'Operation failed',
  }) {
    if (success && data != null) {
      return Result.success(data);
    }
    return Result.failure(ApiError(message: message ?? defaultError));
  }
}

