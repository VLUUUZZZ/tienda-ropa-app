// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/clothing_repository.dart';
import '../../data/sales_repository.dart';
import '../../models/clothing_item.dart';
import '../../models/sale.dart';
import '../../utils/formato.dart';
import '../../widgets/color_dot.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/feedback/app_snackbar.dart';
import '../../widgets/item_avatar.dart';
import '../../widgets/progress_button.dart';
import '../../widgets/unsaved_changes_guard.dart';

/// Registers a sale of one or more variants of [item] in one visit: how many
/// of each color/talla, confirmed together. Decreases stock the same way
/// [QuickStockScreen] does, and records one [Sale] per variant sold.
/// How many pieces were sold out of how many were asked for: fewer when
/// someone else sold the same pieces meanwhile (stock never goes negative).
typedef SaleResult = ({int vendidas, int pedidas});

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

  /// Registered: the button shows its check for a moment before closing.
  bool _saved = false;

  /// Set once the stock decrement has been committed, so a retry after a
  /// failure in the sales-log step below doesn't apply it a second time.
  bool _stockApplied = false;

  /// Sales still left to register; registered ones are removed as they
  /// succeed, so a retry only repeats what actually failed.
  List<Sale> _ventasPendientes = const [];
  int _totalRegistradoFinal = 0;

  @override
  void initState() {
    super.initState();
    _cantidades = List.filled(widget.item.variantes.length, 0);
  }

  void _adjust(int index, int delta) {
    HapticFeedback.selectionClick();
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
    setState(() => _saving = true);

    if (!_stockApplied) {
      // The garment may have changed on another device since this screen
      // opened (including its stock): apply the sale on top of its latest
      // version, and never sell more than what's actually left.
      final latest = widget.repo.getById(widget.item.id);
      if (latest == null) {
        setState(() => _saving = false);
        if (mounted) {
          AppSnackBar.error(
            context,
            'Esta prenda se eliminó del catálogo (quizá en otro teléfono); '
            'no se registró la venta.',
          );
        }
        return;
      }

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
        // Accumulated, not overwritten: two variants could in principle
        // share the same normalized color/talla key (see
        // ClothingItem.firstDuplicateVariant), and withStockChanges applies
        // one delta per key to every variant that has it.
        deltas[variante.key] = (deltas[variante.key] ?? 0) - cantidad;
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
        AppSnackBar.error(
          context,
          'Esas piezas ya se vendieron o ajustaron en otro teléfono: no '
          'queda existencia para esta venta.',
        );
        return;
      }

      try {
        await widget.repo.applyStockDelta(latest.id, deltas);
      } catch (e) {
        if (mounted) {
          setState(() => _saving = false);
          AppSnackBar.error(
            context,
            'No se pudo registrar la venta. Toca "Registrar venta" otra vez '
            'para reintentar.',
          );
        }
        return;
      }
      _stockApplied = true;
      _ventasPendientes = ventas;
      _totalRegistradoFinal = ventas.fold(0, (sum, v) => sum + v.cantidad);
    }

    final totalPedido = _totalPiezas;
    try {
      // Registered one at a time, removed from the pending list as each
      // succeeds: a retry after a failure here only repeats what's left,
      // instead of re-registering sales (and re-decrementing stock) already
      // committed in an earlier attempt.
      while (_ventasPendientes.isNotEmpty) {
        await widget.salesRepo.registrar(_ventasPendientes.first);
        _ventasPendientes = _ventasPendientes.skip(1).toList();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        // The stock is already taken out: a retry only records what's left.
        AppSnackBar.error(
          context,
          'La existencia ya se descontó, pero falta anotar la venta. Toca '
          '"Registrar venta" otra vez para terminar.',
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() => _saved = true);
    await Future<void>.delayed(ProgressButton.doneHold);
    if (!mounted) return;
    // The stock may have changed (otro teléfono) entre que se abrió esta
    // pantalla y se confirmó: avisar si se vendieron menos piezas de las
    // pedidas, en vez de decir simplemente "Venta registrada".
    // Reported by the screen this returns to, so the message isn't cut
    // short by the transition.
    Navigator.of(
      context,
    ).pop<SaleResult>((vendidas: _totalRegistradoFinal, pedidas: totalPedido));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final variantes = widget.item.variantes;
    final item = widget.item;

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
      message: 'Tienes una venta sin confirmar; si sales, no se registrará.',
      busy: _saving,
      busyMessage: 'Espera a que termine de registrar la venta.',
      child: Scaffold(
        appBar: AppBar(title: const Text('Registrar venta')),
        body: variantes.isEmpty
            ? Center(
                child: EmptyState(
                  icon: Icons.layers_outlined,
                  title: 'Sin tallas ni colores',
                  message:
                      'Esta prenda no tiene colores ni tallas registradas, '
                      'así que no hay piezas que vender.',
                  actionLabel: 'Volver al catálogo',
                  actionIcon: Icons.arrow_back_rounded,
                  onAction: () => Navigator.of(context).pop(),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  Row(
                    children: [
                      ItemAvatar(
                        nombre: item.nombre,
                        size: 60,
                        photoPath: widget.repo.photoPathFor(item.id),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.nombre.isEmpty
                                  ? '(sin nombre)'
                                  : item.nombre,
                              style: textTheme.titleLarge,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${formatoPrecio(item.precio)} por pieza',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Toca + en el color y la talla que se llevan. La '
                    'existencia se descuenta al tocar "Registrar venta".',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (final color in colores) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          ColorDot(nombre: color, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(color, style: textTheme.titleMedium),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: Column(
                        children: [
                          for (final (n, i)
                              in indicesPorColor[color]!.indexed) ...[
                            if (n > 0) const Divider(indent: 20, endIndent: 20),
                            _SaleVariantRow(
                              variant: variantes[i],
                              color: color,
                              cantidad: _cantidades[i],
                              onDecrement: () => _adjust(i, -1),
                              onIncrement: () => _adjust(i, 1),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
        bottomNavigationBar: variantes.isEmpty
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_hasChanges) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total · ${formatoPiezas(_totalPiezas)}',
                            style: textTheme.titleSmall,
                          ),
                          Text(
                            formatoPrecio(_totalPrecio),
                            style: textTheme.titleLarge?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    ProgressButton(
                      state: _saved
                          ? ProgressState.done
                          : _saving
                          ? ProgressState.busy
                          : ProgressState.idle,
                      icon: Icons.point_of_sale_rounded,
                      onPressed: _hasChanges ? _confirmar : null,
                      label: _hasChanges
                          ? 'Registrar venta'
                          : 'Elige con + cuántas piezas se venden',
                      busyLabel: 'Registrando…',
                      doneLabel: 'Venta registrada',
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
  final String color;
  final int cantidad;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _SaleVariantRow({
    required this.variant,
    required this.color,
    required this.cantidad,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final agotado = variant.existencia <= 0;
    final talla = variant.talla.isEmpty ? '(sin talla)' : variant.talla;
    final descripcion = 'talla $talla, color $color';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Talla $talla', style: textTheme.titleMedium),
                Row(
                  children: [
                    if (agotado) ...[
                      Icon(
                        Icons.remove_shopping_cart_outlined,
                        size: 14,
                        color: colorScheme.error,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      agotado
                          ? 'Agotado'
                          : 'Hay ${formatoPiezas(variant.existencia)}',
                      style: textTheme.labelMedium?.copyWith(
                        color: agotado
                            ? colorScheme.error
                            : colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(100),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_rounded),
                  tooltip: 'Vender una pieza menos de $descripcion',
                  onPressed: cantidad > 0 ? onDecrement : null,
                ),
                SizedBox(
                  width: 40,
                  child: Semantics(
                    liveRegion: true,
                    label:
                        'Vendiendo ${formatoPiezas(cantidad)} de $descripcion',
                    excludeSemantics: true,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(scale: animation, child: child),
                      ),
                      child: Text(
                        '$cantidad',
                        key: ValueKey(cantidad),
                        textAlign: TextAlign.center,
                        style: textTheme.titleLarge?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton.filled(
                  icon: const Icon(Icons.add_rounded),
                  tooltip: 'Vender una pieza más de $descripcion',
                  onPressed: cantidad < variant.existencia ? onIncrement : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
