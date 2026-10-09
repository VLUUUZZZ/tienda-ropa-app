// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/backoff.dart';
import '../firestore_paths.dart';
import 'app_user.dart';
import 'auth_service.dart';

/// Turns Firebase Auth's signed-in user plus their live Firestore profile
/// into [AuthState]s.
///
/// The profile is followed live, so a role change or deactivation applies at
/// once. If that listener fails for a transient reason (network, server) it
/// is re-opened with [Backoff] while the current state is kept; only a real
/// permission denial shows as [AccessDenied].
class SessionWatcher {
  SessionWatcher(this._auth, this._firestore, {this.isProvisioning = _never});

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// True while this device itself is in the middle of creating a brand-new
  /// store: its own profile document may not have reached Firestore yet, so
  /// a missing document must not be read as "no access" during that window.
  final bool Function() isProvisioning;

  static bool _never() => false;

  final Backoff _backoff = Backoff(
    initial: const Duration(seconds: 3),
    max: const Duration(minutes: 2),
  );

  late final StreamController<AuthState> _controller =
      StreamController<AuthState>(onListen: _start, onCancel: _stop);

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  Timer? _retryTimer;

  Stream<AuthState> get states => _controller.stream;

  void _start() {
    _authSub = _auth.authStateChanges().listen(_onUser);
  }

  Future<void> _stop() async {
    _stopProfile();
    await _authSub?.cancel();
  }

  void _onUser(User? user) {
    _stopProfile();
    _backoff.reset();
    if (user == null) {
      _controller.add(const SignedOut());
      return;
    }
    _controller.add(const AuthLoading());
    _followProfile(user);
  }

  void _followProfile(User user) {
    // includeMetadataChanges: true, same as CatalogSync's listener, so a
    // cached "no such document" that the server later confirms still fires:
    // otherwise that transition is metadata-only and gets skipped, leaving
    // a nonexistent profile stuck in AuthLoading forever.
    _profileSub = FirestorePaths.user(_firestore, user.uid)
        .snapshots(includeMetadataChanges: true)
        .listen(
          (doc) {
            _backoff.reset();
            final state = _stateFor(user, doc, isProvisioning());
            if (state != null) _controller.add(state);
          },
          onError: (Object e) => _onProfileError(user, e),
          // Firestore can also close the listener without an error; without this
          // a role change or reactivation could stop being picked up for the
          // rest of the session.
          onDone: () => _scheduleProfileRetry(user),
        );
  }

  void _onProfileError(User user, Object error) {
    debugPrint('Error al leer el perfil de ${user.uid}: $error');
    if (error is FirebaseException && error.code == 'permission-denied') {
      _controller.add(AccessDenied(user.email ?? ''));
    }
    _scheduleProfileRetry(user);
  }

  /// Re-opens the profile listener after an error or an unexpected close, or
  /// later role changes (or the connection coming back) would never be seen.
  void _scheduleProfileRetry(User user) {
    // onError and onDone can both fire for the same closed listener; only
    // the first one needs to schedule a retry.
    if (_retryTimer != null) return;
    _profileSub = null;
    _retryTimer = Timer(_backoff.next(), () {
      _retryTimer = null;
      if (_auth.currentUser?.uid == user.uid) _followProfile(user);
    });
  }

  void _stopProfile() {
    _retryTimer?.cancel();
    _retryTimer = null;
    unawaited(_profileSub?.cancel());
    _profileSub = null;
  }

  /// Null while the answer isn't known yet: right after signing in (or
  /// creating a store) the profile may not have reached the device.
  static AuthState? _stateFor(
    User user,
    DocumentSnapshot<Map<String, dynamic>> doc,
    bool isProvisioning,
  ) {
    final data = doc.data();
    if (data == null) {
      return doc.metadata.isFromCache || isProvisioning
          ? null
          : AccessDenied(user.email ?? '');
    }
    final profile = AppUser.fromMap(user.uid, data);
    final hasAccess = profile.activo && profile.tienda != null;
    return hasAccess ? SignedIn(profile) : AccessDenied(profile.correo);
  }
}
