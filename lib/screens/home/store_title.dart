// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../widgets/role_badge.dart';

/// The store's name, with a greeting to whoever is in and their role.
class StoreTitle extends StatelessWidget {
  const StoreTitle({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final tienda = user.tienda;
    final nombre = user.nombre.trim().split(RegExp(r'\s+')).first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (tienda != null)
          Row(
            children: [
              Flexible(
                child: Text(
                  nombre.isEmpty ? 'Hola' : 'Hola, $nombre',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              RoleBadge(role: user.role),
            ],
          ),
        Text(
          tienda?.nombre ?? 'Tienda de Ropa',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.headlineSmall,
        ),
      ],
    );
  }
}
