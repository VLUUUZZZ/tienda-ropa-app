import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/clothing_repository.dart';
import '../models/clothing_item.dart';
import '../utils/formato.dart';
import '../widgets/color_dot.dart';
import '../widgets/item_avatar.dart';
import '../widgets/feedback/app_snackbar.dart';
import '../widgets/unsaved_changes_guard.dart';

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
    });
  }

  int _delta(int i) =>
      _variantes[i].existencia - widget.item.variantes[i].existencia;

  /// How much each variant moved on this screen, by [ClothingVariant.key].
  Map<String, int> get _stockChanges => {
    for (var i = 0; i < _variantes.length; i++) _variantes[i].key: _delta(i),
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
      AppSnackBar.error(context, 'Esta prenda ya no existe en el catálogo.');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repo.save(latest.withStockChanges(_stockChanges));
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnackBar.error(context, 'No se pudo guardar. Inténtalo de nuevo.');
      }
      return;
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
    final total = _variantes.fold(0, (sum, v) => sum + v.existencia);
    final totalDelta = total - widget.item.existenciaTotal;

    return UnsavedChangesGuard(
      hasChanges: _hasChanges,
      message:
          'Los ajustes de existencia que hiciste todavía no se han guardado.',
      child: Scaffold(
        appBar: AppBar(title: const Text('Ajustar existencia')),
        body: _variantes.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Esta prenda todavía no tiene colores ni tallas.\n'
                    'Agrégalos desde la ficha completa.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  _ItemHeader(
                    item: widget.item,
                    total: total,
                    totalDelta: totalDelta,
                  ),
                  const SizedBox(height: 24),
                  for (final color in colores) ...[
                    _ColorHeader(
                      color: color,
                      total: indicesPorColor[color]!.fold(
                        0,
                        (sum, i) => sum + _variantes[i].existencia,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: Column(
                        children: [
                          for (final (n, i)
                              in indicesPorColor[color]!.indexed) ...[
                            if (n > 0) const Divider(indent: 20, endIndent: 20),
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
                    const SizedBox(height: 24),
                  ],
                ],
              ),
        bottomNavigationBar: _variantes.isEmpty
            ? null
            : _SaveBar(
                enabled: _hasChanges && !_saving,
                saving: _saving,
                onSave: _save,
              ),
      ),
    );
  }
}

/// The garment being adjusted and its total, with how much this screen has
/// moved it so far.
class _ItemHeader extends StatelessWidget {
  const _ItemHeader({
    required this.item,
    required this.total,
    required this.totalDelta,
  });

  final ClothingItem item;
  final int total;
  final int totalDelta;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        ItemAvatar(nombre: item.nombre, size: 60),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.nombre.isEmpty ? '(sin nombre)' : item.nombre,
                style: textTheme.titleLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${item.id} · ${formatoPrecio(item.precio)}',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Text(
                '$total',
                key: ValueKey(total),
                style: textTheme.headlineMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Text(
              totalDelta == 0
                  ? (total == 1 ? 'pieza' : 'piezas')
                  : '${totalDelta > 0 ? '+' : ''}$totalDelta sin guardar',
              style: textTheme.labelMedium?.copyWith(
                color: totalDelta == 0
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
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
          ColorDot(nombre: color, size: 18),
          const SizedBox(width: 10),
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
    final agotado = variant.existencia <= 0;
    final talla = variant.talla.isEmpty ? '(sin talla)' : variant.talla;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
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
          _Stepper(
            value: variant.existencia,
            talla: talla,
            onDecrement: variant.existencia > 0 ? onDecrement : null,
            onIncrement: variant.existencia < Limites.existenciaMax
                ? onIncrement
                : null,
          ),
        ],
      ),
    );
  }
}

/// "− 3 +" as one pill: big touch targets, a tick of haptic feedback per
/// press, and the number animating as it changes.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.talla,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int value;
  final String talla;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  VoidCallback? _withHaptics(VoidCallback? action) => action == null
      ? null
      : () {
          HapticFeedback.selectionClick();
          action();
        };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
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
            tooltip: 'Restar una pieza de talla $talla',
            onPressed: _withHaptics(onDecrement),
          ),
          SizedBox(
            width: 44,
            child: Semantics(
              liveRegion: true,
              label: '${formatoPiezas(value)} en talla $talla',
              excludeSemantics: true,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: Text(
                  '$value',
                  key: ValueKey(value),
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
            tooltip: 'Sumar una pieza a talla $talla',
            onPressed: _withHaptics(onIncrement),
          ),
        ],
      ),
    );
  }
}

/// Save action pinned to the bottom, above the system navigation.
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.enabled,
    required this.saving,
    required this.onSave,
  });

  final bool enabled;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: FilledButton.icon(
        onPressed: enabled ? onSave : null,
        icon: saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.check_rounded),
        label: const Text('Guardar cambios'),
      ),
    );
  }
}
