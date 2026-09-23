import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/clothing_item.dart';
import 'remote_catalog.dart';

/// Storage for the store's catalog: clothing items keyed by the id printed on
/// their QR. Hive is always what the UI reads, so the app works the same
/// offline; once a [RemoteCatalog] is attached, every change is mirrored to it
/// and remote changes land back in Hive.
class ClothingRepository {
  static const String boxName = 'clothing_items';
  static const String _syncBoxName = 'catalog_sync';

  /// Set once the items that existed only on this device (from before the
  /// backend was connected) have been uploaded.
  static const String _uploadedLocalKey = 'uploadedLocalCatalog';

  /// Stores the running counter used to mint readable ids (see [generateId]).
  /// Kept in the same box under a key that can never collide with an item id,
  /// since item ids always start with [_idPrefix].
  static const String _sequenceKey = '__sequence__';
  static const String _idPrefix = 'PRENDA-';

  late final Box _box;
  Box? _syncBox;
  RemoteCatalog? _remote;
  StreamSubscription<void>? _remoteSub;
  Future<void> _lastApply = Future.value();

  /// Completes once the latest remote snapshot has been written to Hive.
  @visibleForTesting
  Future<void> get remoteSettled => _lastApply;

  Future<void> init() async {
    _box = await Hive.openBox(boxName);
  }

  /// Fires whenever the catalog changes, including changes that arrive from
  /// other devices.
  Listenable get listenable => _box.listenable();

  Future<void> attachRemote(RemoteCatalog remote) async {
    if (_remote != null) return;
    _syncBox = await Hive.openBox(_syncBoxName);
    _remote = remote;
    // asyncMap applies snapshots one at a time, in order.
    _remoteSub = remote
        .watch()
        .asyncMap((snapshot) => _lastApply = _applyRemote(snapshot))
        .listen(
          null,
          onError: (Object e) => debugPrint('Error de sincronización: $e'),
        );
  }

  Future<void> detachRemote() async {
    await _remoteSub?.cancel();
    _remoteSub = null;
    _remote = null;
  }

  Future<void> _applyRemote(RemoteSnapshot snapshot) async {
    final remoteIds = <String>{};
    for (final item in snapshot.items) {
      if (!_isItemKey(item.id)) continue;
      remoteIds.add(item.id);
      final local = getById(item.id);
      if (local == null || !_sameContent(local, item)) {
        await _box.put(item.id, item.toMap());
      }
    }

    if (!snapshot.fromServer) return;

    final syncBox = _syncBox!;
    if (syncBox.get(_uploadedLocalKey) != true) {
      // First server contact: upload what only this device had instead of
      // treating it as deleted remotely.
      for (final item in getAll()) {
        if (!remoteIds.contains(item.id)) _pushSave(item);
      }
      await syncBox.put(_uploadedLocalKey, true);
      return;
    }

    final removed = _box.keys
        .where((key) => _isItemKey(key) && !remoteIds.contains(key))
        .toList();
    if (removed.isNotEmpty) await _box.deleteAll(removed);
  }

  static bool _sameContent(ClothingItem a, ClothingItem b) =>
      jsonEncode(a.toMap()) == jsonEncode(b.toMap());

  // Not awaited on purpose: Firestore queues writes while offline and its
  // futures only complete once the server acknowledges them.
  void _pushSave(ClothingItem item) {
    _remote
        ?.upsert(item)
        .catchError((Object e) => debugPrint('No se subió ${item.id}: $e'));
  }

  void _pushDelete(String id) {
    _remote
        ?.delete(id)
        .catchError((Object e) => debugPrint('No se borró $id remoto: $e'));
  }

  bool _isItemKey(dynamic key) => key is String && key != _sequenceKey;

  /// Mints the next human-readable id, e.g. "PRENDA-000024". Meant to be
  /// printed on a QR sticker, so it needs to be short and easy to read back
  /// if the sticker gets smudged.
  ///
  /// Skips ids already in the catalog: with sync, another device may have
  /// used numbers this device's counter hasn't reached yet.
  Future<String> generateId() async {
    var next = ((_box.get(_sequenceKey) as int?) ?? 0) + 1;
    while (_box.containsKey(_formatId(next))) {
      next++;
    }
    await _box.put(_sequenceKey, next);
    return _formatId(next);
  }

  static String _formatId(int n) => '$_idPrefix${n.toString().padLeft(6, '0')}';

  List<ClothingItem> getAll() {
    return _box.keys
        .where(_isItemKey)
        .map(
          (key) => ClothingItem.fromMap(
            Map<String, dynamic>.from(_box.get(key) as Map),
          ),
        )
        .toList()
      ..sort(
        (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
      );
  }

  ClothingItem? getById(String id) {
    if (!_isItemKey(id)) return null;
    final raw = _box.get(id);
    if (raw == null) return null;
    return ClothingItem.fromMap(Map<String, dynamic>.from(raw as Map));
  }

  Future<void> save(ClothingItem item) async {
    _pushSave(item);
    await _box.put(item.id, item.toMap());
  }

  Future<void> delete(String id) async {
    _pushDelete(id);
    await _box.delete(id);
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
