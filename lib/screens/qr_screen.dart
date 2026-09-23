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
          _repaintKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'image/png',
              name: '${widget.item.id}.png',
            ),
          ],
          fileNameOverrides: ['${widget.item.id}.png'],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo compartir la imagen. Intenta de nuevo.'),
          ),
        );
      }
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
        // Scrolls so the label and button still fit in landscape or with
        // large system fonts.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.15),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: RepaintBoundary(
                    key: _repaintKey,
                    child: _PrintableLabel(item: widget.item),
                  ),
                ),
              ),
              const SizedBox(height: 20),
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

/// What gets captured as the shared image: always black on white, whatever
/// the app's theme, so it prints cleanly and scans reliably.
class _PrintableLabel extends StatelessWidget {
  const _PrintableLabel({required this.item});

  final ClothingItem item;

  static const Color _ink = Color(0xFF1B1B1D);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Text(
              item.nombre.isEmpty ? '(sin nombre)' : item.nombre,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          QrImageView(
            data: item.id,
            version: QrVersions.auto,
            size: 240,
            gapless: true,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: _ink,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: _ink,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            item.id,
            style: const TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
