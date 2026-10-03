import 'package:flutter/material.dart';

import '../../data/clothing_repository.dart';
import '../../data/sales_repository.dart';
import '../../models/clothing_item.dart';
import '../../models/sale.dart';
import '../../widgets/snackbars.dart';
import '../../widgets/unsaved_changes_guard.dart';

/// Registers a sale of one or more variants of [item] in one visit: how many
/// of each color/talla, confirmed together. Decreases stock the same way
/// [QuickStockScreen] does, and records one [Sale] per variant sold.
class RegisterSaleScreen extends StatefulWidget {
  final ClothingRepository repo;
  final SalesRepository salesRepo;
  final ClothingItem item;

  const RegisterSaleScreen({
    super.key,
    required this.repo,
    required this.salesRepo,
    required this.item,
  });

  @override
  State<RegisterSaleScreen> createState() => _RegisterSaleScreenState();
}

class _RegisterSaleScreenState extends State<RegisterSaleScreen> {
  /// How many of each variant (by index into `widget.item.variantes`) are
  /// being sold in this visit, starting at zero.
  late List<int> _cantidades;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _cantidades = List.filled(widget.item.variantes.length, 0);
  }

  void _adjust(int index, int delta) {
    setState(() {
      final max = widget.item.variantes[index].existencia;
      final next = _cantidades[index] + delta;
      _cantidades[index] = next.clamp(0, max);
    });
  }

  int get _totalPiezas => _cantidades.fold(0, (sum, c) => sum + c);

  double get _totalPrecio => _totalPiezas * widget.item.precio;

  bool get _hasChanges => _totalPiezas > 0;

  Future<void> _confirmar() async {
    // A second tap while saving would register the same sale twice.
    if (_saving || !_hasChanges) return;

    // The garment may have changed on another device since this screen
    // opened (including its stock): apply the sale on top of its latest
    // version, and never sell more than what's actually left.
    final latest = widget.repo.getById(widget.item.id);
    if (latest == null) {
      showErrorSnackBar(context, 'Esta prenda ya no existe en el catálogo.');
      return;
    }

    setState(() => _saving = true);

    final ventas = <Sale>[];
    final deltas = <String, int>{};
    for (var i = 0; i < widget.item.variantes.length; i++) {
      final pedido = _cantidades[i];
      if (pedido <= 0) continue;
      final variante = widget.item.variantes[i];
      final enStock = latest.variantes.where((v) => v.key == variante.key);
      final cantidad = pedido.clamp(
        0,
        enStock.isEmpty ? 0 : enStock.first.existencia,
      );
      if (cantidad <= 0) continue;
      deltas[variante.key] = -cantidad;
      ventas.add(
        Sale(
          id: Sale.newId(),
          itemId: latest.id,
          nombreItem: latest.nombre,
          color: variante.color,
          talla: variante.talla,
          cantidad: cantidad,
          precioUnitario: latest.precio,
          fecha: DateTime.now(),
        ),
      );
    }

    if (ventas.isEmpty) {
      setState(() => _saving = false);
      showErrorSnackBar(
        context,
        'Ya no queda existencia suficiente para registrar esta venta.',
      );
      return;
    }

    try {
      await widget.repo.save(latest.withStockChanges(deltas));
      for (final venta in ventas) {
        await widget.salesRepo.registrar(venta);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showErrorSnackBar(context, 'No se pudo registrar la venta.');
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final variantes = widget.item.variantes;

    // Group variant indices by color, preserving first-seen order — same as
    // QuickStockScreen.
    final colores = <String>[];
    final indicesPorColor = <String, List<int>>{};
    for (var i = 0; i < variantes.length; i++) {
      final color = variantes[i].color.isEmpty
          ? '(sin color)'
          : variantes[i].color;
      indicesPorColor
          .putIfAbsent(color, () {
            colores.add(color);
            return [];
          })
          .add(i);
    }

    return UnsavedChangesGuard(
      hasChanges: _hasChanges,
      message: 'Tienes una venta sin confirmar. ¿Deseas salir sin registrarla?',
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.item.nombre.isEmpty ? 'Registrar venta' : widget.item.nombre,
          ),
        ),
        body: variantes.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Esta prenda no tiene colores ni tallas registradas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colorScheme.outline),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  for (final color in colores) ...[
                    Text(
                      color,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: [
                            for (final i in indicesPorColor[color]!)
                              _SaleVariantRow(
                                variant: variantes[i],
                                cantidad: _cantidades[i],
                                onDecrement: () => _adjust(i, -1),
                                onIncrement: () => _adjust(i, 1),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
        bottomNavigationBar: variantes.isEmpty
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_hasChanges) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$_totalPiezas pieza${_totalPiezas == 1 ? '' : 's'}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '\$${_totalPrecio.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    FilledButton.icon(
                      onPressed: _hasChanges && !_saving ? _confirmar : null,
                      icon: const Icon(Icons.point_of_sale_rounded),
                      label: const Text('Registrar venta'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _SaleVariantRow extends StatelessWidget {
  final ClothingVariant variant;
  final int cantidad;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _SaleVariantRow({
    required this.variant,
    required this.cantidad,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final agotado = variant.existencia <= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              variant.talla.isEmpty ? '(sin talla)' : variant.talla,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              agotado ? 'AGOTADO' : '${variant.existencia} en stock',
              style: TextStyle(
                color: agotado ? colorScheme.error : colorScheme.outline,
                fontWeight: agotado ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
          IconButton.filledTonal(
            icon: const Icon(Icons.remove_rounded),
            tooltip: 'Quitar una de esta venta',
            onPressed: cantidad > 0 ? onDecrement : null,
            visualDensity: VisualDensity.compact,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 32),
            child: Text(
              '$cantidad',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton.filledTonal(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Agregar una a esta venta',
            onPressed: cantidad < variant.existencia ? onIncrement : null,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
