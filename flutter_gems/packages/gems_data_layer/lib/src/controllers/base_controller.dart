import 'package:get/get.dart';
import '../utils/api_response.dart';

/// Base Controller for single item
abstract class BaseController<T> extends GetxController {
  final Rx<ApiResponse<T?>> state = ApiResponse<T?>(success: false).obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  void setLoading(bool loading) => isLoading.value = loading;
  void setError(String message) {
    errorMessage.value = message;
    state.value = ApiResponse.error(message);
  }
  void setSuccess(T data) {
    errorMessage.value = '';
    state.value = ApiResponse.success(data);
  }

  @override
  void onClose() {
    state.close();
    super.onClose();
  }
}

/// Base List Controller for lists
abstract class BaseListController<T> extends GetxController {
  final RxList<T> items = <T>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  void setLoading(bool loading) => isLoading.value = loading;
  void setError(String message) => errorMessage.value = message;
  void addItems(List<T> newItems) => items.addAll(newItems);

  Future<void> refresh() {
    items.clear();
    return loadItems();
  }

  Future<void> loadItems();

  @override
  void onClose() {
    items.close();
    super.onClose();
  }
}
