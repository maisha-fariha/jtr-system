import 'package:gems_core/gems_core.dart';

/// Extensions for Result type to make it easier to use
/// Note: GetX snackbar functionality is optional - use handle() method
extension ResultExtensions<T> on Result<T> {
  /// Execute callback on success or failure
  void handle({
    required void Function(T) onSuccess,
    required void Function(AppError) onFailure,
  }) {
    when(
      success: onSuccess,
      failure: onFailure,
    );
  }

  /// Get value or return null on failure
  T? getOrNull() {
    return when(
      success: (data) => data,
      failure: (_) => null,
    );
  }

  /// Get value or throw error
  T getOrThrow() {
    return when(
      success: (data) => data,
      failure: (error) => throw error,
    );
  }

  /// Get value or return default
  T getOrElse(T defaultValue) {
    return when(
      success: (data) => data,
      failure: (_) => defaultValue,
    );
  }
}

/// Extension for Future<Result<T>>
extension FutureResultExtensions<T> on Future<Result<T>> {
  /// Execute callback on success or failure
  Future<void> handle({
    required void Function(T) onSuccess,
    required void Function(AppError) onFailure,
  }) async {
    final result = await this;
    result.handle(onSuccess: onSuccess, onFailure: onFailure);
  }

  /// Get value or return null on failure
  Future<T?> getOrNull() async {
    final result = await this;
    return result.getOrNull();
  }
}

