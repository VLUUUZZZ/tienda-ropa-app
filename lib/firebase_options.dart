// Placeholder until the Firebase project is connected.
//
// Run `flutterfire configure` in this folder: it overwrites this file with the
// real options for the project. Until then [currentPlatform] throws, and the
// app keeps working in local-only mode (see `startFirebaseSync`).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Firebase aún no está configurado. Ejecuta `flutterfire configure`.',
    );
  }
}
