// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/sync_health.dart';
import '../utils/formato.dart';

/// What's waiting to reach the server, by kind, for the details sheet.
typedef PendingChanges = ({int prendas, int ventas, int ajustes});

/// A small pill saying whether what's on this phone already reached the
/// rest of the store: "✓ Sincronizado", "Sincronizando…", "Sin conexión ·
/// 3 pendientes". Tapping it explains the state in plain words.
///
/// Always visible but quiet; it only changes when the state does, with a
/// short cross-fade so the change is noticed without distracting.
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({
    super.key,
    required this.health,
    required this.changes,
    required this.pending,
  });

  final ValueListenable<SyncHealth> health;

  /// Fires when [pending] may have changed.
  final Listenable changes;
  final PendingChanges Function() pending;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([health, changes]),
      builder: (context, _) {
        final status = _SyncStatus.from(health.value, pending());
        final colors = status.colors(context);
        return Semantics(
          button: true,
          liveRegion: true,
          label: 'Estado de sincronización: ${status.label}',
          hint: 'Toca para ver detalles',
          excludeSemantics: true,
          child: Material(
            color: colors.background,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => _showDetails(context),
              child: ConstrainedBox(
                // Comfortable to tap even though it looks small.
                constraints: const BoxConstraints(minHeight: 36),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Row(
                      key: ValueKey(status.label),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        status.busy
                            ? SizedBox.square(
                                dimension: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.foreground,
                                ),
                              )
                            : Icon(
                                status.icon,
                                size: 16,
                                color: colors.foreground,
                              ),
                        const SizedBox(width: 6),
                        Text(
                          status.label,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: colors.foreground,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => ListenableBuilder(
        listenable: Listenable.merge([health, changes]),
        builder: (context, _) =>
            _SyncDetails(health: health.value, pending: pending()),
      ),
    );
  }
}

enum _Kind { connecting, synced, syncing, offline }

class _SyncStatus {
  const _SyncStatus(this.kind, this.label, this.icon, {this.busy = false});

  final _Kind kind;
  final String label;
  final IconData icon;
  final bool busy;

  static _SyncStatus from(SyncHealth health, PendingChanges pending) {
    final total = pending.prendas + pending.ventas + pending.ajustes;
    final pendientes = total == 1 ? '1 pendiente' : '$total pendientes';
    return switch (health.connection) {
      SyncConnection.offline => _SyncStatus(
        _Kind.offline,
        total == 0 ? 'Sin conexión' : 'Sin conexión · $pendientes',
        Icons.cloud_off_rounded,
      ),
      SyncConnection.connecting => const _SyncStatus(
        _Kind.connecting,
        'Conectando…',
        Icons.cloud_queue_rounded,
        busy: true,
      ),
      SyncConnection.online when total > 0 => const _SyncStatus(
        _Kind.syncing,
        'Sincronizando…',
        Icons.cloud_upload_rounded,
        busy: true,
      ),
      SyncConnection.online => const _SyncStatus(
        _Kind.synced,
        'Sincronizado',
        Icons.cloud_done_rounded,
      ),
    };
  }

  ({Color background, Color foreground}) colors(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final stock = StockColors.of(context);
    return switch (kind) {
      _Kind.offline => (
        background: stock.lowContainer,
        foreground: stock.onLowContainer,
      ),
      _Kind.synced => (
        background: colorScheme.secondaryContainer,
        foreground: colorScheme.onSecondaryContainer,
      ),
      _Kind.connecting || _Kind.syncing => (
        background: colorScheme.surfaceContainerHigh,
        foreground: colorScheme.onSurfaceVariant,
      ),
    };
  }
}

class _SyncDetails extends StatelessWidget {
  const _SyncDetails({required this.health, required this.pending});

  final SyncHealth health;
  final PendingChanges pending;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final status = _SyncStatus.from(health, pending);
    final total = pending.prendas + pending.ventas + pending.ajustes;

    final explicacion = switch (status.kind) {
      _Kind.synced =>
        'Todo está sincronizado: lo que hiciste en este teléfono ya está en '
            'todos los teléfonos de la tienda.',
      _Kind.syncing =>
        'Enviando tus últimos cambios. Puedes seguir trabajando mientras '
            'tanto.',
      _Kind.connecting =>
        'Buscando conexión con la tienda. Puedes seguir trabajando: todo se '
            'guarda en este teléfono.',
      _Kind.offline =>
        total == 0
            ? 'Este teléfono no tiene internet ahora. Puedes seguir trabajando; '
                  'lo que cambies se enviará solo al volver la conexión.'
            : 'Tus cambios están guardados en este teléfono y se enviarán '
                  'solos cuando vuelva la conexión. Puedes seguir trabajando.',
    };

    String desglose() {
      final partes = [
        if (pending.prendas > 0)
          pending.prendas == 1 ? '1 prenda' : '${pending.prendas} prendas',
        if (pending.ventas > 0)
          pending.ventas == 1 ? '1 venta' : '${pending.ventas} ventas',
        if (pending.ajustes > 0)
          pending.ajustes == 1 ? '1 ajuste' : '${pending.ajustes} ajustes',
      ];
      return partes.isEmpty ? 'Ninguno' : partes.join(', ');
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(status.icon, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(status.label, style: textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              explicacion,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _Row(label: 'Cambios por enviar', value: desglose()),
            _Row(
              label: 'Última sincronización',
              value: health.lastSync == null
                  ? 'Aún no en este teléfono'
                  : formatoFecha(health.lastSync!),
            ),
            if (health.retrying)
              const _Row(
                label: 'Aviso',
                value:
                    'No se pudo conectar con el servidor. Se reintenta solo, '
                    'no tienes que hacer nada.',
                warning: true,
              ),
            if (health.lastRejection != null)
              _Row(
                label: 'Aviso',
                value:
                    '${formatoFecha(health.lastRejection!)}: un cambio no se '
                    'aceptó (tu cuenta ya no tenía permiso) y se dejó como '
                    'estaba en la tienda.',
                warning: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.warning = false});

  final String label;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (warning) ...[
            Icon(
              Icons.warning_amber_rounded,
              size: 18,
              color: StockColors.of(context).low,
            ),
            const SizedBox(width: 6),
          ],
          SizedBox(
            width: warning ? 106 : 130,
            child: Text(
              label,
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
