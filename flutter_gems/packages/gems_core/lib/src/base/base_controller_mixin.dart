import 'package:get/get.dart';
import 'package:gems_data_layer/gems_data_layer.dart';
import '../result/result.dart';
import '../result/app_error.dart';

/// Mixin for common controller patterns
/// Provides helper methods for handling Result types with loading states
mixin BaseControllerMixin<T> on BaseListController<T> {
  /// Handle result with loading state
  Future<void> handleResult<R>(
    Future<Result<R>> Function() action, {
    required void Function(R) onSuccess,
    void Function(AppError)? onError,
    bool showSuccessMessage = false,
    String? successMessage,
  }) async {
    setLoading(true);
    try {
      final result = await action();
      result.when(
        success: (data) {
          onSuccess(data);
          if (showSuccessMessage) {
            Get.snackbar('Success', successMessage ?? 'Operation successful');
          }
        },
        failure: (error) {
          setError(error.message);
          onError?.call(error);
          Get.snackbar('Error', error.message);
        },
      );
    } finally {
      setLoading(false);
    }
  }

  /// Handle list result
  Future<void> handleListResult(
    Future<Result<List<T>>> Function() action,
  ) async {
    await handleResult(
      action,
      onSuccess: (items) => addItems(items),
    );
  }
}

