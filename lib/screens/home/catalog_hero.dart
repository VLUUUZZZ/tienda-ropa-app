import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../models/clothing_item.dart';
import '../../utils/formato.dart';

/// The catalog at a glance, as the first thing on the home screen: what the
/// stock is worth (for roles that manage the catalog; pieces on hand for
/// everyone else) and how many garments, pieces and sold-out ones there are.
class CatalogHero extends StatelessWidget {
  const CatalogHero({super.key, required this.items, required this.showValue});

  final List<ClothingItem> items;
  final bool showValue;

  static const Color _fg = Colors.white;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final piezas = items.fold(0, (sum, i) => sum + i.existenciaTotal);
    final agotadas = items
        .where((i) => i.nivelExistencia == StockLevel.agotado)
        .length;
    final valor = items.fold(0.0, (sum, i) => sum + i.valorInventario);

    // Light: the brand terracotta. Dark: a deeper shade of it, so the card
    // doesn't glare against the dark background. White text on both.
    final base = isDark
        ? Color.lerp(brandColor, Colors.black, 0.3)!
        : colorScheme.primary;
    final deep = Color.lerp(base, const Color(0xFF2A1208), isDark ? 0.5 : 0.3)!;

    final (label, value) = showValue
        ? ('Valor del inventario', formatoPrecio(valor))
        : ('Piezas en tienda', '$piezas');

    return Semantics(
      container: true,
      label:
          '$label: $value. ${items.length} prendas, $piezas piezas, '
          '$agotadas agotadas.',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.xl),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [base, deep],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: textTheme.titleSmall?.copyWith(
                      color: _fg.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                Icon(
                  showValue
                      ? Icons.account_balance_wallet_outlined
                      : Icons.inventory_2_outlined,
                  color: _fg.withValues(alpha: 0.85),
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: textTheme.displaySmall?.copyWith(
                  color: _fg,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _fg.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    _HeroStat(value: '${items.length}', label: 'Prendas'),
                    const _StatDivider(),
                    _HeroStat(value: '$piezas', label: 'Piezas'),
                    const _StatDivider(),
                    _HeroStat(value: '$agotadas', label: 'Agotadas'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) => VerticalDivider(
    width: 1,
    thickness: 1,
    indent: 4,
    endIndent: 4,
    color: CatalogHero._fg.withValues(alpha: 0.2),
  );
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: textTheme.titleLarge?.copyWith(
                color: CatalogHero._fg,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: CatalogHero._fg.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
