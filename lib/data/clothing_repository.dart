import 'package:flutter/foundation.dart';

import '../models/clothing_item.dart';
import '../utils/texto.dart';
import 'backoff.dart';
import 'catalog_sync.dart';
import 'local_catalog.dart';
import 'remote_catalog.dart';
import 'sync_state.dart';

/// The store's catalog as the screens see it: clothing items keyed by the id
/// printed on their QR.
///
/// Reads always come from the device ([LocalCatalog]), so the app works the
/// same offline. Every change is recorded as pending in [SyncState] and, once
/// a [RemoteCatalog] is attached, [CatalogSync] mirrors it to the backend.
///
/// Each store keeps its own data on the device, so two stores signed in on
/// the same phone never mix their catalogs.
class ClothingRepository {
  ClothingRepository._(this._local, this._syncState);

  /// Wait before re-listening to the remote after an error; doubles on each
  /// consecutive failure up to [_maxRetryDelay].
  static const Duration _initialRetryDelay = Duration(seconds: 5);
  static const Duration _maxRetryDelay = Duration(minutes: 5);

  final LocalCatalog _local;
  final SyncState _syncState;
  CatalogSync? _sync;

  /// Opens the catalog of the store [tiendaId], or the local-only catalog
  /// when null (app without backend, and data from before stores existed).
  static Future<ClothingRepository> open({String? tiendaId}) async {
    String scoped(String base) => tiendaId == null ? base : '${base}_$tiendaId';
    return ClothingRepository._(
      await LocalCatalog.open(scoped('clothing_items')),
      await SyncState.open(scoped('catalog_sync')),
    );
  }

  /// Stops sync and releases the store's storage (e.g. on sign-out).
  Future<void> close() async {
    await detachRemote();
    await _local.close();
    await _syncState.close();
  }

  /// Fires whenever the catalog changes, including changes that arrive from
  /// other devices.
  Listenable get listenable => _local.listenable;

  Future<void> attachRemote(RemoteCatalog remote) async {
    if (_sync != null) return;
    _sync = CatalogSync(
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

  /// The id the next new garment would get, e.g. "PRENDA-000024". Nothing is
  /// reserved until that garment is saved, so abandoning a new garment
  /// leaves no gap in the numbering.
  String nextId() => _local.peekNextId();

  bool exists(String id) => _local.ids.contains(id);

  List<ClothingItem> getAll() => _local.readAll()
    ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

  /// Null if there's no such garment, or its record is unreadable: a corrupt
  /// entry must never crash the screen that opens or scans it.
  ClothingItem? getById(String id) {
    try {
      return _local.read(id);
    } catch (e) {
      debugPrint('Prenda $id ilegible: $e');
      return null;
    }
  }

  Future<void> save(ClothingItem item) async {
    await _local.write(item);
    await _recordChange(item.id);
  }

  Future<void> delete(String id) async {
    await _local.remove(id);
    await _recordChange(id);
  }

  Future<void> _recordChange(String id) async {
    await _syncState.markPending(id);
    _sync?.push(id);
  }

  /// Matches the name, code or a color by substring, and a talla only when
  /// typed in full (so "3" doesn't pull in every talla 32, 34...). Case and
  /// accents are ignored everywhere.
  ///
  /// Searches [items] when given (already read from the catalog), otherwise
  /// the whole catalog.
  List<ClothingItem> search(String query, [List<ClothingItem>? items]) {
    final q = normalizar(query.trim());
    final all = items ?? getAll();
    if (q.isEmpty) return all;
    return all.where((item) => _matches(item, q)).toList();
  }

  static bool _matches(ClothingItem item, String q) {
    if (normalizar(item.nombre).contains(q)) return true;
    if (normalizar(item.id).contains(q)) return true;
    for (final v in item.variantes) {
      if (normalizar(v.color).contains(q)) return true;
      if (normalizar(v.talla.trim()) == q) return true;
    }
    return false;
  }
}
