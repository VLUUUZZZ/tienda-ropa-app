import 'package:flutter/material.dart';

import '../../models/clothing_item.dart';

/// The editable state of one color+talla row in the garment form: its text
/// controllers, their validation, and the [ClothingVariant] they produce.
class VariantRowControllers {
  VariantRowControllers({
    String talla = '',
    String color = '',
    int existencia = 0,
  }) : talla = TextEditingController(text: talla),
       color = TextEditingController(text: color),
       existencia = TextEditingController(text: existencia.toString());

  VariantRowControllers.fromVariant(ClothingVariant v)
    : this(talla: v.talla, color: v.color, existencia: v.existencia);

  final TextEditingController talla;
  final TextEditingController color;
  final TextEditingController existencia;

  /// A row with neither talla nor color is ignored on save, so a spare blank
  /// row never blocks the form.
  bool get isUsed =>
      talla.text.trim().isNotEmpty || color.text.trim().isNotEmpty;

  /// An empty count means 0.
  int get existenciaValue => int.tryParse(existencia.text.trim()) ?? 0;

  bool get agotado => isUsed && existenciaValue <= 0;

  ClothingVariant toVariant() => ClothingVariant(
    talla: talla.text.trim(),
    color: color.text.trim(),
    existencia: existenciaValue,
  );

  void addListener(VoidCallback listener) {
    talla.addListener(listener);
    color.addListener(listener);
    existencia.addListener(listener);
  }

  String? validateTalla(String? _) =>
      isUsed && talla.text.trim().isEmpty ? 'Requerido' : null;

  String? validateColor(String? _) =>
      isUsed && color.text.trim().isEmpty ? 'Requerido' : null;

  static String? validateExistencia(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = int.tryParse(text);
    if (parsed == null) return 'Inválido';
    if (parsed < 0) return 'No negativo';
    return null;
  }

  void dispose() {
    talla.dispose();
    color.dispose();
    existencia.dispose();
  }
}

/// The fields for one variant row, with an "AGOTADO" hint when a used row
/// has no stock.
class VariantRowFields extends StatelessWidget {
  const VariantRowFields({super.key, required this.row, this.onRemove});

  final VariantRowControllers row;

  /// Null disables removing (the form always keeps at least one row).
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
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
                    decoration: const InputDecoration(
                      labelText: 'Talla',
                      isDense: true,
                    ),
                    validator: row.validateTalla,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: row.color,
                    decoration: const InputDecoration(
                      labelText: 'Color',
                      isDense: true,
                    ),
                    validator: row.validateColor,
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
                    validator: VariantRowControllers.validateExistencia,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'Quitar fila',
                  onPressed: onRemove,
                ),
              ],
            ),
            ListenableBuilder(
              listenable: Listenable.merge([
                row.talla,
                row.color,
                row.existencia,
              ]),
              builder: (context, _) =>
                  row.agotado ? const _AgotadoLabel() : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgotadoLabel extends StatelessWidget {
  const _AgotadoLabel();

  @override
  Widget build(BuildContext context) {
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
  }
}
