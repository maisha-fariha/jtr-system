import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gems_data_layer/gems_data_layer.dart';

part 'product_model.freezed.dart';
part 'product_model.g.dart';

@freezed
class ProductRating with _$ProductRating {
  const factory ProductRating({
    @Default(0.0) double rate,
    @Default(0) int count,
  }) = _ProductRating;

  factory ProductRating.fromJson(Map<String, dynamic> json) =>
      _$ProductRatingFromJson(json);
}

@freezed
class Product with _$Product implements BaseModel {
  // ignore: invalid_annotation_target
  const factory Product({
    // ignore: invalid_annotation_target
    @JsonKey(fromJson: _idFromJson) required String id,
    required String title,
    required String description,
    required double price,
    required String category,
    required String image,
    @JsonKey(fromJson: _ratingFromJson) @Default(ProductRating()) ProductRating rating,
  }) = _Product;

  factory Product.fromJson(Map<String, dynamic> json) => _$ProductFromJson(json);
}

// Helper functions for JSON conversion
String _idFromJson(dynamic value) {
  if (value is int) return value.toString();
  if (value is String) return value;
  return value?.toString() ?? '';
}

ProductRating _ratingFromJson(dynamic value) {
  if (value == null) {
    return const ProductRating();
  }
  if (value is Map<String, dynamic>) {
    return ProductRating.fromJson(value);
  }
  return const ProductRating();
}
