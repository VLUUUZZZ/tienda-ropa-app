import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// What sync needs to remember across app restarts: which local changes the
/// remote hasn't confirmed yet, and whether this device's pre-sync catalog
/// was already uploaded.
class SyncState {
  SyncState._(this._box);

  /// Set once the items that existed only on this device (from before the
  /// backend was connected) have been uploaded.
  static const String _initialUploadKey = 'uploadedLocalCatalog';

  /// `pendiente:<id>` -> token of the latest unconfirmed change to that item.
  /// The token lets a confirmation of an older change be ignored while a
  /// newer change to the same item is still in flight.
  static const String _pendingPrefix = 'pendiente:';
  static const String _pendingSeqKey = 'pendienteSeq';

  /// `nuevo:<id>` -> true while [id] was minted by this device and never
  /// confirmed to exist anywhere else yet (see [CatalogSync]).
  static const String _mintedPrefix = 'nuevo:';

  final Box _box;

  static Future<SyncState> open(String boxName) async =>
      SyncState._(await Hive.openBox(boxName));

  Future<void> close() => _box.close();

  /// Fires whenever a change is marked pending or confirmed, so the screens
  /// can show whether everything reached the server.
  Listenable get listenable => _box.listenable();

  static const String _lastSyncKey = 'ultimaSincronizacion';

  /// Last time the server confirmed data or a change, kept across restarts
  /// so it can be shown even before reconnecting.
  DateTime? get lastSync {
    final stored = _box.get(_lastSyncKey);
    return stored is int ? DateTime.fromMillisecondsSinceEpoch(stored) : null;
  }

  Future<void> setLastSync(DateTime when) =>
      _box.put(_lastSyncKey, when.millisecondsSinceEpoch);

  bool get initialUploadDone => _box.get(_initialUploadKey) == true;

  Future<void> markInitialUploadDone() => _box.put(_initialUploadKey, true);

  Set<String> get pendingIds => _box.keys
      .whereType<String>()
      .where((key) => key.startsWith(_pendingPrefix))
      .map((key) => key.substring(_pendingPrefix.length))
      .toSet();

  /// Records that [id] changed locally; returns the token identifying this
  /// change.
  Future<int> markPending(String id) async {
    final token = ((_box.get(_pendingSeqKey) as int?) ?? 0) + 1;
    await _box.put(_pendingSeqKey, token);
    await _box.put(_pendingKey(id), token);
    return token;
  }

  int? pendingToken(String id) => _box.get(_pendingKey(id)) as int?;

  /// Clears [id]'s pending mark, unless a newer change replaced [token].
  Future<void> confirm(String id, int token) async {
    if (pendingToken(id) == token) await _box.delete(_pendingKey(id));
  }

  static String _pendingKey(String id) => '$_pendingPrefix$id';

  /// Marks [id] as freshly minted by this device: its first push must
  /// create it remotely only if no one else's device already claimed that
  /// id while both were offline, instead of blindly overwriting it.
  Future<void> markLocallyMinted(String id) => _box.put(_mintedKey(id), true);

  bool isLocallyMinted(String id) => _box.get(_mintedKey(id)) == true;

  Future<void> clearLocallyMinted(String id) => _box.delete(_mintedKey(id));

  /// Every id still marked as freshly minted (see [markLocallyMinted]),
  /// including ones whose "new item" flow was abandoned before ever being
  /// saved — those are never cleared otherwise and would sit in this box
  /// forever.
  Set<String> get mintedIds => _box.keys
      .whereType<String>()
      .where((key) => key.startsWith(_mintedPrefix))
      .map((key) => key.substring(_mintedPrefix.length))
      .toSet();

  static String _mintedKey(String id) => '$_mintedPrefix$id';
}
