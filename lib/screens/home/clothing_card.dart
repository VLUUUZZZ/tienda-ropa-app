import 'package:flutter/material.dart';

import '../../models/clothing_item.dart';
import '../../utils/formato.dart';
import '../../widgets/color_stack.dart';
import '../../widgets/item_avatar.dart';
import '../../widgets/stock_badge.dart';

/// One garment in the catalog list: tap opens it, the side button adjusts
/// its stock directly.
class ClothingCard extends StatelessWidget {
  const ClothingCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onQuickEdit,
  });

  final ClothingItem item;
  final VoidCallback onTap;
  final VoidCallback onQuickEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final colores = item.coloresDisponibles;

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ItemAvatar(nombre: item.nombre),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.nombre.isEmpty ? '(sin nombre)' : item.nombre,
                            style: textTheme.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatoPrecio(item.precio),
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.id,
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Flexible(
                          child: StockBadge(existencia: item.existenciaTotal),
                        ),
                        if (colores.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          ColorStack(colores: colores),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton.filledTonal(
                icon: const Icon(Icons.tune_rounded, size: 20),
                tooltip: 'Ajustar existencia',
                onPressed: onQuickEdit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
