import 'auth/app_user.dart';
import 'auth/auth_service.dart';
import 'auth/user_directory.dart';
import 'data/remote_catalog.dart';
import 'data/remote_sales.dart';

/// The remote services the app talks to once someone signs in. Absent when
/// the app runs local-only (no backend configured for the platform).
class Backend {
  const Backend({
    required this.auth,
    required this.users,
    required this.catalogFor,
    required this.salesFor,
  });

  final AuthService auth;
  final UserDirectory users;

  /// Each store has its own catalog.
  final RemoteCatalog Function(Tienda tienda) catalogFor;

  /// Each store has its own sales log.
  final RemoteSales Function(Tienda tienda) salesFor;
}
