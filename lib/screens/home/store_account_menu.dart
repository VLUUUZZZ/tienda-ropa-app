// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../auth/app_user.dart';
import '../../auth/license.dart';
import '../../auth/user_directory.dart';
import '../../data/adjustments_repository.dart';
import '../../data/catalog_export.dart';
import '../../data/clothing_repository.dart';
import '../../data/license_admin.dart';
import '../../widgets/feedback/app_snackbar.dart';
import '../../widgets/feedback/confirm_dialog.dart';
import '../adjustments/adjustments_screen.dart';
import '../admin/license_admin_screen.dart';
import '../users/users_screen.dart';
import 'account_menu.dart';

/// El menú de la cuenta (avatar con iniciales) con todas sus acciones ya
/// cableadas según el rol: tema, licencias (solo dueño de la app), usuarios,
/// historial de ajustes, exportar catálogo y cerrar sesión. Se usa igual en
/// el Inicio y en el Catálogo para no duplicar la lógica.
class StoreAccountMenu extends StatelessWidget {
  const StoreAccountMenu({
    super.key,
    required this.user,
    required this.repo,
    required this.adjustmentsRepo,
    required this.isDarkMode,
    required this.onToggleTheme,
    this.users,
    this.licenseAdmin,
    this.onSignOut,
  });

  final AppUser user;
  final ClothingRepository repo;
  final AdjustmentsRepository adjustmentsRepo;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  /// Null en modo local (sin backend).
  final UserDirectory? users;

  /// Solo con valor para el dueño de la app.
  final LicenseAdminService? licenseAdmin;

  /// Null cuando no hay sesión que cerrar (modo local).
  final VoidCallback? onSignOut;

  bool get _canManageLicenses =>
      licenseAdmin != null && user.uid == LicenseConfig.duenoUid;

  bool get _canOpenUsers => users != null && user.canManageUsers;

  Future<void> _export(BuildContext context) async {
    final csv = catalogToCsv(repo.getAll());
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              // BOM para que Excel abra bien los acentos.
              const Utf8Encoder().convert('﻿$csv'),
              mimeType: 'text/csv',
              name: 'catalogo.csv',
            ),
          ],
          fileNameOverrides: ['catalogo.csv'],
        ),
      );
      if (context.mounted && result.status == ShareResultStatus.success) {
        AppSnackBar.success(context, 'Catálogo exportado');
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.error(context, 'No se pudo exportar el catálogo.');
      }
    }
  }

  Future<void> _confirmSignOut(BuildContext context, VoidCallback signOut) async {
    final confirmed = await confirmAction(
      context,
      icon: Icons.logout_rounded,
      title: 'Cerrar sesión',
      message:
          '¿Seguro que quieres cerrar sesión? Para volver a entrar '
          'necesitarás tu correo y contraseña. Lo que ya guardaste se '
          'conserva y se sincroniza al entrar de nuevo.',
      confirmLabel: 'Cerrar sesión',
    );
    if (confirmed) signOut();
  }

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return AccountMenu(
      user: user,
      isDarkMode: isDarkMode,
      onToggleTheme: onToggleTheme,
      onManageLicenses: _canManageLicenses
          ? () => _push(context, LicenseAdminScreen(admin: licenseAdmin!))
          : null,
      onManageUsers: _canOpenUsers
          ? () => _push(
              context,
              UsersScreen(users: users!, currentUser: user),
            )
          : null,
      onExport: user.canEditCatalog ? () => _export(context) : null,
      onViewAdjustments: user.canManageUsers
          ? () => _push(
              context,
              AdjustmentsScreen(adjustmentsRepo: adjustmentsRepo),
            )
          : null,
      onSignOut: switch (onSignOut) {
        final signOut? => () => _confirmSignOut(context, signOut),
        null => null,
      },
    );
  }
}
