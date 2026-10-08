import 'package:flutter/material.dart';

import '../../models/clothing_item.dart';
import '../../utils/formato.dart';
import '../../widgets/color_stack.dart';
import '../../widgets/item_avatar.dart';
import '../../widgets/stock_badge.dart';

enum ScanAction { stock, details }

/// What to do with a garment just scanned: at the counter it's usually a
/// stock change, so that comes first.
class ScannedItemSheet extends StatelessWidget {
  const ScannedItemSheet({super.key, required this.item});

  final ClothingItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ItemAvatar(nombre: item.nombre, size: 64),
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
                StockBadge(existencia: item.existenciaTotal),
                if (item.coloresDisponibles.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  ColorStack(colores: item.coloresDisponibles),
                ],
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: item.variantes.isEmpty
                  ? null
                  : () => Navigator.pop(context, ScanAction.stock),
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Ajustar existencia'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, ScanAction.details),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Ver ficha completa'),
            ),
          ],
        ),
      ),
    );
  }
}
