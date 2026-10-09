// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'package:flutter/material.dart';

import '../../models/clothing_item.dart';

/// Which garments the catalog list shows, by stock level.
enum CatalogFilter {
  todas('Todas', ''),
  poca('Poca existencia', 'No hay prendas con poca existencia.'),
  agotadas('Agotadas', 'No hay prendas agotadas.');

  const CatalogFilter(this.label, this.emptyMessage);

  final String label;
  final String emptyMessage;

  bool includes(ClothingItem item) => switch (this) {
    CatalogFilter.todas => true,
    // Low overall, or one color/talla about to run out (worth restocking).
    CatalogFilter.poca =>
      item.existenciaTotal > 0 &&
          (item.nivelExistencia == StockLevel.poca || item.tieneStockBajo),
    CatalogFilter.agotadas => item.nivelExistencia == StockLevel.agotado,
  };
}

/// Todas / Poca existencia / Agotadas as pills, each with how many garments
/// it holds.
class CatalogFilterBar extends StatelessWidget {
  const CatalogFilterBar({
    super.key,
    required this.selected,
    required this.all,
    required this.onSelected,
  });

  final CatalogFilter selected;
  final List<ClothingItem> all;
  final ValueChanged<CatalogFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (final filtro in CatalogFilter.values) ...[
            Builder(
              builder: (context) {
                final isSelected = filtro == selected;
                final count = all.where(filtro.includes).length;
                final fg = isSelected
                    ? colorScheme.onInverseSurface
                    : colorScheme.onSurfaceVariant;
                return FilterChip(
                  selected: isSelected,
                  onSelected: (_) => onSelected(filtro),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(filtro.label, style: TextStyle(color: fg)),
                      const SizedBox(width: 6),
                      Container(
                        constraints: const BoxConstraints(minWidth: 22),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: fg.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '$count',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: fg,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
