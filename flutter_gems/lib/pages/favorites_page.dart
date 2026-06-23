import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gems_responsive/gems_responsive.dart';
import '../controllers/favorites_controller.dart';
import '../controllers/product_controller.dart';
import '../models/product/product_model.dart';
import '../utils/app_theme.dart';
import '../services/app_services.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Ensure controllers are available
    ProductController productController;
    FavoritesController favoritesController;
    
    try {
      productController = Get.find<ProductController>();
    } catch (e) {
      productController = Get.put(AppServices.getIt<ProductController>(), permanent: true);
    }
    
    try {
      favoritesController = Get.find<FavoritesController>();
    } catch (e) {
      favoritesController = Get.put(AppServices.getIt<FavoritesController>(), permanent: true);
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Obx(() {
          final count = favoritesController.favoritesCount;
          return Text(
            'Favorites${count > 0 ? ' ($count)' : ''}',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          );
        }),
        backgroundColor: AppTheme.darkSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.goldPrimary),
      ),
      body: Obx(() {
        final favoriteProducts = favoritesController.getFavoriteProducts(productController.items);
        
        if (favoriteProducts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.favorite_border,
                  size: ResponsiveHelper.getResponsiveSize(context, 80),
                  color: AppTheme.goldPrimary.withOpacity(0.5),
                ),
                ResponsiveHelper.getResponsiveSpacing(context, 24),
                Text(
                  'No Favorites Yet',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, 24),
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                ResponsiveHelper.getResponsiveSpacing(context, 8),
                Text(
                  'Start adding products to your favorites',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: ResponsiveHelper.getResponsivePadding(
                context,
                all: 20,
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: ResponsiveHelper.isSmallDevice(context) ? 2 : 3,
                  crossAxisSpacing: ResponsiveHelper.getResponsiveWidth(context, 16),
                  mainAxisSpacing: ResponsiveHelper.getResponsiveHeight(context, 16),
                  childAspectRatio: 0.65,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final product = favoriteProducts[index];
                    return AnimatedListItem(
                      index: index,
                      animationType: ListAnimationType.fadeSlide,
                      slideDirection: ListSlideDirection.fromBottom,
                      child: _FavoriteProductCard(
                        product: product,
                        onTap: () => _showProductDetails(context, product, productController),
                      ),
                    );
                  },
                  childCount: favoriteProducts.length,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  void _showProductDetails(BuildContext context, Product product, ProductController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProductDetailSheet(product: product),
    );
  }
}

class _FavoriteProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _FavoriteProductCard({
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
              // Favorite badge
              Positioned(
                top: 12,
                right: 12,
                child: Obx(() {
                  final favoritesController = Get.find<FavoritesController>();
                  final isFavorite = favoritesController.isFavorite(product);
                  return GestureDetector(
                    onTap: () => favoritesController.toggleFavorite(product),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isFavorite
                            ? AppTheme.goldPrimary
                            : Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? AppTheme.darkBackground : AppTheme.goldPrimary,
                        size: 20,
                      ),
                    ),
                  );
                }),
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
      decoration: const BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: ResponsiveHelper.getResponsivePadding(context, all: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  product.title,
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, 20),
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Obx(() {
                final favoritesController = Get.find<FavoritesController>();
                final isFavorite = favoritesController.isFavorite(product);
                return IconButton(
                  onPressed: () => favoritesController.toggleFavorite(product),
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? AppTheme.goldPrimary : AppTheme.textSecondary,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            product.description,
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '\$${product.price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, 24),
                  fontWeight: FontWeight.bold,
                  color: AppTheme.goldPrimary,
                ),
              ),
              if (product.rating.rate > 0)
                Row(
                  children: [
                    const Icon(Icons.star, color: AppTheme.goldPrimary, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '${product.rating.rate.toStringAsFixed(1)} (${product.rating.count})',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
