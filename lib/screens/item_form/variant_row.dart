import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/clothing_item.dart';
import '../../widgets/color_dot.dart';
import '../../widgets/stock_badge.dart';

/// The editable state of one color+talla row in the garment form: its text
/// controllers, their validation, and the [ClothingVariant] they produce.
class VariantRowControllers {
  VariantRowControllers({
    String talla = '',
    String color = '',
    int existencia = 0,
  }) : talla = TextEditingController(text: talla),
       color = TextEditingController(text: color),
       existencia = TextEditingController(text: existencia.toString()),
       _tallaMax = math.max(Limites.talla, talla.length),
       _colorMax = math.max(Limites.color, color.length);

  VariantRowControllers.fromVariant(ClothingVariant v)
    : this(talla: v.talla, color: v.color, existencia: v.existencia);

  final TextEditingController talla;
  final TextEditingController color;
  final TextEditingController existencia;

  /// Length limits for this row. A value saved before the limits existed
  /// may be longer; it stays valid (and is never cut) as long as it doesn't
  /// grow.
  final int _tallaMax;
  final int _colorMax;

  /// A row with neither talla nor color is ignored on save, so a spare blank
  /// row never blocks the form.
  bool get isUsed =>
      talla.text.trim().isNotEmpty || color.text.trim().isNotEmpty;

  /// An empty count means 0.
  int get existenciaValue => ClothingVariant.clampExistencia(
    int.tryParse(existencia.text.trim()) ?? 0,
  );

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

  String? validateTalla(String? _) => _validateText(talla.text, _tallaMax);

  String? validateColor(String? _) => _validateText(color.text, _colorMax);

  String? _validateText(String text, int max) {
    if (!isUsed) return null;
    if (text.trim().isEmpty) return 'Requerido';
    return text.trim().length > max ? 'Máx. $max' : null;
  }

  /// Only rows in use are checked: a spare blank row never blocks saving.
  String? validateExistencia(String? _) {
    if (!isUsed) return null;
    final text = existencia.text.trim();
    if (text.isEmpty) return null; // treated as 0
    final parsed = int.tryParse(text);
    if (parsed == null) return 'Inválido';
    if (parsed < 0) return 'No negativo';
    if (parsed > Limites.existenciaMax) return 'Máx. ${Limites.existenciaMax}';
    return null;
  }

  void dispose() {
    talla.dispose();
    color.dispose();
    existencia.dispose();
  }
}

/// The fields for one variant row, with a live swatch of the color typed
/// and an "Agotado" hint when a used row has no stock.
int _tallaMax(VariantRowControllers row) => row._tallaMax;
int _colorMax(VariantRowControllers row) => row._colorMax;

class VariantRowFields extends StatelessWidget {
  const VariantRowFields({super.key, required this.row, this.onRemove});

  final VariantRowControllers row;

  /// Null disables removing (the form always keeps at least one row).
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: row.talla,
                      maxLength: _tallaMax(row),
                      maxLengthEnforcement: MaxLengthEnforcement.none,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Talla',
                        isDense: true,
                        counterText: '',
                      ),
                      validator: row.validateTalla,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    // Rebuilt as the color is typed, to show its swatch.
                    child: ListenableBuilder(
                      listenable: row.color,
                      builder: (context, _) {
                        final color = row.color.text.trim();
                        return TextFormField(
                          controller: row.color,
                          maxLength: _colorMax(row),
                          maxLengthEnforcement: MaxLengthEnforcement.none,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Color',
                            isDense: true,
                            counterText: '',
                            prefixIcon: color.isEmpty
                                ? null
                                : Padding(
                                    padding: const EdgeInsets.only(
                                      left: 12,
                                      right: 8,
                                    ),
                                    child: ColorDot(nombre: color, size: 16),
                                  ),
                            prefixIconConstraints: const BoxConstraints(),
                          ),
                          validator: row.validateColor,
                        );
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Quitar esta talla/color',
                    onPressed: onRemove,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    width: 132,
                    child: TextFormField(
                      controller: row.existencia,
                      decoration: const InputDecoration(
                        labelText: 'Piezas',
                        isDense: true,
                        prefixIcon: Icon(Icons.inventory_2_outlined, size: 20),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(5),
                      ],
                      validator: row.validateExistencia,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ListenableBuilder(
                    listenable: Listenable.merge([
                      row.talla,
                      row.color,
                      row.existencia,
                    ]),
                    builder: (context, _) => row.agotado
                        ? const StockBadge(existencia: 0)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
