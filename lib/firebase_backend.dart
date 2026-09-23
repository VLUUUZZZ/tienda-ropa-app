import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'auth/firebase_auth_service.dart';
import 'auth/firestore_user_directory.dart';
import 'backend.dart';
import 'data/firestore_catalog.dart';
import 'firebase_options.dart';

/// Initializes Firebase and wires up the [Backend] on it, or returns null
/// when Firebase isn't configured for this platform (the app then runs
/// local-only, without login).
///
/// Works offline: initializing reads local config only, and a previous
/// session is restored from the device.
Future<Backend?> connectFirebase() async {
  final FirebaseOptions options;
  try {
    options = DefaultFirebaseOptions.currentPlatform;
  } on UnsupportedError {
    debugPrint('Firebase no configurado: la app funciona solo en local.');
    return null;
  }

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: options);
  }
  final firestore = FirebaseFirestore.instance;
  return Backend(
    auth: FirebaseAuthService(FirebaseAuth.instance, firestore),
    users: FirestoreUserDirectory(firestore, options),
    catalogFor: (tienda) => FirestoreCatalog(firestore, tienda.id),
  );
}
