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
    final products = <CatalogProductModel>[];
    var page = 1;
    var hasMore = true;

    while (hasMore) {
      final response = await _client.get<Map<String, dynamic>>(
        ApiEndpoints.productsList,
        queryParameters: {'page': page},
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

      final pageData = envelope.data!;
      final rows = pageData['data'];
      if (rows is List) {
        for (final row in rows) {
          if (row is Map<String, dynamic>) {
            products.add(CatalogProductModel.fromJson(row));
          }
        }
      }

      final meta = pageData['meta'];
      if (meta is Map<String, dynamic>) {
        final current = (meta['current_page'] as num?)?.toInt() ?? page;
        final last = (meta['last_page'] as num?)?.toInt() ?? current;
        hasMore = current < last;
        page = current + 1;
      } else {
        final links = pageData['links'];
        final next = links is Map<String, dynamic> ? links['next'] : null;
        hasMore = next != null;
        page++;
      }
    }

    return products.where((product) => product.isActive).toList();
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
