import 'package:flutter/material.dart';

import 'feedback/confirm_dialog.dart';

/// Wraps a screen that edits something: while [hasChanges], leaving it (back
/// button or gesture) first asks whether to discard the changes.
class UnsavedChangesGuard extends StatelessWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.hasChanges,
    required this.message,
    required this.child,
  });

  final bool hasChanges;

  /// Body of the confirmation dialog.
  final String message;
  final Widget child;

  Future<void> _confirmLeave(BuildContext context) async {
    final discard = await confirmAction(
      context,
      icon: Icons.edit_off_outlined,
      destructive: true,
      title: '¿Descartar cambios?',
      message: message,
      confirmLabel: 'Descartar',
      cancelLabel: 'Seguir editando',
    );
    // pop() leaves unconditionally; only back gestures consult canPop.
    if (discard && context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave(context);
      },
      child: child,
    );
  }
}
