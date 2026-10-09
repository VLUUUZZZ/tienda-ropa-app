// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'package:flutter/material.dart';

import '../../auth/license.dart';
import '../../utils/formato.dart';
import '../../widgets/auth_layout.dart';

/// Se muestra cuando la cuenta está activa pero la licencia de la tienda no
/// es válida (venció o aún no se activa). Los datos siguen guardados; solo se
/// pausa el acceso hasta renovar la licencia con el proveedor de la app.
class LicenseScreen extends StatelessWidget {
  const LicenseScreen({
    super.key,
    required this.tiendaNombre,
    required this.license,
    required this.onRetry,
    required this.onSignOut,
  });

  final String tiendaNombre;
  final License license;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final vencida = license.state == LicenseState.vencida;
    final mensaje = vencida
        ? 'La licencia de $tiendaNombre venció'
            '${license.hasta == null ? '' : ' el ${formatoFecha(license.hasta!)}'}. '
            'Tu información sigue guardada y a salvo; para volver a usar la app, '
            'renueva la licencia con el proveedor.'
        : '$tiendaNombre todavía no tiene una licencia activa. Contacta al '
            'proveedor de la app para activarla. Tu información está guardada '
            'y no se pierde.';

    return AuthLayout(
      title: 'Licencia requerida',
      subtitle: tiendaNombre,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.workspace_premium_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(mensaje, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Ya la renové: reintentar'),
          ),
          const SizedBox(height: 4),
          TextButton(onPressed: onSignOut, child: const Text('Cerrar sesión')),
        ],
      ),
    );
  }
}
