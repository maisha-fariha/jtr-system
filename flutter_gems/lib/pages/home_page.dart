import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gems_responsive/gems_responsive.dart';
import '../controllers/product_controller.dart';
import '../controllers/cart_controller.dart';
import '../controllers/favorites_controller.dart';
import '../models/product/product_model.dart';
import '../models/cart/cart_model.dart';
import '../utils/app_theme.dart';
import '../routes/app_pages.dart';
import '../pages/search_page.dart';
import '../services/app_services.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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

        if (controller.items.isEmpty) {
          return Center(
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
                  'No products available.\nAdd products to get started!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      16,
                    ),
                    color: AppTheme.textSecondary,
                  ),
                ),
                ResponsiveHelper.getResponsiveSpacing(context, 24),
                ElevatedButton(
                  onPressed: () => Get.toNamed(AppRoutes.products),
                  child: const Text('View All Products'),
                ),
              ],
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            // Brand Header with Overlay Effect
            SliverAppBar(
              expandedHeight: 250,
              floating: false,
              pinned: true,
              backgroundColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                title: LayoutBuilder(
                  builder: (context, constraints) {
                    // Hide tagline when collapsed
                    final isCollapsed = constraints.maxHeight < 100;
                    return Padding(
                      padding: const EdgeInsets.only(left: 24, bottom: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text(
                            'ShowProd',
                            style: TextStyle(
                              color: AppTheme.goldPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                              letterSpacing: 2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!isCollapsed)
                            Flexible(
                              child: Text(
                                'EXPERIENCE CULINARY ARTISTRY',
                                style: TextStyle(
                                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, 10),
                                  color: AppTheme.textSecondary,
                                  letterSpacing: 3,
                                  fontWeight: FontWeight.w300,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                centerTitle: false,
                titlePadding: EdgeInsets.zero,
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.darkSurface,
                            AppTheme.darkBackground,
                          ],
                        ),
                      ),
                    ),
                    // Decorative steam effects
                    Positioned(
                      top: 40,
                      left: 0,
                      right: 0,
                      child: Opacity(
                        opacity: 0.2,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            5,
                            (i) => Container(
                              width: 30,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    AppTheme.goldPrimary.withOpacity(0.1),
                                    Colors.transparent,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                Obx(() {
                  final favoritesController = Get.find<FavoritesController>();
                  final favoritesCount = favoritesController.favoritesCount;
                  return GestureDetector(
                    onTap: () => Get.toNamed(AppRoutes.favorites),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.darkSurface.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        children: [
                          const Icon(
                            Icons.favorite,
                            color: AppTheme.goldPrimary,
                            size: 24,
                          ),
                          if (favoritesCount > 0)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppTheme.error,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  favoritesCount > 9 ? '9+' : '$favoritesCount',
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                GestureDetector(
                  onTap: () {
                    // Navigate to search page - use Get.to for full-screen navigation
                    Get.to(() => const SearchPage());
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.darkSurface.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.search,
                      color: AppTheme.goldPrimary,
                    ),
                  ),
                ),
              ],
            ),
            // Featured Products - Full Screen Cards
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.75,
                child: PageView.builder(
                  itemCount: controller.items.length,
                  itemBuilder: (context, index) {
                    final product = controller.items[index];
                    return _OverlappingProductCard(
                      product: product,
                      index: index,
                      totalItems: controller.items.length,
                      onTap: () => _showProductDetails(context, product),
                    );
                  },
                ),
              ),
            ),
            // All Products Grid
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'All Products',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        letterSpacing: 1,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showAllProductsBottomSheet(context, controller),
                      child: const Text(
                        'See All',
                        style: TextStyle(color: AppTheme.goldPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: (ResponsiveHelper.isLargeDevice(context) ||
                          ResponsiveHelper.isMediumDevice(context))
                      ? 3
                      : 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.65, // Slightly reduced to give more space for content
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index >= controller.items.length) return null;
                    final product = controller.items[index];
                    return _ProductCard(
                      product: product,
                      onTap: () => _showProductDetails(context, product),
                    );
                  },
                  childCount: controller.items.length > 6 ? 6 : controller.items.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
          ],
        );
      }),
    );
  }

  void _showProductDetails(BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProductDetailSheet(product: product),
    );
  }

  void _showAllProductsBottomSheet(BuildContext context, ProductController controller) {
    final categories = controller.getCategories();
    
    AdaptiveBottomSheet.show(
      context: context,
      title: 'All Products',
      maxHeight: MediaQuery.of(context).size.height * 0.9,
      backgroundColor: AppTheme.darkSurface,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: categories.length,
        itemBuilder: (context, categoryIndex) {
          final category = categories[categoryIndex];
          final categoryProducts = controller.getProductsByCategory(category);
          
          if (categoryProducts.isEmpty) return const SizedBox.shrink();
          
          return Padding(
            padding: ResponsiveHelper.getResponsivePadding(
              context,
              bottom: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Title
                Padding(
                  padding: ResponsiveHelper.getResponsivePadding(
                    context,
                    horizontal: 20,
                    bottom: 12,
                  ),
                  child: Text(
                    category.toUpperCase(),
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 18),
                      fontWeight: FontWeight.bold,
                      color: AppTheme.goldPrimary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                // Horizontal Carousel for this category
                SizedBox(
                  height: ResponsiveHelper.getResponsiveHeight(context, 280),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: ResponsiveHelper.getResponsivePadding(
                      context,
                      horizontal: 20,
                    ),
                    itemCount: categoryProducts.length,
                    itemBuilder: (context, productIndex) {
                      final product = categoryProducts[productIndex];
                      return Container(
                        width: ResponsiveHelper.getResponsiveWidth(context, 200),
                        margin: ResponsiveHelper.getResponsiveMargin(
                          context,
                          right: 16,
                        ),
                        child: _CategoryProductCard(
                          product: product,
                          onTap: () {
                            Navigator.pop(context);
                            _showProductDetails(context, product);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OverlappingProductCard extends StatelessWidget {
  final Product product;
  final int index;
  final int totalItems;
  final VoidCallback onTap;

  const _OverlappingProductCard({
    required this.product,
    required this.index,
    required this.totalItems,
    required this.onTap,
  });

  CartController get _cartController {
    try {
      return Get.find<CartController>();
    } catch (e) {
      return Get.put(AppServices.getIt<CartController>(), permanent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Create overlapping effect
    final offset = index * 20.0;
    final scale = 1.0 - (index * 0.05).clamp(0.0, 0.2);

    return GestureDetector(
      onTap: onTap,
      child: Transform.translate(
        offset: Offset(offset, 0),
        child: Transform.scale(
          scale: scale,
          child: Container(
            margin: EdgeInsets.only(
              left: index * 30.0,
              right: (totalItems - index - 1) * 30.0,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  // Product Image
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
                  // Gradient overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.3),
                            Colors.black.withOpacity(0.7),
                          ],
                          stops: const [0.0, 0.6, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Product Info Overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(24),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            product.title,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                              letterSpacing: 1,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
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
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '\$${product.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.goldPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Obx(() {
                            final cart = _cartController.currentUserCart.value;
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
                              height: 56,
                              child: ElevatedButton(
                                onPressed: () {
                                  _cartController.addToCart(product);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isInCart
                                      ? AppTheme.success
                                      : AppTheme.goldPrimary,
                                  foregroundColor: AppTheme.darkBackground,
                                  elevation: 8,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  isInCart
                                      ? 'In Cart ($quantity)'
                                      : 'Add to Cart',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  // Favorite icon
                  Positioned(
                    right: 20,
                    top: MediaQuery.of(context).size.height * 0.2,
                    child: Obx(() {
                      final favoritesController = Get.find<FavoritesController>();
                      final isFavorite = favoritesController.isFavorite(product);
                      return GestureDetector(
                        onTap: () => favoritesController.toggleFavorite(product),
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _CategoryProductCard({
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: AppTheme.darkCard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppTheme.darkSurface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: product.image.isNotEmpty
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: Image.network(
                          product.image,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                            Icons.image_not_supported,
                            size: 48,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.image_not_supported,
                        size: 48,
                        color: AppTheme.textTertiary,
                      ),
              ),
            ),
            // Product Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.goldPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (product.rating.rate > 0)
                      Row(
                        children: [
                          const Icon(Icons.star,
                              color: AppTheme.goldPrimary, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${product.rating.rate.toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductCard({
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Product Image
              Positioned.fill(
                child: product.image.isNotEmpty
                    ? Image.network(
                        product.image,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(
                              color: AppTheme.darkCard,
                              child: const Icon(Icons.image_not_supported,
                                  size: 48, color: AppTheme.textTertiary),
                            ),
                      )
                    : Container(
                        color: AppTheme.darkCard,
                        child: const Icon(Icons.image_not_supported,
                            size: 48, color: AppTheme.textTertiary),
                      ),
              ),
              // Gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.6),
                      ],
                    ),
                  ),
                ),
              ),
              // Product Info
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 70,
                    maxHeight: 90,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppTheme.darkBackground.withOpacity(0.95),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          product.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            flex: 2,
                            child: Text(
                              product.category,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.goldPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            flex: 1,
        child: Text(
                              '\$${product.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.goldPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Add to Cart'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
