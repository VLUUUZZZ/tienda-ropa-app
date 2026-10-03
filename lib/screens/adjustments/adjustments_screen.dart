import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../data/adjustments_repository.dart';
import '../../models/stock_adjustment.dart';

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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de ajustes')),
      body: _ajustes.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Aún no se ha registrado ningún ajuste de existencia.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.outline),
                ),
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
                    '${ajuste.usuarioNombre.isEmpty ? 'Alguien' : ajuste.usuarioNombre} · '
                    '${_formatFecha(ajuste.fecha)}',
                    style: TextStyle(fontSize: 12, color: colorScheme.outline),
                  ),
                ],
              ),
            ),
            Text(
              '${positivo ? '+' : ''}${ajuste.delta}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: positivo ? colorScheme.primary : colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatFecha(DateTime fecha) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(fecha.day)}/${two(fecha.month)}/${fecha.year} '
        '${two(fecha.hour)}:${two(fecha.minute)}';
  }
}
