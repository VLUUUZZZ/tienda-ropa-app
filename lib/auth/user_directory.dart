import 'app_user.dart';

/// The store's user accounts, managed by administrators. Methods throw
/// [AuthException] with a message ready to show.
abstract class UserDirectory {
  Stream<List<AppUser>> watchAll();

  /// Creates the account with a temporary password the admin hands over.
  Future<void> create({
    required String nombre,
    required String correo,
    required String password,
    required UserRole role,
  });

  /// Saves a changed role or active flag.
  Future<void> update(AppUser user);
}
