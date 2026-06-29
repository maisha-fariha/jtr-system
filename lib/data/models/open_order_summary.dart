import 'package:freezed_annotation/freezed_annotation.dart';

part 'open_order_summary.freezed.dart';
part 'open_order_summary.g.dart';

@freezed
abstract class OpenOrderSummary with _$OpenOrderSummary {
  const factory OpenOrderSummary({
    required int id,
    @JsonKey(name: 'order_number') required String orderNumber,
    @JsonKey(name: 'table_id') int? tableId,
    required String status,
    @JsonKey(name: 'total_price') required String totalPrice,
    @JsonKey(name: 'created_at') String? createdAt,
  }) = _OpenOrderSummary;

  factory OpenOrderSummary.fromJson(Map<String, dynamic> json) =>
      _$OpenOrderSummaryFromJson(json);
}

@freezed
abstract class OpenOrdersData with _$OpenOrdersData {
  const factory OpenOrdersData({
    @JsonKey(name: 'hasOpenOrders') required bool hasOpenOrders,
    @JsonKey(name: 'openOrdersCount') required int openOrdersCount,
    @JsonKey(name: 'openOrders') required List<OpenOrderSummary> openOrders,
  }) = _OpenOrdersData;

  factory OpenOrdersData.fromJson(Map<String, dynamic> json) =>
      _$OpenOrdersDataFromJson(json);
}
