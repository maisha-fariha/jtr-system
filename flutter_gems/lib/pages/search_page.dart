import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gems_responsive/gems_responsive.dart';
import '../controllers/search_controller.dart' as search show ProductSearchController;
import '../controllers/search_controller.dart' show SortOption;
import '../controllers/product_controller.dart';
import '../models/product/product_model.dart';
import '../utils/app_theme.dart';
import '../services/app_services.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  late search.ProductSearchController searchController;
  late ProductController productController;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    // Get controllers
    try {
      searchController = Get.find<search.ProductSearchController>();
    } catch (e) {
      searchController = Get.put(AppServices.getIt<search.ProductSearchController>(), permanent: true);
    }
    
    try {
      productController = Get.find<ProductController>();
    } catch (e) {
      productController = Get.put(AppServices.getIt<ProductController>(), permanent: true);
    }
    
    // Sync search text with controller
    _searchController.text = searchController.searchQuery.value;
    _searchController.addListener(() {
      searchController.setSearchQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search products...',
            hintStyle: TextStyle(color: AppTheme.textSecondary),
            border: InputBorder.none,
            suffixIcon: Obx(() {
              if (searchController.searchQuery.value.isNotEmpty) {
                return IconButton(
                  icon: const Icon(Icons.clear, color: AppTheme.goldPrimary),
                  onPressed: () {
                    _searchController.clear();
                    searchController.clearSearch();
                  },
                );
              }
              return const SizedBox.shrink();
            }),
          ),
        ),
        backgroundColor: AppTheme.darkSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.goldPrimary),
        actions: [
          Obx(() {
            final filterCount = searchController.activeFilterCount;
            return Stack(
              children: [
                IconButton(
                  icon: Icon(
                    _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
                    color: filterCount > 0 ? AppTheme.goldPrimary : AppTheme.textSecondary,
                  ),
                  onPressed: () {
                    setState(() {
                      _showFilters = !_showFilters;
                    });
                  },
                ),
                if (filterCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
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
                        '$filterCount',
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
            );
          }),
        ],
      ),
      body: Column(
        children: [
          // Filter Panel
          if (_showFilters) _buildFilterPanel(),
          // Search Results
          Expanded(
            child: Obx(() {
              final filteredProducts = searchController.filterAndSortProducts(productController.items);
              
              if (searchController.searchQuery.value.isEmpty && !searchController.hasActiveFilters) {
                return _buildSearchHistory();
              }
              
              if (filteredProducts.isEmpty) {
                return _buildEmptyState();
              }
              
              return _buildSearchResults(filteredProducts);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      padding: ResponsiveHelper.getResponsivePadding(context, all: 20),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.goldPrimary.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filters',
                style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, 18),
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (searchController.hasActiveFilters)
                TextButton(
                  onPressed: () => searchController.resetFilters(),
                  child: const Text(
                    'Reset',
                    style: TextStyle(color: AppTheme.goldPrimary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Category Filter
          Text(
            'Category',
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Obx(() => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: searchController.categories.map((category) {
              final isSelected = searchController.selectedCategory.value == category;
              return FilterChip(
                label: Text(category),
                selected: isSelected,
                onSelected: (selected) {
                  searchController.setCategory(category);
                },
                selectedColor: AppTheme.goldPrimary.withOpacity(0.3),
                checkmarkColor: AppTheme.goldPrimary,
                labelStyle: TextStyle(
                  color: isSelected ? AppTheme.goldPrimary : AppTheme.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          )),
          const SizedBox(height: 20),
          // Price Range Filter
          Text(
            'Price Range',
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Obx(() => Column(
            children: [
              RangeSlider(
                values: RangeValues(
                  searchController.minPrice.value,
                  searchController.maxPrice.value,
                ),
                min: searchController.priceRangeMin.value,
                max: searchController.priceRangeMax.value,
                divisions: 50,
                activeColor: AppTheme.goldPrimary,
                inactiveColor: AppTheme.goldPrimary.withOpacity(0.3),
                onChanged: (values) {
                  searchController.setPriceRange(values.start, values.end);
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '\$${searchController.minPrice.value.toStringAsFixed(0)}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  Text(
                    '\$${searchController.maxPrice.value.toStringAsFixed(0)}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ],
          )),
          const SizedBox(height: 20),
          // Rating Filter
          Text(
            'Minimum Rating',
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Obx(() => Column(
            children: [
              Slider(
                value: searchController.minRating.value,
                min: 0.0,
                max: 5.0,
                divisions: 10,
                activeColor: AppTheme.goldPrimary,
                inactiveColor: AppTheme.goldPrimary.withOpacity(0.3),
                onChanged: (value) {
                  searchController.setMinRating(value);
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '0.0',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  Text(
                    '${searchController.minRating.value.toStringAsFixed(1)} ⭐',
                    style: const TextStyle(
                      color: AppTheme.goldPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    '5.0',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ],
          )),
          const SizedBox(height: 20),
          // Sort Options
          Text(
            'Sort By',
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Obx(() => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SortOption.values.map((option) {
              final isSelected = searchController.sortOption.value == option;
              return FilterChip(
                label: Text(_getSortOptionLabel(option)),
                selected: isSelected,
                onSelected: (selected) {
                  searchController.setSortOption(option);
                },
                selectedColor: AppTheme.goldPrimary.withOpacity(0.3),
                checkmarkColor: AppTheme.goldPrimary,
                labelStyle: TextStyle(
                  color: isSelected ? AppTheme.goldPrimary : AppTheme.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          )),
        ],
      ),
    );
  }

  String _getSortOptionLabel(SortOption option) {
    switch (option) {
      case SortOption.newest:
        return 'Newest';
      case SortOption.oldest:
        return 'Oldest';
      case SortOption.priceLowToHigh:
        return 'Price: Low to High';
      case SortOption.priceHighToLow:
        return 'Price: High to Low';
      case SortOption.ratingHighToLow:
        return 'Rating: High to Low';
      case SortOption.ratingLowToHigh:
        return 'Rating: Low to High';
    }
  }

  Widget _buildSearchHistory() {
    return Obx(() {
      if (searchController.searchHistory.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search,
                size: ResponsiveHelper.getResponsiveSize(context, 64),
                color: AppTheme.goldPrimary.withOpacity(0.5),
              ),
              ResponsiveHelper.getResponsiveSpacing(context, 16),
              Text(
                'Start searching for products',
                style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, 18),
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              ResponsiveHelper.getResponsiveSpacing(context, 8),
              Text(
                'Try searching for categories or product names',
                style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        );
      }
      
      return ListView(
        padding: ResponsiveHelper.getResponsivePadding(context, all: 20),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, 18),
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () => searchController.clearHistory(),
                child: const Text(
                  'Clear',
                  style: TextStyle(color: AppTheme.goldPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...searchController.searchHistory.map((query) => ListTile(
            leading: const Icon(Icons.history, color: AppTheme.textSecondary),
            title: Text(
              query,
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 20, color: AppTheme.textSecondary),
              onPressed: () => searchController.removeFromHistory(query),
            ),
            onTap: () {
              _searchController.text = query;
              searchController.setSearchQuery(query);
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          )),
        ],
      );
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: ResponsiveHelper.getResponsiveSize(context, 80),
            color: AppTheme.goldPrimary.withOpacity(0.5),
          ),
          ResponsiveHelper.getResponsiveSpacing(context, 24),
          Text(
            'No products found',
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 24),
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          ResponsiveHelper.getResponsiveSpacing(context, 8),
          Text(
            'Try adjusting your search or filters',
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
              color: AppTheme.textSecondary,
            ),
          ),
          ResponsiveHelper.getResponsiveSpacing(context, 24),
          ElevatedButton(
            onPressed: () {
              searchController.resetFilters();
              _searchController.clear();
              searchController.clearSearch();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.goldPrimary,
              foregroundColor: AppTheme.darkBackground,
            ),
            child: const Text('Clear All Filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(List<Product> products) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Results count and sort
        Container(
          constraints: const BoxConstraints(
            maxHeight: 60,
          ),
          padding: ResponsiveHelper.getResponsivePadding(
            context,
            horizontal: 20,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            border: Border(
              bottom: BorderSide(
                color: AppTheme.goldPrimary.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      '${products.length} ${products.length == 1 ? 'product' : 'products'} found',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                        color: AppTheme.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<SortOption>(
                    padding: EdgeInsets.zero,
                    iconSize: 24,
                    icon: const Icon(
                      Icons.sort,
                      color: AppTheme.goldPrimary,
                      size: 24,
                    ),
                    onSelected: (option) => searchController.setSortOption(option),
                    itemBuilder: (context) {
                      final currentSort = searchController.sortOption.value;
                      return SortOption.values.map((option) {
                        return PopupMenuItem(
                          value: option,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (currentSort == option)
                                const Icon(Icons.check, color: AppTheme.goldPrimary, size: 20)
                              else
                                const SizedBox(width: 20),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _getSortOptionLabel(option),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList();
                    },
                  ),
                ],
              );
            },
          ),
        ),
        // Products Grid
        Expanded(
          child: GridView.builder(
            padding: ResponsiveHelper.getResponsivePadding(context, all: 20),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: ResponsiveHelper.isSmallDevice(context) ? 2 : 3,
              crossAxisSpacing: ResponsiveHelper.getResponsiveWidth(context, 16),
              mainAxisSpacing: ResponsiveHelper.getResponsiveHeight(context, 16),
              childAspectRatio: 0.65,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return AnimatedListItem(
                index: index,
                animationType: ListAnimationType.fadeSlide,
                slideDirection: ListSlideDirection.fromBottom,
                child: _ProductCard(
                  product: product,
                  onTap: () => _showProductDetails(context, product),
                ),
              );
            },
          ),
        ),
      ],
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
      decoration: const BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: ResponsiveHelper.getResponsivePadding(context, all: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.title,
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 20),
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
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
