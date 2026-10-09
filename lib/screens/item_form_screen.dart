// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/app_user.dart';
import '../data/adjustments_repository.dart';
import '../data/clothing_repository.dart';
import '../models/clothing_item.dart';
import '../models/stock_adjustment.dart';
import '../utils/formato.dart';
import '../widgets/feedback/app_snackbar.dart';
import '../widgets/feedback/confirm_dialog.dart';
import '../widgets/progress_button.dart';
import '../widgets/unsaved_changes_guard.dart';
import 'item_form/photo_picker.dart';
import 'item_form/variant_row.dart';
import 'qr_screen.dart';
import 'quick_stock_screen.dart';
import 'scanner_screen.dart';

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
  final AdjustmentsRepository adjustmentsRepo;
  final AppUser user;

  const ItemFormScreen({
    super.key,
    required this.repo,
    required this.item,
    this.isNew = false,
    required this.adjustmentsRepo,
    required this.user,
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
  bool _deleting = false;

  /// Saved: the button shows its check for a moment before the screen
  /// closes.
  bool _saved = false;
  late final TextEditingController _codigoProveedorCtrl;

  /// A save or a delete is already running: every other action that could
  /// race it (quick edit, QR, delete, save, leaving) waits.
  bool get _busy => _saving || _deleting;

  /// Stock per variant as it was when the rows were filled in, by
  /// [ClothingVariant.key]. Saving applies the difference from these onto
  /// the latest stored counts, so pieces sold on another phone while this
  /// form was open aren't overwritten.
  Map<String, int> _loadedStock = {};

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.item.nombre);
    _precioCtrl = TextEditingController(text: _precioTexto(widget.item.precio));
    _codigoProveedorCtrl = TextEditingController(
      text: widget.item.codigoProveedor,
    );
    _nombreCtrl.addListener(_markDirty);
    _codigoProveedorCtrl.addListener(_markDirty);
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

  /// How a price shows in its field: "199", "649.50", empty for none.
  static String _precioTexto(double precio) =>
      precio == 0 ? '' : precio.toStringAsFixed(2).replaceAll('.00', '');

  /// Removing a saved row that still has pieces takes that stock out of the
  /// catalog, so it's confirmed first. Rows typed in this session (never
  /// saved) and empty ones just go.
  Future<void> _removeVariantRow(int index) async {
    final row = _variantes[index];
    final saved = _loadedStock.containsKey(row.toVariant().key);
    if (saved && row.existenciaValue > 0) {
      final talla = row.talla.text.trim();
      final color = row.color.text.trim();
      final confirmed = await confirmAction(
        context,
        icon: Icons.layers_clear_outlined,
        destructive: true,
        title: 'Quitar $color / $talla',
        message:
            '¿Seguro que quieres quitar $color / $talla? Todavía tiene '
            '${formatoPiezas(row.existenciaValue)}; al guardar, esta '
            'combinación y sus piezas dejarán de estar en el catálogo.',
        confirmLabel: 'Quitar',
      );
      if (!confirmed || !mounted || !_variantes.contains(row)) return;
      index = _variantes.indexOf(row);
    }
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
    if (nombre.isEmpty) return 'Escribe el nombre de la prenda';
    return nombre.length > _nombreMax
        ? 'Usa como máximo $_nombreMax caracteres'
        : null;
  }

  static String? _validatePrecio(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Escribe el precio de venta, por ejemplo 199.50';
    }
    final precio = leerPrecio(value);
    if (precio == null || precio < 0) {
      return 'Escribe solo el número, por ejemplo 199.50';
    }
    if (precio == 0) return 'El precio debe ser mayor a \$0';
    if (precio > Limites.precioMax) {
      return 'El precio no puede pasar de ${formatoPrecio(Limites.precioMax)}';
    }
    return null;
  }

  /// Puts [item]'s stored values back in every field, as if just opened.
  void _fillFrom(ClothingItem item) {
    _nombreCtrl.text = item.nombre;
    _precioCtrl.text = _precioTexto(item.precio);
    _setVariantRows(item.variantes);
    _dirty = false;
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
    if (_busy) return;
    if (!_formKey.currentState!.validate()) {
      // The field with the problem may be scrolled out of sight.
      AppSnackBar.error(
        context,
        'Falta algo por llenar o corregir: revisa los campos marcados en rojo.',
      );
      return;
    }

    final codigoProveedor = _codigoProveedorCtrl.text.trim();
    if (codigoProveedor.isNotEmpty) {
      final other = widget.repo.getByProviderCode(codigoProveedor);
      if (other != null && other.id != widget.item.id) {
        AppSnackBar.error(
          context,
          'Ese código de proveedor ya lo tiene "${other.nombre}". Revisa el '
          'código o quítalo de esa prenda primero.',
        );
        return;
      }
    }

    var variantes = [
      for (final row in _variantes)
        if (row.isUsed) row.toVariant(),
    ];

    final duplicate = ClothingItem.firstDuplicateVariant(variantes);
    if (duplicate != null) {
      AppSnackBar.error(
        context,
        '${duplicate.color} / ${duplicate.talla} aparece dos veces. Deja una '
        'sola fila por cada color y talla, con todas sus piezas.',
      );
      return;
    }

    final id = widget.item.id;
    // The stock this save starts from, for the adjustment history.
    var before = const <ClothingVariant>[];
    if (!widget.isNew) {
      final latest = widget.repo.getById(id);
      if (latest == null) {
        AppSnackBar.error(
          context,
          'Esta prenda se eliminó en otro teléfono; no se guardaron los cambios.',
        );
        return;
      }
      before = latest.variantes;
      variantes = _rebaseStock(variantes, latest);
    }

    final updated = ClothingItem(
      id: id,
      nombre: _nombreCtrl.text.trim(),
      precio: _precio(),
      variantes: variantes,
      codigoProveedor: codigoProveedor,
    );

    setState(() => _saving = true);
    try {
      await widget.repo.save(updated);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnackBar.error(context, 'No se pudo guardar. Inténtalo de nuevo.');
      }
      return;
    }

    if (!widget.isNew) _logStockChanges(before, updated);
    if (!mounted) return;
    setState(() {
      _dirty = false;
      _saved = true;
    });
    await Future<void>.delayed(ProgressButton.doneHold);
    if (!mounted) return;
    Navigator.of(
      context,
    ).pop<ItemFormResult>((outcome: ItemFormOutcome.saved, item: updated));
  }

  /// Best-effort history of the stock changes made directly in this form
  /// (the quick-stock editor logs its own). A failure here must never block
  /// the save itself, already done.
  void _logStockChanges(List<ClothingVariant> before, ClothingItem updated) {
    final beforeByKey = {for (final v in before) v.key: v.existencia};
    final updatedKeys = updated.variantes.map((v) => v.key).toSet();
    void log(String color, String talla, int delta) {
      if (delta == 0) return;
      unawaited(
        widget.adjustmentsRepo.registrar(
          StockAdjustment(
            id: StockAdjustment.newId(),
            itemId: updated.id,
            nombreItem: updated.nombre,
            color: color,
            talla: talla,
            delta: delta,
            usuarioNombre: widget.user.nombre,
            fecha: DateTime.now(),
          ),
        ),
      );
    }

    for (final v in updated.variantes) {
      log(v.color, v.talla, v.existencia - (beforeByKey[v.key] ?? 0));
    }
    // A color/talla removed from the form takes its stock with it; without
    // this it would vanish from inventory with no trace in the history.
    for (final v in before) {
      if (!updatedKeys.contains(v.key)) log(v.color, v.talla, -v.existencia);
    }
  }

  Future<void> _scanProviderCode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const ScannerScreen(
          title: 'Código del proveedor',
          hint: 'Apunta al código de barras de la etiqueta del proveedor',
        ),
      ),
    );
    if (code == null || !mounted) return;
    _codigoProveedorCtrl.text = code;
    AppSnackBar.success(context, 'Código del proveedor leído: $code');
  }

  Future<void> _quickEditStock() async {
    if (_dirty) {
      final discard = await confirmAction(
        context,
        icon: Icons.edit_off_outlined,
        destructive: true,
        title: 'Descartar cambios de la ficha',
        message:
            '¿Seguro que quieres continuar? Para ajustar la existencia se usa '
            'lo último guardado: los cambios que hiciste aquí y aún no '
            'guardas se perderán.',
        confirmLabel: 'Descartar y ajustar',
      );
      if (!discard || !mounted) return;
    }
    // Read after the dialog: another phone may have saved meanwhile.
    final current = widget.repo.getById(widget.item.id);
    if (current == null) {
      AppSnackBar.error(context, 'Esta prenda ya no existe en el catálogo.');
      return;
    }
    if (_dirty) setState(() => _fillFrom(current));
    final outcome = await Navigator.of(context).push<StockSaveOutcome>(
      MaterialPageRoute(
        builder: (_) => QuickStockScreen(
          repo: widget.repo,
          adjustmentsRepo: widget.adjustmentsRepo,
          user: widget.user,
          item: current,
        ),
      ),
    );
    if (outcome == null || !mounted) return;
    AppSnackBar.success(context, 'Existencia actualizada');
    // Reflect the updated counts in this screen's fields too.
    final refreshed = widget.repo.getById(widget.item.id);
    if (refreshed != null) {
      setState(() => _setVariantRows(refreshed.variantes));
    }
  }

  Future<void> _delete() async {
    if (_busy) return;
    final nombre = _nombreCtrl.text.trim().isEmpty
        ? 'esta prenda'
        : '«${_nombreCtrl.text.trim()}»';
    final stored = widget.repo.getById(widget.item.id) ?? widget.item;
    final combinaciones = stored.variantes.length;
    final confirm = await confirmAction(
      context,
      icon: Icons.delete_outline_rounded,
      destructive: true,
      title: 'Eliminar prenda',
      message:
          '¿Seguro que quieres eliminar $nombre? '
          '${combinaciones == 0 ? '' : 'Esta acción eliminará también sus ${combinaciones == 1 ? 'tallas y colores' : '$combinaciones combinaciones de talla y color'} (${formatoPiezas(stored.existenciaTotal)}). '}'
          'Desaparecerá de todos los teléfonos de la tienda; podrás '
          'deshacerlo durante unos segundos.',
      confirmLabel: 'Eliminar',
    );
    if (!confirm || !mounted) return;
    setState(() => _deleting = true);
    // What "undo" will bring back: the stored version, which may be newer
    // than the one this form opened with.
    final deleted = widget.repo.getById(widget.item.id) ?? widget.item;
    try {
      await widget.repo.delete(widget.item.id);
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        AppSnackBar.error(context, 'No se pudo eliminar. Inténtalo de nuevo.');
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
      busy: _busy,
      busyMessage: 'Espera a que termine de guardar.',
      message:
          'Los cambios que hiciste en esta prenda todavía no se han guardado.',
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isNew ? 'Nueva prenda' : 'Editar prenda'),
          actions: [
            if (isExisting)
              IconButton(
                icon: const Icon(Icons.qr_code_2_rounded),
                tooltip: 'Ver código QR',
                onPressed: _busy ? null : _showQr,
              ),
            if (isExisting)
              PopupMenuButton<_FormAction>(
                enabled: !_busy,
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
                        onPressed: _busy ? null : _showQr,
                      )
                    : Chip(
                        avatar: const Icon(Icons.qr_code_rounded, size: 18),
                        label: const Text('El código QR se genera al guardar'),
                      ),
              ),
              const SizedBox(height: 20),
              ItemPhotoPicker(repo: widget.repo, itemId: widget.item.id),
              const SizedBox(height: 20),
              const _SectionTitle('Información'),
              const SizedBox(height: 4),
              Text(
                'Los campos con * son obligatorios.',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
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
                  labelText: 'Nombre de la prenda *',
                  hintText: 'Ej. Playera básica',
                  prefixIcon: Icon(Icons.checkroom_rounded),
                ),
                validator: _validateNombre,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _precioCtrl,
                decoration: const InputDecoration(
                  labelText: 'Precio *',
                  hintText: '0.00',
                  helperText: 'Precio de venta de cada pieza.',
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
              const SizedBox(height: 14),
              TextFormField(
                controller: _codigoProveedorCtrl,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Código del proveedor',
                  helperText:
                      'Opcional. Si la etiqueta del proveedor trae código de '
                      'barras, tócalo a la derecha para leerlo: así, '
                      'escanearlo también abrirá esta prenda.',
                  helperMaxLines: 3,
                  prefixIcon: const Icon(Icons.barcode_reader),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    tooltip: 'Escanear código del proveedor',
                    onPressed: _busy ? null : _scanProviderCode,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              _SectionTitle(
                'Tallas y colores',
                trailing: usadas == 0
                    ? null
                    : (usadas == 1 ? '1 combinación' : '$usadas combinaciones'),
              ),
              const SizedBox(height: 4),
              Text(
                'Una fila por cada color y talla que tengas, con cuántas '
                'piezas hay. Ej.: Negro · M · 4 piezas.',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
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
              // After the rows, where the next one will appear.
              OutlinedButton.icon(
                onPressed: _variantes.length < Limites.variantes
                    ? _addVariantRow
                    : null,
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  _variantes.length < Limites.variantes
                      ? 'Agregar otro color o talla'
                      : 'Llegaste al máximo de ${Limites.variantes} filas',
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: ProgressButton(
            state: _saved
                ? ProgressState.done
                : _saving
                ? ProgressState.busy
                : ProgressState.idle,
            icon: Icons.check_rounded,
            // An existing garment with nothing changed has nothing to save:
            // the disabled button itself says so.
            onPressed: _busy || (isExisting && !_dirty) ? null : _save,
            label: widget.isNew
                ? 'Guardar prenda'
                : _dirty
                ? 'Guardar cambios'
                : 'Sin cambios por guardar',
            doneLabel: widget.isNew ? 'Prenda guardada' : 'Cambios guardados',
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
