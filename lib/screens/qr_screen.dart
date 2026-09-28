import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/clothing_item.dart';
import '../widgets/snackbars.dart';

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
        showErrorSnackBar(
          context,
          'No se pudo compartir la imagen. Inténtalo de nuevo.',
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
        // Scrolls so the sticker never gets cut off on small or landscape
        // screens.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                key: _repaintKey,
                child: _QrSticker(item: widget.item),
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

/// The printable part: always black on white, whatever the app's theme, so
/// every sticker looks the same and scans well once printed.
class _QrSticker extends StatelessWidget {
  const _QrSticker({required this.item});

  final ClothingItem item;

  static const Color _ink = Color(0xFF1C1B1F);
  static const Color _mutedInk = Color(0xFF605D62);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.nombre.isEmpty ? '(sin nombre)' : item.nombre,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          QrImageView(
            data: item.id,
            version: QrVersions.auto,
            size: 240,
            gapless: true,
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 18),
          SelectableText(
            item.id,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: _mutedInk,
            ),
          ),
        ],
      ),
    );
  }
}
