// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Where each garment's photo file lives on this phone, if it has one.
///
/// Local only, on purpose: syncing a photo between phones needs a file
/// storage backend (e.g. Firebase Storage) this app doesn't use yet, so a
/// photo taken on one device isn't seen on another — see BACKLOG.md.
class LocalPhotos {
  LocalPhotos._(this._box);

  final Box _box;

  static Future<LocalPhotos> open(String boxName) async =>
      LocalPhotos._(await Hive.openBox(boxName));

  Future<void> close() => _box.close();

  /// Fires when a photo is set or removed, so a screen showing a thumbnail
  /// can refresh.
  Listenable get listenable => _box.listenable();

  /// Every garment id that currently has a stored photo.
  Iterable<String> get ids => _box.keys.cast<String>();

  String? pathFor(String itemId) => _box.get(itemId) as String?;

  Future<void> setPath(String itemId, String path) => _box.put(itemId, path);

  Future<void> remove(String itemId) => _box.delete(itemId);
}
