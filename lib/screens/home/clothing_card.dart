import 'package:flutter/material.dart';

import '../../models/clothing_item.dart';
import '../../utils/formato.dart';
import '../../widgets/color_dot.dart';
import '../../widgets/stock_badge.dart';

/// One garment in the catalog list.
class ClothingCard extends StatelessWidget {
  final ClothingItem item;
  final VoidCallback onTap;
  final VoidCallback onQuickEdit;

  const ClothingCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onQuickEdit,
  });

  /// Up to two letters from the name, e.g. "Playera Básica" → "PB".
  static String _initials(String nombre) {
    final words = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty);
    return words.take(2).map((w) => w.characters.first.toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final colores = item.coloresDisponibles;
    const maxColores = 4;
    final initials = _initials(item.nombre);

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: initials.isEmpty
                    ? Icon(
                        Icons.checkroom_rounded,
                        color: colorScheme.onPrimaryContainer,
                      )
                    : Text(
                        initials,
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nombre.isEmpty ? '(sin nombre)' : item.nombre,
                      style: textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: formatoPrecio(item.precio),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.primary,
                            ),
                          ),
                          TextSpan(
                            text: '  ·  ${item.id}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (colores.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          for (final color in colores.take(maxColores))
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ColorDot(nombre: color),
                                const SizedBox(width: 4),
                                Text(
                                  color,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          if (colores.length > maxColores)
                            Text(
                              '+${colores.length - maxColores}',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    StockBadge(existencia: item.existenciaTotal),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Editar existencia rápido',
                onPressed: onQuickEdit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
