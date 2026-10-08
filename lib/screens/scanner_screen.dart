import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Scans a QR code and pops with the raw text it contains (the item's id).
/// Does not look anything up itself — the caller decides what to do with it.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _controller = MobileScannerController();
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    // Some printers/readers add spaces or a line break around the id.
    final value = barcodes.first.rawValue?.trim();
    if (value == null || value.isEmpty) return;
    _handled = true;
    if (!mounted) return;
    Navigator.of(context).pop(value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Escanear prenda'),
        titleTextStyle: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(color: Colors.white),
        actions: [
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, state, child) {
              final encendida = state.torchState == TorchState.on;
              return IconButton(
                icon: Icon(
                  encendida ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                ),
                tooltip: encendida ? 'Apagar linterna' : 'Encender linterna',
                onPressed: state.torchState == TorchState.unavailable
                    ? null
                    : _controller.toggleTorch,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) =>
                _ScannerError(error: error, onRetry: () => _controller.start()),
          ),
          // The frame only guides aiming: detection still uses the whole
          // picture, which reads codes more reliably on more phones.
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, state, _) => state.error != null
                ? const SizedBox.shrink()
                : const IgnorePointer(child: _ScanFrame()),
          ),
        ],
      ),
    );
  }
}

/// Darkens everything but a rounded square in the middle, outlines its
/// corners, and says what to do.
class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = (constraints.biggest.shortestSide * 0.7).clamp(
          180.0,
          320.0,
        );
        final window = Rect.fromCenter(
          center: constraints.biggest.center(Offset.zero),
          width: side,
          height: side,
        );
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _ScanFramePainter(window)),
            ),
            Positioned(
              left: 24,
              right: 24,
              top: window.bottom + 28,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'Apunta al código QR de la etiqueta',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  _ScanFramePainter(this.window);

  final Rect window;

  static const double _radius = 28;
  static const double _corner = 36;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(
      window,
      const Radius.circular(_radius),
    );
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(hole),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final r = window;
    // One rounded corner bracket per corner of the window.
    for (final (corner, dx, dy) in [
      (r.topLeft, 1.0, 1.0),
      (r.topRight, -1.0, 1.0),
      (r.bottomLeft, 1.0, -1.0),
      (r.bottomRight, -1.0, -1.0),
    ]) {
      final path = Path()
        ..moveTo(corner.dx, corner.dy + dy * _corner)
        ..lineTo(corner.dx, corner.dy + dy * _radius)
        ..arcToPoint(
          Offset(corner.dx + dx * _radius, corner.dy),
          radius: const Radius.circular(_radius),
          clockwise: dx * dy > 0,
        )
        ..lineTo(corner.dx + dx * _corner, corner.dy);
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(_ScanFramePainter old) => old.window != window;
}

class _ScannerError extends StatelessWidget {
  final MobileScannerException error;
  final VoidCallback onRetry;

  const _ScannerError({required this.error, required this.onRetry});

  String get _message {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return 'Se necesita permiso de cámara para escanear.\n'
            'Actívalo desde los ajustes del sistema para esta app.';
      case MobileScannerErrorCode.unsupported:
        return 'Este dispositivo no tiene una cámara compatible con el escáner.';
      default:
        return 'No se pudo iniciar la cámara.\n'
            'Verifica que ninguna otra app la esté usando e inténtalo de nuevo.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off_rounded,
                color: Colors.white,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              if (error.errorCode != MobileScannerErrorCode.unsupported) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
