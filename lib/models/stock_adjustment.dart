// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'dart:math';

/// One manual stock change (quick edit or full form), kept for audit: who
/// moved how many pieces of what, and when.
///
/// Append-only: an [StockAdjustment] is created once and never edited or
/// deleted, so [nombreItem] is a snapshot taken at the time of the change —
/// the history stays readable even if the garment is later renamed or
/// removed from the catalog.
class StockAdjustment {
  final String id;

  /// The garment this adjustment refers to (see [ClothingItem.id]).
  final String itemId;

  /// The garment's name at the moment of the change.
  final String nombreItem;
  final String color;
  final String talla;

  /// How many pieces moved: positive when added, negative when removed.
  final int delta;

  /// Who made the change, by name (not uid, so it reads on its own).
  final String usuarioNombre;
  final DateTime fecha;

  StockAdjustment({
    required this.id,
    required this.itemId,
    required this.nombreItem,
    required this.color,
    required this.talla,
    required this.delta,
    required this.usuarioNombre,
    required this.fecha,
  });

  /// Mints a practically-unique id with no sequential counter to coordinate
  /// between devices — same approach as [Sale.newId].
  static String newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-'
      '${Random().nextInt(0xFFFFFF).toRadixString(36)}';

  Map<String, dynamic> toMap() => {
    'id': id,
    'itemId': itemId,
    'nombreItem': nombreItem,
    'color': color,
    'talla': talla,
    'delta': delta,
    'usuarioNombre': usuarioNombre,
    'fecha': fecha.millisecondsSinceEpoch,
  };

  factory StockAdjustment.fromMap(Map<String, dynamic> map) {
    return StockAdjustment(
      id: map['id'] as String,
      itemId: map['itemId'] as String? ?? '',
      nombreItem: map['nombreItem'] as String? ?? '',
      color: map['color'] as String? ?? '',
      talla: map['talla'] as String? ?? '',
      delta: (map['delta'] as num?)?.toInt() ?? 0,
      usuarioNombre: map['usuarioNombre'] as String? ?? '',
      fecha: DateTime.fromMillisecondsSinceEpoch(
        (map['fecha'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}
