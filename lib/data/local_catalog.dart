// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'dart:convert';
import 'dart:math' as math;

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

  /// Whether [key] can be a garment's id here. Hive only accepts ASCII
  /// string keys of up to 255 characters, so anything else (a document
  /// created by hand in the console with accents, a random QR) is rejected
  /// up front instead of failing when it's written. Spaces and other ASCII
  /// are fine: ids like that may already be stored.
  static bool isItemId(dynamic key) =>
      key is String &&
      key != _sequenceKey &&
      key.isNotEmpty &&
      key.length <= 255 &&
      key.codeUnits.every((c) => c < 0x80);

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
  /// created here or arrived from another device, so [nextId] never
  /// offers a number already in use.
  Future<void> write(ClothingItem item) async {
    await _box.put(item.id, item.toMap());
    await _advanceSequencePast([item.id]);
  }

  Future<void> _advanceSequencePast(Iterable<String> ids) async {
    final highest = ids.map(_parseId).nonNulls.fold(_sequence, math.max);
    if (highest > _sequence) await _box.put(_sequenceKey, highest);
  }

  /// Writes those of [items] that differ from what's stored, all in one disk
  /// write, so a remote snapshot with many garments doesn't cause one write
  /// (and one UI refresh) per garment, and an unchanged one causes none.
  Future<void> writeAllChanged(Iterable<ClothingItem> items) async {
    final changed = {
      for (final item in items)
        if (!_storedEquals(item)) item.id: item.toMap(),
    };
    if (changed.isEmpty) return;
    await _box.putAll(changed);
    await _advanceSequencePast(changed.keys);
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

  /// Serializes [nextId] calls: everything before its `await` runs
  /// synchronously, so two overlapping calls (e.g. a double-tapped "new
  /// garment" button) would otherwise read the same counter and mint the
  /// same id, silently overwriting one garment with the other on save.
  Future<void> _mintQueue = Future.value();

  /// Mints the next human-readable id, e.g. "PRENDA-000024". Meant to be
  /// printed on a QR sticker, so it needs to be short and easy to read back
  /// if the sticker gets smudged.
  ///
  /// Skips ids already in the catalog: with sync, another device may have
  /// used numbers this device's counter hasn't reached yet.
  Future<String> nextId() {
    final result = _mintQueue.then((_) => _mintNextId());
    _mintQueue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<String> _mintNextId() async {
    // A plain `as int?` would throw instead of defaulting if this were ever
    // somehow stored as something else, which would break minting new ids
    // entirely until fixed by hand.
    final stored = _box.get(_sequenceKey);
    var next = (stored is int ? stored : 0) + 1;
    while (_box.containsKey(_formatId(next))) {
      next++;
    }
    await _box.put(_sequenceKey, next);
    return _formatId(next);
  }

  /// The id counter, tolerating a corrupt stored value (see [_mintNextId]).
  int get _sequence {
    final stored = _box.get(_sequenceKey);
    return stored is int ? stored : 0;
  }

  static String _formatId(int n) => '$_idPrefix${n.toString().padLeft(6, '0')}';

  static final RegExp _idPattern = RegExp('^$_idPrefix(\\d+)\$');

  static int? _parseId(String id) {
    final match = _idPattern.firstMatch(id);
    return match == null ? null : int.tryParse(match.group(1)!);
  }
}
