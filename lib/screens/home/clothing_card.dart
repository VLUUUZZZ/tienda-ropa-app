import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/clothing_item.dart';

/// A garment in the catalog list: name, price, colors and stock at a glance,
/// with a shortcut to adjust stock.
class ClothingCard extends StatelessWidget {
  final ClothingItem item;
  final VoidCallback onTap;
  final VoidCallback onQuickEdit;
  final VoidCallback onSell;

  /// This phone's local photo file for [item], if it has one (see
  /// `ClothingRepository.photoPathFor` — never synced between devices).
  final String? photoPath;

  const ClothingCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onQuickEdit,
    required this.onSell,
    this.photoPath,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sinStock = item.existenciaTotal == 0;
    final stockBajo = !sinStock && item.tieneStockBajo;
    final colores = item.coloresDisponibles;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _ItemAvatar(photoPath: photoPath),
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
                            : stockBajo
                            ? Icons.warning_amber_rounded
                            : Icons.inventory_2_outlined,
                        size: 16,
                        color: sinStock
                            ? colorScheme.error
                            : stockBajo
                            ? colorScheme.onTertiaryContainer
                            : null,
                      ),
                      label: Text(
                        sinStock
                            ? 'AGOTADO'
                            : stockBajo
                            ? '${item.existenciaTotal} piezas · pocas'
                            : '${item.existenciaTotal} piezas',
                      ),
                      labelStyle: sinStock
                          ? TextStyle(color: colorScheme.onErrorContainer)
                          : stockBajo
                          ? TextStyle(color: colorScheme.onTertiaryContainer)
                          : null,
                      backgroundColor: sinStock
                          ? colorScheme.errorContainer.withValues(alpha: 0.6)
                          : stockBajo
                          ? colorScheme.tertiaryContainer.withValues(alpha: 0.6)
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

/// The garment's circular thumbnail, falling back to the generic clothing
/// icon both when there's no photo and when the stored file fails to load
/// (missing, corrupted, moved to a new phone without it).
class _ItemAvatar extends StatefulWidget {
  const _ItemAvatar({required this.photoPath});

  final String? photoPath;

  @override
  State<_ItemAvatar> createState() => _ItemAvatarState();
}

class _ItemAvatarState extends State<_ItemAvatar> {
  bool _failed = false;

  @override
  void didUpdateWidget(_ItemAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.photoPath != oldWidget.photoPath) _failed = false;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final path = widget.photoPath;
    final showPhoto = path != null && !_failed;

    return CircleAvatar(
      radius: 26,
      backgroundColor: colorScheme.primaryContainer,
      backgroundImage: showPhoto ? FileImage(File(path)) : null,
      onBackgroundImageError: showPhoto
          ? (exception, stackTrace) {
              if (mounted) setState(() => _failed = true);
            }
          : null,
      child: showPhoto
          ? null
          : Icon(
              Icons.checkroom_rounded,
              color: colorScheme.onPrimaryContainer,
            ),
    );
  }
}
