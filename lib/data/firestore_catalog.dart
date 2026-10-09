// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'dart:convert';

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
    // Without includeMetadataChanges, a cache snapshot that already matches
    // the server (e.g. a brand-new, still-empty store) never gets a follow-up
    // event once the server confirms it — Firestore treats that transition as
    // a metadata-only change and skips it by default. That follow-up is what
    // [CatalogSync] waits for to know it can trust the server's answer.
    //
    // The price is an extra event per local write (pending -> confirmed),
    // each of which would make sync re-read and compare the whole catalog.
    // Those are let through only if a garment actually changed or the
    // cache/server state did. State is per listen, so a re-listen starts
    // fresh.
    bool? lastFromServer;
    final seen = <String, String>{};

    return _collection
        .snapshots(includeMetadataChanges: true)
        .where((snapshot) {
          final fromServer = !snapshot.metadata.isFromCache;
          var relevant = fromServer != lastFromServer;
          lastFromServer = fromServer;
          for (final change in snapshot.docChanges) {
            final id = change.doc.id;
            if (change.type == DocumentChangeType.removed) {
              relevant |= seen.remove(id) != null;
            } else {
              final signature = _signature(change.doc);
              relevant |= seen[id] != signature;
              seen[id] = signature;
            }
          }
          return relevant;
        })
        .map(
          (snapshot) => RemoteSnapshot(
            items: snapshot.docs.map(_parse).nonNulls.toList(),
            ids: {for (final doc in snapshot.docs) doc.id},
            fromServer: !snapshot.metadata.isFromCache,
          ),
        );
  }

  /// What the app reads from a document, to tell a real change from a
  /// metadata-only one (the server timestamp isn't part of a garment).
  static String _signature(DocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      final data = doc.data();
      if (data == null) return '';
      return jsonEncode(ClothingItem.fromMap({...data, 'id': doc.id}).toMap());
    } catch (_) {
      return 'ilegible:${doc.data()}';
    }
  }

  @override
  Future<ClothingItem?> fetch(String id) async {
    final doc = await _collection
        .doc(id)
        .get(const GetOptions(source: Source.server));
    final data = doc.data();
    if (data == null) return null;
    return ClothingItem.fromMap({...data, 'id': doc.id});
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
