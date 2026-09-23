import 'dart:math' as math;

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
  String get key =>
      '${color.trim().toLowerCase()}|${talla.trim().toLowerCase()}';

  Map<String, dynamic> toMap() => {
    'talla': talla,
    'color': color,
    'existencia': existencia,
  };

  factory ClothingVariant.fromMap(Map<String, dynamic> map) {
    return ClothingVariant(
      talla: map['talla'] as String? ?? '',
      color: map['color'] as String? ?? '',
      existencia: (map['existencia'] as num?)?.toInt() ?? 0,
    );
  }
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
          existencia: math.max(0, v.existencia + (deltas[v.key] ?? 0)),
        ),
    ],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'nombre': nombre,
    'precio': precio,
    'variantes': variantes.map((v) => v.toMap()).toList(),
  };

  factory ClothingItem.fromMap(Map<String, dynamic> map) {
    final rawVariantes = (map['variantes'] as List?) ?? [];
    return ClothingItem(
      id: map['id'] as String,
      nombre: map['nombre'] as String? ?? '',
      precio: (map['precio'] as num?)?.toDouble() ?? 0,
      variantes: rawVariantes
          .map(
            (v) => ClothingVariant.fromMap(Map<String, dynamic>.from(v as Map)),
          )
          .toList(),
    );
  }
}
