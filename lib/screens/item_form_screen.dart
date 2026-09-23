import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/clothing_repository.dart';
import '../models/clothing_item.dart';
import '../utils/formato.dart';
import '../widgets/snackbars.dart';
import 'qr_screen.dart';
import 'quick_stock_screen.dart';

/// What [ItemFormScreen] pops with, so the caller can tell a save apart from
/// a delete and react accordingly (e.g. offer "undo" only after a delete).
enum ItemFormResult { saved, deleted }

class _VariantRow {
  final TextEditingController talla;
  final TextEditingController color;
  final TextEditingController existencia;

  _VariantRow({String talla = '', String color = '', int existencia = 0})
    : talla = TextEditingController(text: talla),
      color = TextEditingController(text: color),
      existencia = TextEditingController(text: existencia.toString());

  void dispose() {
    talla.dispose();
    color.dispose();
    existencia.dispose();
  }
}

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
  final List<_VariantRow> _variantes = [];
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
            ? [_VariantRow()]
            : variantes.map(
                (v) => _VariantRow(
                  talla: v.talla,
                  color: v.color,
                  existencia: v.existencia,
                ),
              ),
      );
    for (final row in _variantes) {
      _attachDirtyListeners(row);
    }
  }

  void _attachDirtyListeners(_VariantRow row) {
    row.talla.addListener(_markDirty);
    row.color.addListener(_markDirty);
    row.existencia.addListener(_markDirty);
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<bool> _confirmDiscard() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar cambios'),
        content: const Text(
          'Tienes cambios sin guardar. ¿Deseas salir sin guardarlos?',
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
    final row = _VariantRow();
    _attachDirtyListeners(row);
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

  bool _rowIsUsed(_VariantRow row) =>
      row.talla.text.trim().isNotEmpty || row.color.text.trim().isNotEmpty;

  String? _validateTalla(_VariantRow row) {
    if (!_rowIsUsed(row)) {
      return null;
    }
    return row.talla.text.trim().isEmpty ? 'Requerido' : null;
  }

  String? _validateColor(_VariantRow row) {
    if (!_rowIsUsed(row)) return null;
    return row.color.text.trim().isEmpty ? 'Requerido' : null;
  }

  String? _validateExistencia(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null; // treated as 0
    final parsed = int.tryParse(text);
    if (parsed == null) return 'Inválido';
    if (parsed < 0) return 'No negativo';
    if (parsed > Limites.existenciaMax) return 'Máx. ${Limites.existenciaMax}';
    return null;
  }

  String? _validatePrecio(String? value) {
    if (value == null || value.trim().isEmpty) return 'Requerido';
    final parsed = leerPrecio(value);
    if (parsed == null || parsed < 0) return 'Precio inválido';
    if (parsed > Limites.precioMax) {
      return 'Máximo ${formatoPrecio(Limites.precioMax)}';
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _doSave();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _doSave() async {
    if (!_formKey.currentState!.validate()) return;

    final variantes = _variantes
        .where(_rowIsUsed)
        .map(
          (row) => ClothingVariant(
            talla: row.talla.text.trim(),
            color: row.color.text.trim(),
            existencia: int.tryParse(row.existencia.text.trim()) ?? 0,
          ),
        )
        .toList();

    final duplicate = ClothingItem.firstDuplicateVariant(variantes);
    if (duplicate != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'La combinación ${duplicate.color} / ${duplicate.talla} ya está registrada.',
          ),
        ),
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
      _rebaseStock(variantes, latest);
    }

    final updated = ClothingItem(
      id: id,
      nombre: _nombreCtrl.text.trim(),
      precio: ClothingItem.clampPrecio(leerPrecio(_precioCtrl.text) ?? 0),
      variantes: variantes,
    );

    try {
      await widget.repo.save(updated);
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'No se pudo guardar. Inténtalo de nuevo.');
      }
      return;
    }

    if (!mounted) return;
    _dirty = false;
    Navigator.of(context).pop(ItemFormResult.saved);
  }

  /// Turns the counts in [variantes] (absolute, as typed) into "latest
  /// stored count + what changed in this form", for the variants that
  /// existed when the form was filled and still exist now.
  void _rebaseStock(List<ClothingVariant> variantes, ClothingItem latest) {
    final latestStock = {for (final v in latest.variantes) v.key: v.existencia};
    for (final v in variantes) {
      final loaded = _loadedStock[v.key];
      final current = latestStock[v.key];
      if (loaded == null || current == null) continue;
      v.existencia = ClothingVariant.clampExistencia(
        current + v.existencia - loaded,
      );
    }
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
    Navigator.of(context).pop(ItemFormResult.deleted);
  }

  void _showQr() {
    // Build a live snapshot so the QR screen reflects unsaved edits too.
    final snapshot = ClothingItem(
      id: widget.item.id,
      nombre: _nombreCtrl.text.trim(),
      precio: ClothingItem.clampPrecio(leerPrecio(_precioCtrl.text) ?? 0),
      variantes: const [],
    );
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => QrScreen(item: snapshot)));
  }

  @override
  Widget build(BuildContext context) {
    // A new garment's number can show up from another device mid-edit; that
    // doesn't make this form an edit of it.
    final isExisting =
        !widget.isNew && widget.repo.getById(widget.item.id) != null;

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
          title: Text(widget.isNew ? 'Nueva prenda' : 'Editar prenda'),
          actions: [
            if (isExisting && widget.item.variantes.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Editar existencia rápido',
                onPressed: _quickEditStock,
              ),
            IconButton(
              icon: const Icon(Icons.qr_code),
              tooltip: 'Ver código QR',
              onPressed: _showQr,
            ),
            if (isExisting)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Eliminar',
                onPressed: _delete,
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nombreCtrl,
                        maxLength: Limites.nombre,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de la prenda',
                          prefixIcon: Icon(Icons.checkroom_rounded),
                          counterText: '',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Requerido'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _precioCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Precio',
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tallas, colores y existencia',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _variantes.length < Limites.variantes
                          ? _addVariantRow
                          : null,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Agregar'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              ..._variantes.asMap().entries.map((entry) {
                final index = entry.key;
                final row = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: row.talla,
                                maxLength: Limites.talla,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  labelText: 'Talla',
                                  isDense: true,
                                  counterText: '',
                                ),
                                validator: (_) => _validateTalla(row),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: row.color,
                                maxLength: Limites.color,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  labelText: 'Color',
                                  isDense: true,
                                  counterText: '',
                                ),
                                validator: (_) => _validateColor(row),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: row.existencia,
                                decoration: const InputDecoration(
                                  labelText: 'Existencia',
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(5),
                                ],
                                validator: _validateExistencia,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              tooltip: 'Quitar esta talla/color',
                              onPressed: _variantes.length > 1
                                  ? () => _removeVariantRow(index)
                                  : null,
                            ),
                          ],
                        ),
                        AnimatedBuilder(
                          animation: row.existencia,
                          builder: (context, _) {
                            final agotado =
                                (int.tryParse(row.existencia.text.trim()) ??
                                    0) <=
                                0;
                            if (!agotado || !_rowIsUsed(row)) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'AGOTADO',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
