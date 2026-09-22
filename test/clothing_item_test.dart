import 'package:flutter_test/flutter_test.dart';

import 'package:tienda_ropa_app/models/clothing_item.dart';

void main() {
  test('coloresDisponibles lists unique colors in first-seen order', () {
    final item = ClothingItem(
      id: '1',
      nombre: 'Sudadera Essential',
      precio: 450,
      variantes: [
        ClothingVariant(talla: 'CH', color: 'Negro', existencia: 2),
        ClothingVariant(talla: 'M', color: 'Negro', existencia: 5),
        ClothingVariant(talla: 'M', color: 'Gris', existencia: 1),
      ],
    );

    expect(item.coloresDisponibles, ['Negro', 'Gris']);
  });

  test('firstDuplicateVariant finds a repeated color+talla pair', () {
    final duplicate = ClothingItem.firstDuplicateVariant([
      ClothingVariant(talla: 'M', color: 'Negro', existencia: 2),
      ClothingVariant(talla: 'm', color: 'negro', existencia: 1),
    ]);

    expect(duplicate, isNotNull);
    expect(duplicate!.color, 'negro');
    expect(duplicate.talla, 'm');
  });

  test('firstDuplicateVariant returns null when all pairs are unique', () {
    final duplicate = ClothingItem.firstDuplicateVariant([
      ClothingVariant(talla: 'CH', color: 'Negro', existencia: 2),
      ClothingVariant(talla: 'M', color: 'Negro', existencia: 5),
    ]);

    expect(duplicate, isNull);
  });

  test('toMap/fromMap round-trip preserves all fields', () {
    final item = ClothingItem(
      id: 'PRENDA-000007',
      nombre: 'Chamarra de mezclilla',
      precio: 899.5,
      variantes: [
        ClothingVariant(talla: 'CH', color: 'Azul', existencia: 3),
        ClothingVariant(talla: 'M', color: 'Negro', existencia: 0),
      ],
    );

    final restored = ClothingItem.fromMap(item.toMap());

    expect(restored.id, item.id);
    expect(restored.nombre, item.nombre);
    expect(restored.precio, item.precio);
    expect(restored.variantes.length, item.variantes.length);
    for (var i = 0; i < item.variantes.length; i++) {
      expect(restored.variantes[i].talla, item.variantes[i].talla);
      expect(restored.variantes[i].color, item.variantes[i].color);
      expect(restored.variantes[i].existencia, item.variantes[i].existencia);
    }
  });

  test('fromMap fills in safe defaults for missing optional fields', () {
    final restored = ClothingItem.fromMap({'id': 'PRENDA-000008'});

    expect(restored.id, 'PRENDA-000008');
    expect(restored.nombre, '');
    expect(restored.precio, 0);
    expect(restored.variantes, isEmpty);
  });
}
