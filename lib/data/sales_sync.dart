import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/sale.dart';
import 'backoff.dart';
import 'local_sales.dart';
import 'remote_sales.dart';
import 'sync_state.dart';

/// Keeps a [LocalSales] log and a [RemoteSales] log in step.
///
/// Simpler than [CatalogSync] because sales are append-only: a sale is never
/// edited or deleted once recorded, so there's no conflict to resolve and no
/// "remove what's no longer remote" step — only "has this device's copy been
/// uploaded yet".
///
/// * Remote snapshots are merged into the local log, except for sales with
///   a local change the remote hasn't confirmed yet.
/// * New sales are pushed with [push] and stay pending in [SyncState] until
///   confirmed, so they survive failures and app restarts.
/// * If the remote listener fails it is re-opened with [Backoff], and
///   pending sales are pushed again. Writes the remote rejects for good
///   ([RemoteWriteRejected]) are dropped.
class SalesSync {
  SalesSync({
    required LocalSales local,
    required SyncState state,
    required RemoteSales remote,
    required Backoff backoff,
  }) : _local = local,
       _state = state,
       _remote = remote,
       _backoff = backoff;

  final LocalSales _local;
  final SyncState _state;
  final RemoteSales _remote;
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

  /// Uploads the local copy of sale [id] and confirms it in [SyncState] once
  /// the remote acknowledges it.
  ///
  /// Not awaited on purpose: Firestore queues writes while offline and its
  /// futures only complete once the server acknowledges them.
  void push(String id) {
    if (!_running) return;
    final token = _state.pendingToken(id);
    if (token == null) return;

    final Sale? sale;
    try {
      sale = _local.read(id);
    } catch (e) {
      // Unreadable locally: nothing to upload. Also drops the pending mark,
      // or this id would retry forever and stay pending — the same bug
      // fixed today in catalog_sync.dart for the catalog.
      debugPrint('Venta $id ilegible, no se sube: $e');
      unawaited(_state.confirm(id, token));
      return;
    }

    if (sale == null) {
      // Shouldn't happen — sales are never removed locally — but confirming
      // avoids a pending id with nothing left to push.
      unawaited(_state.confirm(id, token));
      return;
    }

    unawaited(_send(id, sale, token));
  }

  Future<void> _send(String id, Sale sale, int token) async {
    try {
      await _remote.upload(sale);
      await _state.confirm(id, token);
    } on RemoteWriteRejected catch (e) {
      // Retrying can't help; dropping the pending mark lets the next remote
      // snapshot settle this id (e.g. if some other copy of it exists).
      debugPrint('Venta $id rechazada, se descarta: $e');
      await _state.confirm(id, token);
    } catch (e) {
      // Stays pending: retried on reconnect or on the next launch.
      debugPrint('No se sincronizó la venta $id, se reintentará: $e');
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
            debugPrint('Error de sincronización de ventas: $e');
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

  /// Merges remote sales into the local log, skipping any still pending
  /// upload from this device (the local copy wins until that upload lands).
  /// No deletion step, unlike [CatalogSync._apply]: sales are never removed.
  Future<void> _apply(RemoteSalesSnapshot snapshot) async {
    final pending = _state.pendingIds;
    await _local.writeAllChanged(
      snapshot.items.where((sale) => !pending.contains(sale.id)),
    );
  }
}
