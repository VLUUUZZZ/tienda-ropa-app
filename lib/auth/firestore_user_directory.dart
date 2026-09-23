import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firestore_paths.dart';
import 'app_user.dart';
import 'auth_service.dart';
import 'firebase_auth_errors.dart';
import 'user_directory.dart';

/// [UserDirectory] on Firebase: accounts in Firebase Auth, profiles (store
/// and role) in the `usuarios` collection.
class FirestoreUserDirectory implements UserDirectory {
  FirestoreUserDirectory(this._firestore, this._options);

  /// Name of a second Firebase app used only to create accounts: creating
  /// one signs in as it, and doing that on the main app would log the
  /// admin out.
  static const String _accountCreatorApp = 'altaUsuarios';

  final FirebaseFirestore _firestore;
  final FirebaseOptions _options;

  @override
  Stream<List<AppUser>> watchStore(Tienda tienda) =>
      FirestorePaths.users(_firestore)
          .where('tiendaId', isEqualTo: tienda.id)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs
                    .map((doc) => AppUser.fromMap(doc.id, doc.data()))
                    .toList()
                  ..sort(
                    (a, b) => a.nombre.toLowerCase().compareTo(
                      b.nombre.toLowerCase(),
                    ),
                  ),
          );

  @override
  Future<void> create({
    required Tienda tienda,
    required String nombre,
    required String correo,
    required String password,
    required UserRole role,
  }) async {
    final creatorAuth = FirebaseAuth.instanceFor(app: await _creatorApp());
    try {
      final UserCredential credential;
      try {
        credential = await creatorAuth.createUserWithEmailAndPassword(
          email: correo.trim(),
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        throw authExceptionFrom(e);
      }
      final account = credential.user!;

      final profile = AppUser(
        uid: account.uid,
        nombre: nombre.trim(),
        correo: correo.trim(),
        role: role,
        tienda: tienda,
      );
      try {
        // Not timed out: offline, Firestore keeps the write queued and
        // sends it later, so giving up here would leave a profile behind
        // for an account deleted below.
        await _write(
          () => FirestorePaths.user(
            _firestore,
            profile.uid,
          ).set({...profile.toMap(), 'creado': FieldValue.serverTimestamp()}),
        );
      } catch (e) {
        // Without its profile the account can't enter any store, and its
        // email would stay taken. Still signed in as it on the creator app,
        // so it can remove itself.
        await _deleteQuietly(account);
        if (e is AuthException) rethrow;
        throw const AuthException(
          'No se pudo crear el usuario. Revisa tu conexión e inténtalo de nuevo.',
        );
      }
    } finally {
      await creatorAuth.signOut();
    }
  }

  static Future<void> _deleteQuietly(User account) async {
    try {
      await account.delete();
    } catch (e) {
      debugPrint('No se pudo borrar la cuenta sin perfil ${account.uid}: $e');
    }
  }

  @override
  Future<void> update(AppUser user) => _write(
    () => FirestorePaths.user(_firestore, user.uid).update(user.toMap()),
  );

  Future<FirebaseApp> _creatorApp() async {
    for (final app in Firebase.apps) {
      if (app.name == _accountCreatorApp) return app;
    }
    return Firebase.initializeApp(name: _accountCreatorApp, options: _options);
  }

  static Future<void> _write(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseException catch (e) {
      throw AuthException(
        e.code == 'permission-denied'
            ? 'No tienes permiso para gestionar usuarios.'
            : 'No se pudo guardar el usuario (${e.code}).',
      );
    }
  }
}
