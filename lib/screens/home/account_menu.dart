import 'package:flutter/material.dart';

import '../../auth/app_user.dart';

enum _AccountAction { users, adjustments, export, signOut }

/// Who is signed in, plus the account actions their role allows.
class AccountMenu extends StatelessWidget {
  const AccountMenu({
    super.key,
    required this.user,
    required this.onManageUsers,
    required this.onExport,
    this.onViewAdjustments,
    this.onSignOut,
  });

  final AppUser user;
  final VoidCallback? onManageUsers;
  final VoidCallback onExport;

  /// Null when there's no adjustment history to audit (e.g. not an admin).
  final VoidCallback? onViewAdjustments;

  /// Null when there's no session to end (local-only mode).
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_AccountAction>(
      icon: const Icon(Icons.account_circle_outlined),
      tooltip: 'Cuenta',
      onSelected: (action) => switch (action) {
        _AccountAction.users => onManageUsers?.call(),
        _AccountAction.adjustments => onViewAdjustments?.call(),
        _AccountAction.export => onExport(),
        _AccountAction.signOut => onSignOut?.call(),
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(user.nombre),
            subtitle: Text('${user.role.label} · ${user.correo}'),
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
    );
  }
}
