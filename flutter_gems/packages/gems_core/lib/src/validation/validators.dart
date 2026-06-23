import '../result/app_error.dart';
import '../result/result.dart';

/// Base validator interface
abstract class Validator<T> {
  Result<T> validate(T value);
}

/// Validation rule
class ValidationRule<T> {
  final String? Function(T)? validator;
  final String errorMessage;

  const ValidationRule({
    this.validator,
    required this.errorMessage,
  });

  bool isValid(T value) {
    if (validator == null) return true;
    try {
      return validator!(value) == null;
    } catch (_) {
      return false;
    }
  }

  String? validate(T value) {
    if (validator == null) return null;
    try {
      return validator!(value);
    } catch (e) {
      return errorMessage;
    }
  }
}

/// String validators
class StringValidators {
  /// Required field validator
  static ValidationRule<String> required({String? message}) {
    return ValidationRule<String>(
      validator: (value) {
        if (value.trim().isEmpty) {
          return message ?? 'This field is required';
        }
        return null as String?;
      },
      errorMessage: message ?? 'This field is required',
    );
  }

  /// Minimum length validator
  static ValidationRule<String> minLength(int min, {String? message}) {
    return ValidationRule<String>(
      validator: (value) {
        if (value.length < min) {
          return message ?? 'Must be at least $min characters';
        }
        return null as String?;
      },
      errorMessage: message ?? 'Must be at least $min characters',
    );
  }

  /// Maximum length validator
  static ValidationRule<String> maxLength(int max, {String? message}) {
    return ValidationRule<String>(
      validator: (value) {
        if (value.length > max) {
          return message ?? 'Must be at most $max characters';
        }
        return null as String?;
      },
      errorMessage: message ?? 'Must be at most $max characters',
    );
  }

  /// Email validator
  static ValidationRule<String> email({String? message}) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return ValidationRule<String>(
      validator: (value) {
        if (!emailRegex.hasMatch(value)) {
          return message ?? 'Invalid email format';
        }
        return null as String?;
      },
      errorMessage: message ?? 'Invalid email format',
    );
  }

  /// URL validator
  static ValidationRule<String> url({String? message}) {
    return ValidationRule<String>(
      validator: (value) {
        try {
          Uri.parse(value);
          return null as String?;
        } catch (_) {
          return message ?? 'Invalid URL format';
        }
      },
      errorMessage: message ?? 'Invalid URL format',
    );
  }

  /// Phone number validator (basic)
  static ValidationRule<String> phone({String? message}) {
    final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]+$');
    return ValidationRule<String>(
      validator: (value) {
        if (!phoneRegex.hasMatch(value) || value.replaceAll(RegExp(r'[\s\-\(\)]'), '').length < 10) {
          return message ?? 'Invalid phone number';
        }
        return null as String?;
      },
      errorMessage: message ?? 'Invalid phone number',
    );
  }

  /// Pattern validator
  static ValidationRule<String> pattern(RegExp pattern, {String? message}) {
    return ValidationRule<String>(
      validator: (value) {
        if (!pattern.hasMatch(value)) {
          return message ?? 'Invalid format';
        }
        return null as String?;
      },
      errorMessage: message ?? 'Invalid format',
    );
  }
}

/// Number validators
class NumberValidators {
  /// Required number validator
  static ValidationRule<num> required({String? message}) {
    return ValidationRule<num>(
      validator: (value) {
        // num is non-nullable, so this check is always false
        // But kept for API consistency
        return null as String?;
      },
      errorMessage: message ?? 'This field is required',
    );
  }

  /// Minimum value validator
  static ValidationRule<num> min(num min, {String? message}) {
    return ValidationRule<num>(
      validator: (value) {
        if (value < min) {
          return message ?? 'Must be at least $min';
        }
        return null as String?;
      },
      errorMessage: message ?? 'Must be at least $min',
    );
  }

  /// Maximum value validator
  static ValidationRule<num> max(num max, {String? message}) {
    return ValidationRule<num>(
      validator: (value) {
        if (value > max) {
          return message ?? 'Must be at most $max';
        }
        return null as String?;
      },
      errorMessage: message ?? 'Must be at most $max',
    );
  }

  /// Range validator
  static ValidationRule<num> range(num min, num max, {String? message}) {
    return ValidationRule<num>(
      validator: (value) {
        if (value < min || value > max) {
          return message ?? 'Must be between $min and $max';
        }
        return null as String?;
      },
      errorMessage: message ?? 'Must be between $min and $max',
    );
  }
}

/// Form validator
class FormValidator {
  /// Validate a single field with multiple rules
  static Result<T> validateField<T>({
    required T value,
    required List<ValidationRule<T>> rules,
  }) {
    final errors = <String>[];

    for (final rule in rules) {
      final error = rule.validate(value);
      if (error != null) {
        errors.add(error);
      }
    }

    if (errors.isNotEmpty) {
      return Result.failure(
        ValidationError(message: errors.first, fieldErrors: {'field': errors}),
      );
    }

    return Result.success(value);
  }

  /// Validate multiple fields
  static Result<Map<String, dynamic>> validateForm({
    required Map<String, dynamic> values,
    required Map<String, List<ValidationRule>> rules,
  }) {
    final fieldErrors = <String, List<String>>{};

    for (final entry in rules.entries) {
      final fieldName = entry.key;
      final fieldRules = entry.value;
      final fieldValue = values[fieldName];

      if (fieldValue == null) {
        fieldErrors[fieldName] = ['This field is required'];
        continue;
      }

      for (final rule in fieldRules) {
        final error = rule.validate(fieldValue);
        if (error != null) {
          fieldErrors.putIfAbsent(fieldName, () => []).add(error);
        }
      }
    }

    if (fieldErrors.isNotEmpty) {
      return Result.failure(
        ValidationError.fromFields(fieldErrors),
      );
    }

    return Result.success(values);
  }
}

