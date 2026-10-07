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
    return _collection
        .snapshots(includeMetadataChanges: true)
        .map(
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
  Future<void> create(ClothingItem item) => _write(() async {
    await _collection.firestore.runTransaction((tx) async {
      final ref = _collection.doc(item.id);
      if ((await tx.get(ref)).exists) throw RemoteIdTaken(item.id);
      tx.set(ref, {
        ...item.toMap(),
        'actualizado': FieldValue.serverTimestamp(),
      });
    });
  });

  @override
  Future<void> upsert(ClothingItem item) => _write(
    () => _collection.doc(item.id).set({
      ...item.toMap(),
      'actualizado': FieldValue.serverTimestamp(),
    }),
  );

  @override
  Future<void> delete(String id) => _write(() => _collection.doc(id).delete());

  @override
  Future<ClothingItem> applyStockDelta(String id, Map<String, int> deltas) =>
      _write(() async {
        final ref = _collection.doc(id);
        return _collection.firestore.runTransaction((tx) async {
          final snap = await tx.get(ref);
          final data = snap.data();
          if (data == null) {
            throw StateError('La prenda $id ya no existe en el servidor.');
          }
          // Applied against whatever the server has *right now*, not a
          // possibly-stale local copy: a concurrent transaction on the same
          // document is retried by Firestore from a fresh read, so two
          // overlapping sales both land instead of one clobbering the other.
          final current = ClothingItem.fromMap({...data, 'id': id});
          final updated = current.withStockChanges(deltas);
          tx.update(ref, {
            'variantes': updated.variantes.map((v) => v.toMap()).toList(),
            'actualizado': FieldValue.serverTimestamp(),
          });
          return updated;
        });
      });

  /// A rules rejection won't succeed on retry, so it's reported as
  /// [RemoteWriteRejected] instead of a plain error.
  static Future<T> _write<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw RemoteWriteRejected(e.message ?? e.code);
      }
      rethrow;
    }
  }
}
