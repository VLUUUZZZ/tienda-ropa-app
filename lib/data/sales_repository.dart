import 'package:flutter/foundation.dart';

import '../models/sale.dart';
import 'backoff.dart';
import 'local_sales.dart';
import 'remote_sales.dart';
import 'sales_sync.dart';
import 'sync_state.dart';

/// The store's sales log as the screens see it.
///
/// Reads always come from the device ([LocalSales]), so the app works the
/// same offline. Every new sale is recorded as pending in [SyncState] and,
/// once a [RemoteSales] is attached, [SalesSync] mirrors it to the backend.
///
/// Each store keeps its own data on the device, so two stores signed in on
/// the same phone never mix their sales.
class SalesRepository {
  SalesRepository._(this._local, this._syncState);

  /// Wait before re-listening to the remote after an error; doubles on each
  /// consecutive failure up to [_maxRetryDelay].
  static const Duration _initialRetryDelay = Duration(seconds: 5);
  static const Duration _maxRetryDelay = Duration(minutes: 5);

  final LocalSales _local;
  final SyncState _syncState;
  SalesSync? _sync;

  /// Opens the sales log of the store [tiendaId], or the local-only log when
  /// null (app without backend).
  static Future<SalesRepository> open({String? tiendaId}) async {
    String scoped(String base) => tiendaId == null ? base : '${base}_$tiendaId';
    return SalesRepository._(
      await LocalSales.open(scoped('sales')),
      await SyncState.open(scoped('sales_sync')),
    );
  }

  /// Stops sync and releases the store's storage (e.g. on sign-out).
  Future<void> close() async {
    await detachRemote();
    await _local.close();
    await _syncState.close();
  }

  /// Fires whenever the sales log changes, including sales recorded on other
  /// devices.
  Listenable get listenable => _local.listenable;

  Future<void> attachRemote(RemoteSales remote) async {
    if (_sync != null) return;
    _sync = SalesSync(
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

  /// Most recent sale first (see [LocalSales.readAll]).
  List<Sale> getAll() => _local.readAll();

  /// Records a new sale locally and queues it for upload.
  Future<void> registrar(Sale venta) async {
    await _local.write(venta);
    await _syncState.markPending(venta.id);
    _sync?.push(venta.id);
  }

  /// Total sold on [dia] (comparing year/month/day in local time), summing
  /// each matching sale's [Sale.total].
  double totalDe(DateTime dia) => getAll()
      .where(
        (venta) =>
            venta.fecha.year == dia.year &&
            venta.fecha.month == dia.month &&
            venta.fecha.day == dia.day,
      )
      .fold(0.0, (suma, venta) => suma + venta.total);
}
