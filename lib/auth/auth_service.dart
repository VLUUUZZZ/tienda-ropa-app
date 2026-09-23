import 'app_user.dart';

/// Where the session stands, as the app needs to route it.
sealed class AuthState {
  const AuthState();
}

/// Still finding out (startup, or loading the signed-in user's profile).
class AuthLoading extends AuthState {
  const AuthLoading();
}

class SignedOut extends AuthState {
  const SignedOut();
}

class SignedIn extends AuthState {
  const SignedIn(this.user);

  final AppUser user;
}

/// Signed in, but without an active profile: never given access by an admin,
/// or deactivated.
class AccessDenied extends AuthState {
  const AccessDenied(this.correo);

  final String correo;
}

/// A failure the user can act on, with a message ready to show.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Sign-in and session for the app. Methods throw [AuthException].
abstract class AuthService {
  /// Emits the current state on listen, then every change (sign-in, sign-out,
  /// or the user's profile being edited by an admin).
  Stream<AuthState> watch();

  Future<void> signIn({required String correo, required String password});

  Future<void> signOut();

  Future<void> sendPasswordReset(String correo);

  /// Opens a new store: creates the account, makes it the store's
  /// administrator and signs in as them. The store starts empty and is only
  /// visible to its own staff.
  Future<void> createStore({
    required String nombreTienda,
    required String nombre,
    required String correo,
    required String password,
  });
}
