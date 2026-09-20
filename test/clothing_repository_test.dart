import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:tienda_ropa_app/data/clothing_repository.dart';
import 'package:tienda_ropa_app/models/clothing_item.dart';

void main() {
  late Directory tempDir;
  late ClothingRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test');
    Hive.init(tempDir.path);
    repo = ClothingRepository();
    await repo.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  test('saves an item and finds it by id', () async {
    final item = ClothingItem(
      id: 'qr-001',
      nombre: 'Playera básica',
      precio: 199.0,
      variantes: [ClothingVariant(talla: 'M', color: 'Negro', existencia: 5)],
    );

    await repo.save(item);
    final loaded = repo.getById('qr-001');

    expect(loaded, isNotNull);
    expect(loaded!.nombre, 'Playera básica');
    expect(loaded.existenciaTotal, 5);
  });

  test('search filters by name, case-insensitively', () async {
    await repo.save(ClothingItem(id: '1', nombre: 'Playera Nike', precio: 250, variantes: []));
    await repo.save(ClothingItem(id: '2', nombre: 'Pantalón Levi\'s', precio: 500, variantes: []));

    final results = repo.search('playera');

    expect(results, hasLength(1));
    expect(results.first.id, '1');
  });

  test('unknown id returns null, matching the "add new item" scan flow', () {
    expect(repo.getById('does-not-exist'), isNull);
  });
}
