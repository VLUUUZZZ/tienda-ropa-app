import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/app_user.dart';
import '../data/adjustments_repository.dart';
import '../data/clothing_repository.dart';
import '../models/clothing_item.dart';
import '../models/stock_adjustment.dart';
import '../widgets/snackbars.dart';
import '../widgets/unsaved_changes_guard.dart';
import 'item_form/photo_picker.dart';
import 'item_form/variant_row.dart';
import 'qr_screen.dart';
import 'quick_stock_screen.dart';
import 'scanner_screen.dart';

/// What [ItemFormScreen] pops with, so the caller can tell a save apart from
/// a delete and react accordingly (e.g. offer "undo" only after a delete).
sealed class ItemFormResult {
  const ItemFormResult();
}

class ItemFormSaved extends ItemFormResult {
  const ItemFormSaved();
}

/// Carries the exact garment that was removed (including any quick stock
/// edit made earlier in this same form session), so "Deshacer" restores the
/// version the user actually saw, not a stale copy from before it opened.
class ItemFormDeleted extends ItemFormResult {
  const ItemFormDeleted(this.item);
  final ClothingItem item;
}

/// Create/edit screen for a single garment. Works both for a brand-new item
/// (blank fields, id already assigned) and an existing one loaded from a scan
/// or from the catalog list.
class ItemFormScreen extends StatefulWidget {
  final ClothingRepository repo;
  final AdjustmentsRepository adjustmentsRepo;
  final AppUser user;
  final ClothingItem item;
  final bool isNew;

  const ItemFormScreen({
    super.key,
    required this.repo,
    required this.adjustmentsRepo,
    required this.user,
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
  late final TextEditingController _codigoProveedorCtrl;
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
    _codigoProveedorCtrl = TextEditingController(
      text: widget.item.codigoProveedor,
    );
    _nombreCtrl.addListener(_markDirty);
    _precioCtrl.addListener(_markDirty);
    _codigoProveedorCtrl.addListener(_markDirty);
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
    _codigoProveedorCtrl.dispose();
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
      codigoProveedor: _codigoProveedorCtrl.text.trim(),
    );

    // The freshest saved stock, in case a quick edit happened earlier in
    // this same form session: that's the real "before" for the audit log,
    // not widget.item (loaded when the screen first opened).
    final baseline = widget.isNew
        ? const <ClothingVariant>[]
        : widget.repo.getById(widget.item.id)?.variantes ??
              widget.item.variantes;

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
    if (!widget.isNew) _logStockChanges(baseline, updated);

    if (!mounted) return;
    _dirty = false;
    Navigator.of(context).pop(const ItemFormSaved());
  }

  /// Best-effort audit trail for stock changes made directly in this form
  /// (as opposed to the quick-stock editor, which logs its own). A failure
  /// here must never block the save itself, already done above.
  void _logStockChanges(List<ClothingVariant> before, ClothingItem updated) {
    final baselineByKey = {for (final v in before) v.key: v.existencia};
    for (final v in updated.variantes) {
      final delta = v.existencia - (baselineByKey[v.key] ?? 0);
      if (delta == 0) continue;
      unawaited(
        widget.adjustmentsRepo.registrar(
          StockAdjustment(
            id: StockAdjustment.newId(),
            itemId: updated.id,
            nombreItem: updated.nombre,
            color: v.color,
            talla: v.talla,
            delta: delta,
            usuarioNombre: widget.user.nombre,
            fecha: DateTime.now(),
          ),
        ),
      );
    }
  }

  Future<void> _quickEditStock() async {
    // The quick-stock screen reloads this garment from the repository, not
    // from these controllers, and replaces the variant rows with whatever it
    // saved: doing that while there are unsaved edits here would silently
    // discard them.
    if (_dirty) {
      showErrorSnackBar(
        context,
        'Guarda o descarta los cambios antes de usar el ajuste rápido.',
      );
      return;
    }
    final current = widget.repo.getById(widget.item.id);
    if (current == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QuickStockScreen(
          repo: widget.repo,
          adjustmentsRepo: widget.adjustmentsRepo,
          user: widget.user,
          item: current,
        ),
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
    // The freshest copy, including any quick stock edit made earlier in this
    // same session: "Deshacer" should restore that, not a stale snapshot.
    final current = widget.repo.getById(widget.item.id) ?? widget.item;
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
    Navigator.of(context).pop(ItemFormDeleted(current));
  }

  void _showQr() {
    // A label printed before the first save carries a code the catalog
    // doesn't recognize yet, and still won't if the item is never saved.
    if (widget.isNew) {
      showErrorSnackBar(
        context,
        'Guarda la prenda antes de imprimir o compartir su código QR.',
      );
      return;
    }
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

  Future<void> _scanProviderCode() async {
    final code = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const ScannerScreen()));
    if (code == null || !mounted) return;
    _codigoProveedorCtrl.text = code;
  }

  @override
  Widget build(BuildContext context) {
    final isExisting = !widget.isNew;

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
              ItemPhotoPicker(repo: widget.repo, itemId: widget.item.id),
              const SizedBox(height: 16),
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
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _codigoProveedorCtrl,
                        decoration: InputDecoration(
                          labelText: 'Código de barras de proveedor (opcional)',
                          prefixIcon: const Icon(Icons.barcode_reader),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.qr_code_scanner_rounded),
                            tooltip: 'Escanear código de proveedor',
                            onPressed: _scanProviderCode,
                          ),
                        ),
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
