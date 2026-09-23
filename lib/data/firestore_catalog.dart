import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/clothing_item.dart';
import 'remote_catalog.dart';

/// Catalog stored in Firestore under `prendas/{id}`, where the document id is
/// the same id printed on the garment's QR.
class FirestoreCatalog implements RemoteCatalog {
  static const String collectionName = 'prendas';

  final FirebaseFirestore _firestore;

  FirestoreCatalog(this._firestore);

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(collectionName);

  @override
  Stream<RemoteSnapshot> watch() {
    return _collection.snapshots().map(
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
  Future<void> upsert(ClothingItem item) {
    return _collection.doc(item.id).set({
      ...item.toMap(),
      'actualizado': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> delete(String id) => _collection.doc(id).delete();
}
