import 'auth/auth_service.dart';
import 'auth/user_directory.dart';
import 'data/remote_catalog.dart';

/// The remote services the app talks to once someone signs in. Absent when
/// the app runs local-only (no backend configured for the platform).
class Backend {
  const Backend({
    required this.auth,
    required this.users,
    required this.catalog,
  });

  final AuthService auth;
  final UserDirectory users;
  final RemoteCatalog catalog;
}
