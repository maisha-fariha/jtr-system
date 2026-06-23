import 'package:get/get.dart';
import '../models/product/product_model.dart';

class FavoritesController extends GetxController {
  final RxList<String> favoriteProductIds = <String>[].obs;
  
  /// Toggle favorite status for a product
  void toggleFavorite(Product product) {
    final productId = product.id;
    if (favoriteProductIds.contains(productId)) {
      favoriteProductIds.remove(productId);
    } else {
      favoriteProductIds.add(productId);
    }
  }
  
  /// Check if a product is favorited
  bool isFavorite(Product product) {
    return favoriteProductIds.contains(product.id);
  }
  
  /// Check if a product is favorited by ID
  bool isFavoriteById(String productId) {
    return favoriteProductIds.contains(productId);
  }
  
  /// Get all favorite products from the product list
  List<Product> getFavoriteProducts(List<Product> allProducts) {
    return allProducts.where((product) => favoriteProductIds.contains(product.id)).toList();
  }
  
  /// Add product to favorites
  void addToFavorites(Product product) {
    if (!favoriteProductIds.contains(product.id)) {
      favoriteProductIds.add(product.id);
    }
  }
  
  /// Remove product from favorites
  void removeFromFavorites(Product product) {
    favoriteProductIds.remove(product.id);
  }
  
  /// Clear all favorites
  void clearFavorites() {
    favoriteProductIds.clear();
  }
  
  /// Get favorites count
  int get favoritesCount => favoriteProductIds.length;
}
