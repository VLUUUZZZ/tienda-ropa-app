import 'package:flutter/foundation.dart';

import '../models/clothing_item.dart';
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
class ClothingRepository {
  /// Wait before re-listening to the remote after an error; doubles on each
  /// consecutive failure up to [_maxRetryDelay].
  static const Duration _initialRetryDelay = Duration(seconds: 5);
  static const Duration _maxRetryDelay = Duration(minutes: 5);

  late final LocalCatalog _local;
  late final SyncState _syncState;
  CatalogSync? _sync;

  Future<void> init() async {
    _local = await LocalCatalog.open();
    _syncState = await SyncState.open();
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

  /// Mints the next human-readable id, e.g. "PRENDA-000024".
  Future<String> generateId() => _local.nextId();

  List<ClothingItem> getAll() => _local.readAll()
    ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

  ClothingItem? getById(String id) => _local.read(id);

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

  List<ClothingItem> search(String query) {
    final q = _normalize(query.trim());
    final all = getAll();
    if (q.isEmpty) return all;
    return all.where((item) => _normalize(item.nombre).contains(q)).toList();
  }

  /// Lowercases and strips common Spanish accents so "pantalon" also finds
  /// "Pantalón" — the tolerant matching the search box is meant to have.
  static String _normalize(String input) {
    const accented = 'áàäâéèëêíìïîóòöôúùüûñ';
    const plain = 'aaaaeeeeiiiioooouuuun';
    final buffer = StringBuffer();
    for (final rune in input.toLowerCase().runes) {
      final ch = String.fromCharCode(rune);
      final idx = accented.indexOf(ch);
      buffer.write(idx == -1 ? ch : plain[idx]);
    }
    return buffer.toString();
  }
}
