import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../firestore_paths.dart';
import '../models/sale.dart';
import 'remote_sales.dart';

/// One store's sales log in Firestore (see [FirestorePaths.sales]).
class FirestoreSales implements RemoteSales {
  FirestoreSales(FirebaseFirestore firestore, String tiendaId)
    : _collection = FirestorePaths.sales(firestore, tiendaId);

  final CollectionReference<Map<String, dynamic>> _collection;

  @override
  Stream<RemoteSalesSnapshot> watch() {
    // Same reasoning as FirestoreCatalog.watch: includeMetadataChanges is
    // what lets a cache snapshot that already matches the server (e.g. a
    // brand-new, still-empty log) get the follow-up event that SalesSync
    // waits for to know it can trust the server's answer.
    return _collection
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => RemoteSalesSnapshot(
            items: snapshot.docs.map(_parse).nonNulls.toList(),
            fromServer: !snapshot.metadata.isFromCache,
          ),
        );
  }

  Sale? _parse(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      return Sale.fromMap({...doc.data(), 'id': doc.id});
    } catch (e) {
      // One malformed document (e.g. edited by hand in the console) must
      // not stop the rest of the log from syncing.
      debugPrint('Documento de venta ${doc.id} ignorado: $e');
      return null;
    }
  }

  @override
  Future<void> upload(Sale sale) async {
    try {
      // No equivalent of upsert's merge semantics is needed: a sale's id is
      // only ever written once, by the device that recorded it.
      await _collection.doc(sale.id).set({
        ...sale.toMap(),
        'creado': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      // A rules rejection won't succeed on retry, so it's reported as
      // RemoteWriteRejected instead of a plain error.
      if (e.code == 'permission-denied') {
        throw RemoteWriteRejected(e.message ?? e.code);
      }
      rethrow;
    }
  }
}
