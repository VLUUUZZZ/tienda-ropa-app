import 'dart:math' as math;

import '../utils/texto.dart';

/// Bounds for what a garment may hold. The forms enforce them and reading
/// stored data clamps to them, so a bad record (typed by hand in the
/// console, from an old version) can't break a screen or the totals.
abstract final class Limites {
  static const int nombre = 80;
  static const int talla = 15;
  static const int color = 30;
  static const double precioMax = 1000000;
  static const int existenciaMax = 99999;
  static const int variantes = 100;
}

/// How much of a garment is left, for the catalog's badges and filters.
enum StockLevel {
  agotado,
  poca,
  normal;

  /// At or below this many pieces in total a garment counts as running low.
  static const int umbralPoca = 3;

  static StockLevel of(int existencia) {
    if (existencia <= 0) return agotado;
    if (existencia <= umbralPoca) return poca;
    return normal;
  }
}

class ClothingVariant {
  String talla;
  String color;
  int existencia;

  ClothingVariant({
    required this.talla,
    required this.color,
    required this.existencia,
  });

  /// What makes a variant unique within a garment: its color and talla,
  /// ignoring case and surrounding spaces.
  /// Accents count as the same letter too, so "Café" and "cafe" can't
  /// become two separate stock lines.
  String get key => '${normalizar(color.trim())}|${normalizar(talla.trim())}';

  Map<String, dynamic> toMap() => {
    'talla': talla,
    'color': color,
    'existencia': existencia,
  };

  /// Tolerant of wrong types: a number where text was expected is turned
  /// into text, and stock is clamped to 0..[Limites.existenciaMax].
  factory ClothingVariant.fromMap(Map<String, dynamic> map) {
    return ClothingVariant(
      talla: _text(map['talla']),
      color: _text(map['color']),
      existencia: clampExistencia(_number(map['existencia'])?.round() ?? 0),
    );
  }

  static int clampExistencia(int n) =>
      n.clamp(0, Limites.existenciaMax).toInt();
}

class ClothingItem {
  /// Same value that is encoded in the item's printed QR code.
  final String id;
  String nombre;
  double precio;
  List<ClothingVariant> variantes;

  ClothingItem({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.variantes,
  });

  int get existenciaTotal => variantes.fold(0, (sum, v) => sum + v.existencia);

  StockLevel get nivelExistencia => StockLevel.of(existenciaTotal);

  /// What the pieces on hand are worth at the listed price.
  double get valorInventario => precio * existenciaTotal;

  /// Unique colors across all variants, in first-seen order — what the
  /// catalog card and the quick stock editor show.
  List<String> get coloresDisponibles {
    final seen = <String>{};
    final result = <String>[];
    for (final v in variantes) {
      if (v.color.isNotEmpty && seen.add(v.color)) {
        result.add(v.color);
      }
    }
    return result;
  }

  /// The color+talla combination is what makes a variant unique within a
  /// garment; finds the first pair that repeats, if any.
  static ({String color, String talla})? firstDuplicateVariant(
    List<ClothingVariant> variantes,
  ) {
    final seen = <String>{};
    for (final v in variantes) {
      if (!seen.add(v.key)) {
        return (color: v.color.trim(), talla: v.talla.trim());
      }
    }
    return null;
  }

  /// A copy with each variant's stock moved by its entry in [deltas] (keyed
  /// by [ClothingVariant.key]), never below zero.
  ///
  /// Applying changes as deltas onto the latest version, instead of saving
  /// absolute counts read earlier, keeps adjustments made meanwhile on other
  /// devices. Deltas for variants that no longer exist are ignored.
  ClothingItem withStockChanges(Map<String, int> deltas) => ClothingItem(
    id: id,
    nombre: nombre,
    precio: precio,
    variantes: [
      for (final v in variantes)
        ClothingVariant(
          talla: v.talla,
          color: v.color,
          existencia: ClothingVariant.clampExistencia(
            v.existencia + (deltas[v.key] ?? 0),
          ),
        ),
    ],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'nombre': nombre,
    'precio': precio,
    'variantes': variantes.map((v) => v.toMap()).toList(),
  };

  /// Reads a stored or synced record. Only a missing id is fatal
  /// ([FormatException]); anything else that's the wrong type or out of
  /// range falls back to a safe value, and variants that aren't maps are
  /// skipped, so one bad field doesn't hide the whole garment.
  factory ClothingItem.fromMap(Map<String, dynamic> map) {
    final id = map['id'];
    if (id is! String || id.isEmpty) {
      throw FormatException('Prenda sin id válido: $id');
    }
    final rawVariantes = map['variantes'];
    return ClothingItem(
      id: id,
      nombre: _text(map['nombre']),
      precio: clampPrecio(_number(map['precio'])?.toDouble() ?? 0),
      variantes: [
        if (rawVariantes is List)
          for (final v in rawVariantes.take(Limites.variantes))
            if (v is Map) ClothingVariant.fromMap(Map<String, dynamic>.from(v)),
      ],
    );
  }

  /// 0..[Limites.precioMax], rounded to cents; NaN and infinities become 0.
  static double clampPrecio(double precio) {
    if (!precio.isFinite || precio < 0) return 0;
    return (math.min(precio, Limites.precioMax) * 100).round() / 100;
  }
}

String _text(Object? value) => switch (value) {
  null => '',
  final String s => s.trim(),
  _ => value.toString().trim(),
};

num? _number(Object? value) => switch (value) {
  final num n when n.isFinite => n,
  final String s => num.tryParse(s.trim()),
  _ => null,
};
