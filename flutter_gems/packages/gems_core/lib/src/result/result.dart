import 'package:dartz/dartz.dart';
import 'app_error.dart';

/// Result type for handling success and failure cases
/// 
/// Usage:
/// ```dart
/// Result<String> fetchData() {
///   try {
///     return Result.success('Data loaded');
///   } catch (e) {
///     return Result.failure(AppError(message: e.toString()));
///   }
/// }
/// 
/// final result = fetchData();
/// result.when(
///   success: (data) => print(data),
///   failure: (error) => print(error.message),
/// );
/// ```
class Result<T> {
  final Either<AppError, T> _either;

  const Result._(this._either);

  /// Create a successful result
  factory Result.success(T value) {
    return Result._(Right(value));
  }

  /// Create a failed result
  factory Result.failure(AppError error) {
    return Result._(Left(error));
  }

  /// Check if result is successful
  bool get isSuccess => _either.isRight();

  /// Check if result is failure
  bool get isFailure => _either.isLeft();

  /// Get the value if successful, null otherwise
  T? get value => _either.fold((l) => null, (r) => r);

  /// Get the error if failed, null otherwise
  AppError? get error => _either.fold((l) => l, (r) => null);

  /// Transform the value if successful
  Result<R> map<R>(R Function(T) transform) {
    return Result._(_either.map(transform));
  }

  /// Transform the error if failed
  Result<T> mapError(AppError Function(AppError) transform) {
    return Result._(_either.leftMap(transform));
  }

  /// Execute callback based on success or failure
  R when<R>({
    required R Function(T) success,
    required R Function(AppError) failure,
  }) {
    return _either.fold(failure, success);
  }

  /// Execute callback if successful
  Result<T> onSuccess(void Function(T) callback) {
    _either.fold((_) {}, callback);
    return this;
  }

  /// Execute callback if failed
  Result<T> onFailure(void Function(AppError) callback) {
    _either.fold(callback, (_) {});
    return this;
  }

  /// Get value or throw error
  T getOrThrow() {
    return _either.fold(
      (error) => throw error,
      (value) => value,
    );
  }

  /// Get value or return default
  T getOrElse(T Function(AppError) defaultValue) {
    return _either.fold(defaultValue, (value) => value);
  }

  /// Get value or null
  T? getOrNull() {
    return _either.fold((_) => null, (value) => value);
  }
}

/// Extension methods for Future<Result<T>>
extension FutureResultExtension<T> on Future<Result<T>> {
  /// Wait for result and execute callback
  Future<R> when<R>({
    required Future<R> Function(T) success,
    required Future<R> Function(AppError) failure,
  }) async {
    final result = await this;
    return result.when(success: success, failure: failure);
  }

  /// Wait for result and execute on success
  Future<Result<T>> onSuccess(Future<void> Function(T) callback) async {
    final result = await this;
    result.onSuccess((value) async => await callback(value));
    return result;
  }

  /// Wait for result and execute on failure
  Future<Result<T>> onFailure(Future<void> Function(AppError) callback) async {
    final result = await this;
    result.onFailure((error) async => await callback(error));
    return result;
  }
}

