import 'package:flutter/material.dart';

import '../data/mappers/order_mapper.dart';
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
    this.waiterId,
    this.customerId,
    this.isPartiallyPaid = false,
    int? itemCount,
    List<OrderDisplayEntry>? displayEntries,
  })  : itemCount = itemCount ?? products.length,
        displayEntries = displayEntries ?? _entriesFromProducts(products);

  /// API order id. `0` for locally created orders not yet synced.
  final int id;

  /// Assigned waiter user id from the API, when known.
  final int? waiterId;

  /// Cardex customer id when the sales zone requires a client.
  final int? customerId;

  /// True when some amount is paid but remaining > 0.
  final bool isPartiallyPaid;
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

  /// Visible line count (from detail or list API hint).
  final int itemCount;

  static List<OrderDisplayEntry> _entriesFromProducts(List<OrderProduct> products) {
    return [
      for (var i = 0; i < products.length; i++)
        OrderDisplayEntry.product(product: products[i], lineIndex: i),
    ];
  }

  bool get isLocalOnly => id <= 0;

  /// List/header label: local `CL1` / `CL2`, after Send `C{id}`.
  String get displayNumber => OrderMapper.ticketDisplayLabel(
        id: id,
        number: number,
      );

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
    int? waiterId,
    int? customerId,
    bool clearCustomerId = false,
    bool? isPartiallyPaid,
    int? itemCount,
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
      waiterId: waiterId ?? this.waiterId,
      customerId: clearCustomerId ? null : (customerId ?? this.customerId),
      isPartiallyPaid: isPartiallyPaid ?? this.isPartiallyPaid,
      products: nextProducts,
      itemCount: itemCount ??
          (products != null ? nextProducts.length : this.itemCount),
      displayEntries: displayEntries ?? this.displayEntries,
    );
  }
}
