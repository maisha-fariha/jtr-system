import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gems_responsive/gems_responsive.dart';
import '../controllers/cart_controller.dart';
import '../controllers/product_controller.dart';
import '../models/cart/cart_model.dart';
import '../models/product/product_model.dart';
import '../utils/app_theme.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cartController = Get.find<CartController>();
    final productController = Get.find<ProductController>();

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: ResponsiveAppBar(
        title: Obx(() {
          final totalItems = cartController.currentUserCart.value?.products.fold<int>(
                0,
                (sum, product) => sum + product.quantity,
              ) ?? 0;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Cart',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.goldPrimary,
                ),
              ),
              if (totalItems > 0) ...[
                SizedBox(width: ResponsiveHelper.getResponsiveWidth(context, 12)),
                Container(
                  padding: ResponsiveHelper.getResponsivePadding(
                    context,
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.goldPrimary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(
                      ResponsiveHelper.getResponsiveRadius(context, 12),
                    ),
                  ),
                  child: Text(
                    '$totalItems',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
                      fontWeight: FontWeight.bold,
                      color: AppTheme.goldPrimary,
                    ),
                  ),
                ),
              ],
            ],
          );
        }),
        actions: [
          Obx(() {
            if (cartController.currentUserCart.value == null ||
                cartController.currentUserCart.value!.products.isEmpty) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: ResponsiveHelper.getResponsivePadding(context, all: 8),
              child: GemsAnimatedIcon(
                icon: Icons.delete_outline,
                animationType: AnimationType.pulse,
                onTap: () => _showClearCartDialog(context, cartController),
                duration: const Duration(milliseconds: 300),
              ),
            );
          }),
        ],
      ),
      body: Obx(() {
        if (cartController.isLoading.value && cartController.currentUserCart.value == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (index) => Padding(
                  padding: ResponsiveHelper.getResponsiveMargin(
                    context,
                    vertical: 8,
                  ),
                  child: ShimmerListItem(
                    hasAvatar: false,
                    hasSubtitle: true,
                    lines: 2,
                  ),
                ),
              ),
            ),
          );
        }

        if (cartController.currentUserCart.value == null ||
            cartController.currentUserCart.value!.products.isEmpty) {
          return Center(
            child: FadeSlideTransition(
              slideDirection: SlideDirection.fromBottom,
              duration: const Duration(milliseconds: 500),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GemsAnimatedIcon(
                    icon: Icons.shopping_cart_outlined,
                    animationType: AnimationType.pulse,
                    repeat: true,
                    size: ResponsiveHelper.getResponsiveSize(context, 80),
                    color: AppTheme.goldPrimary,
                  ),
                  ResponsiveHelper.getResponsiveSpacing(context, 24),
                  Text(
                    'Your cart is empty.\nAdd products to get started!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(
                        context,
                        16,
                      ),
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => cartController.loadUserCart(),
                color: AppTheme.goldPrimary,
                child: ListView.builder(
                  padding: ResponsiveHelper.getResponsivePadding(context, all: 16),
                  itemCount: cartController.currentUserCart.value?.products.length ?? 0,
                  itemBuilder: (context, index) {
                    final cartProduct = cartController.currentUserCart.value!.products[index];
                    return _CartItemCard(
                      cartProduct: cartProduct,
                      cartController: cartController,
                      productController: productController,
                    );
                  },
                ),
              ),
            ),
            // Total and Checkout Section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.darkSurface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Obx(() {
                      final total = cartController.currentUserCart.value != null
                          ? cartController.calculateTotal(productController.items)
                          : 0.0;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total:',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            '\$${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.goldPrimary,
                            ),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          // Handle checkout
                          Get.snackbar(
                            'Checkout',
                            'Checkout functionality coming soon!',
                            backgroundColor: AppTheme.goldPrimary,
                            colorText: AppTheme.darkBackground,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.goldPrimary,
                          foregroundColor: AppTheme.darkBackground,
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Checkout',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  void _showClearCartDialog(BuildContext context, CartController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Clear Cart',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'Are you sure you want to clear all items from your cart?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              controller.clearCart();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartProduct cartProduct;
  final CartController cartController;
  final ProductController productController;

  const _CartItemCard({
    required this.cartProduct,
    required this.cartController,
    required this.productController,
  });

  @override
  Widget build(BuildContext context) {
    // Find product details
    final product = productController.items.firstWhere(
      (p) => int.parse(p.id) == cartProduct.productId,
      orElse: () => Product(
        id: cartProduct.productId.toString(),
        title: 'Product ${cartProduct.productId}',
        description: '',
        price: 0,
        category: '',
        image: '',
      ),
    );

    return Card(
      margin: ResponsiveHelper.getResponsiveMargin(
        context,
        vertical: 8,
      ),
      color: AppTheme.darkCard,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Product Image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppTheme.darkSurface,
              ),
              child: product.image.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        product.image,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                          Icons.image_not_supported,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.image_not_supported,
                      color: AppTheme.textTertiary,
                    ),
            ),
            const SizedBox(width: 16),
            // Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.category,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.goldPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.goldPrimary,
                    ),
                  ),
                ],
              ),
            ),
            // Quantity Controls
            Column(
              children: [
                IconButton(
                  onPressed: () {
                    cartController.updateQuantity(
                      cartProduct.productId,
                      cartProduct.quantity + 1,
                    );
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppTheme.goldPrimary,
                ),
                Text(
                  '${cartProduct.quantity}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    cartController.updateQuantity(
                      cartProduct.productId,
                      cartProduct.quantity - 1,
                    );
                  },
                  icon: const Icon(Icons.remove_circle_outline),
                  color: AppTheme.goldPrimary,
                ),
                const SizedBox(height: 8),
                IconButton(
                  onPressed: () {
                    cartController.removeFromCart(cartProduct.productId);
                  },
                  icon: const Icon(Icons.delete_outline),
                  color: AppTheme.error,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
