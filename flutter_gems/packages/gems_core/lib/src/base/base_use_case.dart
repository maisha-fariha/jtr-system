import '../result/result.dart';
import '../helpers/use_case_helper.dart';

/// Base use case with common patterns
abstract class BaseUseCase<Params, ResultType> {
  Future<Result<ResultType>> call(Params params);
}

/// Use case without parameters
abstract class SimpleUseCase<ResultType> {
  Future<Result<ResultType>> call();
}

/// Use case with validation helper
mixin ValidationMixin {
  /// Validate string field
  Result<String> validateString(
    String value, {
    String fieldName = 'Field',
    int? minLength,
    int? maxLength,
    bool required = true,
  }) {
    return UseCaseHelper.validateStringField(
      value,
      fieldName: fieldName,
      minLength: minLength,
      maxLength: maxLength,
      required: required,
    );
  }
}

