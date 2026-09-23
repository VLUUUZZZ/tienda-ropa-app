import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'clothing_repository.dart';
import 'firestore_catalog.dart';

/// Connects [repo] to Firestore in the background. Never throws: if Firebase
/// isn't configured yet, or there is no connection on the very first launch
/// (anonymous sign-in needs one), the app simply stays local-only for this
/// session and tries again on the next launch.
Future<void> startFirebaseSync(ClothingRepository repo) async {
  final FirebaseOptions options;
  try {
    options = DefaultFirebaseOptions.currentPlatform;
  } on UnsupportedError {
    debugPrint('Firebase no configurado: la app funciona solo en local.');
    return;
  }

  try {
    await Firebase.initializeApp(options: options);
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
    await repo.attachRemote(FirestoreCatalog(FirebaseFirestore.instance));
  } catch (e) {
    debugPrint('No se pudo conectar con Firebase, se sigue en local: $e');
  }
}
