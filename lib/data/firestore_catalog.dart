import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../firestore_paths.dart';
import '../models/clothing_item.dart';
import 'remote_catalog.dart';

/// One store's catalog in Firestore (see [FirestorePaths.catalog]), where the
/// document id is the same id printed on the garment's QR.
class FirestoreCatalog implements RemoteCatalog {
  FirestoreCatalog(FirebaseFirestore firestore, String tiendaId)
    : _collection = FirestorePaths.catalog(firestore, tiendaId);

  final CollectionReference<Map<String, dynamic>> _collection;

  @override
  Stream<RemoteSnapshot> watch() {
    // Without this, a cache snapshot that already matches the server (e.g. a
    // brand-new, still-empty store) never gets a follow-up event once the
    // server confirms it — Firestore treats that transition as a
    // metadata-only change and skips it by default. That follow-up is what
    // [CatalogSync] waits for to know it can trust the server's answer.
    return _collection.snapshots(includeMetadataChanges: true).map(
      (snapshot) => RemoteSnapshot(
        items: snapshot.docs.map(_parse).nonNulls.toList(),
        fromServer: !snapshot.metadata.isFromCache,
      ),
    );
  }

  ClothingItem? _parse(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      return ClothingItem.fromMap({...doc.data(), 'id': doc.id});
    } catch (e) {
      // One malformed document (e.g. edited by hand in the console) must not
      // stop the rest of the catalog from syncing.
      debugPrint('Documento ${doc.id} ignorado: $e');
      return null;
    }
  }

  @override
  Future<void> upsert(ClothingItem item) => _write(
    () => _collection.doc(item.id).set({
      ...item.toMap(),
      'actualizado': FieldValue.serverTimestamp(),
    }),
  );

  @override
  Future<void> delete(String id) => _write(() => _collection.doc(id).delete());

  /// A rules rejection won't succeed on retry, so it's reported as
  /// [RemoteWriteRejected] instead of a plain error.
  static Future<void> _write(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw RemoteWriteRejected(e.message ?? e.code);
      }
      rethrow;
    }
  }
}
