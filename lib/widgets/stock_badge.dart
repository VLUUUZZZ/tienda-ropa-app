import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/clothing_item.dart';
import '../utils/formato.dart';

/// Pill with a garment's stock: icon, word and color together, so the level
/// never depends on color alone.
class StockBadge extends StatelessWidget {
  const StockBadge({
    super.key,
    required this.existencia,
    this.algunaTallaBaja = false,
  });

  final int existencia;

  /// Plenty overall, but some color/talla is about to run out: shown as a
  /// warning too, so it gets restocked in time.
  final bool algunaTallaBaja;

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
      StockLevel.normal when algunaTallaBaja => (
        Icons.warning_amber_rounded,
        '$existencia · tallas bajas',
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 4),
          // Shrinks with ellipsis when the card is narrow (long counts or
          // the low-talla warning) instead of overflowing.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
