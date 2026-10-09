// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'package:flutter/material.dart';

import '../utils/texto.dart';

/// A person's initials in a circle; muted when their account is inactive.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.nombre,
    this.activo = true,
    this.radius = 22,
  });

  final String nombre;
  final bool activo;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initials = iniciales(nombre);
    return CircleAvatar(
      radius: radius,
      backgroundColor: activo
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest,
      foregroundColor: activo
          ? colorScheme.onPrimaryContainer
          : colorScheme.onSurfaceVariant,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}
