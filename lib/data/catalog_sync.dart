import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/clothing_item.dart';
import 'backoff.dart';
import 'local_catalog.dart';
import 'remote_catalog.dart';
import 'sync_state.dart';

/// Keeps a [LocalCatalog] and a [RemoteCatalog] in step, in both directions:
///
/// * Remote snapshots are merged into the local catalog, except for items
///   with local changes the remote hasn't confirmed yet (local wins).
/// * Local changes are pushed with [push] and stay pending in [SyncState]
///   until confirmed, so they survive failures and app restarts.
/// * If the remote listener fails it is re-opened with [Backoff], and
///   pending changes are pushed again.
class CatalogSync {
  CatalogSync({
    required LocalCatalog local,
    required SyncState state,
    required RemoteCatalog remote,
    required Backoff backoff,
  }) : _local = local,
       _state = state,
       _remote = remote,
       _backoff = backoff;

  final LocalCatalog _local;
  final SyncState _state;
  final RemoteCatalog _remote;
  final Backoff _backoff;

  StreamSubscription<void>? _subscription;
  Timer? _retryTimer;
  bool _running = false;
  Future<void> _lastApply = Future.value();

  /// Completes once the latest remote snapshot has been applied locally.
  Future<void> get settled => _lastApply;

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

  /// Pushes the current local state of [id] (an upsert, or a delete if it's
  /// gone) and confirms it in [SyncState] once the remote acknowledges it.
  ///
  /// Not awaited on purpose: Firestore queues writes while offline and its
  /// futures only complete once the server acknowledges them.
  void push(String id) {
    if (!_running) return;
    final token = _state.pendingToken(id);
    if (token == null) return;

    final ClothingItem? item;
    try {
      item = _local.read(id);
    } catch (e) {
      // Unreadable locally: better to leave the remote copy alone.
      debugPrint('Prenda $id ilegible, no se sube: $e');
      return;
    }

    unawaited(_send(id, item, token));
  }

  Future<void> _send(String id, ClothingItem? item, int token) async {
    try {
      if (item == null) {
        await _remote.delete(id);
      } else {
        await _remote.upsert(item);
      }
      await _state.confirm(id, token);
    } catch (e) {
      // Stays pending: retried on reconnect or on the next launch.
      debugPrint('No se sincronizó $id, se reintentará: $e');
    }
  }

  void pushAllPending() => _state.pendingIds.forEach(push);

  void _listen() {
    // asyncMap applies snapshots one at a time, in order.
    _subscription = _remote
        .watch()
        .asyncMap((snapshot) => _lastApply = _apply(snapshot))
        .listen(
          (_) => _backoff.reset(),
          onError: (Object e) {
            debugPrint('Error de sincronización: $e');
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

  Future<void> _apply(RemoteSnapshot snapshot) async {
    // Items with unconfirmed local changes keep their local version: the
    // remote copy of them is stale until our write reaches it.
    final pending = _state.pendingIds;
    final remoteItems = snapshot.items.where(
      (item) => LocalCatalog.isItemId(item.id),
    );
    final remoteIds = {for (final item in remoteItems) item.id};

    for (final item in remoteItems) {
      if (!pending.contains(item.id)) await _local.writeIfChanged(item);
    }

    // Only the server can be trusted to say an item was deleted: a cold or
    // partial offline cache could otherwise look like "everything was deleted".
    if (!snapshot.fromServer) return;

    if (_state.initialUploadDone) {
      await _removeDeletedRemotely(remoteIds, pending);
    } else {
      await _uploadLocalOnlyItems(remoteIds);
    }
  }

  /// First server contact: what only this device had is uploaded instead of
  /// being treated as deleted remotely.
  Future<void> _uploadLocalOnlyItems(Set<String> remoteIds) async {
    for (final id in _local.ids.toList()) {
      if (!remoteIds.contains(id)) await _state.markPending(id);
    }
    await _state.markInitialUploadDone();
    pushAllPending();
  }

  Future<void> _removeDeletedRemotely(
    Set<String> remoteIds,
    Set<String> pending,
  ) async {
    final removed = _local.ids
        .where((id) => !remoteIds.contains(id) && !pending.contains(id))
        .toList();
    if (removed.isNotEmpty) await _local.removeAll(removed);
  }
}
