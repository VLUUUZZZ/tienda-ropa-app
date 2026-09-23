import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/clothing_item.dart';

/// The catalog as stored on this device (Hive): plain reads and writes, with
/// no knowledge of sync. What the UI always reads from.
class LocalCatalog {
  LocalCatalog._(this._box);

  /// Stores the running counter used to mint readable ids (see [nextId]).
  /// Kept in the same box under a key that can never collide with an item id,
  /// since item ids always start with [_idPrefix].
  static const String _sequenceKey = '__sequence__';
  static const String _idPrefix = 'PRENDA-';

  final Box _box;

  static Future<LocalCatalog> open(String boxName) async =>
      LocalCatalog._(await Hive.openBox(boxName));

  Future<void> close() => _box.close();

  /// Fires on every change, whether made here or synced from elsewhere.
  Listenable get listenable => _box.listenable();

  Iterable<String> get ids => _box.keys.where(isItemId).cast<String>();

  static bool isItemId(dynamic key) => key is String && key != _sequenceKey;

  /// Throws if the stored record is corrupt; see [readAll] for the tolerant
  /// version.
  ClothingItem? read(String id) {
    if (!isItemId(id)) return null;
    final raw = _box.get(id);
    if (raw == null) return null;
    return ClothingItem.fromMap(Map<String, dynamic>.from(raw as Map));
  }

  /// Skips records that can't be read, so one corrupt entry never takes the
  /// whole catalog screen down with it.
  List<ClothingItem> readAll() {
    final items = <ClothingItem>[];
    for (final id in ids) {
      try {
        final item = read(id);
        if (item != null) items.add(item);
      } catch (e) {
        debugPrint('Prenda $id ilegible, se omite: $e');
      }
    }
    return items;
  }

  /// Also moves the id counter past [item]'s number, whether the garment was
  /// created here or arrived from another device, so [peekNextId] never
  /// offers a number already in use.
  Future<void> write(ClothingItem item) async {
    await _box.put(item.id, item.toMap());
    final n = _parseId(item.id);
    if (n != null && n > _sequence) await _box.put(_sequenceKey, n);
  }

  /// Writes [item] only if it differs from what's stored, so an unchanged
  /// remote snapshot doesn't trigger needless disk writes and UI rebuilds.
  Future<void> writeIfChanged(ClothingItem item) async {
    if (!_storedEquals(item)) await write(item);
  }

  Future<void> remove(String id) => _box.delete(id);

  Future<void> removeAll(Iterable<String> ids) => _box.deleteAll(ids);

  /// A stored record that can't even be parsed counts as different, so it
  /// gets replaced by the good copy.
  bool _storedEquals(ClothingItem item) {
    try {
      final stored = read(item.id);
      return stored != null &&
          jsonEncode(stored.toMap()) == jsonEncode(item.toMap());
    } catch (_) {
      return false;
    }
  }

  int get _sequence => (_box.get(_sequenceKey) as int?) ?? 0;

  /// The next human-readable id, e.g. "PRENDA-000024", without reserving it:
  /// [write] advances the counter once a garment with that id is saved.
  /// Meant to be printed on a QR sticker, so it needs to be short and easy to
  /// read back if the sticker gets smudged.
  ///
  /// Skips ids already in the catalog: with sync, another device may have
  /// used numbers this device's counter hasn't reached yet.
  String peekNextId() {
    var next = _sequence + 1;
    while (_box.containsKey(_formatId(next))) {
      next++;
    }
    return _formatId(next);
  }

  static String _formatId(int n) => '$_idPrefix${n.toString().padLeft(6, '0')}';

  static final RegExp _idPattern = RegExp('^$_idPrefix(\\d+)\$');

  static int? _parseId(String id) {
    final match = _idPattern.firstMatch(id);
    return match == null ? null : int.tryParse(match.group(1)!);
  }
}
