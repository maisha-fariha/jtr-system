import 'package:flutter/material.dart';

import 'order_product.dart';

class SessionOrder {
  const SessionOrder({
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
}
