import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:tienda_ropa_app/data/clothing_repository.dart';
import 'package:tienda_ropa_app/models/clothing_item.dart';
import 'package:tienda_ropa_app/screens/item_form_screen.dart';

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

  Widget buildForm({List<ClothingVariant> variantes = const []}) {
    return MaterialApp(
      home: ItemFormScreen(
        repo: repo,
        item: ClothingItem(
          id: 'PRENDA-000001',
          nombre: '',
          precio: 0,
          variantes: variantes,
        ),
        isNew: true,
      ),
    );
  }

  testWidgets('shows validation errors when required fields are empty', (
    tester,
  ) async {
    await tester.pumpWidget(buildForm());

    await tester.tap(find.text('Guardar'));
    await tester.pump();

    expect(find.text('Requerido'), findsWidgets);
  });

  testWidgets(
    'warns about a duplicate color+talla combination without saving',
    (tester) async {
      await tester.pumpWidget(
        buildForm(
          variantes: [
            ClothingVariant(talla: 'M', color: 'Negro', existencia: 3),
          ],
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre de la prenda'),
        'Playera básica',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Precio'),
        '199',
      );

      await tester.tap(find.text('Agregar'));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Talla').last,
        'M',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Color').last,
        'Negro',
      );

      await tester.tap(find.text('Guardar'));
      await tester.pump();

      expect(find.textContaining('ya está registrada'), findsOneWidget);
    },
  );

  testWidgets(
    'shows AGOTADO only once a used row is filled with 0 existencia',
    (tester) async {
      await tester.pumpWidget(buildForm());

      expect(find.text('AGOTADO'), findsNothing);

      await tester.enterText(find.widgetWithText(TextFormField, 'Talla'), 'CH');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Color'),
        'Blanco',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Existencia'),
        '0',
      );
      await tester.pump();

      expect(find.text('AGOTADO'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Existencia'),
        '5',
      );
      await tester.pump();

      expect(find.text('AGOTADO'), findsNothing);
    },
  );

  testWidgets('Agregar adds a new blank variant row', (tester) async {
    await tester.pumpWidget(buildForm());

    expect(find.widgetWithText(TextFormField, 'Talla'), findsOneWidget);

    await tester.tap(find.text('Agregar'));
    await tester.pump();

    expect(find.widgetWithText(TextFormField, 'Talla'), findsNWidgets(2));
  });
}
