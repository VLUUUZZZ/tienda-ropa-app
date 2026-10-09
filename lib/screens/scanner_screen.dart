// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Scans a QR code or barcode and pops with the raw text it contains (the
/// item's id, or a supplier's code). Does not look anything up itself — the
/// caller decides what to do with it. A label that won't read can be typed
/// in instead.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({
    super.key,
    this.title = 'Escanear prenda',
    this.hint = 'Apunta al código QR o de barras de la etiqueta',
  });

  final String title;

  /// What to aim at, shown under the frame.
  final String hint;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _controller = MobileScannerController();
  bool _handled = false;

  /// A code was just read: the frame shows a check for a moment.
  bool _found = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    // Some printers/readers add spaces or a line break around the id.
    final value = barcodes.first.rawValue?.trim();
    if (value == null || value.isEmpty) return;
    _handled = true;
    if (!mounted) return;
    // Felt even with the phone's sound off: the code was read, it can be
    // lowered now.
    HapticFeedback.mediumImpact();
    // Seen, not only felt: a brief check in the frame before moving on.
    setState(() => _found = true);
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    Navigator.of(context).pop(value);
  }

  /// For a label that's torn, wrinkled or too faded to read.
  Future<void> _typeCode() async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _TypeCodeDialog(),
    );
    if (code == null || code.isEmpty || !mounted || _handled) return;
    _handled = true;
    Navigator.of(context).pop(code);
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
        title: Text(widget.title),
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
                : IgnorePointer(
                    child: _ScanFrame(hint: widget.hint, found: _found),
                  ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: SafeArea(
              child: Center(
                child: FilledButton.tonalIcon(
                  onPressed: _typeCode,
                  icon: const Icon(Icons.keyboard_rounded),
                  label: const Text('¿No lee? Escribir el código'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Darkens everything but a rounded square in the middle, outlines its
/// corners, and says what to do.
class _ScanFrame extends StatelessWidget {
  const _ScanFrame({required this.hint, required this.found});

  final String hint;

  /// A code was read: the corners turn the app's color, a check appears and
  /// the hint says so.
  final bool found;

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
        final accent = Theme.of(context).colorScheme.primary;
        return Stack(
          children: [
            Positioned.fill(
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: found ? accent : Colors.white),
                duration: const Duration(milliseconds: 160),
                builder: (context, color, _) => CustomPaint(
                  painter: _ScanFramePainter(window, color ?? Colors.white),
                ),
              ),
            ),
            if (found)
              Positioned.fromRect(
                rect: window,
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.3, end: 1),
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 44,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
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
                    found ? '¡Código leído!' : hint,
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
  _ScanFramePainter(this.window, this.color);

  final Rect window;
  final Color color;

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
      ..color = color
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
  bool shouldRepaint(_ScanFramePainter old) =>
      old.window != window || old.color != color;
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

/// Asks for the code printed under the QR (e.g. PRENDA-000012) or the
/// supplier's barcode number.
class _TypeCodeDialog extends StatefulWidget {
  const _TypeCodeDialog();

  @override
  State<_TypeCodeDialog> createState() => _TypeCodeDialogState();
}

class _TypeCodeDialogState extends State<_TypeCodeDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _ctrl.text.trim();
    if (code.isEmpty) return;
    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.keyboard_rounded),
      title: const Text('Escribe el código'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(
          labelText: 'Código',
          hintText: 'Ej. PRENDA-000012',
          helperText:
              'Está impreso debajo del QR, o son los números del código de '
              'barras.',
          helperMaxLines: 2,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ListenableBuilder(
          listenable: _ctrl,
          builder: (context, _) => FilledButton(
            onPressed: _ctrl.text.trim().isEmpty ? null : _submit,
            child: const Text('Buscar'),
          ),
        ),
      ],
    );
  }
}
