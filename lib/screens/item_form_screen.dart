import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/clothing_repository.dart';
import '../models/clothing_item.dart';
import '../utils/formato.dart';
import '../widgets/snackbars.dart';
import '../widgets/unsaved_changes_guard.dart';
import 'item_form/variant_row.dart';
import 'qr_screen.dart';
import 'quick_stock_screen.dart';

/// What [ItemFormScreen] pops with, so the caller can tell a save apart from
/// a delete and react accordingly (e.g. offer "undo" only after a delete).
enum ItemFormOutcome { saved, deleted }

/// The outcome, and the garment as saved (its id may differ from the one
/// the form opened with, see [_ItemFormScreenState._save]) or as it was
/// right before being deleted (for "undo").
typedef ItemFormResult = ({ItemFormOutcome outcome, ClothingItem item});

/// Create/edit screen for a single garment. Works both for a brand-new item
/// (blank fields, id already assigned) and an existing one loaded from a scan
/// or from the catalog list.
class ItemFormScreen extends StatefulWidget {
  final ClothingRepository repo;
  final ClothingItem item;
  final bool isNew;

  const ItemFormScreen({
    super.key,
    required this.repo,
    required this.item,
    this.isNew = false,
  });

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _precioCtrl;
  final List<VariantRowControllers> _variantes = [];
  bool _dirty = false;
  bool _saving = false;

