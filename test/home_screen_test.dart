import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:tienda_ropa_app/data/clothing_repository.dart';
import 'package:tienda_ropa_app/models/clothing_item.dart';
import 'package:tienda_ropa_app/screens/home_screen.dart';

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

  Widget buildHomeScreen() {
    return MaterialApp(
      home: HomeScreen(repo: repo, isDarkMode: false, onToggleTheme: () {}),
    );
  }

  testWidgets('shows the empty-catalog message when there are no items', (
    tester,
  ) async {
    await tester.pumpWidget(buildHomeScreen());

    expect(
      find.text(
        'Aún no hay prendas registradas.\nEscanéala o agrégala con el botón +.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('lists an item that already exists in the repository', (
    tester,
  ) async {
    // repo.save does real file I/O, which needs tester.runAsync to escape
    // testWidgets' fake-async zone — otherwise it hangs forever.
    await tester.runAsync(
      () => repo.save(
        ClothingItem(
          id: 'PRENDA-000001',
          nombre: 'Playera básica',
          precio: 199,
          variantes: [
            ClothingVariant(talla: 'M', color: 'Negro', existencia: 5),
          ],
        ),
      ),
    );

    await tester.pumpWidget(buildHomeScreen());

    expect(find.text('Playera básica'), findsOneWidget);
    expect(find.text('\$199.00'), findsOneWidget);
  });

  testWidgets('filters the list as the user types in the search box', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await repo.save(
        ClothingItem(
          id: 'PRENDA-000001',
          nombre: 'Playera básica',
          precio: 199,
          variantes: const [],
        ),
      );
      await repo.save(
        ClothingItem(
          id: 'PRENDA-000002',
          nombre: 'Pantalón de mezclilla',
          precio: 599,
          variantes: const [],
        ),
      );
    });

    await tester.pumpWidget(buildHomeScreen());
    expect(find.text('Playera básica'), findsOneWidget);
    expect(find.text('Pantalón de mezclilla'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'pantalon');
    await tester.pump();

    expect(find.text('Playera básica'), findsNothing);
    expect(find.text('Pantalón de mezclilla'), findsOneWidget);
  });
}
