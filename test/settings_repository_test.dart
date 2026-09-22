import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:tienda_ropa_app/data/settings_repository.dart';

void main() {
  late Directory tempDir;
  late SettingsRepository settings;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test');
    Hive.init(tempDir.path);
    settings = SettingsRepository();
    await settings.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  test('defaults to light mode when nothing was saved yet', () {
    expect(settings.isDarkMode, isFalse);
  });

  test('persists the dark mode preference', () async {
    await settings.setDarkMode(true);
    expect(settings.isDarkMode, isTrue);

    await settings.setDarkMode(false);
    expect(settings.isDarkMode, isFalse);
  });
}
