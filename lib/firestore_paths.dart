import 'package:cloud_firestore/cloud_firestore.dart';

/// Where everything lives in Firestore, in one place (mirrors
/// `firestore.rules`):
///
/// * `usuarios/{uid}`: each user's profile, store and role.
/// * `tiendas/{tiendaId}`: each store.
/// * `tiendas/{tiendaId}/prendas/{prendaId}`: that store's catalog.
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
}
