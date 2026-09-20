import 'package:hive_flutter/hive_flutter.dart';

import '../models/clothing_item.dart';

/// Local-only storage for the store's catalog. No backend, no accounts,
/// nothing sensitive: just clothing items keyed by the id printed on their QR.
class ClothingRepository {
  static const String boxName = 'clothing_items';
  late final Box _box;

  Future<void> init() async {
    _box = await Hive.openBox(boxName);
  }

  List<ClothingItem> getAll() {
    return _box.values
        .map((raw) => ClothingItem.fromMap(Map<String, dynamic>.from(raw as Map)))
        .toList()
      ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
  }

  ClothingItem? getById(String id) {
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
    final q = query.trim().toLowerCase();
    final all = getAll();
    if (q.isEmpty) return all;
    return all.where((item) => item.nombre.toLowerCase().contains(q)).toList();
  }
}
