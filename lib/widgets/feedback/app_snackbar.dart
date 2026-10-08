import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_messenger.dart';

/// The kinds of quick message the app shows, each with its own icon and
/// color so they read at a glance, and never by color alone.
enum _Kind { success, error, info }

/// Quick, non-blocking messages at the bottom of the screen: one look and
/// one API for every "saved", "couldn't save" or "undo" in the app.
///
/// A new message replaces the one on screen instead of queuing behind it,
/// so feedback always matches the last thing the person did; except an
/// "undo", which is never cut short: whatever comes next waits its turn.
abstract final class AppSnackBar {
  /// The undo message on screen, if any.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _undo;

  /// Something the person did worked ("Cambios guardados").
  static void success(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) => _show(
    context,
    _Kind.success,
    message,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  /// Something didn't work; says what, and ideally what to do next.
  static void error(BuildContext context, String message) =>
      _show(context, _Kind.error, message);

  /// Neutral information ("Te enviamos un correo…").
  static void info(BuildContext context, String message) =>
      _show(context, _Kind.info, message);

  /// An action that can still be reverted for a few seconds.
  static void undo(
    BuildContext context,
    String message, {
    required VoidCallback onUndo,
  }) => _show(
    context,
    _Kind.info,
    message,
    actionLabel: 'Deshacer',
    onAction: onUndo,
    icon: Icons.delete_outline_rounded,
    duration: const Duration(seconds: 5),
    isUndo: true,
  );

  static void _show(
    BuildContext context,
    _Kind kind,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    IconData? icon,
    Duration? duration,
    bool isUndo = false,
  }) {
    // Falls back to the app-wide host when this screen has none (or is
    // already closing), so the message is never lost.
    final messenger =
        ScaffoldMessenger.maybeOf(context) ?? appMessengerKey.currentState;
    if (messenger == null) return;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final (
      Color bg,
      Color fg,
      Color accent,
      IconData defaultIcon,
    ) = switch (kind) {
      _Kind.success => (
        colorScheme.inverseSurface,
        colorScheme.onInverseSurface,
        isDark ? const Color(0xFF2E7D4F) : const Color(0xFF7BD6A0),
        Icons.check_circle_rounded,
      ),
      _Kind.error => (
        colorScheme.error,
        colorScheme.onError,
        colorScheme.onError,
        Icons.error_outline_rounded,
      ),
      _Kind.info => (
        colorScheme.inverseSurface,
        colorScheme.onInverseSurface,
        colorScheme.inversePrimary,
        Icons.info_outline_rounded,
      ),
    };

    switch (kind) {
      case _Kind.success:
        HapticFeedback.lightImpact();
      case _Kind.error:
        HapticFeedback.mediumImpact();
      case _Kind.info:
        break;
    }

    if (_undo == null) messenger.hideCurrentSnackBar();
    final controller = messenger.showSnackBar(
      SnackBar(
        backgroundColor: bg,
        duration:
            duration ??
            (kind == _Kind.error
                ? const Duration(seconds: 5)
                : const Duration(seconds: 3)),
        content: Row(
          children: [
            Icon(icon ?? defaultIcon, color: accent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.snackBarTheme.contentTextStyle?.copyWith(
                  color: fg,
                ),
              ),
            ),
          ],
        ),
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                textColor: kind == _Kind.error ? fg : accent,
                onPressed: onAction,
              ),
      ),
    );
    if (isUndo) {
      _undo = controller;
      controller.closed.then((_) {
        if (_undo == controller) _undo = null;
      });
    }
  }
}
