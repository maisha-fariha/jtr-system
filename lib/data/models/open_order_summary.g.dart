// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'open_order_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OpenOrderSummary _$OpenOrderSummaryFromJson(Map<String, dynamic> json) =>
    _OpenOrderSummary(
      id: (json['id'] as num).toInt(),
      orderNumber: json['order_number'] as String,
      tableId: (json['table_id'] as num?)?.toInt(),
      tableNumber: (json['table_number'] as num?)?.toInt(),
      status: json['status'] as String,
      totalPrice: json['total_price'] as String,
      createdAt: json['created_at'] as String?,
    );

Map<String, dynamic> _$OpenOrderSummaryToJson(_OpenOrderSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'order_number': instance.orderNumber,
      'table_id': instance.tableId,
      'table_number': instance.tableNumber,
      'status': instance.status,
      'total_price': instance.totalPrice,
      'created_at': instance.createdAt,
    };

_OpenOrdersData _$OpenOrdersDataFromJson(Map<String, dynamic> json) =>
    _OpenOrdersData(
      hasOpenOrders: json['hasOpenOrders'] as bool,
      openOrdersCount: (json['openOrdersCount'] as num).toInt(),
      openOrders: (json['openOrders'] as List<dynamic>)
          .map((e) => OpenOrderSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$OpenOrdersDataToJson(_OpenOrdersData instance) =>
    <String, dynamic>{
      'hasOpenOrders': instance.hasOpenOrders,
      'openOrdersCount': instance.openOrdersCount,
      'openOrders': instance.openOrders,
    };
