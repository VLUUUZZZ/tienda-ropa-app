import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/clothing_item.dart';

/// Shows the item's QR big enough to screenshot/print and stick on the garment.
/// The QR only encodes the plain item id — no encryption, nothing sensitive.
class QrScreen extends StatefulWidget {
  final ClothingItem item;

  const QrScreen({super.key, required this.item});

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  final _repaintKey = GlobalKey();
  bool _sharing = false;

  Future<void> _shareAsImage() async {
    setState(() => _sharing = true);
    try {
      final boundary =
          _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'image/png', name: '${widget.item.id}.png')],
          fileNameOverrides: ['${widget.item.id}.png'],
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Código QR de la prenda')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                key: _repaintKey,
                child: Container(
                  color: Colors.white,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.item.nombre.isEmpty ? '(sin nombre)' : widget.item.nombre,
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
                              data: widget.item.id,
                              version: QrVersions.auto,
                              size: 240,
                              gapless: true,
                            ),
                          ),
                          const SizedBox(height: 18),
                          SelectableText(
                            widget.item.id,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.outline,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Imprime y pega este código en la prenda.\nAl escanearlo se abrirá su ficha.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _sharing ? null : _shareAsImage,
                icon: _sharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.share_rounded),
                label: const Text('Guardar / compartir imagen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
