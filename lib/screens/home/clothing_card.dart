import 'package:flutter/material.dart';

import '../../models/clothing_item.dart';

/// A garment in the catalog list: name, price, colors and stock at a glance,
/// with a shortcut to adjust stock.
class ClothingCard extends StatelessWidget {
  final ClothingItem item;
  final VoidCallback onTap;
  final VoidCallback onQuickEdit;
  final VoidCallback onSell;

  const ClothingCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onQuickEdit,
    required this.onSell,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sinStock = item.existenciaTotal == 0;
    final colores = item.coloresDisponibles;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  Icons.checkroom_rounded,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nombre.isEmpty ? '(sin nombre)' : item.nombre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${item.precio.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                    if (colores.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        colores.join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Chip(
                      avatar: Icon(
                        sinStock
                            ? Icons.error_outline
                            : Icons.inventory_2_outlined,
                        size: 16,
                        color: sinStock ? colorScheme.error : null,
                      ),
                      label: Text(
                        sinStock ? 'AGOTADO' : '${item.existenciaTotal} piezas',
                      ),
                      backgroundColor: sinStock
                          ? colorScheme.errorContainer.withValues(alpha: 0.6)
                          : null,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.point_of_sale_rounded),
                tooltip: 'Registrar venta',
                onPressed: sinStock ? null : onSell,
              ),
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Editar existencia rápido',
                onPressed: onQuickEdit,
              ),
              Icon(Icons.chevron_right_rounded, color: colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
