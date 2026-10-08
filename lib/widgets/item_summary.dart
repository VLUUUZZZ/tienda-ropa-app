import 'package:flutter/material.dart';

import '../models/clothing_item.dart';
import '../utils/formato.dart';
import 'item_avatar.dart';
import 'stock_badge.dart';

/// A garment in one row: avatar, name, code and price, and its stock.
class ItemSummary extends StatelessWidget {
  const ItemSummary({super.key, required this.item});

  final ClothingItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        ItemAvatar(nombre: item.nombre, size: 52),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.nombre.isEmpty ? '(sin nombre)' : item.nombre,
                style: textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${item.id} · ${formatoPrecio(item.precio)}',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              StockBadge(existencia: item.existenciaTotal),
            ],
          ),
        ),
      ],
    );
  }
}
