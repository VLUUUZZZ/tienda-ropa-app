// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Asks before an important action. True only if the person confirmed;
/// cancelling, tapping outside or going back all count as "no".
///
/// [destructive] actions (deleting, discarding, removing access) get a red
/// confirm button, and the safe choice is always on the left so it's the
/// one a hurried tap lands on.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancelar',
  IconData? icon,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final colorScheme = Theme.of(ctx).colorScheme;
      return AlertDialog(
        icon: icon == null
            ? null
            : Icon(
                icon,
                color: destructive ? colorScheme.error : colorScheme.primary,
              ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(64, 44),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              backgroundColor: destructive ? colorScheme.error : null,
              foregroundColor: destructive ? colorScheme.onError : null,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  if (result == true) {
    // Felt as "done": firmer for what removes or discards something.
    if (destructive) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }
  return result ?? false;
}

/// Tells the person something they need to read before going on, with a
/// single way to close it.
Future<void> showNotice(
  BuildContext context, {
  required String title,
  required String message,
  IconData? icon,
  String closeLabel = 'Entendido',
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: icon == null ? null : Icon(icon),
      title: Text(title),
      content: Text(message),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(64, 44),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          onPressed: () => Navigator.pop(ctx),
          child: Text(closeLabel),
        ),
      ],
    ),
  );
}
