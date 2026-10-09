// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'package:flutter/material.dart';

import '../../auth/license.dart';
import '../../data/license_admin.dart';
import '../../utils/formato.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/feedback/app_snackbar.dart';
import '../../widgets/feedback/confirm_dialog.dart';
import '../../widgets/skeleton.dart';

/// Panel del dueño de la app: lista todas las tiendas y deja renovar o
/// suspender su licencia. Solo se abre para la cuenta dueña; además, el
/// servidor rechaza cualquier cambio de otra cuenta.
class LicenseAdminScreen extends StatefulWidget {
  const LicenseAdminScreen({super.key, required this.admin});

  final LicenseAdminService admin;

  @override
  State<LicenseAdminScreen> createState() => _LicenseAdminScreenState();
}

class _LicenseAdminScreenState extends State<LicenseAdminScreen> {
  late Stream<List<StoreLicense>> _stores = widget.admin.watchStores();

  void _retry() => setState(() => _stores = widget.admin.watchStores());

  Future<void> _renovar(StoreLicense store, int meses) async {
    // Desde hoy o desde la fecha vigente, lo que sea mayor, para no acortar.
    final base = switch (store.license.hasta) {
      final h? when h.isAfter(DateTime.now()) => h,
      _ => DateTime.now(),
    };
    final nueva = DateTime(base.year, base.month + meses, base.day);
    await _guardar(
      store,
      nueva,
      'Licencia renovada hasta ${formatoFecha(nueva)}',
    );
  }

  Future<void> _suspender(StoreLicense store) async {
    final ok = await confirmAction(
      context,
      icon: Icons.block_rounded,
      destructive: true,
      title: 'Suspender tienda',
      message:
          '¿Seguro que quieres suspender a "${store.nombre}"? Dejará de poder '
          'usar la app de inmediato (su información no se borra; puedes '
          'reactivarla cuando quieras).',
      confirmLabel: 'Suspender',
    );
    if (!ok) return;
    await _guardar(
      store,
      DateTime.now().subtract(const Duration(minutes: 1)),
      'Tienda suspendida',
    );
  }

  Future<void> _elegirFecha(StoreLicense store) async {
    final hoy = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: store.license.hasta ?? hoy.add(const Duration(days: 30)),
      firstDate: hoy.subtract(const Duration(days: 1)),
      lastDate: DateTime(hoy.year + 10),
      helpText: 'Licencia válida hasta',
    );
    if (fecha == null) return;
    // Hasta el final de ese día.
    final hasta = DateTime(fecha.year, fecha.month, fecha.day, 23, 59, 59);
    await _guardar(
      store,
      hasta,
      'Licencia válida hasta ${formatoFecha(hasta)}',
    );
  }

  Future<void> _guardar(StoreLicense store, DateTime hasta, String ok) async {
    try {
      await widget.admin.setLicense(store.id, hasta);
      if (mounted) AppSnackBar.success(context, ok);
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(
          context,
          'No se pudo cambiar la licencia. Revisa tu conexión y que tu cuenta '
          'sea la dueña de la app.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Licencias de tiendas')),
      body: StreamBuilder<List<StoreLicense>>(
        stream: _stores,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'No se pudo cargar',
                message:
                    'Revisa tu conexión. Recuerda que solo la cuenta dueña de '
                    'la app puede ver y cambiar las licencias.',
                actionLabel: 'Reintentar',
                actionIcon: Icons.refresh_rounded,
                onAction: _retry,
              ),
            );
          }
          final stores = snap.data;
          if (stores == null) {
            return const SkeletonList(label: 'Cargando tiendas…');
          }
          if (stores.isEmpty) {
            return const Center(
              child: EmptyState(
                icon: Icons.storefront_outlined,
                title: 'Sin tiendas',
                message: 'Todavía no hay ninguna tienda registrada.',
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: stores.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Renueva o suspende la licencia de cada tienda. Los '
                    'cambios se aplican al momento y no borran ningún dato.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              final store = stores[i - 1];
              return _StoreCard(
                store: store,
                onRenovar: (meses) => _renovar(store, meses),
                onFecha: () => _elegirFecha(store),
                onSuspender: () => _suspender(store),
              );
            },
          );
        },
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({
    required this.store,
    required this.onRenovar,
    required this.onFecha,
    required this.onSuspender,
  });

  final StoreLicense store;
  final ValueChanged<int> onRenovar;
  final VoidCallback onFecha;
  final VoidCallback onSuspender;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final lic = store.license;
    final (IconData icon, String estado, Color color) = switch (lic.state) {
      LicenseState.vigente => (
        Icons.check_circle_rounded,
        lic.hasta == null
            ? 'Vigente'
            : 'Vigente hasta ${formatoFecha(lic.hasta!)}',
        colorScheme.primary,
      ),
      LicenseState.vencida => (
        Icons.cancel_rounded,
        lic.hasta == null ? 'Vencida' : 'Venció el ${formatoFecha(lic.hasta!)}',
        colorScheme.error,
      ),
      LicenseState.sinLicencia => (
        Icons.remove_circle_outline_rounded,
        'Sin licencia',
        colorScheme.error,
      ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              store.nombre,
              style: textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    estado,
                    style: textTheme.bodyMedium?.copyWith(color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => onRenovar(1),
                  child: const Text('+1 mes'),
                ),
                TextButton(
                  onPressed: () => onRenovar(12),
                  child: const Text('+1 año'),
                ),
                TextButton(
                  onPressed: onFecha,
                  child: const Text('Elegir fecha'),
                ),
                TextButton(
                  onPressed: onSuspender,
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.error,
                  ),
                  child: const Text('Suspender'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
