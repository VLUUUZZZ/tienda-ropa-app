import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/stock_adjustment.dart';
import 'backoff.dart';
import 'local_adjustments.dart';
import 'remote_adjustments.dart';
import 'sync_state.dart';

/// Keeps a [LocalAdjustments] log and a [RemoteAdjustments] log in step.
///
/// Simpler than [CatalogSync] because adjustments are append-only — same
/// reasoning as [SalesSync], which this mirrors closely.
class AdjustmentsSync {
  AdjustmentsSync({
    required LocalAdjustments local,
    required SyncState state,
    required RemoteAdjustments remote,
    required Backoff backoff,
  }) : _local = local,
       _state = state,
       _remote = remote,
       _backoff = backoff;

  final LocalAdjustments _local;
  final SyncState _state;
  final RemoteAdjustments _remote;
  final Backoff _backoff;

  StreamSubscription<void>? _subscription;
  Timer? _retryTimer;
  bool _running = false;

  void start() {
    if (_running) return;
    _running = true;
    _listen();
    pushAllPending();
  }

  Future<void> stop() async {
    _running = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Uploads the local copy of adjustment [id] and confirms it in
  /// [SyncState] once the remote acknowledges it.
  ///
  /// Not awaited on purpose: Firestore queues writes while offline and its
  /// futures only complete once the server acknowledges them.
  void push(String id) {
    if (!_running) return;
    final token = _state.pendingToken(id);
    if (token == null) return;

    final StockAdjustment? adjustment;
    try {
      adjustment = _local.read(id);
    } catch (e) {
      // Unreadable locally: nothing to upload. Also drops the pending mark,
      // or this id would retry forever and stay pending.
      debugPrint('Ajuste $id ilegible, no se sube: $e');
      unawaited(_state.confirm(id, token));
      return;
    }

    if (adjustment == null) {
      // Shouldn't happen — adjustments are never removed locally — but
      // confirming avoids a pending id with nothing left to push.
      unawaited(_state.confirm(id, token));
      return;
    }

    unawaited(_send(id, adjustment, token));
  }

  Future<void> _send(String id, StockAdjustment adjustment, int token) async {
    try {
      await _remote.upload(adjustment);
      await _state.confirm(id, token);
    } catch (e) {
      // Unlike CatalogSync, there's no remote copy to fall back on if an
      // adjustment was never actually uploaded — dropping the pending mark
      // here (as a rejected catalog write safely does) would silently erase
      // it from every record but this one device's local log. A
      // permission-denied here is also often transient (token/claims not
      // propagated yet right after sign-in) rather than permanent, so it
      // stays pending and keeps retrying on reconnect or the next launch
      // either way.
      debugPrint('No se sincronizó el ajuste $id, se reintentará: $e');
    }
  }

  void pushAllPending() => _state.pendingIds.forEach(push);

  void _listen() {
    // asyncMap applies snapshots one at a time, in order.
    _subscription = _remote
        .watch()
        .asyncMap(_apply)
        .listen(
          (_) => _backoff.reset(),
          onError: (Object e) {
            debugPrint('Error de sincronización de ajustes: $e');
            _scheduleRelisten();
          },
          // Firestore closes the listener after an error (network, rules...),
          // so it has to be re-opened or sync silently stops for the session.
          onDone: _scheduleRelisten,
          cancelOnError: true,
        );
  }

  void _scheduleRelisten() {
    if (!_running || _retryTimer != null) return;
    _subscription = null;
    _retryTimer = Timer(_backoff.next(), () {
      _retryTimer = null;
      if (!_running) return;
      _listen();
      // Writes rejected while the connection was failing get another try.
      pushAllPending();
    });
  }

  /// Merges remote adjustments into the local log, skipping any still
  /// pending upload from this device (the local copy wins until that upload
  /// lands). No deletion step: adjustments are never removed.
  Future<void> _apply(RemoteAdjustmentsSnapshot snapshot) async {
    final pending = _state.pendingIds;
    await _local.writeAllChanged(
      snapshot.items.where((adjustment) => !pending.contains(adjustment.id)),
    );
  }
}