  /// Stock per variant as it was when the rows were filled in, by
  /// [ClothingVariant.key]. Saving applies the difference from these onto
  /// the latest stored counts, so pieces sold on another phone while this
  /// form was open aren't overwritten.
  Map<String, int> _loadedStock = {};

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.item.nombre);
    _precioCtrl = TextEditingController(
      text: widget.item.precio == 0
          ? ''
          : widget.item.precio.toStringAsFixed(2).replaceAll('.00', ''),
    );
    _nombreCtrl.addListener(_markDirty);
    _precioCtrl.addListener(_markDirty);
    _setVariantRows(widget.item.variantes);
  }

  /// Replaces the variant rows with [variantes] (one blank row if empty).
  void _setVariantRows(List<ClothingVariant> variantes) {
    _loadedStock = {for (final v in variantes) v.key: v.existencia};
    for (final row in _variantes) {
      row.dispose();
    }
    _variantes
      ..clear()
      ..addAll(
        variantes.isEmpty
            ? [VariantRowControllers()]
            : variantes.map(VariantRowControllers.fromVariant),
      );
    for (final row in _variantes) {
      row.addListener(_markDirty);
    }
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _precioCtrl.dispose();
    for (final row in _variantes) {
      row.dispose();
    }
    super.dispose();
  }

  void _addVariantRow() {
    final row = VariantRowControllers()..addListener(_markDirty);
    setState(() {
      _variantes.add(row);
      _dirty = true;
    });
  }

  void _removeVariantRow(int index) {
    setState(() {
      _variantes[index].dispose();
      _variantes.removeAt(index);
      _dirty = true;
    });
  }

  /// What the price field holds, as it will be stored (see [leerPrecio]).
  double _precio() =>
      ClothingItem.clampPrecio(leerPrecio(_precioCtrl.text) ?? 0);

  late final int _nombreMax = math.max(
    Limites.nombre,
    widget.item.nombre.length,
  );

  String? _validateNombre(String? value) {
    final nombre = value?.trim() ?? '';
    if (nombre.isEmpty) return 'Requerido';
    return nombre.length > _nombreMax ? 'Máximo $_nombreMax caracteres' : null;
  }

  static String? _validatePrecio(String? value) {
    if (value == null || value.trim().isEmpty) return 'Requerido';
    final precio = leerPrecio(value);
    if (precio == null || precio < 0) return 'Precio inválido';
    if (precio > Limites.precioMax) {
      return 'Máximo ${formatoPrecio(Limites.precioMax)}';
    }
    return null;
  }

  /// Turns the counts in [variantes] (absolute, as typed) into "latest
  /// stored count + what changed in this form", for the variants that
  /// existed when the form was filled and still exist now.
  List<ClothingVariant> _rebaseStock(
    List<ClothingVariant> variantes,
    ClothingItem latest,
  ) {
    final latestStock = {for (final v in latest.variantes) v.key: v.existencia};
    return [
      for (final v in variantes)
        switch ((_loadedStock[v.key], latestStock[v.key])) {
          (final int loaded, final int current) => ClothingVariant(
            talla: v.talla,
            color: v.color,
            existencia: ClothingVariant.clampExistencia(
              current + v.existencia - loaded,
            ),
          ),
          _ => v,
        },
    ];
  }

  Future<void> _save() async {
    // A second tap while saving would pop this screen twice, closing the
    // catalog behind it too.
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    var variantes = [
      for (final row in _variantes)
        if (row.isUsed) row.toVariant(),
    ];

    final duplicate = ClothingItem.firstDuplicateVariant(variantes);
    if (duplicate != null) {
      showErrorSnackBar(
        context,
        'La combinación ${duplicate.color} / ${duplicate.talla} ya está registrada.',
      );
      return;
    }

    // Another device may have saved a garment under this same number while
    // the form was open; taking the next free one keeps both garments.
    var id = widget.item.id;
    if (widget.isNew && widget.repo.exists(id)) id = widget.repo.nextId();

    if (!widget.isNew) {
      final latest = widget.repo.getById(id);
      if (latest == null) {
        showErrorSnackBar(
          context,
          'Esta prenda se eliminó en otro teléfono; no se guardaron los cambios.',
        );
        return;
      }
      variantes = _rebaseStock(variantes, latest);
    }

    final updated = ClothingItem(
      id: id,
      nombre: _nombreCtrl.text.trim(),
      precio: _precio(),
      variantes: variantes,
    );

    setState(() => _saving = true);
    try {
      await widget.repo.save(updated);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showErrorSnackBar(context, 'No se pudo guardar. Inténtalo de nuevo.');
      }
      return;
    }

    if (!mounted) return;
    _dirty = false;
    Navigator.of(
      context,
    ).pop<ItemFormResult>((outcome: ItemFormOutcome.saved, item: updated));
  }

  Future<void> _quickEditStock() async {
    if (_dirty) {
      showErrorSnackBar(
        context,
        'Guarda o descarta los cambios del formulario antes de ajustar la existencia.',
      );
      return;
    }
    final current = widget.repo.getById(widget.item.id);
    if (current == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QuickStockScreen(repo: widget.repo, item: current),
      ),
    );
    if (saved != true || !mounted) return;
    // Reflect the updated counts in this screen's fields too.
    final refreshed = widget.repo.getById(widget.item.id);
    if (refreshed != null) {
      setState(() => _setVariantRows(refreshed.variantes));
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar prenda'),
        content: const Text('¿Eliminar esta prenda del catálogo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
              minimumSize: const Size(64, 44),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    // What "undo" will bring back: the stored version, which may be newer
    // than the one this form opened with.
    final deleted = widget.repo.getById(widget.item.id) ?? widget.item;
    try {
      await widget.repo.delete(widget.item.id);
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'No se pudo eliminar. Inténtalo de nuevo.');
      }
      return;
    }
    if (!mounted) return;
    _dirty = false;
    Navigator.of(
      context,
    ).pop<ItemFormResult>((outcome: ItemFormOutcome.deleted, item: deleted));
  }

  void _showQr() {
    // Build a live snapshot so the QR screen reflects unsaved edits too.
    final snapshot = ClothingItem(
      id: widget.item.id,
      nombre: _nombreCtrl.text.trim(),
      precio: _precio(),
      variantes: const [],
    );
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => QrScreen(item: snapshot)));
  }

  @override
  Widget build(BuildContext context) {
    final isExisting = !widget.isNew;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final usadas = _variantes.where((r) => r.isUsed).length;

    return UnsavedChangesGuard(
      hasChanges: _dirty,
      message: 'Tienes cambios sin guardar. ¿Deseas salir sin guardarlos?',
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isNew ? 'Nueva prenda' : 'Editar prenda'),
          actions: [
            if (isExisting)
              IconButton(
                icon: const Icon(Icons.qr_code_2_rounded),
                tooltip: 'Ver código QR',
                onPressed: _showQr,
              ),
            if (isExisting)
              PopupMenuButton<_FormAction>(
                tooltip: 'Más opciones',
                onSelected: (action) => switch (action) {
                  _FormAction.stock => _quickEditStock(),
                  _FormAction.delete => _delete(),
                },
                itemBuilder: (context) => [
                  if (widget.item.variantes.isNotEmpty)
                    const PopupMenuItem(
                      value: _FormAction.stock,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.tune_rounded),
                        title: Text('Ajustar existencia'),
                      ),
                    ),
                  PopupMenuItem(
                    value: _FormAction.delete,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.delete_outline_rounded,
                        color: colorScheme.error,
                      ),
                      title: Text(
                        'Eliminar prenda',
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              // A new garment's code is only final once saved (another phone
              // may take the number meanwhile), so its QR is offered after.
              Align(
                alignment: Alignment.centerLeft,
                child: isExisting
                    ? ActionChip(
                        avatar: const Icon(Icons.qr_code_rounded, size: 18),
                        label: Text(widget.item.id),
                        tooltip: 'Ver código QR',
                        onPressed: _showQr,
                      )
                    : Chip(
                        avatar: const Icon(Icons.qr_code_rounded, size: 18),
                        label: const Text('El código QR se genera al guardar'),
                      ),
              ),
              const SizedBox(height: 20),
              const _SectionTitle('Información'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nombreCtrl,
                // Counted, never cut: a longer name saved before the limit
                // existed stays as it is unless it's edited to grow.
                maxLength: _nombreMax,
                maxLengthEnforcement: MaxLengthEnforcement.none,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la prenda',
                  hintText: 'Ej. Playera básica',
                  prefixIcon: Icon(Icons.checkroom_rounded),
                ),
                validator: _validateNombre,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _precioCtrl,
                decoration: const InputDecoration(
                  labelText: 'Precio',
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.sell_outlined),
                  prefixText: '\$ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  LengthLimitingTextInputFormatter(13),
                ],
                validator: _validatePrecio,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: _SectionTitle(
                      'Tallas y colores',
                      trailing: usadas == 0
                          ? null
                          : (usadas == 1
                                ? '1 combinación'
                                : '$usadas combinaciones'),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _variantes.length < Limites.variantes
                        ? _addVariantRow
                        : null,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Agregar'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      textStyle: textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final (index, row) in _variantes.indexed)
                VariantRowFields(
                  key: ObjectKey(row),
                  row: row,
                  onRemove: _variantes.length > 1
                      ? () => _removeVariantRow(index)
                      : null,
                ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(widget.isNew ? 'Guardar prenda' : 'Guardar cambios'),
          ),
        ),
      ),
    );
  }
}

enum _FormAction { stock, delete }

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(child: Text(text, style: textTheme.titleMedium)),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Text(
            trailing!,
            style: textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
