import 'package:flutter/material.dart';

import '../../auth/app_user.dart';

enum _AccountAction { users, signOut }

/// Who is signed in, plus the account actions their role allows.
class AccountMenu extends StatelessWidget {
  const AccountMenu({
    super.key,
    required this.user,
    required this.onManageUsers,
    required this.onSignOut,
  });

  final AppUser user;
  final VoidCallback? onManageUsers;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_AccountAction>(
      icon: const Icon(Icons.account_circle_outlined),
      tooltip: 'Cuenta',
      onSelected: (action) => switch (action) {
        _AccountAction.users => onManageUsers?.call(),
        _AccountAction.signOut => onSignOut(),
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
