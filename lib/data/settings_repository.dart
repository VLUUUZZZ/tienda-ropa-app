// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../auth/license.dart';

/// Tiny local-only store for app-wide preferences (currently just the theme).
///
/// Preferences are a convenience: if their storage can't be opened or
/// written, the app runs on the defaults instead of failing.
class SettingsRepository implements LicenseCache {
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

  static String _licHastaKey(String tiendaId) => 'lic_hasta_$tiendaId';
  static String _licVistaKey(String tiendaId) => 'lic_vista_$tiendaId';

  @override
  LicenseCacheEntry? read(String tiendaId) {
    final hasta = _box?.get(_licHastaKey(tiendaId));
    final vista = _box?.get(_licVistaKey(tiendaId));
    if (hasta is! int || vista is! int) return null;
    return LicenseCacheEntry(
      hasta: DateTime.fromMillisecondsSinceEpoch(hasta),
      validadaEn: DateTime.fromMillisecondsSinceEpoch(vista),
    );
  }

  @override
  Future<void> save(String tiendaId, LicenseCacheEntry entry) async {
    try {
      await _box?.put(
        _licHastaKey(tiendaId),
        entry.hasta.millisecondsSinceEpoch,
      );
      await _box?.put(
        _licVistaKey(tiendaId),
        entry.validadaEn.millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('No se pudo guardar la licencia en caché: $e');
    }
  }
}
