// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app_user.dart';
import 'auth_service.dart';
import 'license.dart';
import 'firebase_auth_errors.dart';
import 'session_watcher.dart';
import '../firestore_paths.dart';

/// [AuthService] on Firebase Auth (email and password), with each user's
/// store and role kept in Firestore under `usuarios/{uid}`.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this._auth, this._firestore, {LicenseCache? licenseCache})
    : _licenseCache = licenseCache;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final LicenseCache? _licenseCache;

  /// True while [createStore] is writing this device's own profile: read by
  /// [SessionWatcher] so it doesn't flash "sin acceso" while that write is
  /// still in flight.
  bool _provisioningStore = false;

  /// Each listener gets its own [SessionWatcher].
  @override
  Stream<AuthState> watch() => SessionWatcher(
    _auth,
    _firestore,
    isProvisioning: () => _provisioningStore,
    licenseCache: _licenseCache,
  ).states;

  @override
  Future<void> signIn({required String correo, required String password}) =>
      _guard(
        () => _auth.signInWithEmailAndPassword(
          email: correo.trim(),
          password: password,
        ),
      );

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> sendPasswordReset(String correo) async {
    try {
      await _auth.sendPasswordResetEmail(email: correo.trim());
    } on FirebaseAuthException catch (e) {
      throw passwordResetExceptionFrom(e);
    }
  }

  @override
  Future<void> createStore({
    required String nombreTienda,
    required String nombre,
    required String correo,
    required String password,
  }) async {
    _provisioningStore = true;
    try {
      final credential = await _guard(
        () => _auth.createUserWithEmailAndPassword(
          email: correo.trim(),
          password: password,
        ),
      );
      final user = credential.user!;
      final tiendaRef = FirestorePaths.stores(_firestore).doc();
      final admin = AppUser(
        uid: user.uid,
        nombre: nombre.trim(),
        correo: correo.trim(),
        role: UserRole.admin,
        tienda: Tienda(id: tiendaRef.id, nombre: nombreTienda.trim()),
      );

      // One batch, so the rules can check the store and its owner together.
      final batch = _firestore.batch()
        ..set(tiendaRef, {
          'nombre': nombreTienda.trim(),
          'duenoUid': user.uid,
          'creada': FieldValue.serverTimestamp(),
          // Prueba inicial: la tienda funciona unos días hasta que el dueño
          // de la app le fije su licencia. Las reglas no permiten al creador
          // ponerse una fecha mayor que esta.
          'licenciaHasta': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: LicenseConfig.diasPrueba)),
          ),
        })
        ..set(FirestorePaths.user(_firestore, user.uid), {
          ...admin.toMap(),
          'creado': FieldValue.serverTimestamp(),
        });
      try {
        await batch.commit();
      } catch (_) {
        // Don't leave behind an account with no store. If even this fails,
        // the account stays orphaned, but the message shown must still be
        // the one below and not whatever this cleanup attempt threw.
        try {
          await user.delete();
        } catch (_) {
          // Ignored: reported below regardless of the outcome.
        }
        throw const AuthException(
          'No se pudo crear la tienda. Revisa tu conexión e inténtalo de nuevo.',
        );
      }
    } finally {
      _provisioningStore = false;
    }
  }

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw authExceptionFrom(e);
    }
  }
}
