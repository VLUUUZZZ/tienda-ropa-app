import '../models/clothing_item.dart';

/// One full view of the remote catalog, as pushed by the backend.
class RemoteSnapshot {
  /// The documents that could be read as garments.
  final List<ClothingItem> items;

  /// Every document id in the remote, including ones that couldn't be read.
  /// Deletions are judged by this, not by [items]: a document that exists
  /// but is malformed (e.g. edited by hand in the console) must not look
  /// deleted and take the device's good copy with it.
  final Set<String> ids;

  /// True when the data was confirmed by the server rather than served from
  /// the device's offline cache. Only server-confirmed snapshots are trusted
  /// to say an item was deleted: a cold or partial cache could otherwise look
  /// like "everything was deleted".
  final bool fromServer;

  RemoteSnapshot({
    required this.items,
    required this.fromServer,
    Set<String>? ids,
  }) : ids = ids ?? {for (final item in items) item.id};
}

/// The remote side of the catalog (Firestore in the app, a fake in tests).
/// [ClothingRepository] keeps Hive as what the UI reads and mirrors changes
/// to and from this.
abstract class RemoteCatalog {
  Stream<RemoteSnapshot> watch();

  /// The server's current version of [id], or null if it doesn't exist
  /// there. Throws if it can't be reached or read.
  Future<ClothingItem?> fetch(String id);

  /// Creates [item] only if its id doesn't already exist remotely; throws
  /// [RemoteIdTaken] if it does. Used for an id this device minted and has
  /// never confirmed exists anywhere else, so two devices that independently
  /// minted the same id while both offline don't silently overwrite each
  /// other — see [CatalogSync].
  Future<void> create(ClothingItem item);

  Future<void> upsert(ClothingItem item);

  Future<void> delete(String id);

  /// Atomically applies [deltas] (see [ClothingItem.withStockChanges]) to
  /// [id]'s stock on the server, instead of overwriting the whole document
  /// with a locally-computed result: two devices applying a delta to the
  /// same garment at nearly the same time (e.g. two sales) must both take
  /// effect, not have the second one silently discard the first. Throws if
  /// the garment doesn't exist remotely.
  Future<ClothingItem> applyStockDelta(String id, Map<String, int> deltas);
}

/// The remote refused a write for good (e.g. the user's role doesn't allow
/// it), as opposed to a failure worth retrying.
class RemoteWriteRejected implements Exception {
  const RemoteWriteRejected(this.reason);

  final String reason;

  @override
  String toString() => 'Escritura rechazada: $reason';
}

/// [RemoteCatalog.create] found [id] already taken by another device.
class RemoteIdTaken implements Exception {
  const RemoteIdTaken(this.id);

  final String id;

  @override
  String toString() => 'El id $id ya existe en el catálogo remoto.';
}
