// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

/// Form validators shared by the login and account screens. Each message
/// says what to do, not just what's wrong.
abstract final class CredentialValidators {
  static const int minPasswordLength = 6;

  /// A person's name; a new store is named "Tienda de" + the name, which
  /// has to fit the server's limit for store names.
  static const int maxNombre = 60;

  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? required(String? value) =>
      (value == null || value.trim().isEmpty)
      ? 'Este campo es obligatorio'
      : null;

  static String? nombre(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Escribe el nombre' : null;

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Escribe el correo';
    return _email.hasMatch(text)
        ? null
        : 'Revisa el correo: debe verse como nombre@ejemplo.com';
  }

  /// For signing in: any length (the account may predate the minimum).
  static String? currentPassword(String? value) =>
      (value == null || value.isEmpty) ? 'Escribe tu contraseña' : null;

  /// For a new password.
  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Escribe una contraseña';
    return text.length < minPasswordLength
        ? 'Usa al menos $minPasswordLength caracteres'
        : null;
  }
}
