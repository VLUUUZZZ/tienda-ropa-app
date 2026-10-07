import 'package:flutter/material.dart';

/// Wraps a screen that edits something: while [hasChanges], leaving it (back
/// button or gesture) first asks whether to discard the changes.
class UnsavedChangesGuard extends StatelessWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.hasChanges,
    required this.message,
    required this.child,
    this.busy = false,
    this.busyMessage,
  });

  final bool hasChanges;

  /// Body of the confirmation dialog.
  final String message;
  final Widget child;

  /// True while the change itself is already being saved and can't be
  /// cancelled from here: leaving is blocked outright with [busyMessage]
  /// instead of offering "Descartar", which would be misleading — the save
  /// keeps running in the background regardless.
  final bool busy;
  final String? busyMessage;

  Future<void> _confirmLeave(BuildContext context) async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar cambios'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Seguir editando'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    // pop() leaves unconditionally; only back gestures consult canPop.
    if (discard == true && context.mounted) Navigator.of(context).pop();
  }

  void _blockWhileBusy(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(busyMessage ?? 'Espera a que termine de guardar.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !busy && !hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (busy) {
          _blockWhileBusy(context);
        } else {
          _confirmLeave(context);
        }
      },
      child: child,
    );
  }
}
