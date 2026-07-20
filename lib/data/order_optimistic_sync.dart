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
/// - A generation token drops stale applies so deleted lines do not flash back.
/// - Applies run inline after yields (no microtask defer) to close the race
///   where a newer optimistic delete landed before a deferred apply ran.
class OrderOptimisticSync {
  final Map<int, Future<void>> _queues = {};
  final Map<int, int> _pending = {};
  final Map<int, int> _generation = {};

  void enqueue({
    required int syncKey,
    required SessionOrder snapshot,
    required OrderApply apply,
    required Future<SessionOrder> Function() sync,
    required Future<SessionOrder> Function(SessionOrder snapshot) recover,
    void Function(Object error)? onError,
  }) {
    _pending[syncKey] = (_pending[syncKey] ?? 0) + 1;
    final jobGeneration = (_generation[syncKey] ?? 0) + 1;
    _generation[syncKey] = jobGeneration;

    final task = (_queues[syncKey] ?? Future<void>.value())
        .catchError((_) {})
        .then((_) => _runQueuedMutation(
              syncKey: syncKey,
              applyGeneration: jobGeneration,
              snapshot: snapshot,
              apply: apply,
              sync: sync,
              recover: recover,
              onError: onError,
            ));

    _queues[syncKey] = task;
    unawaited(task);
  }

  /// Bumps generation so in-flight jobs drop their apply without enqueueing.
  ///
  /// Call when the waiter mutates the ticket locally (add / À SUIVRE) so a
  /// late delete response cannot rebuild the visible layout.
  void invalidateApplies(int syncKey) {
    _generation[syncKey] = (_generation[syncKey] ?? 0) + 1;
  }

  Future<void> _runQueuedMutation({
    required int syncKey,
    required int applyGeneration,
    required SessionOrder snapshot,
    required OrderApply apply,
    required Future<SessionOrder> Function() sync,
    required Future<SessionOrder> Function(SessionOrder snapshot) recover,
    void Function(Object error)? onError,
  }) async {
    await Future<void>.delayed(Duration.zero);

    SessionOrder? reconciled;
    Object? error;
    try {
      reconciled = await sync();
    } catch (e) {
      error = e;
    }

    await Future<void>.delayed(Duration.zero);

    final remaining = (_pending[syncKey] ?? 1) - 1;
    if (remaining <= 0) {
      _pending.remove(syncKey);
    } else {
      _pending[syncKey] = remaining;
    }

    if (error != null) {
      if (remaining <= 0) {
        try {
          final recovered = await recover(snapshot);
          _safeApply(
            syncKey: syncKey,
            applyGeneration: applyGeneration,
            apply: apply,
            order: recovered,
          );
        } catch (_) {
          // Never apply the pre-delete snapshot — that resurrects lines.
        }
      }
      onError?.call(error);
      return;
    }

    if (remaining > 0) return;

    if (reconciled != null) {
      _safeApply(
        syncKey: syncKey,
        applyGeneration: applyGeneration,
        apply: apply,
        order: reconciled,
      );
    }
  }

  void _safeApply({
    required int syncKey,
    required int applyGeneration,
    required OrderApply apply,
    required SessionOrder order,
  }) {
    if ((_pending[syncKey] ?? 0) > 0) return;
    if ((_generation[syncKey] ?? 0) != applyGeneration) return;
    try {
      apply(order);
    } catch (_) {}
  }

  bool hasPending(int syncKey) => (_pending[syncKey] ?? 0) > 0;

  Future<void> waitUntilIdle(int syncKey) async {
    final pending = _queues[syncKey];
    if (pending != null) {
      try {
        await pending;
      } catch (_) {}
    }
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
