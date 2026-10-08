import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../auth/app_user.dart';
import '../data/adjustments_repository.dart';
import '../data/clothing_repository.dart';
import '../models/clothing_item.dart';
import '../models/stock_adjustment.dart';
import '../utils/formato.dart';
import '../widgets/color_dot.dart';
import '../widgets/empty_state.dart';
import '../widgets/item_avatar.dart';
import '../widgets/feedback/app_snackbar.dart';
import '../widgets/progress_button.dart';
import '../widgets/unsaved_changes_guard.dart';

/// Fast +/- adjustment of existing colors and sizes, grouped by color — no
/// need to open the full edit form just to bump a count up or down. Does not
/// add or remove colors/tallas; that still goes through [ItemFormScreen].
/// How a stock save ended, for the screen that opened this one to report.
enum StockSaveOutcome {
  saved,

  /// Saved, but someone else had sold or adjusted the same pieces meanwhile,
  /// so less was subtracted than requested (stock never goes below zero).
  savedPartially,
}

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

  /// Saved: the button shows its check for a moment before the screen
  /// closes.
  bool _saved = false;

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
    final changes = _stockChanges;
    setState(() => _saving = true);
    final ClothingItem applied;
    try {
      applied = await widget.repo.applyStockDelta(latest.id, changes);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnackBar.error(context, 'No se pudo guardar. Inténtalo de nuevo.');
      }
      return;
    }
    // What the server actually applied, not what was requested: a decrease
    // never takes stock below zero, so if someone else sold or adjusted the
    // same variant in between, less may have been subtracted than this
    // screen's +/- asked for. The audit trail must reflect the real change.
    final latestByKey = {for (final v in latest.variantes) v.key: v.existencia};
    final appliedByKey = {
      for (final v in applied.variantes) v.key: v.existencia,
    };
    var clamped = false;
    // Best-effort audit trail: a failure here must never block the stock
    // change itself, already saved above.
    for (final v in _variantes) {
      final requested = changes[v.key] ?? 0;
      if (requested == 0) continue;
      final real = (appliedByKey[v.key] ?? 0) - (latestByKey[v.key] ?? 0);
      if (real != requested) clamped = true;
      if (real == 0) continue;
      unawaited(
        widget.adjustmentsRepo.registrar(
          StockAdjustment(
            id: StockAdjustment.newId(),
            itemId: latest.id,
            nombreItem: latest.nombre,
            color: v.color,
            talla: v.talla,
            delta: real,
            usuarioNombre: widget.user.nombre,
            fecha: DateTime.now(),
          ),
        ),
      );
    }
    if (!mounted) return;
    setState(() => _saved = true);
    await Future<void>.delayed(ProgressButton.doneHold);
    if (!mounted) return;
    // Reported by the screen this returns to, so the message isn't cut
    // short by the transition (or replaced by "Cambios guardados").
    Navigator.of(
      context,
    ).pop(clamped ? StockSaveOutcome.savedPartially : StockSaveOutcome.saved);
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
      busy: _saving,
      busyMessage: 'Espera a que termine de guardar.',
      child: Scaffold(
        appBar: AppBar(title: const Text('Ajustar existencia')),
        body: _variantes.isEmpty
            ? Center(
                child: EmptyState(
                  icon: Icons.layers_outlined,
                  title: 'Sin tallas ni colores',
                  message: widget.user.canEditCatalog
                      ? 'Esta prenda todavía no tiene colores ni tallas. '
                            'Agrégalos desde su ficha (toca la prenda en el '
                            'catálogo).'
                      : 'Esta prenda todavía no tiene colores ni tallas. '
                            'Pide a un administrador que los agregue.',
                  actionLabel: 'Volver al catálogo',
                  actionIcon: Icons.arrow_back_rounded,
                  onAction: () => Navigator.of(context).pop(),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  _ItemHeader(
                    item: widget.item,
                    photoPath: widget.repo.photoPathFor(widget.item.id),
                    total: total,
                    totalDelta: totalDelta,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Toca + cuando llegan piezas y − cuando salen. Nada '
                    'cambia hasta que toques "Guardar".',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
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
                              color: color,
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
                saved: _saved,
                totalDelta: totalDelta,
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
    this.photoPath,
    required this.total,
    required this.totalDelta,
  });

  final ClothingItem item;
  final String? photoPath;
  final int total;
  final int totalDelta;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        ItemAvatar(nombre: item.nombre, size: 60, photoPath: photoPath),
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
                  ? (total == 1 ? 'pieza en total' : 'piezas en total')
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

  /// The color group this talla is in, so every label names both (the
  /// person must never wonder which color's M they're changing).
  final String color;

  /// How far this screen has moved the count; shown as "before → now" so
  /// the person can see what they're about to save.
  final int delta;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _VariantRow({
    required this.variant,
    required this.color,
    required this.delta,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final stock = StockColors.of(context);
    final existencia = variant.existencia;
    final talla = variant.talla.isEmpty ? '(sin talla)' : variant.talla;

    // Status in words and icon, never by color alone.
    final (
      IconData? icon,
      String? estado,
      Color estadoColor,
    ) = switch (existencia) {
      <= 0 => (
        Icons.remove_shopping_cart_outlined,
        'Agotado',
        colorScheme.error,
      ),
      <= ClothingVariant.umbralStockBajo => (
        Icons.warning_amber_rounded,
        'Quedan pocas',
        stock.low,
      ),
      _ => (null, null, colorScheme.onSurfaceVariant),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Talla $talla', style: textTheme.titleMedium),
                if (delta != 0)
                  Text(
                    'Había ${existencia - delta} → ahora $existencia',
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (estado != null)
                  Row(
                    children: [
                      Icon(icon, size: 14, color: estadoColor),
                      const SizedBox(width: 4),
                      Text(
                        estado,
                        style: textTheme.labelMedium?.copyWith(
                          color: estadoColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          _Stepper(
            value: existencia,
            descripcion: 'talla $talla, color $color',
            onDecrement: existencia > 0 ? onDecrement : null,
            onIncrement: existencia < Limites.existenciaMax
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
    required this.descripcion,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int value;

  /// Which variant this is, for screen readers ("talla M, color Negro").
  final String descripcion;
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
            tooltip: 'Restar una pieza de $descripcion',
            onPressed: _withHaptics(onDecrement),
          ),
          SizedBox(
            width: 44,
            child: Semantics(
              liveRegion: true,
              label: '${formatoPiezas(value)} en $descripcion',
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
            tooltip: 'Sumar una pieza a $descripcion',
            onPressed: _withHaptics(onIncrement),
          ),
        ],
      ),
    );
  }
}

/// Save action pinned to the bottom, above the system navigation. Says
/// what it will save, or how to start when there's nothing yet.
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.enabled,
    required this.saving,
    required this.saved,
    required this.totalDelta,
    required this.onSave,
  });

  final bool enabled;
  final bool saving;
  final bool saved;
  final int totalDelta;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final String label;
    if (!enabled) {
      label = 'Usa − o + para cambiar las piezas';
    } else if (totalDelta == 0) {
      label = 'Guardar cambios';
    } else {
      final n = totalDelta.abs();
      label = totalDelta > 0
          ? 'Guardar: entran ${formatoPiezas(n)}'
          : 'Guardar: salen ${formatoPiezas(n)}';
    }
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: ProgressButton(
        state: saved
            ? ProgressState.done
            : saving
            ? ProgressState.busy
            : ProgressState.idle,
        icon: Icons.check_rounded,
        label: label,
        doneLabel: 'Existencia guardada',
        onPressed: enabled ? onSave : null,
      ),
    );
  }
}
