import 'package:flutter/material.dart';

import 'order_display_entry.dart';
import 'order_product.dart';

class SessionOrder {
  SessionOrder({
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
    List<OrderDisplayEntry>? displayEntries,
  }) : displayEntries = displayEntries ?? _entriesFromProducts(products);

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
  final List<OrderDisplayEntry> displayEntries;

  static List<OrderDisplayEntry> _entriesFromProducts(List<OrderProduct> products) {
    return [
      for (var i = 0; i < products.length; i++)
        OrderDisplayEntry.product(product: products[i], lineIndex: i),
    ];
  }

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
    List<OrderDisplayEntry>? displayEntries,
  }) {
    final nextProducts = products ?? this.products;
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
      products: nextProducts,
      displayEntries:
          displayEntries ?? (products != null ? null : this.displayEntries),
    );
  }
}
