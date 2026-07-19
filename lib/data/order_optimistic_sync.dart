import 'dart:async';

import '../models/order_display_entry.dart';
import '../models/order_product.dart';
import '../models/session_order.dart';

typedef OrderApply = void Function(SessionOrder order);

/// Serializes background API sync per order while UI updates apply immediately.
///
/// Design for responsiveness (no ANR):
/// - Mutations run one-at-a-time per [syncKey], always yielding to the event
///   loop between jobs so frames can paint.
/// - While more mutations are queued, intermediate API results are **not**
///   applied to the UI (avoids rebuild storms). The last job applies.
/// - Controllers must keep optimistic UI + suppress/epoch guards so skipping
///   intermediate applies cannot resurrect deleted lines.
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
    // Let the UI process taps/frames before starting network + JSON work.
    await Future<void>.delayed(Duration.zero);

    SessionOrder? reconciled;
    Object? error;
    try {
      reconciled = await sync();
    } catch (e) {
      error = e;
    }

    // Yield again before touching GetX/UI state.
    await Future<void>.delayed(Duration.zero);

    final remaining = (_pending[syncKey] ?? 1) - 1;
    if (remaining <= 0) {
      _pending.remove(syncKey);
    } else {
      _pending[syncKey] = remaining;
    }

    if (error != null) {
      // Only the last mutation recovers the UI.
      if (remaining <= 0) {
        try {
          final recovered = await recover(snapshot);
          _applyAsync(apply, recovered);
        } catch (_) {
          _applyAsync(apply, snapshot);
        }
      }
      onError?.call(error);
      return;
    }

    // Skip intermediate applies while more work is queued — prevents ANR from
    // rapid add/delete rebuild storms. The final job applies once.
    if (remaining > 0) return;

    if (reconciled != null) {
      _applyAsync(apply, reconciled);
    }
  }

  /// Apply on a later event-loop turn so the current call stack can finish
  /// painting / handling input first.
  void _applyAsync(OrderApply apply, SessionOrder order) {
    scheduleMicrotask(() {
      try {
        apply(order);
      } catch (_) {
        // Never let a bad apply crash the sync queue.
      }
    });
  }

  bool hasPending(int syncKey) => (_pending[syncKey] ?? 0) > 0;

  /// Waits until every queued mutation for [syncKey] has finished (and its
  /// microtask apply has been scheduled). Used before kitchen send so a
  /// still-in-flight batch add cannot land after DEMANDÉE.
  Future<void> waitUntilIdle(int syncKey) async {
    final pending = _queues[syncKey];
    if (pending != null) {
      try {
        await pending;
      } catch (_) {
        // Queue errors are handled inside the runner; idle is what matters.
      }
    }
    // Let the final scheduleMicrotask apply run before callers read live UI.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  static SessionOrder deepSnapshot(SessionOrder order) {
    return order.copyWith(
      products: List<OrderProduct>.from(order.products),
      displayEntries: List<OrderDisplayEntry>.from(order.displayEntries),
    );
  }
}
