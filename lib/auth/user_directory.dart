import 'app_user.dart';

/// A store's user accounts, managed by its administrators. Methods throw
/// [AuthException] with a message ready to show.
abstract class UserDirectory {
  /// Everyone with an account in [tienda].
  Stream<List<AppUser>> watchStore(Tienda tienda);

  /// Creates an account in [tienda] with a temporary password the admin
  /// hands over.
  Future<void> create({
    required Tienda tienda,
    required String nombre,
    required String correo,
    required String password,
    required UserRole role,
  });

  /// Saves a changed role or active flag.
  Future<void> update(AppUser user);
}
