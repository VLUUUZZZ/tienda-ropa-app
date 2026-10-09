// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../firestore_paths.dart';
import '../models/stock_adjustment.dart';
import 'remote_adjustments.dart';

/// One store's stock-adjustment history in Firestore (see
/// [FirestorePaths.adjustments]).
class FirestoreAdjustments implements RemoteAdjustments {
  FirestoreAdjustments(FirebaseFirestore firestore, String tiendaId)
    : _collection = FirestorePaths.adjustments(firestore, tiendaId);

  final CollectionReference<Map<String, dynamic>> _collection;

  @override
  Stream<RemoteAdjustmentsSnapshot> watch() {
    // Same reasoning as FirestoreSales.watch: includeMetadataChanges is what
    // lets a cache snapshot that already matches the server (e.g. a
    // brand-new, still-empty log) get the follow-up event that
    // AdjustmentsSync waits for to know it can trust the server's answer.
    return _collection
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => RemoteAdjustmentsSnapshot(
            items: snapshot.docs.map(_parse).nonNulls.toList(),
            fromServer: !snapshot.metadata.isFromCache,
          ),
        );
  }

  StockAdjustment? _parse(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      return StockAdjustment.fromMap({...doc.data(), 'id': doc.id});
    } catch (e) {
      // One malformed document (e.g. edited by hand in the console) must
      // not stop the rest of the log from syncing.
      debugPrint('Documento de ajuste ${doc.id} ignorado: $e');
      return null;
    }
  }

  @override
  Future<void> upload(StockAdjustment adjustment) async {
    try {
      // No equivalent of upsert's merge semantics is needed: an adjustment's
      // id is only ever written once, by the device that recorded it.
      await _collection.doc(adjustment.id).set({
        ...adjustment.toMap(),
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
