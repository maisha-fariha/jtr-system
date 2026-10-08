import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jtr_system/data/mappers/order_mapper.dart';
import 'package:jtr_system/models/order_display_entry.dart';
import 'package:jtr_system/models/order_product.dart';
import 'package:jtr_system/models/session_order.dart';

SessionOrder _order(List<OrderDisplayEntry> display) {
  final products = [
    for (final e in display)
      if (e.type == OrderDisplayEntryType.product && e.product != null)
        e.product!,
  ];
  return SessionOrder(
    id: 7,
    number: 'T1',
    numberColor: const Color(0xFF000000),
    group: '1',
    poste: 'A',
    profitCenter: 'SUR PLACE',
    couverts: '2',
    impressionCount: 0,
    impressionColor: const Color(0xFF000000),
    total: '10.00',
    products: products,
    itemCount: products.length,
    displayEntries: display,
  );
}

OrderDisplayEntry _line(
  int line,
  String name, {
  int? course,
  int? itemId,
  String? message,
  int section = 0,
}) {
  return OrderDisplayEntry.product(
    product: OrderProduct(
      quantity: '1',
      name: name,
      price: '5',
      message: message,
    ),
    lineIndex: line,
    sectionIndex: section,
    courseNumber: course,
    itemId: itemId,
  );
}

List<int?> _ids(SessionOrder order) => [
      for (final e in order.displayEntries)
        if (e.type == OrderDisplayEntryType.product) e.itemId,
    ];

void main() {
  test('twin lines in different courses keep their own server ids', () {
    final live = _order([
      _line(0, 'BURGER', course: 2, section: 1),
      _line(1, 'BURGER', course: 1),
    ]);
    final server = _order([
      _line(0, 'BURGER', course: 1, itemId: 101),
      _line(1, 'BURGER', course: 2, itemId: 202),
    ]);

    final patched =
        OrderMapper.patchServerItemIdsOntoLive(live: live, server: server);

    expect(_ids(patched), [202, 101]);
  });

  test('twin lines with different messages keep their own server ids', () {
    final live = _order([
      _line(0, 'STEAK', message: 'BIEN CUIT'),
      _line(1, 'STEAK', message: 'SAIGNANT'),
    ]);
    final server = _order([
      _line(0, 'STEAK', message: 'SAIGNANT', itemId: 11),
      _line(1, 'STEAK', message: 'BIEN CUIT', itemId: 12),
    ]);

    final patched =
        OrderMapper.patchServerItemIdsOntoLive(live: live, server: server);

    expect(_ids(patched), [12, 11]);
  });

  test('falls back to name+qty order when nothing else distinguishes', () {
    final live = _order([_line(0, 'COCA'), _line(1, 'COCA')]);
    final server = _order([
      _line(0, 'COCA', course: 1, itemId: 1),
      _line(1, 'COCA', course: 1, itemId: 2),
    ]);

    final patched =
        OrderMapper.patchServerItemIdsOntoLive(live: live, server: server);

    expect(_ids(patched), [1, 2]);
  });

  test('existing item ids still win over any fingerprint', () {
    final live = _order([
      _line(0, 'BURGER', course: 1, itemId: 202),
      _line(1, 'BURGER', course: 1),
    ]);
    final server = _order([
      _line(0, 'BURGER', course: 1, itemId: 101),
      _line(1, 'BURGER', course: 1, itemId: 202),
    ]);

    final patched =
        OrderMapper.patchServerItemIdsOntoLive(live: live, server: server);

    expect(_ids(patched), [202, 101]);
  });
}
