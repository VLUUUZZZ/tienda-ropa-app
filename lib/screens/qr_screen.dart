import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/clothing_item.dart';

/// Shows the item's QR big enough to screenshot/print and stick on the garment.
/// The QR only encodes the plain item id — no encryption, nothing sensitive.
class QrScreen extends StatelessWidget {
  final ClothingItem item;

  const QrScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Código QR de la prenda')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.nombre.isEmpty ? '(sin nombre)' : item.nombre,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: item.id,
                      version: QrVersions.auto,
                      size: 240,
                      gapless: true,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SelectableText(
                    item.id,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Imprime y pega este código en la prenda.\nAl escanearlo se abrirá su ficha.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
