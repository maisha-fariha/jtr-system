import 'dart:async';

import '../models/order_display_entry.dart';
import '../models/order_product.dart';
import '../models/session_order.dart';

typedef OrderApply = void Function(SessionOrder order);

/// Serializes background API sync per order while UI updates apply immediately.
///
/// Intermediate server responses are **not** pushed to the UI — only the result
/// of the last pending mutation is applied, so rapid taps don't flash stale data.
class OrderOptimisticSync {
  final Map<int, Future<void>> _queues = {};
  final Map<int, int> _pending = {};

  void enqueue({
    required int syncKey,
    required SessionOrder snapshot,
    required OrderApply apply,
    required Future<SessionOrder> Function() sync,
    required Future<SessionOrder> Function(SessionOrder snapshot) recover,
    void Function(Object error)? onError,
  }) {
    _pending[syncKey] = (_pending[syncKey] ?? 0) + 1;

    final task = (_queues[syncKey] ?? Future<void>.value())
        .catchError((_) {})
        .then((_) => _runQueuedMutation(
              syncKey: syncKey,
              snapshot: snapshot,
              apply: apply,
              sync: sync,
              recover: recover,
              onError: onError,
            ));

    _queues[syncKey] = task;
    unawaited(task);
  }

  Future<void> _runQueuedMutation({
    required int syncKey,
    required SessionOrder snapshot,
    required OrderApply apply,
    required Future<SessionOrder> Function() sync,
    required Future<SessionOrder> Function(SessionOrder snapshot) recover,
    void Function(Object error)? onError,
  }) async {
    SessionOrder? reconciled;
    Object? error;
    try {
      reconciled = await sync();
    } catch (e) {
      error = e;
    }

    final remaining = (_pending[syncKey] ?? 1) - 1;
    if (remaining <= 0) {
      _pending.remove(syncKey);
    } else {
      _pending[syncKey] = remaining;
    }

    if (error != null) {
      // Only the last mutation in the queue recovers the UI — earlier failures
      // must not overwrite a newer optimistic ticket (e.g. add after delete).
      if (remaining <= 0) {
        try {
          final recovered = await recover(snapshot);
          apply(recovered);
        } catch (_) {
          apply(snapshot);
        }
      }
      onError?.call(error);
      return;
    }

    // Always apply successful results in order. Skipping intermediate applies
    // caused delete/add races: the add response could reintroduce a line the
    // delete already removed on the server / in the optimistic UI.
    if (reconciled != null) {
      apply(reconciled);
    }
  }

  bool hasPending(int syncKey) => (_pending[syncKey] ?? 0) > 0;

  static SessionOrder deepSnapshot(SessionOrder order) {
    return order.copyWith(
      products: List<OrderProduct>.from(order.products),
      displayEntries: List<OrderDisplayEntry>.from(order.displayEntries),
    );
  }
}
