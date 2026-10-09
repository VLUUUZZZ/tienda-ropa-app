// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Where everything lives in Firestore, in one place (mirrors
/// `firestore.rules`):
///
/// * `usuarios/{uid}`: each user's profile, store and role.
/// * `tiendas/{tiendaId}`: each store.
/// * `tiendas/{tiendaId}/prendas/{prendaId}`: that store's catalog.
/// * `tiendas/{tiendaId}/ventas/{ventaId}`: that store's sales log.
/// * `tiendas/{tiendaId}/ajustes/{ajusteId}`: that store's stock-adjustment
///   history.
abstract final class FirestorePaths {
  static CollectionReference<Map<String, dynamic>> users(
    FirebaseFirestore db,
  ) => db.collection('usuarios');

  static DocumentReference<Map<String, dynamic>> user(
    FirebaseFirestore db,
    String uid,
  ) => users(db).doc(uid);

  static CollectionReference<Map<String, dynamic>> stores(
    FirebaseFirestore db,
  ) => db.collection('tiendas');

  static CollectionReference<Map<String, dynamic>> catalog(
    FirebaseFirestore db,
    String tiendaId,
  ) => stores(db).doc(tiendaId).collection('prendas');

  static CollectionReference<Map<String, dynamic>> sales(
    FirebaseFirestore db,
    String tiendaId,
  ) => stores(db).doc(tiendaId).collection('ventas');

  static CollectionReference<Map<String, dynamic>> adjustments(
    FirebaseFirestore db,
    String tiendaId,
  ) => stores(db).doc(tiendaId).collection('ajustes');
}
