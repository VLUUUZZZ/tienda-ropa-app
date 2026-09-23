import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../auth/auth_service.dart';
import '../../backend.dart';
import '../../data/clothing_repository.dart';
import '../../widgets/auth_layout.dart';
import 'login_screen.dart';

/// Shows the store only to a signed-in user with an active profile, and
/// keeps catalog sync running exactly while that's the case.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.backend,
    required this.repo,
    required this.signedInBuilder,
  });

  final Backend backend;
  final ClothingRepository repo;
  final Widget Function(BuildContext context, AppUser user) signedInBuilder;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _subscription;
  AuthState _state = const AuthLoading();

  @override
  void initState() {
    super.initState();
    _subscription = widget.backend.auth.watch().listen(_onAuthState);
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    unawaited(widget.repo.detachRemote());
    super.dispose();
  }

  void _onAuthState(AuthState next) {
    if (!mounted) return;
    if (_changesWhoIsIn(_state, next)) {
      // Screens opened by the previous user must not stay on top.
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    setState(() => _state = next);

    if (next is SignedIn) {
      unawaited(widget.repo.attachRemote(widget.backend.catalog));
    } else if (next is! AuthLoading) {
      unawaited(widget.repo.detachRemote());
    }
  }

  static bool _changesWhoIsIn(AuthState previous, AuthState next) {
    final before = previous is SignedIn ? previous.user.uid : null;
    final after = next is SignedIn ? next.user.uid : null;
    return before != null && before != after && next is! AuthLoading;
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.backend.auth;
    return switch (_state) {
      AuthLoading() => _LoadingScreen(onSignOut: auth.signOut),
      SignedOut() => LoginScreen(auth: auth),
      AccessDenied(:final correo) => _AccessDeniedScreen(
        correo: correo,
        onSignOut: auth.signOut,
      ),
      SignedIn(:final user) => KeyedSubtree(
        key: ValueKey(user.uid),
        child: widget.signedInBuilder(context, user),
      ),
    };
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            // Escape hatch if the profile can't load (e.g. offline with an
            // empty cache).
            TextButton(
              onPressed: onSignOut,
              child: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen({required this.correo, required this.onSignOut});

  final String correo;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Sin acceso',
      subtitle: correo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Tu cuenta no tiene acceso a la tienda o fue desactivada. '
            'Pide a un administrador que la active.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onSignOut,
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}
