import 'package:hive_flutter/hive_flutter.dart';

import '../models/clothing_item.dart';

/// Local-only storage for the store's catalog. No backend, no accounts,
/// nothing sensitive: just clothing items keyed by the id printed on their QR.
class ClothingRepository {
  static const String boxName = 'clothing_items';

  /// Stores the running counter used to mint readable ids (see [generateId]).
  /// Kept in the same box under a key that can never collide with an item id,
  /// since item ids always start with [_idPrefix].
  static const String _sequenceKey = '__sequence__';
  static const String _idPrefix = 'PRENDA-';

  late final Box _box;

  Future<void> init() async {
    _box = await Hive.openBox(boxName);
  }

  bool _isItemKey(dynamic key) => key is String && key != _sequenceKey;

  /// Mints the next human-readable id, e.g. "PRENDA-000024". Meant to be
  /// printed on a QR sticker, so it needs to be short and easy to read back
  /// if the sticker gets smudged.
  Future<String> generateId() async {
    final current = (_box.get(_sequenceKey) as int?) ?? 0;
    final next = current + 1;
    await _box.put(_sequenceKey, next);
    return '$_idPrefix${next.toString().padLeft(6, '0')}';
  }

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
    await _box.put(item.id, item.toMap());
  }

  Future<void> delete(String id) async {
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
