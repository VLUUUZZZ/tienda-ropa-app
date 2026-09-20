class ClothingVariant {
  String talla;
  String color;
  int existencia;

  ClothingVariant({
    required this.talla,
    required this.color,
    required this.existencia,
  });

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

  int get existenciaTotal =>
      variantes.fold(0, (sum, v) => sum + v.existencia);

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
          .map((v) => ClothingVariant.fromMap(Map<String, dynamic>.from(v as Map)))
          .toList(),
    );
  }
}
