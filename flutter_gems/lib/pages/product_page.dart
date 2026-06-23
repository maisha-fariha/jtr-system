import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gems_responsive/gems_responsive.dart';
import '../controllers/product_controller.dart';
import '../controllers/cart_controller.dart';
import '../controllers/favorites_controller.dart';
import '../models/product/product_model.dart';
import '../models/cart/cart_model.dart';
import '../utils/app_theme.dart';
import '../services/app_services.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ensure controller is available, create if not found
    ProductController controller;
    try {
      controller = Get.find<ProductController>();
    } catch (e) {
      controller = Get.put(AppServices.getIt<ProductController>(), permanent: true);
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Obx(() {
        if (controller.isLoading.value && controller.items.isEmpty) {
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

        if (controller.errorMessage.value.isNotEmpty &&
            controller.items.isEmpty) {
          return Center(
            child: FadeSlideTransition(
              slideDirection: SlideDirection.fromBottom,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GemsAnimatedIcon(
                    icon: Icons.error_outline,
                    animationType: AnimationType.pulse,
                    repeat: true,
                    color: AppTheme.error,
                    size: ResponsiveHelper.getResponsiveSize(context, 64),
                  ),
                  ResponsiveHelper.getResponsiveSpacing(context, 16),
                  Padding(
                    padding: ResponsiveHelper.getResponsivePadding(
                      context,
                      horizontal: 32,
                    ),
                    child: Text(
                      controller.errorMessage.value,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.error,
                        fontSize: ResponsiveHelper.getResponsiveFontSize(
                          context,
                          14,
                        ),
                      ),
                    ),
                  ),
                  ResponsiveHelper.getResponsiveSpacing(context, 24),
                  AnimatedButton(
                    onPressed: () => controller.refresh(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (controller.items.isEmpty) {
          return Center(
            child: FadeSlideTransition(
              slideDirection: SlideDirection.fromBottom,
              duration: const Duration(milliseconds: 500),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GemsAnimatedIcon(
                    icon: Icons.inventory_2_outlined,
                    animationType: AnimationType.pulse,
                    repeat: true,
                    size: ResponsiveHelper.getResponsiveSize(context, 80),
                    color: AppTheme.goldPrimary,
                  ),
                  ResponsiveHelper.getResponsiveSpacing(context, 24),
                  Text(
                    'No products yet.\nTap + to add one!',
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

        return Stack(
          children: [
            // Full-screen product cards with overlapping effect
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemCount: controller.items.length,
              itemBuilder: (context, index) {
                final product = controller.items[index];
                return _FullScreenProductCard(
                  product: product,
                  index: index,
                  currentIndex: _currentIndex,
                  onTap: () => _showProductDetails(context, product, controller),
                );
              },
            ),
            // Top overlay with brand and menu
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Leaf icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.darkSurface.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.eco,
                        color: AppTheme.goldPrimary,
                        size: 24,
                      ),
                    ),
                    // Menu icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.darkSurface.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.menu,
                        color: AppTheme.goldPrimary,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom overlay with product info and action button
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppTheme.darkBackground.withOpacity(0.95),
                      AppTheme.darkBackground,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_currentIndex < controller.items.length) ...[
                          Text(
                            controller.items[_currentIndex].title,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Pair with section
                          Row(
                            children: [
                              const Icon(
                                Icons.wine_bar,
                                color: AppTheme.goldPrimary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Pair with',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Add to Cart button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () {
                                if (_currentIndex < controller.items.length) {
                                  _showProductDetails(
                                    context,
                                    controller.items[_currentIndex],
                                    controller,
                                  );
                                }
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
                                'Add to Cart',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Page indicators
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                controller.items.length,
                                (index) => Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: index == _currentIndex
                                        ? AppTheme.goldPrimary
                                        : AppTheme.textTertiary.withOpacity(0.3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Favorite icon
            if (_currentIndex < controller.items.length)
              Positioned(
                right: 20,
                top: MediaQuery.of(context).size.height * 0.3,
                child: Obx(() {
                  final favoritesController = Get.find<FavoritesController>();
                  final currentProduct = controller.items[_currentIndex];
                  final isFavorite = favoritesController.isFavorite(currentProduct);
                  return GestureDetector(
                    onTap: () => favoritesController.toggleFavorite(currentProduct),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isFavorite
                            ? AppTheme.goldPrimary.withOpacity(0.2)
                            : AppTheme.goldPrimary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isFavorite
                              ? AppTheme.goldPrimary
                              : AppTheme.goldPrimary.withOpacity(0.3),
                          width: isFavorite ? 2 : 1,
                        ),
                      ),
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: AppTheme.goldPrimary,
                        size: 32,
                      ),
                    ),
                  );
                }),
              ),
          ],
        );
      }),
      floatingActionButton: PulseAnimation(
        repeat: false,
        child: FloatingActionButton(
          onPressed: () => _showAddProductDialog(context, controller),
          backgroundColor: AppTheme.goldPrimary,
          foregroundColor: AppTheme.darkBackground,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _showProductDetails(
    BuildContext context,
    Product product,
    ProductController controller,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProductDetailSheet(product: product),
    );
  }

  void _showAddProductDialog(BuildContext context, ProductController controller) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final priceController = TextEditingController();
    final categoryController = TextEditingController();
    final imageController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    AdaptiveBottomSheet.show(
      context: context,
      title: 'Add Product',
      child: ResponsiveForm(
        formKey: formKey,
        padding: EdgeInsets.zero,
        fields: [
          ResponsiveTextField(
            label: 'Title',
            hint: 'Enter product title',
            controller: titleController,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a product title';
              }
              return null;
            },
            autofocus: true,
          ),
          ResponsiveTextField(
            label: 'Description',
            hint: 'Enter product description',
            controller: descriptionController,
            maxLines: 3,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a product description';
              }
              return null;
            },
          ),
          ResponsiveTextField(
            label: 'Price',
            hint: 'Enter product price',
            controller: priceController,
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a price';
              }
              if (double.tryParse(value) == null || double.parse(value) < 0) {
                return 'Please enter a valid price';
              }
              return null;
            },
          ),
          ResponsiveTextField(
            label: 'Category',
            hint: 'Enter product category',
            controller: categoryController,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a category';
              }
              return null;
            },
          ),
          ResponsiveTextField(
            label: 'Image URL',
            hint: 'Enter product image URL',
            controller: imageController,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter an image URL';
              }
              return null;
            },
          ),
        ],
        submitButton: AnimatedButton(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              controller.createProduct(
                title: titleController.text.trim(),
                description: descriptionController.text.trim(),
                price: double.parse(priceController.text.trim()),
                category: categoryController.text.trim(),
                image: imageController.text.trim(),
              );
              Navigator.pop(context);
            }
          },
          child: const Text('Add Product'),
          padding: ResponsiveHelper.getResponsivePadding(
            context,
            horizontal: 16,
            vertical: 12,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _FullScreenProductCard extends StatelessWidget {
  final Product product;
  final int index;
  final int currentIndex;
  final VoidCallback onTap;

  const _FullScreenProductCard({
    required this.product,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final offset = (index - currentIndex).abs().toDouble();
    final scale = 1.0 - (offset * 0.1).clamp(0.0, 0.3);
    final opacity = 1.0 - (offset * 0.3).clamp(0.0, 0.7);

    return GestureDetector(
      onTap: onTap,
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity,
          child: Container(
            width: screenWidth,
            height: screenHeight,
            decoration: BoxDecoration(
              color: AppTheme.darkBackground,
            ),
            child: Stack(
              children: [
                // Product Image - Full Screen
                Positioned.fill(
                  child: product.image.isNotEmpty
                      ? Image.network(
                          product.image,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: AppTheme.darkCard,
                                child: const Center(
                                  child: Icon(
                                    Icons.image_not_supported,
                                    size: 64,
                                    color: AppTheme.textTertiary,
                                  ),
                                ),
                              ),
                        )
                      : Container(
                          color: AppTheme.darkCard,
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 64,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ),
                ),
                // Gradient overlay for text readability
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                        stops: const [0.0, 0.3, 0.7, 1.0],
                      ),
                    ),
                  ),
                ),
                // Steam effect decoration (top)
                Positioned(
                  top: 60,
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: 0.3,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        5,
                        (i) => Container(
                          width: 40,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                AppTheme.goldPrimary.withOpacity(0.1),
                                Colors.transparent,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductDetailSheet extends StatelessWidget {
  final Product product;

  const _ProductDetailSheet({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 300,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: AppTheme.darkCard,
                    ),
                    child: product.image.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              product.image,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.image_not_supported,
                                      size: 64, color: AppTheme.textTertiary),
                            ),
                          )
                        : const Icon(Icons.image_not_supported,
                            size: 64, color: AppTheme.textTertiary),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    product.title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.goldPrimary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      product.category,
                      style: const TextStyle(
                        color: AppTheme.goldPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.goldPrimary,
                        ),
                      ),
                      const Spacer(),
                      if (product.rating.rate > 0)
                        Row(
                          children: [
                            const Icon(Icons.star, color: AppTheme.goldPrimary, size: 20),
                            const SizedBox(width: 4),
                            Text(
                              '${product.rating.rate.toStringAsFixed(1)}',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (product.rating.count > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '(${product.rating.count})',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Obx(() {
                    final cartController = Get.find<CartController>();
                    final cart = cartController.currentUserCart.value;
                    final isInCart = cart != null &&
                        cart.products.any((p) => p.productId == int.parse(product.id));
                    final quantity = cart != null
                        ? cart.products
                            .firstWhere(
                              (p) => p.productId == int.parse(product.id),
                              orElse: () => const CartProduct(productId: -1, quantity: 0),
                            )
                            .quantity
                        : 0;

                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          cartController.addToCart(product);
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: isInCart
                              ? AppTheme.success
                              : AppTheme.goldPrimary,
                        ),
                        child: Text(
                          isInCart
                              ? 'In Cart ($quantity) - Add More'
                              : 'Add to Cart',
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
