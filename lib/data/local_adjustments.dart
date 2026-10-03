import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/stock_adjustment.dart';

/// The stock-adjustment history as stored on this device (Hive): plain reads
/// and writes, with no knowledge of sync. What the UI always reads from.
///
/// Unlike [LocalCatalog], there's no `remove` and no id-minting counter:
/// adjustments are an append-only log, never edited or deleted once
/// recorded, and each [StockAdjustment] already carries its own
/// practically-unique id (see [StockAdjustment.newId]).
class LocalAdjustments {
  LocalAdjustments._(this._box);

  final Box _box;

  static Future<LocalAdjustments> open(String boxName) async =>
      LocalAdjustments._(await Hive.openBox(boxName));

  Future<void> close() => _box.close();

  /// Fires on every change, whether made here or synced from elsewhere.
  Listenable get listenable => _box.listenable();

  Iterable<String> get ids => _box.keys.cast<String>();

  /// Throws if the stored record is corrupt; see [readAll] for the tolerant
  /// version.
  StockAdjustment? read(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    return StockAdjustment.fromMap(Map<String, dynamic>.from(raw as Map));
  }

  /// Skips records that can't be read, so one corrupt entry never takes the
  /// whole history down with it. Most recent adjustment first.
  List<StockAdjustment> readAll() {
    final adjustments = <StockAdjustment>[];
    for (final id in ids) {
      try {
        final adjustment = read(id);
        if (adjustment != null) adjustments.add(adjustment);
      } catch (e) {
        debugPrint('Ajuste $id ilegible, se omite: $e');
      }
    }
    adjustments.sort((a, b) => b.fecha.compareTo(a.fecha));
    return adjustments;
  }

  Future<void> write(StockAdjustment adjustment) =>
      _box.put(adjustment.id, adjustment.toMap());

  /// Writes those of [adjustments] that differ from what's stored, all in
  /// one disk write — same reasoning as [LocalSales.writeAllChanged].
  Future<void> writeAllChanged(Iterable<StockAdjustment> adjustments) async {
    final changed = {
      for (final adjustment in adjustments)
        if (!_storedEquals(adjustment)) adjustment.id: adjustment.toMap(),
    };
    if (changed.isNotEmpty) await _box.putAll(changed);
  }

  /// A stored record that can't even be parsed counts as different, so it
  /// gets replaced by the good copy.
  bool _storedEquals(StockAdjustment adjustment) {
    try {
      final stored = read(adjustment.id);
      return stored != null &&
          jsonEncode(stored.toMap()) == jsonEncode(adjustment.toMap());
    } catch (_) {
      return false;
    }
  }
}
