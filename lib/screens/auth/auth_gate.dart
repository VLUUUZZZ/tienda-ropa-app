import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../auth/auth_service.dart';
import '../../backend.dart';
import '../../data/clothing_repository.dart';
import '../../widgets/auth_layout.dart';
import 'login_screen.dart';

typedef SignedInBuilder =
    Widget Function(
      BuildContext context,
      AppUser user,
      ClothingRepository repo,
    );

/// Shows a store only to a signed-in user with an active profile. While they
/// are in, it keeps their store's catalog open and synced; on sign-out it
/// closes it.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.backend,
    required this.signedInBuilder,
  });

  final Backend backend;
  final SignedInBuilder signedInBuilder;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _subscription;
  AuthState _state = const AuthLoading();

  /// The open catalog, and whose store it belongs to.
  ClothingRepository? _repo;
  String? _repoTiendaId;

  /// Set when the store's catalog couldn't be opened on this device.
  bool _openFailed = false;

  @override
  void initState() {
    super.initState();
    _subscription = widget.backend.auth.watch().listen(_onAuthState);
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    unawaited(_repo?.close());
    super.dispose();
  }

  Future<void> _onAuthState(AuthState next) async {
    if (!mounted) return;
    if (_changesWhoIsIn(_state, next)) {
      // Screens opened by the previous user must not stay on top.
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    setState(() => _state = next);

    switch (next) {
      case SignedIn(:final user):
        await _openStore(user.tienda!);
      case SignedOut() || AccessDenied():
        await _closeStore();
      case AuthLoading():
        break;
    }
  }

  Future<void> _openStore(Tienda tienda) async {
    if (_repoTiendaId == tienda.id && !_openFailed) return;
    await _closeStore();
    _repoTiendaId = tienda.id;
    final ClothingRepository repo;
    try {
      repo = await ClothingRepository.open(tiendaId: tienda.id);
    } catch (e) {
      debugPrint('No se pudo abrir el catálogo de ${tienda.id}: $e');
      if (mounted) setState(() => _openFailed = true);
      return;
    }
    if (!mounted || _repoTiendaId != tienda.id) {
      await repo.close();
      return;
    }
    await repo.attachRemote(widget.backend.catalogFor(tienda));
    setState(() {
      _repo = repo;
      _openFailed = false;
    });
  }

  Future<void> _closeStore() async {
    final repo = _repo;
    _repo = null;
    _repoTiendaId = null;
    _openFailed = false;
    if (repo == null) return;
    if (mounted) {
      setState(() {});
      // Let the store's screens go away before their storage is closed.
      await WidgetsBinding.instance.endOfFrame;
    }
    await repo.close();
  }

  static bool _changesWhoIsIn(AuthState previous, AuthState next) {
    final before = previous is SignedIn ? previous.user.uid : null;
    final after = next is SignedIn ? next.user.uid : null;
    return before != null && before != after && next is! AuthLoading;
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.backend.auth;
    final repo = _repo;
    return switch (_state) {
      AuthLoading() => _LoadingScreen(onSignOut: auth.signOut),
      SignedOut() => LoginScreen(auth: auth),
      AccessDenied(:final correo) => _AccessDeniedScreen(
        correo: correo,
        onSignOut: auth.signOut,
      ),
      SignedIn(:final user) when _openFailed => _OpenFailedScreen(
        onRetry: () => _openStore(user.tienda!),
        onSignOut: auth.signOut,
      ),
      SignedIn() when repo == null => _LoadingScreen(onSignOut: auth.signOut),
      SignedIn(:final user) => KeyedSubtree(
        key: ValueKey(user.uid),
        child: widget.signedInBuilder(context, user, repo!),
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

class _OpenFailedScreen extends StatelessWidget {
  const _OpenFailedScreen({required this.onRetry, required this.onSignOut});

  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'No se pudo abrir la tienda',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Hubo un problema al cargar el catálogo en este teléfono. '
            'Revisa que tenga espacio libre e inténtalo de nuevo.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          TextButton(onPressed: onSignOut, child: const Text('Cerrar sesión')),
        ],
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
