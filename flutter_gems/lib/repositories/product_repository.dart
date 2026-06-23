import 'package:gems_data_layer/gems_data_layer.dart';
import '../models/product/product_model.dart';
import '../utils/api_endpoints.dart';

/// ProductRepository - Extends BaseRepository with fromJson
/// All CRUD operations are handled by BaseRepository
class ProductRepository extends BaseRepository<Product> {
  ProductRepository({
    required super.apiService,
    required super.databaseService,
    required super.syncService,
  }) : super(baseEndpoint: ApiEndpoints.products);

  @override
  Product fromJson(Map<String, dynamic> json) => Product.fromJson(json);
}
