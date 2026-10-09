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
import 'license.dart';

/// Turns Firebase Auth's signed-in user, their live Firestore profile, and
/// their store's license into [AuthState]s.
///
/// The profile is followed live, so a role change or deactivation applies at
/// once. The store's license (`tiendas/{id}.licenciaHasta`) is followed too:
/// if it isn't valid, the session becomes [LicenseInactive] — access is
/// paused, data is never touched. Firestore's offline cache serves the real
/// license date even without internet; a [LicenseCache] adds a grace window
/// for when the store document itself can't be read.
///
/// Transient listener failures are retried with [Backoff] while the current
/// state is kept; only a real permission denial shows as [AccessDenied].
class SessionWatcher {
  SessionWatcher(
    this._auth,
    this._firestore, {
    this.isProvisioning = _never,
    LicenseCache? licenseCache,
  }) : _licenseCache = licenseCache;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final LicenseCache? _licenseCache;

  /// True while this device itself is in the middle of creating a brand-new
  /// store: its own documents may not have reached Firestore yet, so missing
  /// documents must not be read as "no access" during that window.
  final bool Function() isProvisioning;

  static bool _never() => false;

  final Backoff _backoff = Backoff(
    initial: const Duration(seconds: 3),
    max: const Duration(minutes: 2),
  );
  final Backoff _storeBackoff = Backoff(
    initial: const Duration(seconds: 3),
    max: const Duration(minutes: 2),
  );

  late final StreamController<AuthState> _controller =
      StreamController<AuthState>(onListen: _start, onCancel: _stop);

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _storeSub;
  Timer? _retryTimer;
  Timer? _storeRetry;

  /// The profile once it grants access (active, with a store). The store
  /// listener runs only while this is set.
  AppUser? _granted;
  String? _storeId;

  /// Latest known license for [_granted]'s store; null while still loading.
  License? _license;

  Stream<AuthState> get states => _controller.stream;

  void _start() {
    _authSub = _auth.authStateChanges().listen(_onUser);
  }

  Future<void> _stop() async {
    _stopProfile();
    _stopStore();
    await _authSub?.cancel();
  }

  void _onUser(User? user) {
    _stopProfile();
    _stopStore();
    _backoff.reset();
    _granted = null;
    _storeId = null;
    _license = null;
    if (user == null) {
      _controller.add(const SignedOut());
      return;
    }
    _controller.add(const AuthLoading());
    _followProfile(user);
  }

  void _followProfile(User user) {
    // includeMetadataChanges: true so a cached "no such document" that the
    // server later confirms still fires (otherwise it's metadata-only and is
    // skipped, leaving a nonexistent profile stuck in AuthLoading forever).
    _profileSub = FirestorePaths.user(_firestore, user.uid)
        .snapshots(includeMetadataChanges: true)
        .listen(
          (doc) {
            _backoff.reset();
            _onProfile(user, doc);
          },
          onError: (Object e) => _onProfileError(user, e),
          onDone: () => _scheduleProfileRetry(user),
        );
  }

  void _onProfile(User user, DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      // No profile: no access, unless we just can't see it yet.
      _stopStore();
      _granted = null;
      if (!(doc.metadata.isFromCache || isProvisioning())) {
        _controller.add(AccessDenied(user.email ?? ''));
      }
      return;
    }
    final profile = AppUser.fromMap(user.uid, data);
    final tienda = profile.tienda;
    if (!profile.activo || tienda == null) {
      _stopStore();
      _granted = null;
      _controller.add(AccessDenied(profile.correo));
      return;
    }
    // Access granted by the profile; the license decides the rest.
    _granted = profile;
    if (_storeId != tienda.id) {
      _stopStore();
      _storeId = tienda.id;
      _license = null;
      _storeBackoff.reset();
      _followStore(tienda.id);
    }
    _emit();
  }

  void _followStore(String tiendaId) {
    _storeSub = FirestorePaths.stores(_firestore)
        .doc(tiendaId)
        .snapshots(includeMetadataChanges: true)
        .listen(
          (doc) {
            _storeBackoff.reset();
            _onStore(tiendaId, doc);
          },
          onError: (Object e) => _onStoreError(tiendaId, e),
          onDone: () => _scheduleStoreRetry(tiendaId),
        );
  }

  void _onStore(String tiendaId, DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final raw = data?['licenciaHasta'];
    final hasta = raw is Timestamp ? raw.toDate() : null;

    if (data == null && (doc.metadata.isFromCache || isProvisioning())) {
      // Store not readable yet on this device; keep whatever we had (grace),
      // or stay loading.
      _license ??= licenseFromGrace(_licenseCache?.read(tiendaId));
      _emit();
      return;
    }

    final license = License.fromHasta(hasta);
    // Only a server-confirmed valid license refreshes the grace clock.
    if (!doc.metadata.isFromCache && license.vigente && hasta != null) {
      unawaited(
        _licenseCache
                ?.save(
                  tiendaId,
                  LicenseCacheEntry(hasta: hasta, validadaEn: DateTime.now()),
                )
                .catchError((_) {}) ??
            Future<void>.value(),
      );
    }
    _license = license;
    _emit();
  }

  void _onStoreError(String tiendaId, Object error) {
    debugPrint('Error al leer la licencia de $tiendaId: $error');
    // Can't confirm with the server: fall back to the grace window so a
    // transient failure never locks out a store that was valid.
    _license ??= licenseFromGrace(_licenseCache?.read(tiendaId));
    _emit();
    _scheduleStoreRetry(tiendaId);
  }

  /// Emits the combined state from the granted profile and its license.
  void _emit() {
    final profile = _granted;
    if (profile == null) return;
    final license = _license;
    if (license == null) {
      _controller.add(const AuthLoading());
      return;
    }
    final tienda = profile.tienda!;
    if (license.vigente) {
      _controller.add(
        SignedIn(profile.conTienda(tienda.conLicencia(license.hasta))),
      );
    } else {
      _controller.add(
        LicenseInactive(tiendaNombre: tienda.nombre, license: license),
      );
    }
  }

  void _onProfileError(User user, Object error) {
    debugPrint('Error al leer el perfil de ${user.uid}: $error');
    if (error is FirebaseException && error.code == 'permission-denied') {
      _controller.add(AccessDenied(user.email ?? ''));
    }
    _scheduleProfileRetry(user);
  }

  void _scheduleProfileRetry(User user) {
    if (_retryTimer != null) return;
    unawaited(_profileSub?.cancel());
    _profileSub = null;
    _retryTimer = Timer(_backoff.next(), () {
      _retryTimer = null;
      if (_auth.currentUser?.uid == user.uid) _followProfile(user);
    });
  }

  void _scheduleStoreRetry(String tiendaId) {
    if (_storeRetry != null) return;
    unawaited(_storeSub?.cancel());
    _storeSub = null;
    _storeRetry = Timer(_storeBackoff.next(), () {
      _storeRetry = null;
      if (_storeId == tiendaId) _followStore(tiendaId);
    });
  }

  void _stopProfile() {
    _retryTimer?.cancel();
    _retryTimer = null;
    unawaited(_profileSub?.cancel());
    _profileSub = null;
  }

  void _stopStore() {
    _storeRetry?.cancel();
    _storeRetry = null;
    unawaited(_storeSub?.cancel());
    _storeSub = null;
  }
}
