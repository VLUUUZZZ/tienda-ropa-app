import 'package:flutter/material.dart';

/// Floating error message for an action that couldn't be completed.
void showErrorSnackBar(BuildContext context, String message) {
  final colorScheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.onError, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: colorScheme.onError)),
          ),
        ],
      ),
      backgroundColor: colorScheme.error,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
