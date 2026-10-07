import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/clothing_item.dart';
import 'backoff.dart';
import 'catalog_sync.dart';
import 'local_catalog.dart';
import 'local_photos.dart';
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
  ClothingRepository._(this._local, this._syncState, this._photos);

  /// Wait before re-listening to the remote after an error; doubles on each
  /// consecutive failure up to [_maxRetryDelay].
  static const Duration _initialRetryDelay = Duration(seconds: 5);
  static const Duration _maxRetryDelay = Duration(minutes: 5);

  final LocalCatalog _local;
  final SyncState _syncState;
  final LocalPhotos _photos;
  CatalogSync? _sync;
  RemoteCatalog? _remote;

  /// Opens the catalog of the store [tiendaId], or the local-only catalog
  /// when null (app without backend, and data from before stores existed).
  static Future<ClothingRepository> open({String? tiendaId}) async {
    String scoped(String base) => tiendaId == null ? base : '${base}_$tiendaId';
    final repo = ClothingRepository._(
      await LocalCatalog.open(scoped('clothing_items')),
      await SyncState.open(scoped('catalog_sync')),
      await LocalPhotos.open(scoped('clothing_photos')),
    );
    await repo._pruneOrphanPhotos();
    await repo._pruneAbandonedNewIds();
    return repo;
  }

  /// Deletes photos left behind by garments removed since the last time the
  /// catalog was opened (deleting a garment doesn't delete its photo right
  /// away, so "Deshacer" right after can still bring it back within the same
  /// session). Without this, every deleted garment's photo would stay on the
  /// phone's storage forever.
  Future<void> _pruneOrphanPhotos() async {
    final catalogIds = _local.ids.toSet();
    for (final id in _photos.ids.toList()) {
      if (catalogIds.contains(id)) continue;
      final path = _photos.pathFor(id);
      if (path != null) {
        final file = File(path);
        try {
          if (await file.exists()) await file.delete();
        } catch (e) {
          // Couldn't remove the file this time (permission, disk busy):
          // leave the Hive entry in place so the next launch retries,
          // instead of clearing it and leaking the file forever.
          continue;
        }
      }
      await _photos.remove(id);
    }
  }

  /// Clears the "freshly minted" mark left behind by [generateId] when a new
  /// garment's id was generated but the garment was never actually saved
  /// (the user backed out of the form): otherwise that mark, meant to be
  /// cleared on first sync, sits in [SyncState] forever.
  Future<void> _pruneAbandonedNewIds() async {
    final catalogIds = _local.ids.toSet();
    for (final id in _syncState.mintedIds) {
      if (!catalogIds.contains(id)) await _syncState.clearLocallyMinted(id);
    }
  }

  /// Stops sync and releases the store's storage (e.g. on sign-out).
  Future<void> close() async {
    await detachRemote();
    await _local.close();
    await _syncState.close();
    await _photos.close();
  }

  /// This garment's photo file on this phone, if it has one. Never synced to
  /// other devices — see [LocalPhotos].
  String? photoPathFor(String id) => _photos.pathFor(id);

  Future<void> setPhotoPath(String id, String path) =>
      _photos.setPath(id, path);

  Future<void> removePhotoPath(String id) => _photos.remove(id);

  /// Fires whenever the catalog changes, including changes that arrive from
  /// other devices.
  Listenable get listenable => _local.listenable;

  Future<void> attachRemote(RemoteCatalog remote) async {
    if (_sync != null) return;
    _remote = remote;
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
    _remote = null;
  }

  /// Mints the next human-readable id, e.g. "PRENDA-000024", and marks it as
  /// not yet confirmed to exist anywhere else: another device minting the
  /// same id while both are offline must not silently overwrite this one
  /// (see [CatalogSync]).
  Future<String> generateId() async {
    final id = await _local.nextId();
    await _syncState.markLocallyMinted(id);
    return id;
  }

  List<ClothingItem> getAll() => _local.readAll()
    ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

  /// Sum of each garment's price times its total stock — what the whole
  /// catalog is worth right now, at selling price.
  double get valorInventario => getAll().fold(
    0.0,
    (suma, item) => suma + item.precio * item.existenciaTotal,
  );

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

  /// Finds the garment carrying [codigo] as its supplier barcode, so
  /// scanning a label the supplier printed (not the app's own QR) still
  /// finds the right garment. Null if none matches.
  ClothingItem? getByProviderCode(String codigo) {
    final q = codigo.trim();
    if (q.isEmpty) return null;
    for (final item in getAll()) {
      if (item.codigoProveedor.trim() == q) return item;
    }
    return null;
  }

  Future<void> save(ClothingItem item) async {
    // Marked pending *before* the local write (not after): otherwise a
    // remote snapshot landing in the gap between the two could read this id
    // as "not pending yet" and silently overwrite the value just written
    // with the stale remote copy (see CatalogSync._apply).
    await _syncState.markPending(item.id);
    await _local.write(item);
    _sync?.push(item.id);
  }

  /// Applies [deltas] (see [ClothingItem.withStockChanges]) to [id]'s stock
  /// — a sale or a quick stock adjustment, as opposed to a full edit.
  ///
  /// When a remote is attached and reachable, this is applied as an atomic
  /// transaction on the server *first*, against whatever stock is actually
  /// there at that moment, and the confirmed result becomes the new local
  /// state. That matters because two devices applying a delta to the same
  /// garment within moments of each other (two sales in the same store) must
  /// both take effect — [save] alone can't guarantee that, since it always
  /// overwrites the whole remote document with a locally-computed result,
  /// and the second overwrite would silently discard the first device's
  /// change. If there's no remote, or the server round-trip fails (offline,
  /// most likely), falls back to a plain local change queued for the next
  /// sync, same as [save] — correct as long as only one device is editing
  /// this garment while offline.
  Future<ClothingItem> applyStockDelta(
    String id,
    Map<String, int> deltas,
  ) async {
    final remote = _remote;
    if (remote != null) {
      ClothingItem? updated;
      try {
        updated = await remote.applyStockDelta(id, deltas);
      } catch (e) {
        debugPrint(
          'No se pudo aplicar el cambio de existencia de $id en el '
          'servidor, se aplica solo localmente: $e',
        );
      }
      if (updated != null) {
        try {
          await _local.write(updated);
        } catch (e) {
          // The server already has the correct value — losing this local
          // write (disk error, box closed mid-flight) must never be treated
          // as the sale/adjustment itself having failed, or a retry would
          // apply the same delta to the server a second time. The next
          // snapshot from CatalogSync's listener catches the local copy up.
          debugPrint(
            'No se pudo guardar $id localmente tras confirmarlo en el '
            'servidor: $e',
          );
        }
        return updated;
      }
    }
    final current = getById(id);
    if (current == null) {
      throw StateError('La prenda $id ya no existe en el catálogo.');
    }
    final updated = current.withStockChanges(deltas);
    await save(updated);
    return updated;
  }

  Future<void> delete(String id) async {
    await _syncState.markPending(id);
    await _local.remove(id);
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
