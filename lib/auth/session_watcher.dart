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
  SessionWatcher(this._auth, this._firestore);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

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
    _profileSub = FirestorePaths.user(_firestore, user.uid).snapshots().listen((
      doc,
    ) {
      _backoff.reset();
      final state = _stateFor(user, doc);
      if (state != null) _controller.add(state);
    }, onError: (Object e) => _onProfileError(user, e));
  }

  void _onProfileError(User user, Object error) {
    debugPrint('Error al leer el perfil de ${user.uid}: $error');
    if (error is FirebaseException && error.code == 'permission-denied') {
      _controller.add(AccessDenied(user.email ?? ''));
    }
    // Firestore closes a listener after an error: re-open it, or later role
    // changes (or the connection coming back) would never be seen.
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
  ) {
    final data = doc.data();
    if (data == null) {
      return doc.metadata.isFromCache ? null : AccessDenied(user.email ?? '');
    }
    final profile = AppUser.fromMap(user.uid, data);
    final hasAccess = profile.activo && profile.tienda != null;
    return hasAccess ? SignedIn(profile) : AccessDenied(profile.correo);
  }
}
