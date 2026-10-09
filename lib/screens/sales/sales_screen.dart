// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../data/clothing_repository.dart';
import '../../data/sales_repository.dart';
import '../../models/sale.dart';
import '../../utils/formato.dart';
import '../../widgets/empty_state.dart';

/// What was sold, most recent first, with sales totals and the catalog's
/// current worth up top.
class SalesScreen extends StatefulWidget {
  final SalesRepository salesRepo;
  final ClothingRepository repo;

  /// The catalog's worth is only for whoever sees prices of the whole
  /// store (the same rule as the catalog's summary).
  final bool showInventoryValue;

  const SalesScreen({
    super.key,
    required this.salesRepo,
    required this.repo,
    this.showInventoryValue = true,
  });

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  late final Listenable _changes = Listenable.merge([
    widget.salesRepo.listenable,
    widget.repo.listenable,
  ]);
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
    final masVendidos = widget.salesRepo.masVendidos();

    return Scaffold(
      appBar: AppBar(title: const Text('Ventas')),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Hoy',
                          valor: widget.salesRepo.totalDe(hoy),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          label: 'Esta semana',
                          valor: widget.salesRepo.totalSemanaDe(hoy),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          label: 'Este mes',
                          valor: widget.salesRepo.totalMesDe(hoy),
                        ),
                      ),
                    ],
                  ),
                  if (widget.showInventoryValue) ...[
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Valor del inventario',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              formatoPrecio(widget.repo.valorInventario),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (masVendidos.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lo más vendido',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            for (final item in masVendidos)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.nombre,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      formatoPiezas(item.piezas),
                                      style: TextStyle(
                                        color: colorScheme.outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_ventas.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: EmptyState(
                  icon: Icons.receipt_long_rounded,
                  title: 'Aún no hay ventas',
                  message:
                      'Cuando vendas una prenda (botón "Vender" en el '
                      'catálogo o al escanearla) aparecerá aquí, con su '
                      'total del día, la semana y el mes.',
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Últimas ventas',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          if (_ventas.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverList.separated(
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

class _StatCard extends StatelessWidget {
  final String label;
  final double valor;

  const _StatCard({required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: colorScheme.outline),
            ),
            const SizedBox(height: 4),
            Text(
              formatoPrecio(valor),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: colorScheme.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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
                    formatoFecha(venta.fecha),
                    style: TextStyle(fontSize: 12, color: colorScheme.outline),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatoPrecio(venta.total),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
                Text(
                  formatoPiezas(venta.cantidad),
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
