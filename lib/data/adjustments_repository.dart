// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'package:flutter/foundation.dart';

import '../models/stock_adjustment.dart';
import 'adjustments_sync.dart';
import 'backoff.dart';
import 'local_adjustments.dart';
import 'remote_adjustments.dart';
import 'sync_state.dart';

/// The store's stock-adjustment history as the screens see it.
///
/// Reads always come from the device ([LocalAdjustments]), so the app works
/// the same offline. Every new adjustment is recorded as pending in
/// [SyncState] and, once a [RemoteAdjustments] is attached, [AdjustmentsSync]
/// mirrors it to the backend. Mirrors [SalesRepository] closely.
///
/// Each store keeps its own data on the device, so two stores signed in on
/// the same phone never mix their histories.
class AdjustmentsRepository {
  AdjustmentsRepository._(this._local, this._syncState);

  /// Wait before re-listening to the remote after an error; doubles on each
  /// consecutive failure up to [_maxRetryDelay].
  static const Duration _initialRetryDelay = Duration(seconds: 5);
  static const Duration _maxRetryDelay = Duration(minutes: 5);

  final LocalAdjustments _local;
  final SyncState _syncState;
  AdjustmentsSync? _sync;

  /// Opens the adjustment history of the store [tiendaId], or the
  /// local-only history when null (app without backend).
  static Future<AdjustmentsRepository> open({String? tiendaId}) async {
    String scoped(String base) => tiendaId == null ? base : '${base}_$tiendaId';
    return AdjustmentsRepository._(
      await LocalAdjustments.open(scoped('stock_adjustments')),
      await SyncState.open(scoped('stock_adjustments_sync')),
    );
  }

  /// Stops sync and releases the store's storage (e.g. on sign-out).
  Future<void> close() async {
    await detachRemote();
    await _local.close();
    await _syncState.close();
  }

  /// Fires whenever the history changes, including adjustments recorded on
  /// other devices.
  Listenable get listenable => _local.listenable;

  /// Changes made on this phone that the server hasn't confirmed yet
  /// (offline, or still on their way). Always zero without a backend, where
  /// there's nothing to send them to.
  int get pendingChanges => _sync == null ? 0 : _syncState.pendingIds.length;

  /// Fires when [pendingChanges] may have changed.
  Listenable get syncListenable => _syncState.listenable;

  Future<void> attachRemote(RemoteAdjustments remote) async {
    if (_sync != null) return;
    _sync = AdjustmentsSync(
      local: _local,
      state: _syncState,
      remote: remote,
      backoff: Backoff(initial: _initialRetryDelay, max: _maxRetryDelay),
    )..start();
  }

  Future<void> detachRemote() async {
    await _sync?.stop();
    _sync = null;
  }

  /// Most recent adjustment first (see [LocalAdjustments.readAll]).
  List<StockAdjustment> getAll() => _local.readAll();

  /// Records a new adjustment locally and queues it for upload.
  Future<void> registrar(StockAdjustment adjustment) async {
    await _local.write(adjustment);
    await _syncState.markPending(adjustment.id);
    _sync?.push(adjustment.id);
  }
}
