import 'package:flutter/material.dart';

import '../../models/clothing_item.dart';
import '../../utils/formato.dart';
import '../../widgets/color_stack.dart';
import '../../widgets/item_avatar.dart';
import '../../widgets/stock_badge.dart';

/// One garment in the catalog list: what it is, its price and stock at a
/// glance, and its two everyday actions as labeled buttons (selling and
/// adjusting stock). Tapping the rest of the card opens it.
class ClothingCard extends StatelessWidget {
  const ClothingCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onQuickEdit,
    required this.onSell,
    this.photoPath,
  });

  final ClothingItem item;
  final VoidCallback onTap;
  final VoidCallback onQuickEdit;
  final VoidCallback onSell;

  /// This phone's local photo of the garment, if any.
  final String? photoPath;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final colores = item.coloresDisponibles;

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ItemAvatar(nombre: item.nombre, photoPath: photoPath),
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
                                item.nombre.isEmpty
                                    ? '(sin nombre)'
                                    : item.nombre,
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
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
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
                              child: StockBadge(
                                existencia: item.existenciaTotal,
                                algunaTallaBaja: item.tieneStockBajo,
                              ),
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
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: item.existenciaTotal > 0 ? onSell : null,
                      icon: const Icon(Icons.point_of_sale_rounded, size: 20),
                      label: const Text('Vender'),
                      style: _compact,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onQuickEdit,
                      icon: const Icon(Icons.tune_rounded, size: 20),
                      label: const Text('Existencia'),
                      style: _compact,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Big enough to hit comfortably (48), smaller than a screen's main
  /// button: these repeat on every card.
  static final ButtonStyle _compact = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
  );
}
