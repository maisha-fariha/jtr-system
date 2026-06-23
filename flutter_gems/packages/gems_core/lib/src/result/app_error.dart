/// Base error class for application errors
abstract class AppError {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const AppError({
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppError &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          code == other.code;

  @override
  int get hashCode => message.hashCode ^ code.hashCode;
}

/// Network related errors
class NetworkError extends AppError {
  const NetworkError({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory NetworkError.fromException(dynamic exception, StackTrace? stackTrace) {
    return NetworkError(
      message: exception.toString(),
      originalError: exception,
      stackTrace: stackTrace,
    );
  }
}

/// API related errors
class ApiError extends AppError {
  final int? statusCode;
  final Map<String, dynamic>? responseData;

  const ApiError({
    required super.message,
    this.statusCode,
    this.responseData,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory ApiError.fromResponse({
    required String message,
    int? statusCode,
    Map<String, dynamic>? responseData,
  }) {
    return ApiError(
      message: message,
      statusCode: statusCode,
      responseData: responseData,
    );
  }
}

/// Validation errors
class ValidationError extends AppError {
  final Map<String, List<String>>? fieldErrors;

  const ValidationError({
    required super.message,
    this.fieldErrors,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory ValidationError.fromFields(Map<String, List<String>> fieldErrors) {
    return ValidationError(
      message: 'Validation failed',
      fieldErrors: fieldErrors,
    );
  }
}

/// Authentication errors
class AuthError extends AppError {
  const AuthError({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });
}

/// Permission errors
class PermissionError extends AppError {
  const PermissionError({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });
}

/// Storage/Database errors
class StorageError extends AppError {
  const StorageError({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });
}

/// Unknown/Generic errors
class UnknownError extends AppError {
  const UnknownError({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory UnknownError.fromException(dynamic exception, StackTrace? stackTrace) {
    return UnknownError(
      message: exception.toString(),
      originalError: exception,
      stackTrace: stackTrace,
    );
  }
}

