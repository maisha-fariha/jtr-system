import 'dart:convert';

import '../../core/constants/storage_constants.dart';
import '../../core/storage/hive_storage.dart';
import '../models/catalog/catalog_product_model.dart';
import '../models/catalog/leaf_category_model.dart';

class CatalogLocalDataSource {
  CatalogLocalDataSource(this._storage);

  final HiveStorage _storage;

  Future<void> saveLeafCategories(List<LeafCategoryModel> categories) async {
    final encoded = categories.map((c) => c.toJson()).toList();
    await _storage.writeString(
      StorageConstants.catalogLeafCategoriesKey,
      jsonEncode(encoded),
    );
  }

  List<LeafCategoryModel>? readLeafCategories() {
    final raw = _storage.readString(StorageConstants.catalogLeafCategoriesKey);
    if (raw == null || raw.isEmpty) return null;

    final decoded = jsonDecode(raw);
    if (decoded is! List) return null;

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(LeafCategoryModel.fromJson)
        .toList();
  }

  Future<void> saveProducts(List<CatalogProductModel> products) async {
    final encoded = products.map((p) => p.toJson()).toList();
    await _storage.writeString(
      StorageConstants.catalogProductsKey,
      jsonEncode(encoded),
    );
  }

  List<CatalogProductModel>? readProducts() {
    final raw = _storage.readString(StorageConstants.catalogProductsKey);
    if (raw == null || raw.isEmpty) return null;

    final decoded = jsonDecode(raw);
    if (decoded is! List) return null;

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(CatalogProductModel.fromJson)
        .toList();
  }
}
