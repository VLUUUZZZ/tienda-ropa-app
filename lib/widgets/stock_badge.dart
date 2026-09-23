import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/clothing_item.dart';
import '../utils/formato.dart';

/// Pill with a garment's stock: icon, word and color together, so the level
/// never depends on color alone.
class StockBadge extends StatelessWidget {
  const StockBadge({super.key, required this.existencia});

  final int existencia;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final stock = StockColors.of(context);

    final (
      IconData icon,
      String label,
      Color bg,
      Color fg,
    ) = switch (StockLevel.of(existencia)) {
      StockLevel.agotado => (
        Icons.remove_shopping_cart_outlined,
        'Agotado',
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
      ),
      StockLevel.poca => (
        Icons.warning_amber_rounded,
        'Quedan ${formatoPiezas(existencia)}',
        stock.lowContainer,
        stock.onLowContainer,
      ),
      StockLevel.normal => (
        Icons.inventory_2_outlined,
        formatoPiezas(existencia),
        colorScheme.secondaryContainer,
        colorScheme.onSecondaryContainer,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
