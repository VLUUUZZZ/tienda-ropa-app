import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../data/sales_repository.dart';
import '../../models/sale.dart';

/// What was sold, most recent first, with the day's total up top.
class SalesScreen extends StatefulWidget {
  final SalesRepository salesRepo;

  const SalesScreen({super.key, required this.salesRepo});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  late final Listenable _changes = widget.salesRepo.listenable;
  List<Sale> _ventas = [];
  bool _reloadScheduled = false;

  @override
  void initState() {
    super.initState();
    _reload();
    // Picks up sales recorded on other devices.
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

  void _reload() => setState(() => _ventas = widget.salesRepo.getAll());

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hoy = DateTime.now();
    final totalHoy = widget.salesRepo.totalDe(hoy);

    return Scaffold(
      appBar: AppBar(title: const Text('Ventas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Vendido hoy',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '\$${totalHoy.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _ventas.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Aún no se ha registrado ninguna venta.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.outline),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _ventas.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _SaleTile(venta: _ventas[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  final Sale venta;

  const _SaleTile({required this.venta});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final detalle = [
      if (venta.color.isNotEmpty) venta.color,
      if (venta.talla.isNotEmpty) venta.talla,
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
                    venta.nombreItem.isEmpty
                        ? '(sin nombre)'
                        : venta.nombreItem,
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
                    _formatFecha(venta.fecha),
                    style: TextStyle(fontSize: 12, color: colorScheme.outline),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${venta.total.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
                Text(
                  '${venta.cantidad} pieza${venta.cantidad == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 12, color: colorScheme.outline),
                ),
              ],
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
