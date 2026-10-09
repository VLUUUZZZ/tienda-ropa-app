// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'dart:math';

/// One sale of a garment variant.
///
/// Append-only: a [Sale] is created once and never edited or deleted, so
/// [nombreItem] and [precioUnitario] are snapshots taken at sale time —
/// the history stays readable even if the garment is later renamed,
/// repriced, or removed from the catalog.
class Sale {
  final String id;

  /// The garment this sale refers to (see [ClothingItem.id]).
  final String itemId;

  /// The garment's name at the moment of the sale.
  final String nombreItem;
  final String color;
  final String talla;
  final int cantidad;

  /// The garment's unit price at the moment of the sale.
  final double precioUnitario;
  final DateTime fecha;

  Sale({
    required this.id,
    required this.itemId,
    required this.nombreItem,
    required this.color,
    required this.talla,
    required this.cantidad,
    required this.precioUnitario,
    required this.fecha,
  });

  double get total => cantidad * precioUnitario;

  /// Mints a practically-unique id with no sequential counter to coordinate
  /// between devices — the same bug a shared counter would risk in
  /// [ClothingItem] ids (two phones minting the same number while offline)
  /// never comes up here, since this mixes the current time with a random
  /// component instead.
  static String newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-'
      '${Random().nextInt(0xFFFFFF).toRadixString(36)}';

  Map<String, dynamic> toMap() => {
    'id': id,
    'itemId': itemId,
    'nombreItem': nombreItem,
    'color': color,
    'talla': talla,
    'cantidad': cantidad,
    'precioUnitario': precioUnitario,
    'fecha': fecha.millisecondsSinceEpoch,
  };

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'] as String,
      itemId: map['itemId'] as String? ?? '',
      nombreItem: map['nombreItem'] as String? ?? '',
      color: map['color'] as String? ?? '',
      talla: map['talla'] as String? ?? '',
      cantidad: (map['cantidad'] as num?)?.toInt() ?? 0,
      precioUnitario: (map['precioUnitario'] as num?)?.toDouble() ?? 0,
      fecha: DateTime.fromMillisecondsSinceEpoch(
        (map['fecha'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}
