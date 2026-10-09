// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'package:flutter/material.dart';

import 'feedback/app_snackbar.dart';
import 'feedback/confirm_dialog.dart';

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
    final discard = await confirmAction(
      context,
      icon: Icons.edit_off_outlined,
      destructive: true,
      title: 'Descartar cambios',
      message: '¿Seguro que quieres salir? $message',
      confirmLabel: 'Descartar',
      cancelLabel: 'Seguir editando',
    );
    // pop() leaves unconditionally; only back gestures consult canPop.
    if (discard && context.mounted) Navigator.of(context).pop();
  }

  void _blockWhileBusy(BuildContext context) {
    AppSnackBar.info(
      context,
      busyMessage ?? 'Espera a que termine de guardar.',
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
