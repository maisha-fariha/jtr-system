import 'package:gems_data_layer/gems_data_layer.dart';
import 'package:gems_core/gems_core.dart';
import '../models/product/product_model.dart';
import '../repositories/product_repository.dart';

class ProductController extends BaseListController<Product> with BaseControllerMixin<Product> {
  final ProductRepository repository;

  ProductController({
    required this.repository,
  }) {
    loadItems();
  }

  @override
  Future<void> loadItems() async {
    await handleListResult(() => repository.getAll());
  }

  Future<void> createProduct({
    required String title,
    required String description,
    required double price,
    required String category,
    required String image,
    ProductRating? rating,
  }) async {
    // Validation
    final titleValidation = FormValidator.validateField(
      value: title,
      rules: [
        StringValidators.required(),
        StringValidators.minLength(1),
        StringValidators.maxLength(200),
      ],
    );
    if (titleValidation.isFailure) {
      setError(titleValidation.error!.message);
      return;
    }

    final priceValidation = FormValidator.validateField(
      value: price,
      rules: [
        NumberValidators.required(),
        NumberValidators.min(0),
      ],
    );
    if (priceValidation.isFailure) {
      setError(priceValidation.error!.message);
      return;
    }

    // Create model
    final product = Product(
      id: UseCaseHelper.generateId(prefix: 'product'),
      title: title.trim(),
      description: description.trim(),
      price: price,
      category: category.trim(),
      image: image.trim(),
      rating: rating ?? const ProductRating(),
    );

    await handleResult(
      () => repository.create(product),
      onSuccess: (product) => items.insert(0, product),
      showSuccessMessage: true,
      successMessage: 'Product created successfully',
    );
  }

  Future<void> updateProduct(Product product) async {
    await handleResult(
      () => repository.update(product.id, product),
      onSuccess: (product) {
        final index = items.indexWhere((p) => p.id == product.id);
        if (index != -1) items[index] = product;
      },
      showSuccessMessage: true,
      successMessage: 'Product updated successfully',
    );
  }

  Future<void> deleteProduct(String id) async {
    await handleResult(
      () => repository.delete(id),
      onSuccess: (_) => items.removeWhere((p) => p.id == id),
      showSuccessMessage: true,
      successMessage: 'Product deleted successfully',
    );
  }

  List<Product> getProductsByCategory(String category) {
    return items.where((p) => p.category.toLowerCase() == category.toLowerCase()).toList();
  }

  List<Product> getFeaturedProducts() {
    // Return products with rating >= 4.0 as featured
    return items.where((p) => p.rating.rate >= 4.0).toList();
  }

  List<String> getCategories() {
    return items.map((p) => p.category).toSet().toList();
  }
}
