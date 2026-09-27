import 'package:flutter/material.dart';

import '../data/clothing_repository.dart';
import '../models/clothing_item.dart';
import '../widgets/snackbars.dart';
import '../widgets/unsaved_changes_guard.dart';
import 'item_form/variant_row.dart';
import 'qr_screen.dart';
import 'quick_stock_screen.dart';

/// What [ItemFormScreen] pops with, so the caller can tell a save apart from
/// a delete and react accordingly (e.g. offer "undo" only after a delete).
enum ItemFormResult { saved, deleted }

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

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.item.nombre);
    _precioCtrl = TextEditingController(
      text: widget.item.precio == 0 ? '' : widget.item.precio.toString(),
    );
    _nombreCtrl.addListener(_markDirty);
    _precioCtrl.addListener(_markDirty);
    _setVariantRows(widget.item.variantes);
  }

  /// Replaces the variant rows with [variantes] (one blank row if empty).
  void _setVariantRows(List<ClothingVariant> variantes) {
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

  /// Accepts a decimal comma as well ("199,50"), as typed on many phones.
  static double? _parsePrecio(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  static String? _validatePrecio(String? value) {
    if (value == null || value.trim().isEmpty) return 'Requerido';
    final precio = _parsePrecio(value);
    return precio == null || precio < 0 ? 'Precio inválido' : null;
  }

  Future<void> _save() async {
    // A second tap while saving would pop this screen twice, closing the
    // catalog behind it too.
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    final variantes = [
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

    final updated = ClothingItem(
      id: widget.item.id,
      nombre: _nombreCtrl.text.trim(),
      precio: _parsePrecio(_precioCtrl.text) ?? 0,
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
    Navigator.of(context).pop(ItemFormResult.saved);
  }

  Future<void> _quickEditStock() async {
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
          TextButton(
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
      precio: _parsePrecio(_precioCtrl.text) ?? 0,
      variantes: const [],
    );
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => QrScreen(item: snapshot)));
  }

  @override
  Widget build(BuildContext context) {
    final isExisting = widget.repo.getById(widget.item.id) != null;

    return UnsavedChangesGuard(
      hasChanges: _dirty,
      message: 'Tienes cambios sin guardar. ¿Deseas salir sin guardarlos?',
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
                        decoration: const InputDecoration(
                          labelText: 'Nombre de la prenda',
                          prefixIcon: Icon(Icons.checkroom_rounded),
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
                      onPressed: _addVariantRow,
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
              for (final (index, row) in _variantes.indexed)
                VariantRowFields(
                  key: ObjectKey(row),
                  row: row,
                  onRemove: _variantes.length > 1
                      ? () => _removeVariantRow(index)
                      : null,
                ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
