import 'package:gems_data_layer/gems_data_layer.dart';
import 'package:gems_core/gems_core.dart';
import 'package:get/get.dart';
import '../models/cart/cart_model.dart';
import '../models/product/product_model.dart';
import '../repositories/cart_repository.dart';

class CartController extends BaseListController<Cart> with BaseControllerMixin<Cart> {
  final CartRepository repository;
  final Rx<Cart?> currentUserCart = Rx<Cart?>(null);
  final int userId; // Default user ID, can be changed based on auth

  CartController({
    required this.repository,
    this.userId = 1, // Default to user 1
  }) {
    loadUserCart();
  }

  @override
  Future<void> loadItems() async {
    await handleListResult(() => repository.getAll());
  }

  /// Load current user's cart
  Future<void> loadUserCart() async {
    await handleResult(
      () => repository.getUserCart(userId),
      onSuccess: (cart) {
        currentUserCart.value = cart;
        // Also add to items list if not already there
        final index = items.indexWhere((c) => c.id == cart.id);
        if (index == -1) {
          items.add(cart);
        } else {
          items[index] = cart;
        }
      },
      showSuccessMessage: false,
    );
  }

  /// Get current user's cart
  Cart? get userCart => currentUserCart.value;

  /// Get total items in cart
  int get totalItems {
    if (currentUserCart.value == null) return 0;
    return currentUserCart.value!.products.fold<int>(
      0,
      (sum, product) => sum + product.quantity,
    );
  }

  /// Get product quantity in cart
  int getProductQuantity(int productId) {
    if (currentUserCart.value == null) return 0;
    final product = currentUserCart.value!.products
        .firstWhere((p) => p.productId == productId, orElse: () => const CartProduct(productId: -1, quantity: 0));
    return product.productId == -1 ? 0 : product.quantity;
  }

  /// Check if product is in cart
  bool isProductInCart(int productId) {
    return getProductQuantity(productId) > 0;
  }

  /// Add product to cart
  Future<void> addToCart(Product product, {int quantity = 1}) async {
    // If no cart exists, create one first
    if (currentUserCart.value == null) {
      final newCart = Cart(
        id: UseCaseHelper.generateId(prefix: 'cart'),
        userId: userId,
        date: DateTime.now(),
        products: [
          CartProduct(
            productId: int.parse(product.id),
            quantity: quantity,
          ),
        ],
      );

      await handleResult(
        () => repository.create(newCart),
        onSuccess: (cart) {
          currentUserCart.value = cart;
          final index = items.indexWhere((c) => c.id == cart.id);
          if (index == -1) {
            items.add(cart);
          } else {
            items[index] = cart;
          }
        },
        showSuccessMessage: true,
        successMessage: 'Product added to cart',
      );
    } else {
      await handleResult(
        () => repository.addProductToCart(
          cartId: currentUserCart.value!.id,
          productId: int.parse(product.id),
          quantity: quantity,
        ),
        onSuccess: (cart) {
          currentUserCart.value = cart;
          final index = items.indexWhere((c) => c.id == cart.id);
          if (index != -1) {
            items[index] = cart;
          }
        },
        showSuccessMessage: true,
        successMessage: 'Product added to cart',
      );
    }
  }

  /// Remove product from cart
  Future<void> removeFromCart(int productId) async {
    if (currentUserCart.value == null) return;

    await handleResult(
      () => repository.removeProductFromCart(
        cartId: currentUserCart.value!.id,
        productId: productId,
      ),
      onSuccess: (cart) {
        currentUserCart.value = cart;
        final index = items.indexWhere((c) => c.id == cart.id);
        if (index != -1) {
          items[index] = cart;
        }
      },
      showSuccessMessage: true,
      successMessage: 'Product removed from cart',
    );
  }

  /// Update product quantity in cart
  Future<void> updateQuantity(int productId, int quantity) async {
    if (currentUserCart.value == null) return;

    if (quantity <= 0) {
      await removeFromCart(productId);
      return;
    }

    await handleResult(
      () => repository.updateProductQuantity(
        cartId: currentUserCart.value!.id,
        productId: productId,
        quantity: quantity,
      ),
      onSuccess: (cart) {
        currentUserCart.value = cart;
        final index = items.indexWhere((c) => c.id == cart.id);
        if (index != -1) {
          items[index] = cart;
        }
      },
      showSuccessMessage: false,
    );
  }

  /// Clear cart
  Future<void> clearCart() async {
    if (currentUserCart.value == null) return;

    final emptyCart = currentUserCart.value!.copyWith(products: []);
    await handleResult(
      () => repository.update(currentUserCart.value!.id, emptyCart),
      onSuccess: (cart) {
        currentUserCart.value = cart;
        final index = items.indexWhere((c) => c.id == cart.id);
        if (index != -1) {
          items[index] = cart;
        }
      },
      showSuccessMessage: true,
      successMessage: 'Cart cleared',
    );
  }

  /// Calculate total price (requires product details)
  double calculateTotal(List<Product> allProducts) {
    if (currentUserCart.value == null) return 0.0;

    double total = 0.0;
    for (final cartProduct in currentUserCart.value!.products) {
      final product = allProducts.firstWhere(
        (p) => int.parse(p.id) == cartProduct.productId,
        orElse: () => Product(
          id: '-1',
          title: '',
          description: '',
          price: 0,
          category: '',
          image: '',
        ),
      );
      if (product.id != '-1') {
        total += product.price * cartProduct.quantity;
      }
    }
    return total;
  }
}
