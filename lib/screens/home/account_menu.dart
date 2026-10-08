import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../utils/texto.dart';

enum _AccountAction { users, adjustments, export, signOut }

/// Who is signed in, as an avatar with their initials, plus the account
/// actions their role allows.
class AccountMenu extends StatelessWidget {
  const AccountMenu({
    super.key,
    required this.user,
    required this.onManageUsers,
    this.onExport,
    this.onViewAdjustments,
    this.onSignOut,
  });

  final AppUser user;
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
      tooltip: 'Cuenta',
      offset: const Offset(0, 52),
      onSelected: (action) => switch (action) {
        _AccountAction.users => onManageUsers?.call(),
        _AccountAction.adjustments => onViewAdjustments?.call(),
        _AccountAction.export => onExport?.call(),
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
        if (onManageUsers != null)
          const PopupMenuItem(
            value: _AccountAction.users,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.group_outlined),
              title: Text('Usuarios'),
            ),
          ),
        if (onViewAdjustments != null)
          const PopupMenuItem(
            value: _AccountAction.adjustments,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.history_rounded),
              title: Text('Historial de ajustes'),
            ),
          ),
        if (onExport != null)
          const PopupMenuItem(
            value: _AccountAction.export,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.ios_share_rounded),
              title: Text('Exportar catálogo'),
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
