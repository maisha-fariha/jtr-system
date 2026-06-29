import 'package:flutter/material.dart';

import 'order_product.dart';

class SessionOrder {
  const SessionOrder({
    required this.id,
    required this.number,
    required this.numberColor,
    required this.group,
    required this.poste,
    required this.profitCenter,
    required this.couverts,
    required this.impressionCount,
    required this.impressionColor,
    required this.total,
    required this.products,
  });

  /// API order id. `0` for locally created orders not yet synced.
  final int id;
  final String number;
  final Color numberColor;
  final String group;
  final String poste;
  final String profitCenter;
  final String couverts;
  final int impressionCount;
  final Color impressionColor;
  final String total;
  final List<OrderProduct> products;

  bool get isLocalOnly => id <= 0;

  SessionOrder copyWith({
    int? id,
    String? number,
    Color? numberColor,
    String? group,
    String? poste,
    String? profitCenter,
    String? couverts,
    int? impressionCount,
    Color? impressionColor,
    String? total,
    List<OrderProduct>? products,
  }) {
    return SessionOrder(
      id: id ?? this.id,
      number: number ?? this.number,
      numberColor: numberColor ?? this.numberColor,
      group: group ?? this.group,
      poste: poste ?? this.poste,
      profitCenter: profitCenter ?? this.profitCenter,
      couverts: couverts ?? this.couverts,
      impressionCount: impressionCount ?? this.impressionCount,
      impressionColor: impressionColor ?? this.impressionColor,
      total: total ?? this.total,
      products: products ?? this.products,
    );
  }
}
