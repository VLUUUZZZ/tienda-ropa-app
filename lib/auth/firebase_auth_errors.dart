import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';

/// Turns a Firebase Auth error into a message the store's staff can act on.
AuthException authExceptionFrom(FirebaseAuthException e) {
  final message = switch (e.code) {
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'Correo o contraseña incorrectos.',
    'invalid-email' => 'El correo no es válido.',
    'user-disabled' => 'Esta cuenta está deshabilitada.',
    'email-already-in-use' => 'Ese correo ya tiene una cuenta.',
    'weak-password' => 'La contraseña es muy débil (mínimo 6 caracteres).',
    'too-many-requests' => 'Demasiados intentos. Espera un momento.',
    'network-request-failed' => 'Sin conexión a internet.',
    'operation-not-allowed' =>
      'El acceso con correo no está activado en Firebase.',
    _ => 'No se pudo completar (${e.code}).',
  };
  return AuthException(message);
}
