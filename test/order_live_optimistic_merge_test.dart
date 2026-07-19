import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jtr_system/data/mappers/order_mapper.dart';
import 'package:jtr_system/models/order_display_entry.dart';
import 'package:jtr_system/models/order_product.dart';
import 'package:jtr_system/models/session_order.dart';

SessionOrder _order({
  required List<OrderDisplayEntry> display,
  String total = '10.00',
}) {
  final products = [
    for (final e in display)
      if (e.type == OrderDisplayEntryType.product && e.product != null)
        e.product!,
  ];
  return SessionOrder(
    id: 1,
    number: 'T1',
    numberColor: const Color(0xFF000000),
    group: '1',
    poste: 'A',
    profitCenter: 'SUR PLACE',
    couverts: '2',
    impressionCount: 0,
    impressionColor: const Color(0xFF000000),
    total: total,
    products: products,
    itemCount: products.length,
    displayEntries: display,
  );
}

OrderDisplayEntry _product(int line, String name, {int? itemId}) {
  return OrderDisplayEntry.product(
    product: OrderProduct(quantity: '1', name: name, price: '5'),
    lineIndex: line,
    itemId: itemId,
  );
}

void main() {
  test('coalesceLayoutHints treats empty as absent', () {
    expect(OrderMapper.coalesceLayoutHints(null), isNull);
    expect(OrderMapper.coalesceLayoutHints(const []), isNull);
    final entries = [_product(0, 'A', itemId: 1)];
    expect(OrderMapper.coalesceLayoutHints(entries), entries);
  });

  test('merge keeps live À SUIVRE when server omits it', () {
    final live = _order(
      display: [
        _product(0, 'A', itemId: 1),
        _product(1, 'B', itemId: 2),
        _product(2, 'C', itemId: 3),
        const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
        _product(3, 'D', itemId: 0),
      ],
    );
    final server = _order(
      display: [
        _product(0, 'A', itemId: 1),
        _product(1, 'B', itemId: 2),
        _product(2, 'C', itemId: 3),
        _product(3, 'D', itemId: 4),
      ],
    );

    final merged = OrderMapper.mergeLiveOptimisticDetail(
      server: server,
      live: live,
    );

    expect(OrderMapper.suivreSeparatorCount(merged.displayEntries), 1);
    expect(OrderMapper.productEntryCount(merged.displayEntries), 4);
  });

  test('merge does not restore a deleted line from stale server', () {
    final live = _order(
      display: [
        _product(0, 'A', itemId: 1),
        _product(1, 'C', itemId: 3),
      ],
    );
    final server = _order(
      display: [
        _product(0, 'A', itemId: 1),
        _product(1, 'B', itemId: 2),
        _product(2, 'C', itemId: 3),
      ],
    );

    final merged = OrderMapper.mergeLiveOptimisticDetail(
      server: server,
      live: live,
      suppressItemIds: {2},
    );

    final ids = OrderMapper.productItemIds(merged.displayEntries);
    expect(ids.contains(2), isFalse);
    expect(ids, containsAll([1, 3]));
  });

  test('merge does not flash empty over non-empty live ticket', () {
    final live = _order(display: [_product(0, 'A', itemId: 1)]);
    final server = _order(display: const []);

    final merged = OrderMapper.mergeLiveOptimisticDetail(
      server: server,
      live: live,
    );

    expect(merged.products, isNotEmpty);
    expect(merged.displayEntries, isNotEmpty);
  });

  test('merge adopts full server ticket when live is empty session row', () {
    final live = _order(display: const []);
    final server = _order(
      display: [
        _product(0, 'A', itemId: 1990),
        _product(1, 'B', itemId: 1991),
        _product(2, 'C', itemId: 1992),
      ],
      total: '235.03',
    );

    final merged = OrderMapper.mergeLiveOptimisticDetail(
      server: server,
      live: live,
    );

    expect(merged.products.length, 3);
    expect(OrderMapper.productItemIds(merged.displayEntries), {1990, 1991, 1992});
    expect(merged.total, '235.03');
  });

  test('merge keeps empty after delete-all while suppressed ids pending', () {
    final live = _order(display: const []);
    final server = _order(
      display: [
        _product(0, 'COUPE KIDS', itemId: 42),
      ],
      total: '45.00',
    );

    final merged = OrderMapper.mergeLiveOptimisticDetail(
      server: server,
      live: live,
      suppressItemIds: {42},
    );

    expect(merged.products, isEmpty);
    expect(merged.displayEntries, isEmpty);
    expect(merged.total, '0,00 €');
  });
}
