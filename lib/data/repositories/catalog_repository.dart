import '../../core/network/api_exception.dart';
import '../../services/connectivity_service.dart';
import '../datasources/catalog_local_datasource.dart';
import '../datasources/catalog_remote_datasource.dart';
import '../models/catalog/catalog_product_model.dart';
import '../models/catalog/category_tree_node.dart';
import '../models/catalog/leaf_category_model.dart';

class CatalogRepository {
  CatalogRepository({
    required CatalogRemoteDataSource remote,
    required CatalogLocalDataSource local,
    required ConnectivityService connectivity,
  })  : _remote = remote,
        _local = local,
        _connectivity = connectivity;

  final CatalogRemoteDataSource _remote;
  final CatalogLocalDataSource _local;
  final ConnectivityService _connectivity;

  Future<List<LeafCategoryModel>> getLeafCategories({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _local.readLeafCategories();
      if (cached != null && cached.isNotEmpty) {
        _refreshLeafCategoriesInBackground();
        return cached;
      }
    }

    if (!await _connectivity.isOnline) {
      final cached = _local.readLeafCategories();
      if (cached != null && cached.isNotEmpty) return cached;
      throw ApiException(
        message: 'Catégories indisponibles hors ligne.',
      );
    }

    final categories = await _remote.fetchLeafCategories();
    await _local.saveLeafCategories(categories);
    return categories;
  }

  Future<List<CategoryTreeNode>> getCategoryTree({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cachedLeaves = _local.readLeafCategories();
      if (cachedLeaves != null && cachedLeaves.isNotEmpty) {
        final cachedTree = CategoryTreeNode.fromLeafCategories(cachedLeaves);
        if (cachedTree.isNotEmpty) {
          _refreshCategoryTreeInBackground();
          return cachedTree;
        }
      }
    }

    if (!await _connectivity.isOnline) {
      final cachedLeaves = _local.readLeafCategories();
      if (cachedLeaves != null && cachedLeaves.isNotEmpty) {
        return CategoryTreeNode.fromLeafCategories(cachedLeaves);
      }
      throw ApiException(
        message: 'Catégories indisponibles hors ligne.',
      );
    }

    try {
      return await _remote.fetchCategoryTree();
    } on ApiException {
      final leaves = await getLeafCategories(forceRefresh: forceRefresh);
      return CategoryTreeNode.fromLeafCategories(leaves);
    }
  }

  Future<void> _refreshCategoryTreeInBackground() async {
    try {
      if (!await _connectivity.isOnline) return;
      await _remote.fetchCategoryTree();
    } catch (_) {}
  }

  Future<void> _refreshLeafCategoriesInBackground() async {
    try {
      if (!await _connectivity.isOnline) return;
      final categories = await _remote.fetchLeafCategories();
      await _local.saveLeafCategories(categories);
    } catch (_) {}
  }

  Future<List<CatalogProductModel>> getProducts({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _local.readProducts();
      if (cached != null && cached.isNotEmpty) {
        _refreshProductsInBackground();
        return cached;
      }
    }

    if (!await _connectivity.isOnline) {
      final cached = _local.readProducts();
      if (cached != null && cached.isNotEmpty) return cached;
      throw ApiException(
        message: 'Produits indisponibles hors ligne.',
      );
    }

    final products = await _remote.fetchAllProducts();
    await _local.saveProducts(products);
    return products;
  }

  Future<void> _refreshProductsInBackground() async {
    try {
      if (!await _connectivity.isOnline) return;
      final products = await _remote.fetchAllProducts();
      await _local.saveProducts(products);
    } catch (_) {}
  }

  Future<CatalogProductModel> getProductDetail(
    int productId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _local.readProducts();
      final match = cached?.where((p) => p.id == productId).firstOrNull;
      if (match != null && match.menuCategories.isNotEmpty) {
        _refreshProductDetailInBackground(productId);
        return match;
      }
    }

    if (!await _connectivity.isOnline) {
      final cached = _local.readProducts();
      final match = cached?.where((p) => p.id == productId).firstOrNull;
      if (match != null) return match;
      throw ApiException(
        message: 'Produit indisponible hors ligne.',
      );
    }

    final product = await _remote.fetchProductDetail(productId);
    await _mergeProductIntoCache(product);
    return product;
  }

  Future<void> _refreshProductDetailInBackground(int productId) async {
    try {
      if (!await _connectivity.isOnline) return;
      final product = await _remote.fetchProductDetail(productId);
      await _mergeProductIntoCache(product);
    } catch (_) {}
  }

  Future<void> _mergeProductIntoCache(CatalogProductModel product) async {
    final cached = _local.readProducts() ?? <CatalogProductModel>[];
    final updated = [
      product,
      ...cached.where((item) => item.id != product.id),
    ];
    await _local.saveProducts(updated);
  }

  List<CatalogProductModel> productsForCategory(
    List<CatalogProductModel> products,
    int categoryId,
  ) {
    return products
        .where((product) => product.categoryId == categoryId)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// First simple (non-composed) product — used only to satisfy API create
  /// validation, then cancelled/stripped so the new order stays empty in UI.
  /// Prefers the cheapest active simple product (often a placeholder SKU).
  Future<CatalogProductModel?> resolveSeedProductForEmptyOrder() async {
    try {
      final products = await getProducts();
      CatalogProductModel? best;
      for (final product in products) {
        if (!product.isActive || product.isComposed) continue;
        if (product.id <= 0) continue;
        if (best == null || product.unitPrice < best.unitPrice) {
          best = product;
        }
      }
      return best;
    } catch (_) {}
    return null;
  }
}
