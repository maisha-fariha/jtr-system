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

  test('merge keeps revived lines after delete-all when suppress is stale', () {
    final live = _order(display: const []);
    final server = _order(
      display: [
        _product(0, 'OULMES 1L', itemId: 99),
      ],
      total: '30.00',
    );

    final merged = OrderMapper.mergeLiveOptimisticDetail(
      server: server,
      live: live,
      suppressItemIds: {42},
    );

    expect(OrderMapper.productItemIds(merged.displayEntries), [99]);
    expect(merged.products, isNotEmpty);
  });

  test('reconcile keeps pending À SUIVRE over false DEMANDÉE from add sync', () {
    final previous = [
      _product(0, 'A', itemId: 1),
      _product(1, 'B', itemId: 2),
      const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
      _product(2, 'C', itemId: 3),
      _product(3, 'D', itemId: 4),
    ];
    final afterAdd = [
      _product(0, 'A', itemId: 1),
      _product(1, 'B', itemId: 2),
      const OrderDisplayEntry.demande(
        sectionIndex: 1,
        courseNumber: 1,
        demandeTimeLabel: '11:58:00',
      ),
      _product(2, 'C', itemId: 3),
      _product(3, 'D', itemId: 4),
    ];

    final reconciled = OrderMapper.reconcileSuivreDisplay(
      previous: previous,
      next: afterAdd,
    );

    expect(OrderMapper.suivreSeparatorCount(reconciled), 1);
    expect(OrderMapper.demandeSeparatorCount(reconciled), 0);
  });

  test('merge keeps live À SUIVRE when add sync returns DEMANDÉE', () {
    final live = _order(
      display: [
        _product(0, 'A', itemId: 1),
        const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
        _product(1, 'B', itemId: 2),
      ],
    );
    final server = _order(
      display: [
        _product(0, 'A', itemId: 1),
        const OrderDisplayEntry.demande(
          sectionIndex: 1,
          courseNumber: 1,
          demandeTimeLabel: '12:00:00',
        ),
        _product(1, 'B', itemId: 2),
      ],
    );

    final merged = OrderMapper.mergeLiveOptimisticDetail(
      server: server,
      live: live,
    );

    expect(OrderMapper.suivreSeparatorCount(merged.displayEntries), 1);
    expect(OrderMapper.demandeSeparatorCount(merged.displayEntries), 0);
  });

  test('applyDemande converts only on explicit kitchen send', () {
    final pending = [
      _product(0, 'A', itemId: 1),
      const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
      _product(1, 'B', itemId: 2),
    ];
    final detail = <String, dynamic>{
      'seat_orders': [
        {
          'seat_number': 1,
          'courses': [
            {
              'course_number': 1,
              'items': [
                {'id': 1, 'qty': 1, 'status': 'active'},
              ],
            },
            {
              'course_number': 2,
              'requested_at': '2026-07-19T12:00:00Z',
              'status': 'requested',
              'items': [
                {'id': 2, 'qty': 1, 'status': 'active'},
              ],
            },
          ],
        },
      ],
    };

    final onAdd = OrderMapper.applyDemandeSeparatorsFromApi(
      detail,
      pending,
      preservePendingSuivreFrom: pending,
    );
    expect(OrderMapper.suivreSeparatorCount(onAdd), 1);
    expect(OrderMapper.demandeSeparatorCount(onAdd), 0);

    final onKitchen = OrderMapper.applyDemandeSeparatorsFromApi(
      detail,
      pending,
      preservePendingSuivreFrom: pending,
      applyKitchenDemande: true,
    );
    expect(OrderMapper.demandeSeparatorCount(onKitchen), 1);
    expect(OrderMapper.suivreSeparatorCount(onKitchen), 0);
  });

  test('finalize after kitchen send keeps DEMANDÉE (no revert to À SUIVRE)', () {
    final previous = [
      _product(0, 'A', itemId: 1),
      const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
      _product(1, 'B', itemId: 2),
    ];
    final detail = <String, dynamic>{
      'id': 1,
      'table': {'table_number': 1},
      'seat_orders': [
        {
          'seat_number': 1,
          'courses': [
            {
              'course_number': 1,
              'items': [
                {
                  'id': 1,
                  'qty': 1,
                  'status': 'active',
                  'product': {'id': 10, 'name': 'A'},
                  'sub_total': 5,
                },
              ],
            },
            {
              'course_number': 2,
              'requested_at': '2026-07-19T12:00:00Z',
              'status': 'requested',
              'items': [
                {
                  'id': 2,
                  'qty': 1,
                  'status': 'active',
                  'product': {'id': 11, 'name': 'B'},
                  'sub_total': 5,
                },
              ],
            },
          ],
        },
      ],
    };

    final entries = OrderMapper.finalizeDisplayEntries(
      detail,
      previousDisplayEntries: previous,
      suivreCountHint: 1,
      applyKitchenDemande: true,
    );

    expect(OrderMapper.demandeSeparatorCount(entries), 1);
    expect(OrderMapper.suivreSeparatorCount(entries), 0);
  });

  test(
    'kitchen send keeps flat batch above DEMANDÉE when API splits courses',
    () {
      // Waiter added 3 identical lines then Envoyer — UI was flat.
      final previous = [
        _product(0, 'OULMES', itemId: 0),
        _product(1, 'OULMES', itemId: 0),
        _product(2, 'OULMES', itemId: 0),
      ];
      // API parked line 1 in course 1 and lines 2–3 in course 2 (both requested).
      final detail = <String, dynamic>{
        'id': 1,
        'table': {'table_number': 1},
        'seat_orders': [
          {
            'seat_number': 1,
            'courses': [
              {
                'course_number': 1,
                'requested_at': '2026-07-19T12:51:51Z',
                'status': 'requested',
                'items': [
                  {
                    'id': 11,
                    'qty': 1,
                    'status': 'active',
                    'product': {'id': 10, 'name': 'OULMES'},
                    'sub_total': 15,
                  },
                ],
              },
              {
                'course_number': 2,
                'requested_at': '2026-07-19T12:51:51Z',
                'status': 'requested',
                'items': [
                  {
                    'id': 12,
                    'qty': 1,
                    'status': 'active',
                    'product': {'id': 10, 'name': 'OULMES'},
                    'sub_total': 15,
                  },
                  {
                    'id': 13,
                    'qty': 1,
                    'status': 'active',
                    'product': {'id': 10, 'name': 'OULMES'},
                    'sub_total': 15,
                  },
                ],
              },
            ],
          },
        ],
      };

      final entries = OrderMapper.finalizeDisplayEntries(
        detail,
        previousDisplayEntries: previous,
        applyKitchenDemande: true,
      );

      expect(OrderMapper.demandeSeparatorCount(entries), 1);
      final before = <int?>[];
      final after = <int?>[];
      var seenDivider = false;
      for (final entry in entries) {
        if (entry.isSectionDivider) {
          seenDivider = true;
          continue;
        }
        if (entry.type != OrderDisplayEntryType.product) continue;
        (seenDivider ? after : before).add(entry.itemId);
      }
      expect(before, [11, 12, 13]);
      expect(after, isEmpty);
    },
  );

  test('writable suivre reuses empty shell with server id after suite delete',
      () {
    final detail = <String, dynamic>{
      'id': 1,
      'seat_orders': [
        {
          'seat_number': 1,
          'courses': [
            {
              'id': 10,
              'course_number': 1,
              'status': 'pending',
              'items': [
                {
                  'id': 1,
                  'qty': 1,
                  'status': 'active',
                  'product': {'id': 20, 'name': 'SIDI'},
                  'sub_total': 30,
                },
                {
                  'id': 3,
                  'qty': 1,
                  'status': 'active',
                  'product': {'id': 30, 'name': 'ORANGE'},
                  'sub_total': 1,
                },
              ],
            },
            {
              'id': 11,
              'course_number': 2,
              'status': 'to_be_continued',
              'items': <dynamic>[],
            },
          ],
        },
      ],
    };

    // Empty shell with real API id must be reused (not skipped to course 3).
    expect(
      OrderMapper.resolveWritableSuivreCourseNumber(
        detail,
        preferredCourseNumber: 2,
      ),
      2,
    );

    final layout = [
      _product(0, 'SIDI', itemId: 1),
      const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
      _product(1, 'ORANGE', itemId: 3),
    ];
    final rebaked = OrderMapper.rebakeSuivreSectionOntoCourse(
      detail,
      layout: layout,
      sectionIndex: 1,
      targetCourseNumber: 2,
    );
    expect(rebaked.changed, isTrue);

    final course1 = OrderMapper.findCourseInOrderDetail(rebaked.detail, 1)!;
    final course2 = OrderMapper.findCourseInOrderDetail(rebaked.detail, 2)!;
    expect(
      [
        for (final item in (course1['items'] as List))
          if (item is Map && item['status'] != 'cancelled') item['id'],
      ],
      [1],
    );
    expect(
      OrderMapper.extractRequestableCourseIdsForSuivreSection(
        rebaked.detail,
        courseNumber: 2,
      ),
      [11],
    );
    expect(
      [
        for (final item in (course2['items'] as List))
          if (item is Map && item['status'] != 'cancelled') item,
      ].length,
      1,
    );
  });

  test('PUT payload omits courses with empty items arrays', () {
    final detail = <String, dynamic>{
      'id': 1,
      'waiter_id': 5,
      'number_of_guests': 2,
      'seat_orders': [
        {
          'seat_number': 1,
          'courses': [
            {
              'id': 10,
              'course_number': 1,
              'items': [
                {
                  'id': 1,
                  'qty': 1,
                  'status': 'active',
                  'product': {'id': 20, 'name': 'A'},
                  'sub_total': 10,
                },
              ],
            },
            {
              'id': 11,
              'course_number': 2,
              'items': <dynamic>[],
            },
          ],
        },
      ],
    };

    final payload = OrderMapper.buildOrderUpdatePayload(detail);
    final seats = payload['seat_orders'] as List;
    final courses = (seats.first as Map)['courses'] as List;
    expect(courses.length, 1);
    expect((courses.first as Map)['course_number'], 1);
    expect(((courses.first as Map)['items'] as List).isNotEmpty, isTrue);
  });

  test('writable suivre reuses empty shell slot even without server id', () {
    final detail = <String, dynamic>{
      'id': 1,
      'seat_orders': [
        {
          'seat_number': 1,
          'courses': [
            {
              'id': 10,
              'course_number': 1,
              'items': [
                {
                  'id': 1,
                  'qty': 1,
                  'status': 'active',
                  'product': {'id': 20, 'name': 'A'},
                  'sub_total': 10,
                },
              ],
            },
            {
              'id': 0,
              'course_number': 2,
              'items': <dynamic>[],
            },
          ],
        },
      ],
    };

    expect(
      OrderMapper.resolveWritableSuivreCourseNumber(
        detail,
        preferredCourseNumber: 2,
      ),
      2,
    );
  });

  test('convertSuivreSectionToDemande flips only the demanded section', () {
    final entries = [
      _product(0, 'A', itemId: 1),
      const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
      _product(1, 'B', itemId: 2),
    ];
    final converted = OrderMapper.convertSuivreSectionToDemande(
      entries,
      sectionIndex: 1,
      demandeTimeLabel: '16:07:00',
    );
    expect(OrderMapper.suivreSeparatorCount(converted), 0);
    expect(OrderMapper.demandeSeparatorCount(converted), 1);
    expect(converted[1].demandeTimeLabel, '16:07:00');
  });

  test(
    'applyDemande after rebake converts when later course was requested',
    () {
      final pending = [
        _product(0, 'A', itemId: 1),
        const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
        _product(1, 'B', itemId: 2),
      ];
      // Course 2 empty shell; suite items demanded on course 3.
      final detail = <String, dynamic>{
        'id': 1,
        'seat_orders': [
          {
            'seat_number': 1,
            'courses': [
              {
                'course_number': 1,
                'items': [
                  {'id': 1, 'qty': 1, 'status': 'active'},
                ],
              },
              {
                'course_number': 2,
                'items': <dynamic>[],
              },
              {
                'course_number': 3,
                'requested_at': '2026-07-19T14:07:00Z',
                'status': 'requested',
                'items': [
                  {'id': 2, 'qty': 1, 'status': 'active'},
                ],
              },
            ],
          },
        ],
      };

      final onKitchen = OrderMapper.applyDemandeSeparatorsFromApi(
        detail,
        pending,
        applyKitchenDemande: true,
      );
      expect(OrderMapper.demandeSeparatorCount(onKitchen), 1);
      expect(OrderMapper.suivreSeparatorCount(onKitchen), 0);
    },
  );

  test('append after suite delete reuses empty shell with server id', () {
    final detail = <String, dynamic>{
      'id': 1,
      'seat_orders': [
        {
          'seat_number': 1,
          'courses': [
            {
              'id': 10,
              'course_number': 1,
              'items': [
                {
                  'id': 1,
                  'qty': 1,
                  'status': 'active',
                  'product': {'id': 1, 'name': 'A'},
                  'sub_total': 1,
                },
              ],
            },
            {
              'id': 11,
              'course_number': 2,
              'items': <dynamic>[],
            },
          ],
        },
      ],
    };
    final layout = [
      _product(0, 'A', itemId: 1),
      const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
    ];
    final course = OrderMapper.resolveAppendCourse(
      detail,
      layoutHints: layout,
    );
    expect(course.number, 2);
    expect(course.id, 11);
  });

  test('removeSuivreSectionFromDisplay drops divider and its items', () {
    final entries = [
      _product(0, 'A', itemId: 1),
      const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
      _product(1, 'B', itemId: 2),
      _product(2, 'C', itemId: 3),
    ];

    final trimmed = OrderMapper.removeSuivreSectionFromDisplay(entries, 1);

    expect(OrderMapper.suivreSeparatorCount(trimmed), 0);
    expect(
      [
        for (final e in trimmed)
          if (e.type == OrderDisplayEntryType.product) e.itemId,
      ],
      [1],
    );
  });

  test('applyTrimmedSuivreLayout preserves DEMANDÉE when later suite removed', () {
    final trimmed = [
      _product(0, 'A', itemId: 1),
      const OrderDisplayEntry.demande(
        sectionIndex: 1,
        courseNumber: 1,
        demandeTimeLabel: '12:00:00',
      ),
      _product(1, 'B', itemId: 2),
      _product(2, 'C', itemId: 3),
    ];
    final products = [
      for (final e in trimmed)
        if (e.type == OrderDisplayEntryType.product && e.product != null)
          e.product!,
    ];

    final rebuilt = OrderMapper.applyTrimmedSuivreLayout(
      products: products,
      trimmedLayout: trimmed,
    );

    expect(OrderMapper.demandeSeparatorCount(rebuilt), 1);
    expect(OrderMapper.suivreSeparatorCount(rebuilt), 0);
    expect(rebuilt[1].type, OrderDisplayEntryType.demandeSeparator);
  });

  test('append course stays in suite for optimistic product without courseNumber', () {
    final layout = [
      _product(0, 'A', itemId: 1),
      const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
      OrderDisplayEntry.product(
        product: const OrderProduct(quantity: '1', name: 'B', price: '5'),
        lineIndex: 1,
        sectionIndex: 1,
        // courseNumber intentionally null (optimistic)
      ),
    ];

    expect(OrderMapper.resolveAppendCourseNumberFromLayout(layout), 2);
  });

  test('empty API follow-up course does not auto-insert À SUIVRE', () {
    final detail = <String, dynamic>{
      'seat_orders': [
        {
          'seat_number': 1,
          'courses': [
            {
              'course_number': 1,
              'items': [
                {
                  'id': 1,
                  'qty': 1,
                  'sub_total': 5,
                  'status': 'to_be_continued',
                  'product': {'id': 10, 'name': 'A'},
                },
                {
                  'id': 2,
                  'qty': 1,
                  'sub_total': 5,
                  'status': 'to_be_continued',
                  'product': {'id': 11, 'name': 'B'},
                },
                {
                  'id': 3,
                  'qty': 1,
                  'sub_total': 5,
                  'status': 'to_be_continued',
                  'product': {'id': 12, 'name': 'C'},
                },
              ],
            },
            {
              'course_number': 2,
              'items': <dynamic>[],
            },
          ],
        },
      ],
    };

    final entries = OrderMapper.extractOrderDisplayEntries(detail);
    expect(OrderMapper.sectionDividerCount(entries), 0);
    expect(
      [
        for (final e in entries)
          if (e.type == OrderDisplayEntryType.product) e.product!.name,
      ],
      ['A', 'B', 'C'],
    );
  });

  test('pin keeps pre-suivre items above when API moves them to course 2', () {
    final previous = [
      _product(0, 'A', itemId: 1),
      _product(1, 'B', itemId: 2),
      _product(2, 'C', itemId: 3),
      const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
      OrderDisplayEntry.product(
        product: const OrderProduct(quantity: '1', name: 'D', price: '5'),
        lineIndex: 3,
        sectionIndex: 1,
        courseNumber: 2,
        itemId: 4,
      ),
    ];
    // API wrongly put B+C into course 2 with D.
    final next = [
      _product(0, 'A', itemId: 1),
      const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
      OrderDisplayEntry.product(
        product: const OrderProduct(quantity: '1', name: 'B', price: '5'),
        lineIndex: 1,
        sectionIndex: 1,
        courseNumber: 2,
        itemId: 2,
      ),
      OrderDisplayEntry.product(
        product: const OrderProduct(quantity: '1', name: 'C', price: '5'),
        lineIndex: 2,
        sectionIndex: 1,
        courseNumber: 2,
        itemId: 3,
      ),
      OrderDisplayEntry.product(
        product: const OrderProduct(quantity: '1', name: 'D', price: '5'),
        lineIndex: 3,
        sectionIndex: 1,
        courseNumber: 2,
        itemId: 4,
      ),
    ];

    final pinned = OrderMapper.pinProductsRelativeToDividers(
      previous: previous,
      next: next,
    );

    final before = <String>[];
    final after = <String>[];
    var seenDivider = false;
    for (final e in pinned) {
      if (e.isSectionDivider) {
        seenDivider = true;
        continue;
      }
      if (e.product == null) continue;
      (seenDivider ? after : before).add(e.product!.name);
    }
    expect(before, ['A', 'B', 'C']);
    expect(after, ['D']);
  });

  test('pin keeps pre-suivre items above when optimistic itemId is 0', () {
    final previous = [
      OrderDisplayEntry.product(
        product: const OrderProduct(quantity: '1', name: 'A', price: '5'),
        lineIndex: 0,
        sectionIndex: 0,
        courseNumber: 1,
        itemId: 0,
      ),
      OrderDisplayEntry.product(
        product: const OrderProduct(quantity: '1', name: 'B', price: '5'),
        lineIndex: 1,
        sectionIndex: 0,
        courseNumber: 1,
        itemId: 0,
      ),
      OrderDisplayEntry.product(
        product: const OrderProduct(quantity: '1', name: 'C', price: '5'),
        lineIndex: 2,
        sectionIndex: 0,
        courseNumber: 1,
        itemId: 0,
      ),
      const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
    ];
    // Sync put everything under À SUIVRE (leading divider).
    final next = [
      const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
      OrderDisplayEntry.product(
        product: const OrderProduct(quantity: '1', name: 'A', price: '5'),
        lineIndex: 0,
        sectionIndex: 1,
        courseNumber: 2,
        itemId: 10,
      ),
      OrderDisplayEntry.product(
        product: const OrderProduct(quantity: '1', name: 'B', price: '5'),
        lineIndex: 1,
        sectionIndex: 1,
        courseNumber: 2,
        itemId: 11,
      ),
      OrderDisplayEntry.product(
        product: const OrderProduct(quantity: '1', name: 'C', price: '5'),
        lineIndex: 2,
        sectionIndex: 1,
        courseNumber: 2,
        itemId: 12,
      ),
    ];

    final pinned = OrderMapper.pinProductsRelativeToDividers(
      previous: previous,
      next: next,
    );

    expect(pinned.first.isSectionDivider, isFalse);
    final before = <String>[];
    final after = <String>[];
    var seenDivider = false;
    for (final e in pinned) {
      if (e.isSectionDivider) {
        seenDivider = true;
        continue;
      }
      if (e.product == null) continue;
      (seenDivider ? after : before).add(e.product!.name);
    }
    expect(before, ['A', 'B', 'C']);
    expect(after, isEmpty);
    expect(OrderMapper.suivreSeparatorCount(pinned), 1);
  });

  test('create suivre then reconcile keeps items above empty suite', () {
    final previous = [
      _product(0, 'A', itemId: 1),
      _product(1, 'B', itemId: 2),
      _product(2, 'C', itemId: 3),
      const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
    ];
    final next = [
      const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
      _product(0, 'A', itemId: 1),
      _product(1, 'B', itemId: 2),
      _product(2, 'C', itemId: 3),
    ];

    final reconciled = OrderMapper.reconcileSuivreDisplay(
      previous: previous,
      next: next,
    );

    expect(reconciled.first.isSectionDivider, isFalse);
    expect(
      [
        for (final e in reconciled)
          if (e.type == OrderDisplayEntryType.product) e.product!.name,
      ],
      ['A', 'B', 'C'],
    );
    expect(reconciled.last.type, OrderDisplayEntryType.suivreSeparator);
  });

  test('append course stays under DEMANDÉE after kitchen send', () {
    final withItemsUnder = [
      _product(0, 'A', itemId: 1),
      const OrderDisplayEntry.demande(
        sectionIndex: 1,
        courseNumber: 1,
        demandeTimeLabel: '12:00:00',
      ),
      OrderDisplayEntry.product(
        product: const OrderProduct(quantity: '1', name: 'B', price: '5'),
        lineIndex: 1,
        sectionIndex: 1,
        courseNumber: 2,
        itemId: 2,
      ),
    ];
    expect(OrderMapper.resolveAppendCourseNumberFromLayout(withItemsUnder), 2);

    final trailingDemande = [
      _product(0, 'A', itemId: 1),
      const OrderDisplayEntry.demande(
        sectionIndex: 1,
        courseNumber: 1,
        demandeTimeLabel: '12:00:00',
      ),
    ];
    expect(OrderMapper.resolveAppendCourseNumberFromLayout(trailingDemande), 2);
  });

  test('reconcile does not resurrect deleted À SUIVRE from API', () {
    final previous = [
      _product(0, 'A', itemId: 1),
      const OrderDisplayEntry.demande(
        sectionIndex: 1,
        courseNumber: 1,
        demandeTimeLabel: '12:00:00',
      ),
      _product(1, 'B', itemId: 2),
      const OrderDisplayEntry.suivre(sectionIndex: 2, courseNumber: 2),
    ];
    final next = [
      _product(0, 'A', itemId: 1),
      const OrderDisplayEntry.demande(
        sectionIndex: 1,
        courseNumber: 1,
        demandeTimeLabel: '12:00:00',
      ),
      _product(1, 'B', itemId: 2),
      const OrderDisplayEntry.suivre(sectionIndex: 2, courseNumber: 2),
      _product(2, 'C', itemId: 3),
      const OrderDisplayEntry.suivre(sectionIndex: 3, courseNumber: 3),
      _product(3, 'D', itemId: 4),
    ];

    final reconciled = OrderMapper.reconcileSuivreDisplay(
      previous: previous,
      next: next,
    );

    expect(OrderMapper.suivreSeparatorCount(reconciled), 1);
    expect(OrderMapper.demandeSeparatorCount(reconciled), 1);
  });

  test('create suite after DEMANDÉE adds exactly one À SUIVRE', () {
    final layout = [
      _product(0, 'A', itemId: 1),
      const OrderDisplayEntry.demande(
        sectionIndex: 1,
        courseNumber: 1,
        demandeTimeLabel: '12:00:00',
      ),
      _product(1, 'B', itemId: 2),
      // Ghost empty À SUIVRE left after delete/sync
      const OrderDisplayEntry.suivre(sectionIndex: 2, courseNumber: 2),
    ];

    final cleaned = OrderMapper.stripEmptySuivreSectionsForCreate(layout);
    expect(OrderMapper.suivreSeparatorCount(cleaned), 0);

    final created = OrderMapper.appendSuivreSeparatorAfterRequest(cleaned);
    expect(OrderMapper.suivreSeparatorCount(created), 1);
    expect(created.last.type, OrderDisplayEntryType.suivreSeparator);
  });

  test('predict add after suivre keeps first items above divider', () {
    final layout = [
      OrderDisplayEntry.product(
        product: const OrderProduct(quantity: '1', name: 'A', price: '5'),
        lineIndex: 0,
        sectionIndex: 0,
        courseNumber: 1,
        itemId: 1,
      ),
      OrderDisplayEntry.product(
        product: const OrderProduct(quantity: '1', name: 'B', price: '5'),
        lineIndex: 1,
        sectionIndex: 0,
        courseNumber: 1,
        itemId: 2,
      ),
      OrderDisplayEntry.product(
        product: const OrderProduct(quantity: '1', name: 'C', price: '5'),
        lineIndex: 2,
        sectionIndex: 0,
        courseNumber: 1,
        itemId: 3,
      ),
    ];
    final withSuivre = OrderMapper.appendSuivreSeparatorAfterRequest(layout);
    final current = _order(display: withSuivre);

    final predicted = OrderMapper.predictAfterAppendSimpleProduct(
      current: current,
      productId: 99,
      productName: 'D',
      unitPrice: 5,
      suivreSectionCount: OrderMapper.suivreSeparatorCount(withSuivre),
      suivreSplitHints: OrderMapper.suivreSplitPositions(withSuivre),
    );

    final before = <String>[];
    final after = <String>[];
    var seenDivider = false;
    for (final e in predicted.displayEntries) {
      if (e.isSectionDivider) {
        seenDivider = true;
        continue;
      }
      if (e.product == null) continue;
      (seenDivider ? after : before).add(e.product!.name);
    }
    expect(before, ['A', 'B', 'C']);
    expect(after, ['D']);
  });

  test('finalize strips API À SUIVRE when waiter never opened a suite', () {
    final detail = <String, dynamic>{
      'id': 1,
      'table': {'table_number': 1},
      'seat_orders': [
        {
          'seat_number': 1,
          'courses': [
            {
              'course_number': 1,
              'items': <dynamic>[],
            },
            {
              'course_number': 2,
              'items': [
                {
                  'id': 10,
                  'qty': 1,
                  'status': 'to_be_continued',
                  'product': {'id': 1, 'name': 'A'},
                  'sub_total': 5,
                },
                {
                  'id': 11,
                  'qty': 1,
                  'status': 'to_be_continued',
                  'product': {'id': 2, 'name': 'B'},
                  'sub_total': 5,
                },
              ],
            },
          ],
        },
      ],
    };

    final entries = OrderMapper.finalizeDisplayEntries(
      detail,
      previousDisplayEntries: [
        _product(0, 'A', itemId: 10),
        _product(1, 'B', itemId: 11),
      ],
      suivreCountHint: 0,
    );

    expect(OrderMapper.suivreSeparatorCount(entries), 0);
    expect(entries.first.isSectionDivider, isFalse);
    expect(
      [
        for (final e in entries)
          if (e.type == OrderDisplayEntryType.product) e.product!.name,
      ],
      ['A', 'B'],
    );
  });

  test('merge keeps thinner live ticket after delete (no resurrect)', () {
    final live = _order(
      display: [
        _product(0, 'A', itemId: 1),
        _product(1, 'B', itemId: 2),
      ],
    );
    final server = _order(
      display: [
        _product(0, 'A', itemId: 1),
        _product(1, 'B', itemId: 2),
        _product(2, 'C', itemId: 3),
        const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
        _product(3, 'D', itemId: 4),
      ],
    );

    final merged = OrderMapper.mergeLiveOptimisticDetail(
      server: server,
      live: live,
      suppressItemIds: {3, 4},
    );

    expect(OrderMapper.productEntryCount(merged.displayEntries), 2);
    expect(OrderMapper.suivreSeparatorCount(merged.displayEntries), 0);
    expect(
      [
        for (final e in merged.displayEntries)
          if (e.type == OrderDisplayEntryType.product) e.itemId,
      ],
      [1, 2],
    );
  });

  test('patchServerItemIdsOntoLive keeps layout and assigns ids', () {
    final live = _order(
      display: [
        _product(0, 'A', itemId: 1),
        _product(1, 'B', itemId: 0),
        const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
        _product(2, 'C', itemId: 0),
      ],
    );
    final server = _order(
      display: [
        _product(0, 'A', itemId: 1),
        _product(1, 'X', itemId: 99),
        _product(2, 'B', itemId: 2),
        _product(3, 'C', itemId: 3),
      ],
    );

    final patched = OrderMapper.patchServerItemIdsOntoLive(
      live: live,
      server: server,
      suppressItemIds: {99},
    );

    expect(OrderMapper.suivreSeparatorCount(patched.displayEntries), 1);
    expect(
      [
        for (final e in patched.displayEntries)
          if (e.type == OrderDisplayEntryType.product) e.itemId,
      ],
      [1, 2, 3],
    );
    expect(
      [
        for (final e in patched.displayEntries)
          if (e.type == OrderDisplayEntryType.product) e.product?.name,
      ],
      ['A', 'B', 'C'],
    );
  });

  test('stabilizeLiveLayoutWithServer keeps live order', () {
    final live = [
      _product(0, 'A', itemId: 1),
      _product(1, 'B', itemId: 2),
      const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
    ];
    final server = [
      const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
      _product(0, 'B', itemId: 2),
      _product(1, 'A', itemId: 1),
    ];

    final stabilized = OrderMapper.stabilizeLiveLayoutWithServer(
      live: live,
      server: server,
    );

    expect(stabilized.first.isSectionDivider, isFalse);
    expect(
      [
        for (final e in stabilized)
          if (e.type == OrderDisplayEntryType.product) e.product!.name,
      ],
      ['A', 'B'],
    );
    expect(stabilized.last.type, OrderDisplayEntryType.suivreSeparator);
  });

  test('predict cancel strips empty À SUIVRE after last suite item', () {
    final current = _order(
      display: [
        _product(0, 'A', itemId: 1),
        const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
        _product(1, 'B', itemId: 2),
      ],
    );

    final predicted = OrderMapper.predictAfterCancelLineAtIndex(current, 1);

    expect(OrderMapper.suivreSeparatorCount(predicted.displayEntries), 0);
    expect(predicted.products.length, 1);
    expect(predicted.products.first.name, 'A');
  });

  test('preservePendingSuivreFromLive keeps waiter-opened divider', () {
    final live = _order(
      display: [
        _product(0, 'A', itemId: 1),
        const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
        _product(1, 'B', itemId: 0),
        _product(2, 'C', itemId: 0),
        _product(3, 'D', itemId: 0),
      ],
    );
    final candidate = _order(
      display: [
        _product(0, 'A', itemId: 1),
        _product(1, 'B', itemId: 2),
        _product(2, 'C', itemId: 3),
        _product(3, 'D', itemId: 4),
      ],
    );

    final preserved = OrderMapper.preservePendingSuivreFromLive(
      live: live,
      candidate: candidate,
    );

    expect(OrderMapper.suivreSeparatorCount(preserved.displayEntries), 1);
    expect(OrderMapper.productEntryCount(preserved.displayEntries), 4);
  });

  test('rebake moves suite items from course 1 onto empty course 2', () {
    final detail = <String, dynamic>{
      'id': 1,
      'seat_orders': [
        {
          'seat_number': 1,
          'courses': [
            {
              'id': 10,
              'course_number': 1,
              'status': 'pending',
              'items': [
                {
                  'id': 1,
                  'qty': 1,
                  'status': 'active',
                  'product': {'id': 20, 'name': 'COCA'},
                  'sub_total': 5,
                },
                {
                  'id': 2,
                  'qty': 1,
                  'status': 'active',
                  'product': {'id': 30, 'name': 'AVOCAT'},
                  'sub_total': 5,
                },
                {
                  'id': 3,
                  'qty': 1,
                  'status': 'active',
                  'product': {'id': 30, 'name': 'AVOCAT'},
                  'sub_total': 5,
                },
                {
                  'id': 4,
                  'qty': 1,
                  'status': 'active',
                  'product': {'id': 30, 'name': 'AVOCAT'},
                  'sub_total': 5,
                },
              ],
            },
            {
              'id': 11,
              'course_number': 2,
              'status': 'to_be_continued',
              'items': <dynamic>[],
            },
          ],
        },
      ],
    };

    final layout = [
      _product(0, 'COCA', itemId: 1),
      const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
      _product(1, 'AVOCAT', itemId: 2),
      _product(2, 'AVOCAT', itemId: 3),
      _product(3, 'AVOCAT', itemId: 4),
    ];

    final rebaked = OrderMapper.rebakeSuivreSectionOntoCourse(
      detail,
      layout: layout,
      sectionIndex: 1,
      targetCourseNumber: 2,
    );

    expect(rebaked.changed, isTrue);
    final course2 = OrderMapper.findCourseInOrderDetail(rebaked.detail, 2)!;
    expect(
      [
        for (final item in (course2['items'] as List))
          if (item is Map && item['status'] != 'cancelled') item,
      ].length,
      3,
    );
    expect(
      OrderMapper.extractRequestableCourseIdsForSuivreSection(
        rebaked.detail,
        courseNumber: 2,
      ),
      [11],
    );
  });

  test('ensure puts missing suite items onto empty course 2', () {
    final detail = <String, dynamic>{
      'id': 1,
      'seat_orders': [
        {
          'seat_number': 1,
          'courses': [
            {
              'id': 10,
              'course_number': 1,
              'status': 'pending',
              'items': [
                {
                  'id': 1,
                  'qty': 1,
                  'status': 'active',
                  'product': {'id': 20, 'name': 'COCA'},
                  'sub_total': 5,
                },
                {
                  'id': 2,
                  'qty': 1,
                  'status': 'cancelled',
                  'product': {'id': 30, 'name': 'AVOCAT'},
                  'sub_total': 5,
                },
              ],
            },
            {
              'id': 11,
              'course_number': 2,
              'status': 'to_be_continued',
              'items': <dynamic>[],
            },
          ],
        },
      ],
    };

    final layout = [
      _product(0, 'COCA', itemId: 1),
      const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
      _product(1, 'AVOCAT', itemId: 0),
      _product(2, 'AVOCAT', itemId: 0),
      _product(3, 'AVOCAT', itemId: 0),
    ];

    final ensured = OrderMapper.ensureSuivreSectionOnCourse(
      detail,
      layout: layout,
      sectionIndex: 1,
      targetCourseNumber: 2,
      resolveProductId: (name) =>
          name.toUpperCase() == 'AVOCAT' ? 30 : null,
      resolveUnitPrice: (_) => 5,
    );

    expect(ensured.changed, isTrue);
    final course2 = OrderMapper.findCourseInOrderDetail(ensured.detail, 2)!;
    expect(
      [
        for (final item in (course2['items'] as List))
          if (item is Map && item['status'] != 'cancelled') item,
      ].length,
      3,
    );
    expect(
      OrderMapper.extractRequestableCourseIdsForSuivreSection(
        ensured.detail,
        courseNumber: 2,
      ),
      [11],
    );
  });

  test('pin does not pull suite lines above À SUIVRE when above ids are missing',
      () {
    final previous = [
      _product(0, 'A', itemId: 1),
      _product(1, 'MISSING', itemId: 99), // not on server
      const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
      _product(2, 'D', itemId: 0),
      _product(3, 'E', itemId: 0),
      _product(4, 'F', itemId: 0),
    ];
    final next = [
      _product(0, 'A', itemId: 1),
      _product(1, 'D', itemId: 10),
      _product(2, 'E', itemId: 11),
      _product(3, 'F', itemId: 12),
    ];

    final pinned = OrderMapper.pinProductsRelativeToDividers(
      previous: previous,
      next: next,
    );

    final before = <String>[];
    final after = <String>[];
    var seen = false;
    for (final e in pinned) {
      if (e.isSectionDivider) {
        seen = true;
        continue;
      }
      if (e.product == null) continue;
      (seen ? after : before).add(e.product!.name);
    }
    expect(before, ['A']);
    expect(after, ['D', 'E', 'F']);
  });

  test(
      'stabilize does not pull suite lines above À SUIVRE when above ids missing',
      () {
    final live = [
      _product(0, 'A', itemId: 1),
      _product(1, 'MISSING', itemId: 99),
      const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
      _product(2, 'D', itemId: 0),
      _product(3, 'E', itemId: 0),
      _product(4, 'F', itemId: 0),
    ];
    final server = [
      _product(0, 'A', itemId: 1),
      _product(1, 'D', itemId: 10),
      _product(2, 'E', itemId: 11),
      _product(3, 'F', itemId: 12),
    ];

    final stabilized = OrderMapper.stabilizeLiveLayoutWithServer(
      live: live,
      server: server,
    );

    final before = <String>[];
    final after = <String>[];
    var seen = false;
    for (final e in stabilized) {
      if (e.isSectionDivider) {
        seen = true;
        continue;
      }
      if (e.product == null) continue;
      (seen ? after : before).add(e.product!.name);
    }
    // Unmatched live "MISSING" is kept; suite lines stay under À SUIVRE.
    expect(before, ['A', 'MISSING']);
    expect(after, ['D', 'E', 'F']);
  });

  test(
      'rebuild after Demande keeps suite items under DEMANDÉE when API flattens',
      () {
    final live = [
      const OrderDisplayEntry.demande(
        sectionIndex: 1,
        courseNumber: 1,
        demandeTimeLabel: '13:50:39',
      ),
      _product(0, 'OULMES 1L', itemId: 1),
      _product(1, 'OULMES 50CL', itemId: 2),
      const OrderDisplayEntry.suivre(sectionIndex: 2, courseNumber: 1),
      _product(2, 'COUPE KIDS', itemId: 0),
      _product(3, 'COUPE KIDS', itemId: 0),
      _product(4, 'test grammage', itemId: 0),
      _product(5, 'test grammage', itemId: 0),
      _product(6, 'test grammage', itemId: 0),
    ];
    // Server pin lost suite lines under an empty DEMANDÉE but products[] still
    // has them (total / In order badges).
    final serverDisplay = [
      const OrderDisplayEntry.demande(
        sectionIndex: 1,
        courseNumber: 1,
        demandeTimeLabel: '13:50:39',
      ),
      _product(0, 'OULMES 1L', itemId: 1),
      _product(1, 'OULMES 50CL', itemId: 2),
      const OrderDisplayEntry.demande(
        sectionIndex: 2,
        courseNumber: 1,
        demandeTimeLabel: '13:50:41',
      ),
    ];
    final serverProducts = [
      for (final e in live)
        if (e.type == OrderDisplayEntryType.product && e.product != null)
          e.product!,
    ];
    final server = SessionOrder(
      id: 1,
      number: 'T1',
      numberColor: const Color(0xFF000000),
      group: '1',
      poste: 'A',
      profitCenter: 'SUR PLACE',
      couverts: '3',
      impressionCount: 0,
      impressionColor: const Color(0xFF000000),
      total: '225.00',
      products: serverProducts,
      itemCount: serverProducts.length,
      displayEntries: serverDisplay,
    );

    final rebuilt = OrderMapper.rebuildOrderAfterSuivreDemande(
      serverOrder: server,
      liveLayout: live,
      suivreSectionIndex: 2,
      demandeTimeLabel: '13:50:41',
    );

    expect(OrderMapper.demandeSeparatorCount(rebuilt.displayEntries), 2);
    expect(OrderMapper.suivreSeparatorCount(rebuilt.displayEntries), 0);
    expect(OrderMapper.productEntryCount(rebuilt.displayEntries), 7);
    expect(rebuilt.products.length, 7);

    final underSecond = <String>[];
    var demandeCount = 0;
    for (final e in rebuilt.displayEntries) {
      if (e.isSectionDivider) {
        demandeCount++;
        continue;
      }
      if (demandeCount >= 2 && e.product != null) {
        underSecond.add(e.product!.name);
      }
    }
    expect(underSecond, [
      'COUPE KIDS',
      'COUPE KIDS',
      'test grammage',
      'test grammage',
      'test grammage',
    ]);
  });
}
