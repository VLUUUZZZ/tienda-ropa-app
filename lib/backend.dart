// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'auth/app_user.dart';
import 'auth/auth_service.dart';
import 'auth/user_directory.dart';
import 'data/license_admin.dart';
import 'data/remote_adjustments.dart';
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
    required this.adjustmentsFor,
    this.licenseAdmin,
  });

  final AuthService auth;
  final UserDirectory users;

  /// Administración de licencias, solo útil para el dueño de la app.
  final LicenseAdminService? licenseAdmin;

  /// Each store has its own catalog.
  final RemoteCatalog Function(Tienda tienda) catalogFor;

  /// Each store has its own sales log.
  final RemoteSales Function(Tienda tienda) salesFor;

  /// Each store has its own stock-adjustment history.
  final RemoteAdjustments Function(Tienda tienda) adjustmentsFor;
}
