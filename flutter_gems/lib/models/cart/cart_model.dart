import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gems_data_layer/gems_data_layer.dart';

part 'cart_model.freezed.dart';
part 'cart_model.g.dart';

@freezed
class CartProduct with _$CartProduct {
  const factory CartProduct({
    required int productId,
    required int quantity,
  }) = _CartProduct;

  factory CartProduct.fromJson(Map<String, dynamic> json) =>
      _$CartProductFromJson(json);
}

@freezed
class Cart with _$Cart implements BaseModel {
  // ignore: invalid_annotation_target
  const factory Cart({
    // ignore: invalid_annotation_target
    @JsonKey(fromJson: _idFromJson) required String id,
    @JsonKey(name: 'userId') required int userId,
    @JsonKey(fromJson: _dateFromJson, toJson: _dateToJson) required DateTime date,
    @Default([]) List<CartProduct> products,
  }) = _Cart;

  factory Cart.fromJson(Map<String, dynamic> json) => _$CartFromJson(json);
}

// Helper functions for JSON conversion
String _idFromJson(dynamic value) {
  if (value is int) return value.toString();
  if (value is String) return value;
  return value?.toString() ?? '';
}

DateTime _dateFromJson(dynamic value) {
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  return DateTime.now();
}

String _dateToJson(DateTime date) {
  return date.toIso8601String();
}
