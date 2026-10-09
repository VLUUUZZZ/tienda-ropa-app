// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

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

    // Each level has its own icon and wording, so it reads the same without
    // color (dark mode, color blindness); the spoken label says it in full.
    final (
      IconData icon,
      String label,
      String semantics,
      Color bg,
      Color fg,
    ) = switch (StockLevel.of(existencia)) {
      StockLevel.agotado => (
        Icons.remove_shopping_cart_outlined,
        'AGOTADO',
        'Agotado',
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
      ),
      StockLevel.poca => (
        Icons.warning_amber_rounded,
        '$existencia disponible${existencia == 1 ? '' : 's'}',
        'Existencia baja: ${formatoPiezas(existencia)}',
        stock.lowContainer,
        stock.onLowContainer,
      ),
      StockLevel.normal when algunaTallaBaja => (
        Icons.warning_amber_rounded,
        '$existencia · tallas bajas',
        '${formatoPiezas(existencia)}; algunas tallas están por agotarse',
        stock.lowContainer,
        stock.onLowContainer,
      ),
      StockLevel.normal => (
        Icons.check_circle_outline_rounded,
        '$existencia disponibles',
        '${formatoPiezas(existencia)} disponibles',
        colorScheme.secondaryContainer,
        colorScheme.onSecondaryContainer,
      ),
    };

    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: Container(
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
      ),
    );
  }
}
