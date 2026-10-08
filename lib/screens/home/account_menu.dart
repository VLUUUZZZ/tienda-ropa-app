import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../utils/texto.dart';

enum _AccountAction { users, signOut }

/// Who is signed in, as an avatar with their initials, plus the account
/// actions their role allows.
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
    final colorScheme = Theme.of(context).colorScheme;
    final initials = iniciales(user.nombre);

    return PopupMenuButton<_AccountAction>(
      tooltip: 'Cuenta',
      offset: const Offset(0, 52),
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
