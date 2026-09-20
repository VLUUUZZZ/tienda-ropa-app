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
}
