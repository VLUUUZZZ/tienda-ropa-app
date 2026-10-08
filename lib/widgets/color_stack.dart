import 'package:flutter/material.dart';

import 'color_dot.dart';

/// A garment's colors as a row of overlapping swatches ("+2" past [max]),
/// read out as the list of names for screen readers.
class ColorStack extends StatelessWidget {
  const ColorStack({super.key, required this.colores, this.max = 5});

  final List<String> colores;
  final int max;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shown = colores.take(max).toList();
    const size = 20.0;
    const step = 14.0;

    return Semantics(
      label: 'Colores: ${colores.join(', ')}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size + step * (shown.length - 1),
            height: size,
            child: Stack(
              children: [
                for (final (i, color) in shown.indexed)
                  Positioned(
                    left: i * step,
                    child: Container(
                      // A ring in the card's color separates the swatches.
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).cardTheme.color ??
                            colorScheme.surface,
                        shape: BoxShape.circle,
                      ),
                      child: ColorDot(nombre: color, size: size - 4),
                    ),
                  ),
              ],
            ),
          ),
          if (colores.length > max) ...[
            const SizedBox(width: 6),
            Text(
              '+${colores.length - max}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
