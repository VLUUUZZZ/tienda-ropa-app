import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/app_user.dart';
import '../data/adjustments_repository.dart';
import '../data/clothing_repository.dart';
import '../models/clothing_item.dart';
import '../models/stock_adjustment.dart';
import '../widgets/snackbars.dart';
import '../widgets/unsaved_changes_guard.dart';

/// Fast +/- adjustment of existing colors and sizes, grouped by color — no
/// need to open the full edit form just to bump a count up or down. Does not
/// add or remove colors/tallas; that still goes through [ItemFormScreen].
class QuickStockScreen extends StatefulWidget {
  final ClothingRepository repo;
  final AdjustmentsRepository adjustmentsRepo;
  final AppUser user;
  final ClothingItem item;

  const QuickStockScreen({
    super.key,
    required this.repo,
    required this.adjustmentsRepo,
    required this.user,
    required this.item,
  });

  @override
  State<QuickStockScreen> createState() => _QuickStockScreenState();
}

class _QuickStockScreenState extends State<QuickStockScreen> {
  late List<ClothingVariant> _variantes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Work on copies so backing out without saving never touches storage.
    _variantes = widget.item.variantes
        .map(
          (v) => ClothingVariant(
            talla: v.talla,
            color: v.color,
            existencia: v.existencia,
          ),
        )
        .toList();
  }

  void _adjust(int index, int delta) {
    setState(() {
      final v = _variantes[index];
      final next = v.existencia + delta;
      _variantes[index] = ClothingVariant(
        talla: v.talla,
        color: v.color,
        existencia: next < 0 ? 0 : next,
      );
    });
  }

  /// How much each variant moved on this screen, by [ClothingVariant.key].
  Map<String, int> get _stockChanges => {
    for (var i = 0; i < _variantes.length; i++)
      _variantes[i].key:
          _variantes[i].existencia - widget.item.variantes[i].existencia,
  };

  /// Adding a piece and taking it back out again is not a change: nothing
  /// to save and nothing to discard.
  bool get _hasChanges => _stockChanges.values.any((delta) => delta != 0);

  Future<void> _save() async {
    // A second tap while saving would apply the same +/- twice.
    if (_saving) return;
    // The garment may have changed on another device since this screen
    // opened: apply only this screen's +/- on top of its latest version.
    final latest = widget.repo.getById(widget.item.id);
    if (latest == null) {
      showErrorSnackBar(context, 'Esta prenda ya no existe en el catálogo.');
      return;
    }
    final changes = _stockChanges;
    setState(() => _saving = true);
    try {
      await widget.repo.applyStockDelta(latest.id, changes);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showErrorSnackBar(context, 'No se pudo guardar. Inténtalo de nuevo.');
      }
      return;
    }
    // Best-effort audit trail: a failure here must never block the stock
    // change itself, already saved above.
    for (final v in _variantes) {
      final delta = changes[v.key] ?? 0;
      if (delta == 0) continue;
      unawaited(
        widget.adjustmentsRepo.registrar(
          StockAdjustment(
            id: StockAdjustment.newId(),
            itemId: latest.id,
            nombreItem: latest.nombre,
            color: v.color,
            talla: v.talla,
            delta: delta,
            usuarioNombre: widget.user.nombre,
            fecha: DateTime.now(),
          ),
        ),
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Group variant indices by color, preserving first-seen order.
    final colores = <String>[];
    final indicesPorColor = <String, List<int>>{};
    for (var i = 0; i < _variantes.length; i++) {
      final color = _variantes[i].color.isEmpty
          ? '(sin color)'
          : _variantes[i].color;
      indicesPorColor
          .putIfAbsent(color, () {
            colores.add(color);
            return [];
          })
          .add(i);
    }

    return UnsavedChangesGuard(
      hasChanges: _hasChanges,
      message:
          'Tienes cambios de existencia sin guardar. ¿Deseas salir sin guardarlos?',
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.item.nombre.isEmpty
                ? 'Editar existencia'
                : widget.item.nombre,
          ),
        ),
        body: _variantes.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Esta prenda todavía no tiene colores ni tallas.\nAgrégalos desde el formulario completo.',
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
                              _VariantRow(
                                variant: _variantes[i],
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
        bottomNavigationBar: _variantes.isEmpty
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton.icon(
                  onPressed: _hasChanges && !_saving ? _save : null,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Guardar'),
                ),
              ),
      ),
    );
  }
}

class _VariantRow extends StatelessWidget {
  final ClothingVariant variant;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _VariantRow({
    required this.variant,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final agotado = variant.existencia <= 0;
    final stockBajo = variant.stockBajo;

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
          if (agotado || stockBajo)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                agotado ? 'AGOTADO' : 'POCAS',
                style: TextStyle(
                  color: agotado
                      ? colorScheme.error
                      : colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          IconButton.filledTonal(
            icon: const Icon(Icons.remove_rounded),
            tooltip: 'Restar una pieza',
            onPressed: variant.existencia > 0 ? onDecrement : null,
            visualDensity: VisualDensity.compact,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 32),
            child: Text(
              '${variant.existencia}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton.filledTonal(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Sumar una pieza',
            onPressed: onIncrement,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
