// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'credential_validators.dart';

/// Turns a Firebase Auth error into a message the store's staff can act on.
AuthException authExceptionFrom(FirebaseAuthException e) {
  debugPrint('Firebase Auth: ${e.code}');
  final message = switch (e.code) {
    'invalid-credential' || 'wrong-password' || 'user-not-found' =>
      'Correo o contraseña incorrectos. Revisa que estén bien escritos.',
    'invalid-email' => 'El correo no es válido.',
    'user-disabled' =>
      'Esta cuenta está desactivada. Pide a un administrador que la active.',
    'email-already-in-use' =>
      'Ese correo ya tiene una cuenta. Usa otro, o entra con él desde la pantalla de inicio.',
    'weak-password' =>
      'La contraseña es muy débil (mínimo '
          '${CredentialValidators.minPasswordLength} caracteres).',
    'too-many-requests' =>
      'Demasiados intentos. Espera unos minutos y vuelve a intentarlo.',
    'network-request-failed' =>
      'Sin conexión a internet. Revisa el Wi-Fi o los datos e inténtalo de nuevo.',
    'operation-not-allowed' =>
      'El acceso con correo no está activado para esta tienda. Contacta al soporte.',
    'requires-recent-login' =>
      'Por seguridad, vuelve a iniciar sesión e inténtalo de nuevo.',
    _ => 'No se pudo completar la operación. Inténtalo de nuevo.',
  };
  return AuthException(message);
}

/// Same as [authExceptionFrom], but for "forgot password": that flow never
/// involves a password, so an unknown email must not be reported as one.
AuthException passwordResetExceptionFrom(FirebaseAuthException e) {
  if (e.code == 'user-not-found' || e.code == 'invalid-email') {
    return const AuthException('No encontramos una cuenta con ese correo.');
  }
  return authExceptionFrom(e);
}
