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
      appBar: AppBar(
        title: const Text('Escanear prenda'),
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
        ],
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
        errorBuilder: (context, error, child) =>
            _ScannerError(error: error, onRetry: () => _controller.start()),
      ),
    );
  }
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
