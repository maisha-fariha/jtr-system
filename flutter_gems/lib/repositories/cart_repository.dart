import 'package:gems_data_layer/gems_data_layer.dart';
import 'package:gems_core/gems_core.dart';
import '../models/cart/cart_model.dart';
import '../utils/api_endpoints.dart';

/// CartRepository - Extends BaseRepository with fromJson
/// All CRUD operations are handled by BaseRepository
class CartRepository extends BaseRepository<Cart> {
  CartRepository({
    required super.apiService,
    required super.databaseService,
    required super.syncService,
  }) : super(baseEndpoint: ApiEndpoints.carts);

  @override
  Cart fromJson(Map<String, dynamic> json) => Cart.fromJson(json);

  /// Get user's cart
  Future<Result<Cart>> getUserCart(int userId) async {
    try {
      final response = await apiService.get<Map<String, dynamic>>(
        '${baseEndpoint}/user/$userId',
        fromJson: (data) => data as Map<String, dynamic>,
      );
      if (response.success && response.data != null) {
        final cart = fromJson(response.data!);
        return Result.success(cart);
      }
      return Result.failure(
        ApiError(message: response.message ?? 'Failed to get user cart'),
      );
    } catch (e, stackTrace) {
      return Result.failure(NetworkError.fromException(e, stackTrace));
    }
  }

  /// Get carts in date range
  Future<Result<List<Cart>>> getCartsInDateRange({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    String? sort,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null) {
        queryParams['startdate'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        queryParams['enddate'] = endDate.toIso8601String().split('T')[0];
      }
      if (limit != null) {
        queryParams['limit'] = limit.toString();
      }
      if (sort != null) {
        queryParams['sort'] = sort;
      }

      final queryString = queryParams.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');
      final url = queryString.isNotEmpty
          ? '${baseEndpoint}?$queryString'
          : baseEndpoint;

      final response = await apiService.get<List<dynamic>>(
        url,
        fromJson: (data) => (data as List)
            .map((e) => fromJson(e as Map<String, dynamic>))
            .toList(),
      );
      if (response.success && response.data != null) {
        final carts = response.data! as List<Cart>;
        return Result.success(carts);
      }
      return Result.failure(
        ApiError(message: response.message ?? 'Failed to get carts'),
      );
    } catch (e, stackTrace) {
      return Result.failure(NetworkError.fromException(e, stackTrace));
    }
  }

  /// Add product to cart
  Future<Result<Cart>> addProductToCart({
    required String cartId,
    required int productId,
    required int quantity,
  }) async {
    try {
      final cartResult = await getById(cartId);
      if (cartResult.isFailure) {
        return cartResult;
      }

      final currentCart = cartResult.value!;
      final existingProductIndex = currentCart.products
          .indexWhere((p) => p.productId == productId);

      final updatedProducts = List<CartProduct>.from(currentCart.products);
      if (existingProductIndex >= 0) {
        // Update existing product quantity
        updatedProducts[existingProductIndex] = CartProduct(
          productId: productId,
          quantity: updatedProducts[existingProductIndex].quantity + quantity,
        );
      } else {
        // Add new product
        updatedProducts.add(CartProduct(
          productId: productId,
          quantity: quantity,
        ));
      }

      final updatedCart = currentCart.copyWith(products: updatedProducts);
      return await update(cartId, updatedCart);
    } catch (e, stackTrace) {
      return Result.failure(NetworkError.fromException(e, stackTrace));
    }
  }

  /// Remove product from cart
  Future<Result<Cart>> removeProductFromCart({
    required String cartId,
    required int productId,
  }) async {
    try {
      final cartResult = await getById(cartId);
      if (cartResult.isFailure) {
        return cartResult;
      }

      final currentCart = cartResult.value!;
      final updatedProducts = currentCart.products
          .where((p) => p.productId != productId)
          .toList();

      final updatedCart = currentCart.copyWith(products: updatedProducts);
      return await update(cartId, updatedCart);
    } catch (e, stackTrace) {
      return Result.failure(NetworkError.fromException(e, stackTrace));
    }
  }

  /// Update product quantity in cart
  Future<Result<Cart>> updateProductQuantity({
    required String cartId,
    required int productId,
    required int quantity,
  }) async {
    try {
      final cartResult = await getById(cartId);
      if (cartResult.isFailure) {
        return cartResult;
      }

      final currentCart = cartResult.value!;
      final existingProductIndex = currentCart.products
          .indexWhere((p) => p.productId == productId);

      if (existingProductIndex < 0) {
      return Result.failure(
        ApiError(message: 'Product not found in cart'),
      );
      }

      final updatedProducts = List<CartProduct>.from(currentCart.products);
      if (quantity <= 0) {
        // Remove product if quantity is 0 or less
        updatedProducts.removeAt(existingProductIndex);
      } else {
        // Update quantity
        updatedProducts[existingProductIndex] = CartProduct(
          productId: productId,
          quantity: quantity,
        );
      }

      final updatedCart = currentCart.copyWith(products: updatedProducts);
      return await update(cartId, updatedCart);
    } catch (e, stackTrace) {
      return Result.failure(NetworkError.fromException(e, stackTrace));
    }
  }
}
