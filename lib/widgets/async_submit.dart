import 'package:flutter/widgets.dart';

import '../auth/auth_service.dart';

/// Busy/error state for forms that submit to the backend: disables the
/// button while working and shows [AuthException] messages inline.
mixin AsyncSubmit<T extends StatefulWidget> on State<T> {
  bool busy = false;
  String? error;

  /// Runs [action]; returns true if it succeeded.
  Future<bool> submit(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      return true;
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
      return false;
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Ocurrió un error inesperado. Inténtalo de nuevo.',
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
