import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'backoff.dart';
import 'clothing_repository.dart';
import 'firestore_catalog.dart';

const Duration _signInTimeout = Duration(seconds: 30);

/// Connects [repo] to Firestore in the background. Never throws: if Firebase
/// isn't configured for this platform the app stays local-only; if it can't
/// connect (e.g. no internet on the very first launch, which anonymous sign-in
/// needs) it keeps retrying with a growing delay while the app works locally.
Future<void> startFirebaseSync(ClothingRepository repo) async {
  final FirebaseOptions options;
  try {
    options = DefaultFirebaseOptions.currentPlatform;
  } on UnsupportedError {
    debugPrint('Firebase no configurado: la app funciona solo en local.');
    return;
  }

  final backoff = Backoff(
    initial: const Duration(seconds: 15),
    max: const Duration(minutes: 10),
  );
  while (true) {
    try {
      await _connect(repo, options);
      return;
    } catch (e) {
      final delay = backoff.next();
      debugPrint(
        'No se pudo conectar con Firebase, se reintenta en '
        '${delay.inSeconds} s: $e',
      );
      await Future<void>.delayed(delay);
    }
  }
}

Future<void> _connect(ClothingRepository repo, FirebaseOptions options) async {
  // Safe to call again on a retry: the app may already be initialized.
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: options);
  }
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    await auth.signInAnonymously().timeout(_signInTimeout);
  }
  await repo.attachRemote(FirestoreCatalog(FirebaseFirestore.instance));
}
