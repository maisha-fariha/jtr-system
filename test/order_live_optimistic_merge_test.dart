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

  test('merge adopts new menu line under open À SUIVRE after bg sync', () {
    final live = _order(
      display: [
        _product(0, 'OULMES', itemId: 1),
        _product(1, 'OULMES', itemId: 2),
        _product(2, 'OULMES', itemId: 3),
        _product(3, 'OULMES', itemId: 4),
        const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
      ],
      total: '60,00 €',
    );
    final server = _order(
      display: [
        _product(0, 'OULMES', itemId: 1),
        _product(1, 'OULMES', itemId: 2),
        _product(2, 'OULMES', itemId: 3),
        _product(3, 'OULMES', itemId: 4),
        _product(4, 'MENU DU JOUR', itemId: 99),
      ],
      total: '135,00 €',
    );

    final merged = OrderMapper.mergeLiveOptimisticDetail(
      server: server,
      live: live,
      preferAdoptingNewServerLines: true,
      selectedSuivreSectionIndex: 1,
    );

    expect(OrderMapper.productEntryCount(merged.displayEntries), 5);
    expect(OrderMapper.suivreSeparatorCount(merged.displayEntries), 1);
    expect(
      merged.displayEntries.last.product?.name,
      'MENU DU JOUR',
    );
    expect(merged.products.length, 5);
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

  test('send all keeps pending À SUIVRE after kitchen send', () {
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
      demandedSectionIndices: const {},
      applyKitchenDemande: false,
    );

    expect(OrderMapper.suivreSeparatorCount(entries), 1);
    expect(OrderMapper.demandeSeparatorCount(entries), 0);
  });

  test('send all keeps À SUIVRE when API marks courses requested', () {
    final previous = [
      _product(0, 'A', itemId: 1),
      const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
      _product(1, 'B', itemId: 2),
      const OrderDisplayEntry.suivre(sectionIndex: 2, courseNumber: 2),
      _product(2, 'C', itemId: 3),
    ];
    final detail = <String, dynamic>{
      'id': 1,
      'seat_orders': [
        {
          'seat_number': 1,
          'courses': [
            {
              'course_number': 1,
              'requested_at': '2026-07-19T12:00:00Z',
              'status': 'requested',
              'items': [
                {
                  'id': 1,
                  'qty': 1,
                  'status': 'sent',
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
                  'status': 'sent',
                  'product': {'id': 11, 'name': 'B'},
                  'sub_total': 5,
                },
              ],
            },
            {
              'course_number': 3,
              'requested_at': '2026-07-19T12:00:00Z',
              'status': 'requested',
              'items': [
                {
                  'id': 3,
                  'qty': 1,
                  'status': 'sent',
                  'product': {'id': 12, 'name': 'C'},
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
      suivreSplitHints: const [1, 2],
      suivreCountHint: 2,
      demandedSectionIndices: const {},
    );

    expect(OrderMapper.suivreSeparatorCount(entries), 2);
    expect(OrderMapper.demandeSeparatorCount(entries), 0);
  });

  test('manual demand section shows DEMANDÉE from persisted hint', () {
    final detail = <String, dynamic>{
      'id': 1,
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
                  'status': 'sent',
                  'product': {'id': 10, 'name': 'A'},
                  'sub_total': 5,
                },
              ],
            },
            {
              'course_number': 2,
              'requested_at': '2026-07-19T12:05:00Z',
              'status': 'requested',
              'items': [
                {
                  'id': 2,
                  'qty': 1,
                  'status': 'sent',
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
      suivreSplitHints: const [1],
      suivreCountHint: 1,
      demandedSectionIndices: const {1},
    );

    expect(OrderMapper.demandeSeparatorCount(entries), 1);
    expect(OrderMapper.suivreSeparatorCount(entries), 0);
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

  test('append course uses selected À SUIVRE not only the last divider', () {
    final layout = [
      _product(0, 'A', itemId: 1),
      const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
      _product(1, 'B', itemId: 2),
      const OrderDisplayEntry.suivre(sectionIndex: 2, courseNumber: 2),
    ];

    expect(
      OrderMapper.resolveAppendCourseNumberFromLayout(
        layout,
        selectedSectionIndex: 1,
      ),
      2,
    );
    expect(
      OrderMapper.resolveAppendCourseNumberFromLayout(
        layout,
        selectedSectionIndex: 2,
      ),
      3,
    );
    expect(OrderMapper.resolveAppendCourseNumberFromLayout(layout), 3);
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

  test(
    'patchServerItemIdsOntoLive keeps menu CHOIX labels when server omits them',
    () {
      final live = _order(
        display: [
          const OrderDisplayEntry.demande(
            sectionIndex: 1,
            courseNumber: 1,
            demandeTimeLabel: '18:53:00',
          ),
          OrderDisplayEntry.product(
            product: const OrderProduct(
              quantity: '1',
              name: 'BOULE DE GLACE',
              price: '20,00 €',
              menuItems: ['VANILLE', 'CHOCOLAT'],
            ),
            lineIndex: 0,
            sectionIndex: 1,
            itemId: 0,
          ),
        ],
      );
      final server = _order(
        display: [
          OrderDisplayEntry.product(
            product: const OrderProduct(
              quantity: '1',
              name: 'BOULE DE GLACE',
              price: '20,00 €',
              // GET after Send often returns ids-only menu_selections.
              menuItems: [],
            ),
            lineIndex: 0,
            itemId: 55,
          ),
        ],
      );

      final patched = OrderMapper.patchServerItemIdsOntoLive(
        live: live,
        server: server,
      );

      expect(OrderMapper.demandeSeparatorCount(patched.displayEntries), 1);
      final menu = patched.displayEntries
          .where((e) => e.type == OrderDisplayEntryType.product)
          .single;
      expect(menu.itemId, 55);
      expect(menu.product?.menuItems, ['VANILLE', 'CHOCOLAT']);
    },
  );

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

  test('relogin split hint keeps both duplicate tops above DEMANDÉE', () {
    // Waiter: 2× Avocat, À SUIVRE, 3× BASE ORANGE — split saved as [2].
    // API drift: 2nd Avocat wrongly on course 2 with oranges.
    final detail = <String, dynamic>{
      'id': 1,
      'seat_orders': [
        {
          'seat_number': 1,
          'courses': [
            {
              'id': 101,
              'course_number': 1,
              'requested_at': '2026-07-20T09:16:58Z',
              'status': 'requested',
              'items': [
                {
                  'id': 1,
                  'course_id': 101,
                  'qty': 1,
                  'status': 'sent',
                  'created_at': '2026-07-20T09:10:00Z',
                  'product': {'id': 20, 'name': 'AVOCAT FRUITS SEC'},
                  'sub_total': 55,
                },
              ],
            },
            {
              'id': 102,
              'course_number': 2,
              'requested_at': '2026-07-20T09:16:58Z',
              'status': 'requested',
              'items': [
                {
                  'id': 2,
                  'course_id': 102,
                  'qty': 1,
                  'status': 'sent',
                  'created_at': '2026-07-20T09:11:00Z',
                  'product': {'id': 20, 'name': 'AVOCAT FRUITS SEC'},
                  'sub_total': 55,
                },
                {
                  'id': 3,
                  'course_id': 102,
                  'qty': 1,
                  'status': 'sent',
                  'created_at': '2026-07-20T09:15:00Z',
                  'product': {'id': 30, 'name': 'BASE ORANGE'},
                  'sub_total': 0.01,
                },
                {
                  'id': 4,
                  'course_id': 102,
                  'qty': 1,
                  'status': 'sent',
                  'created_at': '2026-07-20T09:15:01Z',
                  'product': {'id': 30, 'name': 'BASE ORANGE'},
                  'sub_total': 0.01,
                },
                {
                  'id': 5,
                  'course_id': 102,
                  'qty': 1,
                  'status': 'sent',
                  'created_at': '2026-07-20T09:15:02Z',
                  'product': {'id': 30, 'name': 'BASE ORANGE'},
                  'sub_total': 0.01,
                },
              ],
            },
          ],
        },
      ],
    };

    final fromApiOnly = OrderMapper.finalizeDisplayEntries(
      detail,
      suivreSplitHints: const [],
      applyKitchenDemande: true,
    );
    final namesUnderDemandeApi = <String>[];
    var pastDivider = false;
    for (final e in fromApiOnly) {
      if (e.isSectionDivider) {
        pastDivider = true;
        continue;
      }
      if (pastDivider && e.product != null) {
        namesUnderDemandeApi.add(e.product!.name);
      }
    }
    expect(namesUnderDemandeApi.first, 'AVOCAT FRUITS SEC');

    final fromHints = OrderMapper.finalizeDisplayEntries(
      detail,
      suivreSplitHints: const [2],
      applyKitchenDemande: true,
    );
    expect(OrderMapper.demandeSeparatorCount(fromHints), 1);

    final above = <String>[];
    final under = <String>[];
    var section = 0;
    for (final e in fromHints) {
      if (e.isSectionDivider) {
        section = 1;
        continue;
      }
      if (e.product == null) continue;
      if (section == 0) {
        above.add(e.product!.name);
      } else {
        under.add(e.product!.name);
      }
    }
    expect(above, ['AVOCAT FRUITS SEC', 'AVOCAT FRUITS SEC']);
    expect(under, ['BASE ORANGE', 'BASE ORANGE', 'BASE ORANGE']);
  });

  test('flat layout always appends to course 1 even if product.courseNumber is 2',
      () {
    final flatWithStaleCourseNumbers = [
      OrderDisplayEntry.product(
        product: const OrderProduct(quantity: '1', name: 'A', price: '5'),
        lineIndex: 0,
        courseNumber: 2,
        itemId: 1,
      ),
    ];
    expect(
      OrderMapper.resolveAppendCourseNumberFromLayout(
        flatWithStaleCourseNumbers,
      ),
      1,
    );
  });

  test('relogin split hints restore DEMANDÉE then pending À SUIVRE', () {
    // 3× Coca, demand suite (Diver + Coca Zero), new À SUIVRE (Hawaii) — splits [3, 5].
    final detail = <String, dynamic>{
      'id': 1,
      'seat_orders': [
        {
          'seat_number': 1,
          'courses': [
            {
              'id': 101,
              'course_number': 1,
              'requested_at': '2026-07-20T10:00:00Z',
              'status': 'requested',
              'items': [
                for (var i = 1; i <= 3; i++)
                  {
                    'id': i,
                    'course_id': 101,
                    'qty': 1,
                    'status': 'sent',
                    'created_at': '2026-07-20T09:${10 + i}:00Z',
                    'product': {'id': 10, 'name': 'COCA COLA'},
                    'sub_total': 25,
                  },
              ],
            },
            {
              'id': 102,
              'course_number': 2,
              'requested_at': '2026-07-20T10:05:00Z',
              'status': 'requested',
              'items': [
                {
                  'id': 4,
                  'course_id': 102,
                  'qty': 1,
                  'status': 'sent',
                  'created_at': '2026-07-20T09:20:00Z',
                  'product': {'id': 20, 'name': 'DIVER BOISSON'},
                  'sub_total': 0,
                },
                {
                  'id': 5,
                  'course_id': 102,
                  'qty': 1,
                  'status': 'sent',
                  'created_at': '2026-07-20T09:21:00Z',
                  'product': {'id': 30, 'name': 'COCA ZERO'},
                  'sub_total': 25,
                },
              ],
            },
            {
              'id': 103,
              'course_number': 3,
              'status': 'pending',
              'items': [
                {
                  'id': 6,
                  'course_id': 103,
                  'qty': 1,
                  'status': 'pending',
                  'created_at': '2026-07-20T09:22:00Z',
                  'product': {'id': 40, 'name': 'HAWAII'},
                  'sub_total': 25,
                },
              ],
            },
          ],
        },
      ],
    };

    final entries = OrderMapper.finalizeDisplayEntries(
      detail,
      suivreSplitHints: const [3, 5],
      suivreCountHint: 2,
      demandedSectionIndices: const {1},
    );

    expect(OrderMapper.sectionDividerCount(entries), 2);
    expect(OrderMapper.demandeSeparatorCount(entries), 1);
    expect(OrderMapper.suivreSeparatorCount(entries), 1);

    final namesAbove = <String>[];
    final namesUnderDemande = <String>[];
    final namesUnderSuivre = <String>[];
    var section = 0;
    for (final e in entries) {
      if (e.type == OrderDisplayEntryType.demandeSeparator) {
        section = 1;
        continue;
      }
      if (e.type == OrderDisplayEntryType.suivreSeparator) {
        section = 2;
        continue;
      }
      if (e.product == null) continue;
      if (section == 0) {
        namesAbove.add(e.product!.name);
      } else if (section == 1) {
        namesUnderDemande.add(e.product!.name);
      } else {
        namesUnderSuivre.add(e.product!.name);
      }
    }

    expect(namesAbove, ['COCA COLA', 'COCA COLA', 'COCA COLA']);
    expect(namesUnderDemande, ['DIVER BOISSON', 'COCA ZERO']);
    expect(namesUnderSuivre, ['HAWAII']);
  });

  test('relogin keeps back-to-back dividers at same product boundary', () {
    // Demand empty section then open new À SUIVRE — split hints [3, 3].
    final detail = <String, dynamic>{
      'id': 1,
      'seat_orders': [
        {
          'seat_number': 1,
          'courses': [
            {
              'id': 101,
              'course_number': 1,
              'requested_at': '2026-07-20T10:00:00Z',
              'status': 'requested',
              'items': [
                for (var i = 1; i <= 3; i++)
                  {
                    'id': i,
                    'course_id': 101,
                    'qty': 1,
                    'status': 'sent',
                    'created_at': '2026-07-20T09:${10 + i}:00Z',
                    'product': {'id': 10, 'name': 'COCA COLA'},
                    'sub_total': 25,
                  },
              ],
            },
            {
              'id': 102,
              'course_number': 2,
              'requested_at': '2026-07-20T10:05:00Z',
              'status': 'requested',
              'items': <dynamic>[],
            },
            {
              'id': 103,
              'course_number': 3,
              'status': 'pending',
              'items': [
                {
                  'id': 6,
                  'course_id': 103,
                  'qty': 1,
                  'status': 'pending',
                  'created_at': '2026-07-20T09:22:00Z',
                  'product': {'id': 40, 'name': 'HAWAII'},
                  'sub_total': 25,
                },
              ],
            },
          ],
        },
      ],
    };

    final entries = OrderMapper.finalizeDisplayEntries(
      detail,
      suivreSplitHints: const [3, 3],
      suivreCountHint: 2,
      demandedSectionIndices: const {1},
    );

    expect(OrderMapper.sectionDividerCount(entries), 2);
    expect(OrderMapper.demandeSeparatorCount(entries), 1);
    expect(OrderMapper.suivreSeparatorCount(entries), 1);

    final namesUnderSuivre = <String>[];
    var pastSuivre = false;
    for (final e in entries) {
      if (e.type == OrderDisplayEntryType.suivreSeparator) {
        pastSuivre = true;
        continue;
      }
      if (pastSuivre && e.product != null) {
        namesUnderSuivre.add(e.product!.name);
      }
    }
    expect(namesUnderSuivre, ['HAWAII']);
  });

  test('API course groups show À SUIVRE between each course without Hive hints',
      () {
    final detail = <String, dynamic>{
      'id': 408,
      'seat_orders': [
        {
          'seat_number': 1,
          'courses': [
            {
              'course_number': 1,
              'requested_at': '2026-07-21T12:36:02.000000Z',
              'items': [
                {
                  'id': 4444,
                  'qty': 1,
                  'status': 'to_be_continued',
                  'product': {'id': 16, 'name': 'COUPE KIDS'},
                  'sub_total': 45,
                },
                {
                  'id': 4445,
                  'qty': 1,
                  'status': 'to_be_continued',
                  'product': {'id': 16, 'name': 'COUPE KIDS'},
                  'sub_total': 45,
                },
                {
                  'id': 4446,
                  'qty': 1,
                  'status': 'to_be_continued',
                  'product': {'id': 74, 'name': 'test grammage'},
                  'sub_total': 10,
                },
              ],
            },
            {
              'course_number': 2,
              'items': [
                for (var id = 4447; id <= 4449; id++)
                  {
                    'id': id,
                    'qty': 1,
                    'status': 'to_be_continued',
                    'product': {'id': 16, 'name': 'COUPE KIDS'},
                    'sub_total': 45,
                  },
              ],
            },
            {
              'course_number': 3,
              'items': [
                {
                  'id': 4450,
                  'qty': 1,
                  'status': 'to_be_continued',
                  'product': {'id': 64, 'name': 'OULMES 1L'},
                  'sub_total': 30,
                },
                {
                  'id': 4451,
                  'qty': 1,
                  'status': 'to_be_continued',
                  'product': {'id': 63, 'name': 'OULMES 50CL'},
                  'sub_total': 15,
                },
                {
                  'id': 4452,
                  'qty': 1,
                  'status': 'to_be_continued',
                  'product': {'id': 62, 'name': 'SIDI ALI 1L'},
                  'sub_total': 30,
                },
              ],
            },
            {
              'course_number': 4,
              'items': [
                for (var id = 4453; id <= 4454; id++)
                  {
                    'id': id,
                    'qty': 1,
                    'status': 'to_be_continued',
                    'product': {'id': 61, 'name': 'SIDI ALI 50CL'},
                    'sub_total': 15,
                  },
              ],
            },
          ],
        },
      ],
    };

    final entries = OrderMapper.finalizeDisplayEntries(detail);

    expect(OrderMapper.countFollowUpCoursesWithItems(detail), 3);
    expect(OrderMapper.suivreSeparatorCount(entries), 3);
    expect(OrderMapper.productEntryCount(entries), 11);

    final sections = <int>[];
    for (final entry in entries) {
      if (entry.type == OrderDisplayEntryType.product) {
        sections.add(entry.sectionIndex ?? 0);
      }
    }
    expect(sections.where((s) => s == 0).length, 3);
    expect(sections.where((s) => s == 1).length, 3);
    expect(sections.where((s) => s == 2).length, 3);
    expect(sections.where((s) => s == 3).length, 2);
  });

  test(
      'finalize keeps API course dividers when session row is flat but first course has items',
      () {
    final detail = <String, dynamic>{
      'id': 408,
      'seat_orders': [
        {
          'seat_number': 1,
          'courses': [
            {
              'course_number': 1,
              'requested_at': '2026-07-21T12:36:02.000000Z',
              'items': [
                {
                  'id': 4444,
                  'qty': 1,
                  'status': 'to_be_continued',
                  'product': {'id': 16, 'name': 'COUPE KIDS'},
                  'sub_total': 45,
                },
                {
                  'id': 4445,
                  'qty': 1,
                  'status': 'to_be_continued',
                  'product': {'id': 16, 'name': 'COUPE KIDS'},
                  'sub_total': 45,
                },
                {
                  'id': 4446,
                  'qty': 1,
                  'status': 'to_be_continued',
                  'product': {'id': 74, 'name': 'test grammage'},
                  'sub_total': 10,
                },
              ],
            },
            {
              'course_number': 2,
              'items': [
                for (var id = 4447; id <= 4449; id++)
                  {
                    'id': id,
                    'qty': 1,
                    'status': 'to_be_continued',
                    'product': {'id': 16, 'name': 'COUPE KIDS'},
                    'sub_total': 45,
                  },
              ],
            },
            {
              'course_number': 3,
              'items': [
                {
                  'id': 4450,
                  'qty': 1,
                  'status': 'to_be_continued',
                  'product': {'id': 64, 'name': 'OULMES 1L'},
                  'sub_total': 30,
                },
                {
                  'id': 4451,
                  'qty': 1,
                  'status': 'to_be_continued',
                  'product': {'id': 63, 'name': 'OULMES 50CL'},
                  'sub_total': 15,
                },
                {
                  'id': 4452,
                  'qty': 1,
                  'status': 'to_be_continued',
                  'product': {'id': 62, 'name': 'SIDI ALI 1L'},
                  'sub_total': 30,
                },
              ],
            },
            {
              'course_number': 4,
              'items': [
                for (var id = 4453; id <= 4454; id++)
                  {
                    'id': id,
                    'qty': 1,
                    'status': 'to_be_continued',
                    'product': {'id': 61, 'name': 'SIDI ALI 50CL'},
                    'sub_total': 15,
                  },
              ],
            },
          ],
        },
      ],
    };

    final flatPrevious = [
      for (final id in [
        4445,
        4444,
        4446,
        4447,
        4448,
        4449,
        4450,
        4451,
        4452,
        4453,
        4454,
      ])
        _product(id - 4444, 'item $id', itemId: id),
    ];

    final entries = OrderMapper.finalizeDisplayEntries(
      detail,
      previousDisplayEntries: flatPrevious,
    );

    expect(OrderMapper.apiHasFirstCourseWithItemsAndFollowUps(detail), isTrue);
    expect(OrderMapper.suivreSeparatorCount(entries), 3);
    expect(OrderMapper.productEntryCount(entries), 11);
  });

  test('merge keeps API course dividers when live session row is flat', () {
    final detail = <String, dynamic>{
      'id': 408,
      'seat_orders': [
        {
          'seat_number': 1,
          'courses': [
            {
              'course_number': 1,
              'items': [
                {
                  'id': 4444,
                  'qty': 1,
                  'status': 'to_be_continued',
                  'product': {'id': 16, 'name': 'COUPE KIDS'},
                  'sub_total': 45,
                },
                {
                  'id': 4445,
                  'qty': 1,
                  'status': 'to_be_continued',
                  'product': {'id': 16, 'name': 'COUPE KIDS'},
                  'sub_total': 45,
                },
                {
                  'id': 4446,
                  'qty': 1,
                  'status': 'to_be_continued',
                  'product': {'id': 74, 'name': 'test grammage'},
                  'sub_total': 10,
                },
              ],
            },
            {
              'course_number': 2,
              'items': [
                for (var id = 4447; id <= 4449; id++)
                  {
                    'id': id,
                    'qty': 1,
                    'status': 'to_be_continued',
                    'product': {'id': 16, 'name': 'COUPE KIDS'},
                    'sub_total': 45,
                  },
              ],
            },
            {
              'course_number': 3,
              'items': [
                {
                  'id': 4450,
                  'qty': 1,
                  'status': 'to_be_continued',
                  'product': {'id': 64, 'name': 'OULMES 1L'},
                  'sub_total': 30,
                },
              ],
            },
            {
              'course_number': 4,
              'items': [
                {
                  'id': 4453,
                  'qty': 1,
                  'status': 'to_be_continued',
                  'product': {'id': 61, 'name': 'SIDI ALI 50CL'},
                  'sub_total': 15,
                },
              ],
            },
          ],
        },
      ],
    };

    final serverEntries = OrderMapper.finalizeDisplayEntries(detail);
    final flatLive = [
      for (final entry in serverEntries)
        if (entry.type == OrderDisplayEntryType.product) entry,
    ];

    final merged = OrderMapper.mergeLiveOptimisticDetail(
      server: _order(display: serverEntries, total: '340.00'),
      live: _order(display: flatLive, total: '340.00'),
    );

    expect(OrderMapper.suivreSeparatorCount(merged.displayEntries), 3);
    expect(OrderMapper.productEntryCount(merged.displayEntries), 8);
  });

  test('split hints restore multiple suites when API parks items on course 1',
      () {
    // API: 19 lines on course 1, 3 on course 2 — waiter had 3 À SUIVRE splits.
    final detail = <String, dynamic>{
      'id': 407,
      'seat_orders': [
        {
          'seat_number': 1,
          'courses': [
            {
              'course_number': 1,
              'requested_at': '2026-07-21T12:22:01.000000Z',
              'items': [
                for (var i = 1; i <= 19; i++)
                  {
                    'id': i,
                    'course_number': 1,
                    'qty': 1,
                    'status': 'to_be_continued',
                    'created_at':
                        '2026-07-21T12:19:${(35 + i).toString().padLeft(2, '0')}.000000Z',
                    'product': {'id': i, 'name': 'P$i'},
                    'sub_total': 10,
                  },
              ],
            },
            {
              'course_number': 2,
              'requested_at': '2026-07-21T12:26:28.000000Z',
              'items': [
                for (var i = 20; i <= 22; i++)
                  {
                    'id': i,
                    'course_number': 2,
                    'qty': 1,
                    'status': 'to_be_continued',
                    'created_at': '2026-07-21T12:21:40.000000Z',
                    'product': {'id': i, 'name': 'P$i'},
                    'sub_total': 10,
                  },
              ],
            },
            for (var n = 3; n <= 5; n++)
              {
                'course_number': n,
                'requested_at': '2026-07-21T12:22:01.000000Z',
                'items': <dynamic>[],
              },
          ],
        },
      ],
    };

    final flatPrevious = [
      for (var i = 0; i < 22; i++)
        _product(i, 'P${i + 1}', itemId: i + 1),
    ];

    final entries = OrderMapper.finalizeDisplayEntries(
      detail,
      previousDisplayEntries: flatPrevious,
      suivreSplitHints: const [6, 12, 18],
      suivreCountHint: 3,
      demandedSectionIndices: const {1},
    );

    expect(OrderMapper.sectionDividerCount(entries), 3);
    expect(OrderMapper.demandeSeparatorCount(entries), 1);
    expect(OrderMapper.suivreSeparatorCount(entries), 2);
    expect(OrderMapper.productEntryCount(entries), 22);
  });

  test('fresh install shows DEMANDÉE for manually requested follow-up courses',
      () {
    final detail = <String, dynamic>{
      'id': 409,
      'seat_orders': [
        {
          'seat_number': 1,
          'courses': [
            {
              'course_number': 1,
              'requested_at': '2026-07-21T13:14:44.000000Z',
              'items': [
                for (final id in [4456, 4457, 4458, 4459, 4460])
                  {
                    'id': id,
                    'qty': 1,
                    'status': 'to_be_continued',
                    'product': {
                      'id': id == 4457 || id == 4459 || id == 4460 ? 74 : 16,
                      'name': id == 4457 || id == 4459 || id == 4460
                          ? 'test grammage'
                          : 'COUPE KIDS',
                    },
                    'sub_total': id == 4457 || id == 4459 || id == 4460 ? 10 : 45,
                  },
              ],
            },
            {
              'id': 2198,
              'course_number': 2,
              'items': <dynamic>[],
            },
            {
              'id': 2199,
              'course_number': 3,
              'requested_at': '2026-07-21T13:19:06.000000Z',
              'items': [
                for (final id in [4465, 4466])
                  {
                    'id': id,
                    'qty': 1,
                    'status': 'to_be_continued',
                    'product': {'id': 16, 'name': 'COUPE KIDS'},
                    'sub_total': 45,
                  },
              ],
            },
            {
              'id': 2200,
              'course_number': 4,
              'requested_at': '2026-07-21T13:19:17.000000Z',
              'items': [
                for (final id in [4463, 4464])
                  {
                    'id': id,
                    'qty': 1,
                    'status': 'to_be_continued',
                    'product': {'id': 62, 'name': 'SIDI ALI 1L'},
                    'sub_total': 30,
                  },
              ],
            },
          ],
        },
      ],
    };

    final entries = OrderMapper.finalizeDisplayEntries(detail);

    expect(OrderMapper.demandeSeparatorCount(entries), 2);
    expect(OrderMapper.suivreSeparatorCount(entries), 0);
    expect(OrderMapper.countFollowUpCoursesWithItems(detail), 2);

    final names = <String>[
      for (final entry in entries)
        if (entry.type == OrderDisplayEntryType.product)
          entry.product!.name,
    ];
    final kidsAfterFirstDemande = names.indexOf('COUPE KIDS', 5);
    final sidiIndex = names.indexOf('SIDI ALI 1L');
    expect(kidsAfterFirstDemande, lessThan(sidiIndex));
  });

  test('extractKitchenSendCourseIds returns every pending course', () {
    final detail = <String, dynamic>{
      'id': 1,
      'seat_orders': [
        {
          'seat_number': 1,
          'courses': [
            {
              'id': 101,
              'course_number': 1,
              'requested_at': '2026-07-20T10:00:00Z',
              'status': 'requested',
              'items': [
                {
                  'id': 1,
                  'course_id': 101,
                  'qty': 1,
                  'status': 'sent',
                  'product': {'id': 1, 'name': 'A'},
                  'sub_total': 5,
                },
              ],
            },
            {
              'id': 102,
              'course_number': 2,
              'status': 'pending',
              'items': [
                {
                  'id': 2,
                  'course_id': 102,
                  'qty': 1,
                  'status': 'pending',
                  'product': {'id': 2, 'name': 'B'},
                  'sub_total': 5,
                },
              ],
            },
            {
              'id': 103,
              'course_number': 3,
              'status': 'pending',
              'items': [
                {
                  'id': 3,
                  'course_id': 103,
                  'qty': 1,
                  'status': 'pending',
                  'product': {'id': 3, 'name': 'C'},
                  'sub_total': 5,
                },
              ],
            },
          ],
        },
      ],
    };

    final layout = [
      _product(0, 'A', itemId: 1),
      const OrderDisplayEntry.demande(
        sectionIndex: 1,
        courseNumber: 1,
        demandeTimeLabel: '10:00',
      ),
      _product(1, 'B', itemId: 2),
      const OrderDisplayEntry.suivre(sectionIndex: 2, courseNumber: 2),
      _product(2, 'C', itemId: 3),
    ];

    final ids = OrderMapper.extractKitchenSendCourseIds(
      detail,
      layoutHints: layout,
    );
    expect(ids.toSet(), {102, 103});
  });

  test('extractSingleNextCourseIdForDemande returns only first pending suite',
      () {
    final detail = <String, dynamic>{
      'id': 1,
      'seat_orders': [
        {
          'seat_number': 1,
          'courses': [
            {
              'id': 101,
              'course_number': 1,
              'requested_at': '2026-07-20T10:00:00Z',
              'status': 'requested',
              'items': [
                {
                  'id': 1,
                  'course_id': 101,
                  'qty': 1,
                  'status': 'sent',
                  'product': {'id': 1, 'name': 'A'},
                  'sub_total': 5,
                },
              ],
            },
            {
              'id': 102,
              'course_number': 2,
              'status': 'pending',
              'items': [
                {
                  'id': 2,
                  'course_id': 102,
                  'qty': 1,
                  'status': 'pending',
                  'product': {'id': 2, 'name': 'B'},
                  'sub_total': 5,
                },
              ],
            },
            {
              'id': 103,
              'course_number': 3,
              'status': 'pending',
              'items': [
                {
                  'id': 3,
                  'course_id': 103,
                  'qty': 1,
                  'status': 'pending',
                  'product': {'id': 3, 'name': 'C'},
                  'sub_total': 5,
                },
              ],
            },
          ],
        },
      ],
    };

    final layout = [
      _product(0, 'A', itemId: 1),
      const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
      _product(1, 'B', itemId: 2),
      const OrderDisplayEntry.suivre(sectionIndex: 2, courseNumber: 2),
      _product(2, 'C', itemId: 3),
    ];

    final ids = OrderMapper.extractSingleNextCourseIdForDemande(
      detail,
      layout: layout,
    );
    expect(ids, [102]);
  });

  test(
      'extractSingleNextCourseIdForDemande picks next suivre after first demanded',
      () {
    final detail = <String, dynamic>{
      'id': 1,
      'seat_orders': [
        {
          'seat_number': 1,
          'courses': [
            {
              'id': 101,
              'course_number': 1,
              'requested_at': '2026-07-20T10:00:00Z',
              'status': 'requested',
              'items': [
                {
                  'id': 1,
                  'course_id': 101,
                  'qty': 1,
                  'status': 'sent',
                  'product': {'id': 1, 'name': 'A'},
                  'sub_total': 5,
                },
              ],
            },
            {
              'id': 102,
              'course_number': 2,
              'requested_at': '2026-07-20T10:05:00Z',
              'status': 'requested',
              'items': [
                {
                  'id': 2,
                  'course_id': 102,
                  'qty': 1,
                  'status': 'sent',
                  'product': {'id': 2, 'name': 'B'},
                  'sub_total': 5,
                },
              ],
            },
            {
              'id': 103,
              'course_number': 3,
              'status': 'pending',
              'items': [
                {
                  'id': 3,
                  'course_id': 103,
                  'qty': 1,
                  'status': 'pending',
                  'product': {'id': 3, 'name': 'C'},
                  'sub_total': 5,
                },
              ],
            },
          ],
        },
      ],
    };

    final layout = [
      _product(0, 'A', itemId: 1),
      const OrderDisplayEntry.demande(
        sectionIndex: 1,
        courseNumber: 1,
        demandeTimeLabel: '10:05',
      ),
      _product(1, 'B', itemId: 2),
      const OrderDisplayEntry.suivre(sectionIndex: 2, courseNumber: 2),
      _product(2, 'C', itemId: 3),
    ];

    final ids = OrderMapper.extractSingleNextCourseIdForDemande(
      detail,
      layout: layout,
    );
    expect(ids, [103]);
  });

  test('ensureSessionDisplayHydrated keeps empty display for summary rows', () {
    final summary = OrderMapper.sessionOrderSummaryFromListMap({
      'id': 408,
      'table_number': 'T1',
      'total_price': '345',
      'number_of_guests': 3,
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
                  'sub_total': 45,
                  'product': {'name': 'COUPE KIDS'},
                },
                {
                  'id': 2,
                  'qty': 1,
                  'sub_total': 45,
                  'product': {'name': 'MENU'},
                },
              ],
            },
            {
              'course_number': 2,
              'items': [
                {
                  'id': 3,
                  'qty': 1,
                  'sub_total': 30,
                  'product': {'name': 'DESSERT'},
                },
              ],
            },
          ],
        },
      ],
    });

    final hydrated = OrderMapper.ensureSessionDisplayHydrated(summary);
    expect(hydrated.displayEntries, isEmpty);
    expect(OrderMapper.sessionListDetailIsHydrated(hydrated), isFalse);
  });

  test('session list summary is not hydrated until detail layout loads', () {
    final summary = OrderMapper.sessionOrderSummaryFromListMap({
      'id': 408,
      'table_number': 'T1',
      'total_price': '345',
      'number_of_guests': 3,
      'items_count': 10,
      'seat_orders': [
        {
          'seat_number': 1,
          'courses': [
            {
              'course_number': 1,
              'items': [
                {
                  'id': 1,
                  'quantity': 1,
                  'product': {'name': 'COUPE KIDS', 'price': 45},
                },
              ],
            },
          ],
        },
      ],
    });

    expect(summary.displayEntries, isEmpty);
    expect(summary.itemCount, 10);
    expect(OrderMapper.sessionListDetailIsHydrated(summary), isFalse);
  });

  test('sessionListDetailIsHydrated true when course dividers present', () {
    final order = _order(
      display: [
        _product(0, 'A', itemId: 1),
        const OrderDisplayEntry.suivre(sectionIndex: 1, courseNumber: 1),
        _product(1, 'B', itemId: 2),
      ],
    );

    expect(OrderMapper.sessionListDetailIsHydrated(order), isTrue);
  });

  test('sessionListDetailIsHydrated true for single-course detail with item ids', () {
    final order = _order(
      display: [
        _product(0, 'A', itemId: 1),
        _product(1, 'B', itemId: 2),
      ],
    );

    expect(OrderMapper.sessionListDetailIsHydrated(order), isTrue);
  });
}
