// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../legal.dart';
import '../../utils/texto.dart';

enum _AccountAction { theme, licenses, users, adjustments, export, about, signOut }

/// Who is signed in, as an avatar with their initials, plus the app and
/// account options their role allows.
class AccountMenu extends StatelessWidget {
  const AccountMenu({
    super.key,
    required this.user,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.onManageUsers,
    this.onManageLicenses,
    this.onExport,
    this.onViewAdjustments,
    this.onSignOut,
  });

  final AppUser user;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  /// Solo para el dueño de la app: administrar licencias de las tiendas.
  final VoidCallback? onManageLicenses;
  final VoidCallback? onManageUsers;

  /// Null when this role shouldn't see the store's full prices and supplier
  /// codes (e.g. an Empleado).
  final VoidCallback? onExport;

  /// Null when there's no adjustment history to audit (e.g. not an admin).
  final VoidCallback? onViewAdjustments;

  /// Null when there's no session to end (local-only mode).
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initials = iniciales(user.nombre);

    return PopupMenuButton<_AccountAction>(
      tooltip: 'Tu cuenta y opciones',
      offset: const Offset(0, 52),
      onSelected: (action) => switch (action) {
        _AccountAction.theme => onToggleTheme(),
        _AccountAction.licenses => onManageLicenses?.call(),
        _AccountAction.users => onManageUsers?.call(),
        _AccountAction.adjustments => onViewAdjustments?.call(),
        _AccountAction.export => onExport?.call(),
        _AccountAction.about => showAboutDialog(
          context: context,
          applicationName: 'Tienda de Ropa',
          applicationVersion: Legal.version,
          applicationIcon: const Icon(Icons.checkroom_rounded, size: 40),
          applicationLegalese: '${Legal.derechos}\n\n${Legal.aviso}',
        ),
        _AccountAction.signOut => onSignOut?.call(),
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              user.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${user.role.label} · ${user.correo}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _AccountAction.theme,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            title: Text(isDarkMode ? 'Usar tema claro' : 'Usar tema oscuro'),
          ),
        ),
        if (onManageLicenses != null)
          const PopupMenuItem(
            value: _AccountAction.licenses,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.workspace_premium_outlined),
              title: Text('Licencias de tiendas'),
              subtitle: Text('Panel del dueño de la app'),
            ),
          ),
        if (onManageUsers != null)
          const PopupMenuItem(
            value: _AccountAction.users,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.group_outlined),
              title: Text('Usuarios'),
              subtitle: Text('Cuentas del personal'),
            ),
          ),
        if (onViewAdjustments != null)
          const PopupMenuItem(
            value: _AccountAction.adjustments,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.history_rounded),
              title: Text('Historial de ajustes'),
              subtitle: Text('Quién cambió existencias y cuándo'),
            ),
          ),
        if (onExport != null)
          const PopupMenuItem(
            value: _AccountAction.export,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.ios_share_rounded),
              title: Text('Exportar catálogo'),
              subtitle: Text('Hoja de cálculo (CSV)'),
            ),
          ),
        const PopupMenuItem(
          value: _AccountAction.about,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.info_outline_rounded),
            title: Text('Acerca de'),
            subtitle: Text(Legal.derechos),
          ),
        ),
        if (onSignOut != null)
          const PopupMenuItem(
            value: _AccountAction.signOut,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.logout_rounded),
              title: Text('Cerrar sesión'),
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: CircleAvatar(
          radius: 20,
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          child: initials.isEmpty
              ? const Icon(Icons.person_rounded)
              : Text(
                  initials,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
        ),
      ),
    );
  }
}
