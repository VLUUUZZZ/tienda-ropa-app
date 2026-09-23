/// Form validators shared by the login and account screens.
abstract final class CredentialValidators {
  static const int minPasswordLength = 6;

  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Requerido' : null;

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Requerido';
    return _email.hasMatch(text) ? null : 'Correo inválido';
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Requerido';
    return text.length < minPasswordLength
        ? 'Mínimo $minPasswordLength caracteres'
        : null;
  }
}
