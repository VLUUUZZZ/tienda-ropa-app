import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/sale.dart';

/// The sales log as stored on this device (Hive): plain reads and writes,
/// with no knowledge of sync. What the UI always reads from.
///
/// Unlike [LocalCatalog], there's no `remove` and no id-minting counter:
/// sales are an append-only log, never edited or deleted once recorded, and
/// each [Sale] already carries its own practically-unique id (see
/// [Sale.newId]).
class LocalSales {
  LocalSales._(this._box);

  final Box _box;

  static Future<LocalSales> open(String boxName) async =>
      LocalSales._(await Hive.openBox(boxName));

  Future<void> close() => _box.close();

  /// Fires on every change, whether made here or synced from elsewhere.
  Listenable get listenable => _box.listenable();

  Iterable<String> get ids => _box.keys.cast<String>();

  /// Throws if the stored record is corrupt; see [readAll] for the tolerant
  /// version.
  Sale? read(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    return Sale.fromMap(Map<String, dynamic>.from(raw as Map));
  }

  /// Skips records that can't be read, so one corrupt entry never takes the
  /// whole sales history down with it. Most recent sale first.
  List<Sale> readAll() {
    final sales = <Sale>[];
    for (final id in ids) {
      try {
        final sale = read(id);
        if (sale != null) sales.add(sale);
      } catch (e) {
        debugPrint('Venta $id ilegible, se omite: $e');
      }
    }
    sales.sort((a, b) => b.fecha.compareTo(a.fecha));
    return sales;
  }

  Future<void> write(Sale sale) => _box.put(sale.id, sale.toMap());

  /// Writes those of [sales] that differ from what's stored, all in one disk
  /// write, so a remote snapshot with many sales doesn't cause one write
  /// (and one UI refresh) per sale, and an unchanged one causes none.
  Future<void> writeAllChanged(Iterable<Sale> sales) async {
    final changed = {
      for (final sale in sales)
        if (!_storedEquals(sale)) sale.id: sale.toMap(),
    };
    if (changed.isNotEmpty) await _box.putAll(changed);
  }

  /// A stored record that can't even be parsed counts as different, so it
  /// gets replaced by the good copy.
  bool _storedEquals(Sale sale) {
    try {
      final stored = read(sale.id);
      return stored != null &&
          jsonEncode(stored.toMap()) == jsonEncode(sale.toMap());
    } catch (_) {
      return false;
    }
  }
}
