import 'package:flutter/material.dart';

import '../../models/clothing_item.dart';
import '../../utils/formato.dart';
import '../../widgets/color_stack.dart';
import '../../widgets/item_avatar.dart';
import '../../widgets/stock_badge.dart';

enum ScanAction { sell, stock, details, scanAgain }

/// What to do with a garment just scanned. Shows which garment it is (so a
/// wrong label is noticed before acting on it) and offers what's usually
/// done at the counter first: selling it, then adjusting its stock.
class ScannedItemSheet extends StatelessWidget {
  const ScannedItemSheet({
    super.key,
    required this.item,
    this.photoPath,
    required this.canEdit,
  });

  final ClothingItem item;
  final String? photoPath;

  /// Whether the full form (name, price, colors, deleting) is offered.
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final hayExistencia = item.existenciaTotal > 0;
    final sinVariantes = item.variantes.isEmpty;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Prenda encontrada',
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                ItemAvatar(nombre: item.nombre, size: 64, photoPath: photoPath),
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
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Flexible(
                  child: StockBadge(
                    existencia: item.existenciaTotal,
                    algunaTallaBaja: item.tieneStockBajo,
                  ),
                ),
                if (item.coloresDisponibles.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  ColorStack(colores: item.coloresDisponibles),
                ],
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: hayExistencia
                  ? () => Navigator.pop(context, ScanAction.sell)
                  : null,
              icon: const Icon(Icons.point_of_sale_rounded),
              label: Text(
                hayExistencia ? 'Vender' : 'Agotada: no se puede vender',
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: sinVariantes
                  ? null
                  : () => Navigator.pop(context, ScanAction.stock),
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Ajustar existencia'),
            ),
            if (canEdit) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, ScanAction.details),
                icon: const Icon(Icons.edit_outlined),
                label: Text(
                  sinVariantes ? 'Agregar tallas y colores' : 'Editar ficha',
                ),
              ),
            ],
            if (sinVariantes && !canEdit) ...[
              const SizedBox(height: 10),
              Text(
                'Esta prenda aún no tiene tallas ni colores. Pide a un '
                'administrador que los agregue.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () => Navigator.pop(context, ScanAction.scanAgain),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('No es esta prenda: escanear otra'),
            ),
          ],
        ),
      ),
    );
  }
}
