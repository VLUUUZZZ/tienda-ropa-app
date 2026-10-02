import '../models/sale.dart';

// Reused instead of duplicated: a rules rejection means the same thing for a
// sale upload as it does for a catalog write. Re-exported so callers of this
// file (FirestoreSales, SalesSync) don't also need to import
// remote_catalog.dart.
export 'remote_catalog.dart' show RemoteWriteRejected;

/// One full view of the remote sales log, as pushed by the backend.
class RemoteSalesSnapshot {
  final List<Sale> items;

  /// True when the data was confirmed by the server rather than served from
  /// the device's offline cache.
  final bool fromServer;

  const RemoteSalesSnapshot({required this.items, required this.fromServer});
}

/// The remote side of the sales log (Firestore in the app, a fake in tests).
/// [SalesRepository] keeps Hive as what the UI reads and mirrors changes to
/// this.
///
/// Sales are append-only — there's no `upsert`/`delete` as in
/// [RemoteCatalog], only [upload] of a newly-recorded sale.
abstract class RemoteSales {
  Stream<RemoteSalesSnapshot> watch();

  Future<void> upload(Sale sale);
}
