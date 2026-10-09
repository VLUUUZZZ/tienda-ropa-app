// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import '../models/stock_adjustment.dart';

// Reused instead of duplicated: a rules rejection means the same thing for an
// adjustment upload as it does for a catalog write.
export 'remote_catalog.dart' show RemoteWriteRejected;

/// One full view of the remote adjustment history, as pushed by the backend.
class RemoteAdjustmentsSnapshot {
  final List<StockAdjustment> items;

  /// True when the data was confirmed by the server rather than served from
  /// the device's offline cache.
  final bool fromServer;

  const RemoteAdjustmentsSnapshot({
    required this.items,
    required this.fromServer,
  });
}

/// The remote side of the adjustment history (Firestore in the app, a fake in
/// tests). [AdjustmentsRepository] keeps Hive as what the UI reads and
/// mirrors changes to this.
///
/// Adjustments are append-only — there's no `upsert`/`delete` as in
/// [RemoteCatalog], only [upload] of a newly-recorded adjustment.
abstract class RemoteAdjustments {
  Stream<RemoteAdjustmentsSnapshot> watch();

  Future<void> upload(StockAdjustment adjustment);
}
