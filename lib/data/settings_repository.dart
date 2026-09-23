import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Tiny local-only store for app-wide preferences (currently just the theme).
///
/// Preferences are a convenience: if their storage can't be opened or
/// written, the app runs on the defaults instead of failing.
class SettingsRepository {
  SettingsRepository._(this._box);

  static const String boxName = 'app_settings';
  static const String _darkModeKey = 'isDarkMode';

  /// Null when the storage couldn't be opened.
  final Box? _box;

  static Future<SettingsRepository> open() async {
    try {
      return SettingsRepository._(await Hive.openBox(boxName));
    } catch (e) {
      debugPrint('Preferencias no disponibles, se usan las de fábrica: $e');
      return SettingsRepository._(null);
    }
  }

  bool get isDarkMode => _box?.get(_darkModeKey) == true;

  Future<void> setDarkMode(bool value) async {
    try {
      await _box?.put(_darkModeKey, value);
    } catch (e) {
      debugPrint('No se pudo guardar el tema: $e');
    }
  }
}
