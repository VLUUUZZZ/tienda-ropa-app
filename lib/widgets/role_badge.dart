// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'package:flutter/material.dart';

import '../auth/app_user.dart';

/// Small colored label with a user's role.
class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isAdmin = role == UserRole.admin;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: isAdmin
            ? colorScheme.primaryContainer
            : colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        role.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isAdmin
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
