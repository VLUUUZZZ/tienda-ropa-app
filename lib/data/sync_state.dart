import 'package:hive_flutter/hive_flutter.dart';

/// What sync needs to remember across app restarts: which local changes the
/// remote hasn't confirmed yet, and whether this device's pre-sync catalog
/// was already uploaded.
class SyncState {
  SyncState._(this._box);

  static const String _boxName = 'catalog_sync';

  /// Set once the items that existed only on this device (from before the
  /// backend was connected) have been uploaded.
  static const String _initialUploadKey = 'uploadedLocalCatalog';

  /// `pendiente:<id>` -> token of the latest unconfirmed change to that item.
  /// The token lets a confirmation of an older change be ignored while a
  /// newer change to the same item is still in flight.
  static const String _pendingPrefix = 'pendiente:';
  static const String _pendingSeqKey = 'pendienteSeq';

  final Box _box;

  static Future<SyncState> open() async =>
      SyncState._(await Hive.openBox(_boxName));

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
}
