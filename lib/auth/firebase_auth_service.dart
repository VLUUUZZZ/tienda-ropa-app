import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app_user.dart';
import 'auth_service.dart';
import 'firebase_auth_errors.dart';

/// [AuthService] on Firebase Auth (email and password), with each user's role
/// kept in Firestore under `usuarios/{uid}`.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this._auth, this._firestore);

  static const String usersCollection = 'usuarios';

  /// Exists once the first administrator was created; the security rules
  /// only allow creating an admin for yourself while it doesn't.
  static const String _setupDocPath = 'config/inicial';

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _profiles =>
      _firestore.collection(usersCollection);

  @override
  Stream<AuthState> watch() {
    late final StreamController<AuthState> controller;
    StreamSubscription<User?>? authSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? profileSub;

    void followProfile(User? user) {
      unawaited(profileSub?.cancel());
      profileSub = null;
      if (user == null) {
        controller.add(const SignedOut());
        return;
      }
      controller.add(const AuthLoading());
      // A live listener, so a role change or deactivation applies at once.
      profileSub = _profiles.doc(user.uid).snapshots().listen((doc) {
        final state = _stateFor(user, doc);
        if (state != null) controller.add(state);
      }, onError: (Object _) => controller.add(AccessDenied(user.email ?? '')));
    }

    controller = StreamController<AuthState>(
      onListen: () => authSub = _auth.authStateChanges().listen(followProfile),
      onCancel: () async {
        await profileSub?.cancel();
        await authSub?.cancel();
      },
    );
    return controller.stream;
  }

  /// Null while the answer isn't known yet: right after signing in, the
  /// profile may simply not be in the offline cache.
  static AuthState? _stateFor(
    User user,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      return doc.metadata.isFromCache ? null : AccessDenied(user.email ?? '');
    }
    final profile = AppUser.fromMap(user.uid, data);
    return profile.activo ? SignedIn(profile) : AccessDenied(profile.correo);
  }

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
  Future<void> sendPasswordReset(String correo) =>
      _guard(() => _auth.sendPasswordResetEmail(email: correo.trim()));

  @override
  Future<bool> needsFirstAdmin() async {
    try {
      final setup = await _firestore
          .doc(_setupDocPath)
          .get(const GetOptions(source: Source.server));
      return !setup.exists;
    } catch (_) {
      // Offline or unknown: never offer admin setup on a guess.
      return false;
    }
  }

  @override
  Future<void> createFirstAdmin({
    required String nombre,
    required String correo,
    required String password,
  }) async {
    final credential = await _guard(
      () => _auth.createUserWithEmailAndPassword(
        email: correo.trim(),
        password: password,
      ),
    );
    final user = credential.user!;
    final profile = AppUser(
      uid: user.uid,
      nombre: nombre.trim(),
      correo: correo.trim(),
      role: UserRole.admin,
    );

    // One batch, so the rules can check both writes together.
    final batch = _firestore.batch()
      ..set(_profiles.doc(user.uid), {
        ...profile.toMap(),
        'creado': FieldValue.serverTimestamp(),
      })
      ..set(_firestore.doc(_setupDocPath), {'adminUid': user.uid});
    try {
      await batch.commit();
    } catch (_) {
      // Someone else finished setup first: don't leave an account behind.
      await user.delete();
      throw const AuthException('Este proyecto ya tiene administrador.');
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
