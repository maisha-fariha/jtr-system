import 'package:get/get.dart';
import '../data/demo_menu.dart';
import '../models/menu_item.dart';
import '../models/order_product.dart';

class OrderMenuController extends GetxController {
  final categories = <MenuCategory>[].obs;
  final menuItems = <MenuItem>[].obs;
  final cartItems = <OrderProduct>[].obs;
  final selectedCategoryId = ''.obs;

  int tableNumber = 0;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>?;
    tableNumber = args?['tableNumber'] as int? ?? 0;
    categories.assignAll(demoCategories);
    menuItems.assignAll(demoMenuItems);
    if (categories.isNotEmpty) {
      selectedCategoryId.value = categories.first.id;
    }
  }

  List<MenuItem> get filteredItems => menuItems
      .where((item) => item.categoryId == selectedCategoryId.value)
      .toList();

  void selectCategory(String id) => selectedCategoryId.value = id;

  void addToCart(MenuItem item) {
    final index = cartItems.indexWhere((c) => c.id == item.id);
    if (index >= 0) {
      cartItems[index] = cartItems[index]
          .copyWith(quantity: cartItems[index].quantity + 1);
    } else {
      cartItems.add(OrderProduct(
        id: item.id,
        name: item.name,
        unitPrice: item.price,
      ));
    }
  }

  void removeFromCart(String itemId) {
    final index = cartItems.indexWhere((c) => c.id == itemId);
    if (index < 0) return;
    final item = cartItems[index];
    if (item.quantity <= 1) {
      cartItems.removeAt(index);
    } else {
      cartItems[index] = item.copyWith(quantity: item.quantity - 1);
    }
  }

  void clearCart() => cartItems.clear();

  int quantityInCart(String itemId) {
    final index = cartItems.indexWhere((c) => c.id == itemId);
    return index >= 0 ? cartItems[index].quantity : 0;
  }

  double get cartTotal =>
      cartItems.fold(0, (sum, item) => sum + item.totalPrice);

  int get cartItemCount =>
      cartItems.fold(0, (sum, item) => sum + item.quantity);

  void confirmOrder() {
    // In a real app this would POST to the API
    cartItems.clear();
    Get.back();
    Get.snackbar(
      'Commande envoyée',
      'Table $tableNumber — commande transmise en cuisine.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}
