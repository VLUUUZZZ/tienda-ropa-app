// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../data/adjustments_repository.dart';
import '../../models/stock_adjustment.dart';
import '../../utils/formato.dart';
import '../../widgets/empty_state.dart';

/// Who changed stock, how much, and when — most recent first. Useful with
/// several employees sharing the same catalog.
class AdjustmentsScreen extends StatefulWidget {
  final AdjustmentsRepository adjustmentsRepo;

  const AdjustmentsScreen({super.key, required this.adjustmentsRepo});

  @override
  State<AdjustmentsScreen> createState() => _AdjustmentsScreenState();
}

class _AdjustmentsScreenState extends State<AdjustmentsScreen> {
  late final Listenable _changes = widget.adjustmentsRepo.listenable;
  List<StockAdjustment> _ajustes = [];
  bool _reloadScheduled = false;

  @override
  void initState() {
    super.initState();
    _reload();
    // Picks up adjustments recorded on other devices.
    _changes.addListener(_onChanged);
  }

  @override
  void dispose() {
    _changes.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (_reloadScheduled) return;
    _reloadScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _reloadScheduled = false;
      if (mounted) _reload();
    });
  }

  void _reload() => setState(() => _ajustes = widget.adjustmentsRepo.getAll());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de ajustes')),
      body: _ajustes.isEmpty
          ? const Center(
              child: EmptyState(
                icon: Icons.history_rounded,
                title: 'Sin ajustes todavía',
                message:
                    'Cada vez que alguien sume o reste piezas (con '
                    '"Existencia" o desde la ficha de una prenda) quedará '
                    'anotado aquí: quién, qué y cuándo.',
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: _ajustes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _AdjustmentTile(ajuste: _ajustes[index]),
            ),
    );
  }
}

class _AdjustmentTile extends StatelessWidget {
  final StockAdjustment ajuste;

  const _AdjustmentTile({required this.ajuste});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final positivo = ajuste.delta > 0;
    final detalle = [
      if (ajuste.color.isNotEmpty) ajuste.color,
      if (ajuste.talla.isNotEmpty) ajuste.talla,
    ].join(' · ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ajuste.nombreItem.isEmpty
                        ? '(sin nombre)'
                        : ajuste.nombreItem,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (detalle.isNotEmpty)
                    Text(
                      detalle,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  Text(
                    '${ajuste.usuarioNombre.isEmpty ? 'Alguien' : ajuste.usuarioNombre}'
                    ' · ${formatoFecha(ajuste.fecha)}',
                    style: TextStyle(fontSize: 12, color: colorScheme.outline),
                  ),
                ],
              ),
            ),
            // Direction in an arrow and a word too, not only by color.
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      positivo
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 16,
                      color: positivo ? colorScheme.primary : colorScheme.error,
                    ),
                    Text(
                      '${positivo ? '+' : '−'}${ajuste.delta.abs()}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: positivo
                            ? colorScheme.primary
                            : colorScheme.error,
                      ),
                    ),
                  ],
                ),
                Text(
                  positivo ? 'entraron' : 'salieron',
                  style: TextStyle(fontSize: 12, color: colorScheme.outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
