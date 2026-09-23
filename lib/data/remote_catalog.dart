import '../models/clothing_item.dart';

/// One full view of the remote catalog, as pushed by the backend.
class RemoteSnapshot {
  final List<ClothingItem> items;

  /// True when the data was confirmed by the server rather than served from
  /// the device's offline cache. Only server-confirmed snapshots are trusted
  /// to say an item was deleted: a cold or partial cache could otherwise look
  /// like "everything was deleted".
  final bool fromServer;

  const RemoteSnapshot({required this.items, required this.fromServer});
}

/// The remote side of the catalog (Firestore in the app, a fake in tests).
/// [ClothingRepository] keeps Hive as what the UI reads and mirrors changes
/// to and from this.
abstract class RemoteCatalog {
  Stream<RemoteSnapshot> watch();

  Future<void> upsert(ClothingItem item);

  Future<void> delete(String id);
}

/// The remote refused a write for good (e.g. the user's role doesn't allow
/// it), as opposed to a failure worth retrying.
class RemoteWriteRejected implements Exception {
  const RemoteWriteRejected(this.reason);

  final String reason;

  @override
  String toString() => 'Escritura rechazada: $reason';
}
