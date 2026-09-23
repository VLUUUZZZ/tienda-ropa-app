import 'package:flutter/material.dart';

import '../data/clothing_repository.dart';
import '../models/clothing_item.dart';
import '../utils/formato.dart';
import '../widgets/color_dot.dart';
import '../widgets/snackbars.dart';

/// Fast +/- adjustment of existing colors and sizes, grouped by color — no
/// need to open the full edit form just to bump a count up or down. Does not
/// add or remove colors/tallas; that still goes through [ItemFormScreen].
class QuickStockScreen extends StatefulWidget {
  final ClothingRepository repo;
  final ClothingItem item;

  const QuickStockScreen({super.key, required this.repo, required this.item});

  @override
  State<QuickStockScreen> createState() => _QuickStockScreenState();
}

class _QuickStockScreenState extends State<QuickStockScreen> {
  late List<ClothingVariant> _variantes;
  bool _dirty = false;

  /// Guards against a double tap on Guardar: each save applies this screen's
  /// changes as deltas, so saving twice would count them twice.
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
      _variantes[index] = ClothingVariant(
        talla: v.talla,
        color: v.color,
        existencia: ClothingVariant.clampExistencia(v.existencia + delta),
      );
      _dirty = true;
    });
  }

  Future<bool> _confirmDiscard() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar cambios'),
        content: const Text(
          'Tienes cambios de existencia sin guardar. ¿Deseas salir sin guardarlos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Seguir editando'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  int _delta(int i) =>
      _variantes[i].existencia - widget.item.variantes[i].existencia;

  /// How much each variant moved on this screen, by [ClothingVariant.key].
  Map<String, int> get _stockChanges => {
    for (var i = 0; i < _variantes.length; i++) _variantes[i].key: _delta(i),
  };

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _applyChanges();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _applyChanges() async {
    // The garment may have changed on another device since this screen
    // opened: apply only this screen's +/- on top of its latest version.
    final latest = widget.repo.getById(widget.item.id);
    if (latest == null) {
      showErrorSnackBar(context, 'Esta prenda ya no existe en el catálogo.');
      return;
    }
    try {
      await widget.repo.save(latest.withStockChanges(_stockChanges));
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'No se pudo guardar. Inténtalo de nuevo.');
      }
      return;
    }
    if (!mounted) return;
    _dirty = false;
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

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final descartar = await _confirmDiscard();
        if (!descartar) return;
        if (!mounted) return;
        setState(() => _dirty = false);
        // ignore: use_build_context_synchronously
        Navigator.of(context).pop();
      },
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
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  for (final color in colores) ...[
                    _ColorHeader(
                      color: color,
                      total: indicesPorColor[color]!.fold(
                        0,
                        (sum, i) => sum + _variantes[i].existencia,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Column(
                        children: [
                          for (final (n, i)
                              in indicesPorColor[color]!.indexed) ...[
                            if (n > 0) const Divider(indent: 16, endIndent: 16),
                            _VariantRow(
                              variant: _variantes[i],
                              delta: _delta(i),
                              onDecrement: () => _adjust(i, -1),
                              onIncrement: () => _adjust(i, 1),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
        bottomNavigationBar: _variantes.isEmpty
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton.icon(
                  onPressed: _dirty && !_saving ? _save : null,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: const Text('Guardar'),
                ),
              ),
      ),
    );
  }
}

/// A color's name with its swatch and how many pieces it has in total.
class _ColorHeader extends StatelessWidget {
  const _ColorHeader({required this.color, required this.total});

  final String color;
  final int total;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          ColorDot(nombre: color, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(color, style: textTheme.titleMedium)),
          Text(
            formatoPiezas(total),
            style: textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _VariantRow extends StatelessWidget {
  final ClothingVariant variant;

  /// How far this screen has moved the count; shown so the person can see
  /// what they're about to save.
  final int delta;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _VariantRow({
    required this.variant,
    required this.delta,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final agotado = variant.existencia == 0;
    final talla = variant.talla.isEmpty ? '(sin talla)' : variant.talla;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(talla, style: textTheme.titleMedium),
                if (agotado || delta != 0)
                  Text(
                    [
                      if (agotado) 'Agotado',
                      if (delta != 0)
                        '${delta > 0 ? '+' : ''}$delta sin guardar',
                    ].join(' · '),
                    style: textTheme.labelMedium?.copyWith(
                      color: agotado ? colorScheme.error : colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          IconButton.filledTonal(
            icon: const Icon(Icons.remove_rounded),
            tooltip: 'Restar una pieza de talla $talla',
            onPressed: variant.existencia > 0 ? onDecrement : null,
          ),
          SizedBox(
            width: 48,
            child: Semantics(
              liveRegion: true,
              label: '${formatoPiezas(variant.existencia)} en talla $talla',
              excludeSemantics: true,
              child: Text(
                '${variant.existencia}',
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          IconButton.filled(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Sumar una pieza a talla $talla',
            onPressed: variant.existencia < Limites.existenciaMax
                ? onIncrement
                : null,
          ),
        ],
      ),
    );
  }
}
