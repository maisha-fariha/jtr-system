import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import '../models/api_envelope.dart';
import '../models/catalog/catalog_product_model.dart';
import '../models/catalog/category_tree_node.dart';
import '../models/catalog/leaf_category_model.dart';

class CatalogRemoteDataSource {
  CatalogRemoteDataSource(this._client);

  final ApiClient _client;

  Future<List<LeafCategoryModel>> fetchLeafCategories() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.categoriesLeafOnly,
    );
    final envelope = ApiEnvelope<List<dynamic>>.fromJson(
      response.data!,
      (json) => json is List ? json : const [],
    );

    if (!envelope.success || envelope.data == null) {
      throw ApiException(
        message: envelope.message ?? 'Impossible de charger les catégories.',
        statusCode: envelope.status,
      );
    }

    return envelope.data!
        .whereType<Map<String, dynamic>>()
        .map(LeafCategoryModel.fromJson)
        .where((category) => category.isActive)
        .toList();
  }

  Future<List<CategoryTreeNode>> fetchCategoryTree() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.categoriesTree,
    );
    final envelope = ApiEnvelope<dynamic>.fromJson(
      response.data!,
      (json) => json,
    );

    if (!envelope.success) {
      throw ApiException(
        message: envelope.message ?? 'Impossible de charger les catégories.',
        statusCode: envelope.status,
      );
    }

    final nodes = parseCategoryTreeResponse(envelope.data);
    if (nodes.isEmpty) {
      throw ApiException(
        message: 'Arborescence des catégories vide.',
        statusCode: envelope.status,
      );
    }

    return nodes;
  }

  Future<List<CatalogProductModel>> fetchAllProducts() async {
    // Larger pages = fewer round-trips (default API page size is often 10).
    const perPage = 100;

    final firstResponse = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.productsList,
      queryParameters: {'page': 1, 'per_page': perPage},
    );
    final firstEnvelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      firstResponse.data!,
      (json) => json as Map<String, dynamic>,
    );

    if (!firstEnvelope.success || firstEnvelope.data == null) {
      throw ApiException(
        message:
            firstEnvelope.message ?? 'Impossible de charger les produits.',
        statusCode: firstEnvelope.status,
      );
    }

    final products = <CatalogProductModel>[];
    void addRows(Map<String, dynamic> pageData) {
      final rows = pageData['data'];
      if (rows is! List) return;
      for (final row in rows) {
        if (row is Map<String, dynamic>) {
          products.add(CatalogProductModel.fromJson(row));
        }
      }
    }

    final firstPage = firstEnvelope.data!;
    addRows(firstPage);

    final lastPage = _productsLastPage(firstPage);
    if (lastPage != null && lastPage > 1) {
      final remaining = await Future.wait([
        for (var page = 2; page <= lastPage; page++)
          _fetchProductsPage(page: page, perPage: perPage),
      ]);
      for (final pageData in remaining) {
        addRows(pageData);
      }
    } else if (lastPage == null && _productsHasNextLink(firstPage)) {
      // Meta missing — fall back to sequential paging via links.next.
      var page = 2;
      var hasMore = true;
      while (hasMore) {
        final pageData = await _fetchProductsPage(page: page, perPage: perPage);
        addRows(pageData);
        hasMore = _productsHasNextLink(pageData);
        page++;
      }
    }

    return products.where((product) => product.isActive).toList();
  }

  Future<Map<String, dynamic>> _fetchProductsPage({
    required int page,
    required int perPage,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.productsList,
      queryParameters: {'page': page, 'per_page': perPage},
    );
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data!,
      (json) => json as Map<String, dynamic>,
    );
    if (!envelope.success || envelope.data == null) {
      throw ApiException(
        message: envelope.message ?? 'Impossible de charger les produits.',
        statusCode: envelope.status,
      );
    }
    return envelope.data!;
  }

  /// `null` when last_page is unknown (no meta).
  static int? _productsLastPage(Map<String, dynamic> pageData) {
    final meta = pageData['meta'];
    if (meta is Map<String, dynamic>) {
      return (meta['last_page'] as num?)?.toInt() ?? 1;
    }
    // Some APIs put pagination on the envelope data root.
    final current = (pageData['current_page'] as num?)?.toInt();
    final last = (pageData['last_page'] as num?)?.toInt();
    if (current != null || last != null) {
      return last ?? 1;
    }
    return null;
  }

  static bool _productsHasNextLink(Map<String, dynamic> pageData) {
    final links = pageData['links'];
    if (links is Map<String, dynamic>) {
      return links['next'] != null;
    }
    return pageData['next_page_url'] != null;
  }

  Future<CatalogProductModel> fetchProductDetail(int productId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.productById(productId),
    );
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data!,
      (json) => json as Map<String, dynamic>,
    );

    if (!envelope.success || envelope.data == null) {
      throw ApiException(
        message: envelope.message ?? 'Impossible de charger le produit.',
        statusCode: envelope.status,
      );
    }

    return CatalogProductModel.fromJson(envelope.data!);
  }
}
