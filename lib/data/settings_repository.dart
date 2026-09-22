import 'package:hive_flutter/hive_flutter.dart';

/// Tiny local-only store for app-wide preferences (currently just the theme).
class SettingsRepository {
  static const String boxName = 'app_settings';
  static const String _darkModeKey = 'isDarkMode';

  late final Box _box;

  Future<void> init() async {
    _box = await Hive.openBox(boxName);
  }

  bool get isDarkMode => (_box.get(_darkModeKey) as bool?) ?? false;

  Future<void> setDarkMode(bool value) => _box.put(_darkModeKey, value);
}
