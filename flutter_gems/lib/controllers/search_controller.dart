import 'package:get/get.dart';
import '../models/product/product_model.dart';

class ProductSearchController extends GetxController {
  final RxString searchQuery = ''.obs;
  final RxList<String> searchHistory = <String>[].obs;
  final RxList<Product> filteredProducts = <Product>[].obs;
  
  // Filter states
  final RxString selectedCategory = 'All'.obs;
  final RxDouble minPrice = 0.0.obs;
  final RxDouble maxPrice = 1000.0.obs;
  final RxDouble minRating = 0.0.obs;
  
  // Sort state
  final Rx<SortOption> sortOption = SortOption.newest.obs;
  
  // Available categories
  final RxList<String> categories = <String>['All'].obs;
  
  // Price range
  final RxDouble priceRangeMin = 0.0.obs;
  final RxDouble priceRangeMax = 1000.0.obs;
  
  @override
  void onInit() {
    super.onInit();
    // Load search history from storage (can be implemented later)
    _loadSearchHistory();
  }
  
  void _loadSearchHistory() {
    // TODO: Load from local storage
    searchHistory.value = [];
  }
  
  void _saveSearchHistory() {
    // TODO: Save to local storage
  }
  
  /// Set search query and filter products
  void setSearchQuery(String query) {
    searchQuery.value = query.trim();
    if (query.isNotEmpty && !searchHistory.contains(query)) {
      searchHistory.insert(0, query);
      if (searchHistory.length > 10) {
        searchHistory.removeLast();
      }
      _saveSearchHistory();
    }
  }
  
  /// Clear search query
  void clearSearch() {
    searchQuery.value = '';
  }
  
  /// Remove item from search history
  void removeFromHistory(String query) {
    searchHistory.remove(query);
    _saveSearchHistory();
  }
  
  /// Clear all search history
  void clearHistory() {
    searchHistory.clear();
    _saveSearchHistory();
  }
  
  /// Set selected category filter
  void setCategory(String category) {
    selectedCategory.value = category;
  }
  
  /// Set price range filter
  void setPriceRange(double min, double max) {
    minPrice.value = min;
    maxPrice.value = max;
  }
  
  /// Set minimum rating filter
  void setMinRating(double rating) {
    minRating.value = rating;
  }
  
  /// Set sort option
  void setSortOption(SortOption option) {
    sortOption.value = option;
  }
  
  /// Reset all filters
  void resetFilters() {
    selectedCategory.value = 'All';
    minPrice.value = priceRangeMin.value;
    maxPrice.value = priceRangeMax.value;
    minRating.value = 0.0;
    sortOption.value = SortOption.newest;
  }
  
  /// Filter and sort products
  List<Product> filterAndSortProducts(List<Product> allProducts) {
    // Update available categories
    final availableCategories = allProducts.map((p) => p.category).toSet().toList();
    categories.value = ['All', ...availableCategories];
    
    // Update price range
    if (allProducts.isNotEmpty) {
      final prices = allProducts.map((p) => p.price).toList();
      priceRangeMin.value = prices.reduce((a, b) => a < b ? a : b);
      priceRangeMax.value = prices.reduce((a, b) => a > b ? a : b);
      
      // Reset filters if needed
      if (minPrice.value < priceRangeMin.value) minPrice.value = priceRangeMin.value;
      if (maxPrice.value > priceRangeMax.value) maxPrice.value = priceRangeMax.value;
    }
    
    List<Product> filtered = allProducts;
    
    // Apply search query
    if (searchQuery.value.isNotEmpty) {
      filtered = filtered.where((product) {
        final query = searchQuery.value.toLowerCase();
        return product.title.toLowerCase().contains(query) ||
               product.description.toLowerCase().contains(query) ||
               product.category.toLowerCase().contains(query);
      }).toList();
    }
    
    // Apply category filter
    if (selectedCategory.value != 'All') {
      filtered = filtered.where((product) {
        return product.category.toLowerCase() == selectedCategory.value.toLowerCase();
      }).toList();
    }
    
    // Apply price range filter
    filtered = filtered.where((product) {
      return product.price >= minPrice.value && product.price <= maxPrice.value;
    }).toList();
    
    // Apply rating filter
    if (minRating.value > 0) {
      filtered = filtered.where((product) {
        return product.rating.rate >= minRating.value;
      }).toList();
    }
    
    // Apply sorting
    switch (sortOption.value) {
      case SortOption.priceLowToHigh:
        filtered.sort((a, b) => a.price.compareTo(b.price));
        break;
      case SortOption.priceHighToLow:
        filtered.sort((a, b) => b.price.compareTo(a.price));
        break;
      case SortOption.ratingHighToLow:
        filtered.sort((a, b) => b.rating.rate.compareTo(a.rating.rate));
        break;
      case SortOption.ratingLowToHigh:
        filtered.sort((a, b) => a.rating.rate.compareTo(b.rating.rate));
        break;
      case SortOption.newest:
        // Assuming higher ID means newer (adjust based on your data)
        filtered.sort((a, b) => int.parse(b.id).compareTo(int.parse(a.id)));
        break;
      case SortOption.oldest:
        filtered.sort((a, b) => int.parse(a.id).compareTo(int.parse(b.id)));
        break;
    }
    
    filteredProducts.value = filtered;
    return filtered;
  }
  
  /// Get active filter count
  int get activeFilterCount {
    int count = 0;
    if (selectedCategory.value != 'All') count++;
    if (minPrice.value > priceRangeMin.value || maxPrice.value < priceRangeMax.value) count++;
    if (minRating.value > 0) count++;
    return count;
  }
  
  /// Check if any filters are active
  bool get hasActiveFilters => activeFilterCount > 0;
}

enum SortOption {
  newest,
  oldest,
  priceLowToHigh,
  priceHighToLow,
  ratingHighToLow,
  ratingLowToHigh,
}
