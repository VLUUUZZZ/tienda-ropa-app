import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import 'app_messenger.dart';
import 'feedback/app_snackbar.dart';

/// Busy/error state for forms that submit to the backend: disables the
/// button while working and shows [AuthException] messages inline (and a
/// generic one for anything unexpected).
mixin AsyncSubmit<T extends StatefulWidget> on State<T> {
  bool busy = false;
  String? error;

  /// Runs [action]; returns true if it succeeded. Ignored while a previous
  /// submit is still running (a second Enter on the keyboard, for example),
  /// so the same account or store is never created twice.
  Future<bool> submit(Future<void> Function() action) async {
    if (busy) return false;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      return true;
    } on AuthException catch (e) {
      _showError(e.message);
      return false;
    } catch (e) {
      // Anything unexpected (network, plugin) still ends as a message, not
      // as an uncaught error with the form silently doing nothing.
      debugPrint('Error inesperado al enviar el formulario: $e');
      _showError('Algo salió mal. Revisa tu conexión e inténtalo de nuevo.');
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// Inline under the form; or, if the screen was closed meanwhile (e.g. the
  /// session changed while signing up), as a snackbar, so it's never lost.
  void _showError(String message) {
    if (mounted) {
      setState(() => error = message);
    } else {
      final hostContext = appNavigatorKey.currentContext;
      if (hostContext != null) AppSnackBar.error(hostContext, message);
    }
  }
}
