import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../widgets/role_badge.dart';

/// The store's name, and who is in with their role next to it.
class StoreTitle extends StatelessWidget {
  const StoreTitle({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final tienda = user.tienda;
    if (tienda == null) return const Text('Tienda de Ropa');

    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tienda.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
        Row(
          children: [
            Flexible(
              child: Text(
                user.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 6),
            RoleBadge(role: user.role),
          ],
        ),
      ],
    );
  }
}
