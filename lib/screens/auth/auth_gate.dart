// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../auth/auth_service.dart';
import '../../backend.dart';
import '../../data/adjustments_repository.dart';
import '../../data/clothing_repository.dart';
import '../../data/sales_repository.dart';
import '../../widgets/auth_layout.dart';
import 'license_screen.dart';
import 'login_screen.dart';

typedef SignedInBuilder =
    Widget Function(
      BuildContext context,
      AppUser user,
      ClothingRepository repo,
      SalesRepository salesRepo,
      AdjustmentsRepository adjustmentsRepo,
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
  late StreamSubscription<AuthState> _subscription;
  AuthState _state = const AuthLoading();

  /// The open catalog, sales log and adjustment history, and whose store
  /// they belong to.
  ClothingRepository? _repo;
  SalesRepository? _salesRepo;
  AdjustmentsRepository? _adjustmentsRepo;
  String? _repoTiendaId;

  /// Set when the store's catalog couldn't be opened on this device.
  bool _openFailed = false;

  @override
  void initState() {
    super.initState();
    _subscription = widget.backend.auth.watch().listen(_onAuthState);
  }

  /// Starts a fresh session listener, which re-reads the profile and the
  /// store's license right away (e.g. after the user renews their license).
  Future<void> _resubscribe() async {
    await _subscription.cancel();
    if (!mounted) return;
    setState(() => _state = const AuthLoading());
    _subscription = widget.backend.auth.watch().listen(_onAuthState);
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    unawaited(_repo?.close());
    unawaited(_salesRepo?.close());
    unawaited(_adjustmentsRepo?.close());
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
      case SignedOut() || AccessDenied() || LicenseInactive():
        await _closeStore();
      case AuthLoading():
        break;
    }
  }

  /// Bumped by every open and close, so an open that finishes after a newer
  /// one started (sign out and back in while storage was still opening)
  /// knows it's stale and closes what it opened instead of keeping it.
  int _generation = 0;

  Future<void> _openStore(Tienda tienda) async {
    if (_repoTiendaId == tienda.id && !_openFailed) return;
    await _closeStore();
    final generation = ++_generation;
    _repoTiendaId = tienda.id;
    ClothingRepository? repo;
    SalesRepository? salesRepo;
    AdjustmentsRepository? adjustmentsRepo;
    try {
      repo = await ClothingRepository.open(tiendaId: tienda.id);
      salesRepo = await SalesRepository.open(tiendaId: tienda.id);
      adjustmentsRepo = await AdjustmentsRepository.open(tiendaId: tienda.id);
      if (generation != _generation || !mounted) {
        await repo.close();
        await salesRepo.close();
        await adjustmentsRepo.close();
        return;
      }
      await repo.attachRemote(widget.backend.catalogFor(tienda));
      await salesRepo.attachRemote(widget.backend.salesFor(tienda));
      await adjustmentsRepo.attachRemote(widget.backend.adjustmentsFor(tienda));
    } catch (e) {
      debugPrint('No se pudo abrir el catálogo de ${tienda.id}: $e');
      await repo?.close();
      await salesRepo?.close();
      await adjustmentsRepo?.close();
      if (mounted && generation == _generation) {
        setState(() => _openFailed = true);
      }
      return;
    }
    if (generation != _generation || !mounted) {
      await repo.close();
      await salesRepo.close();
      await adjustmentsRepo.close();
      return;
    }
    setState(() {
      _repo = repo;
      _salesRepo = salesRepo;
      _adjustmentsRepo = adjustmentsRepo;
      _openFailed = false;
    });
  }

  Future<void> _closeStore() async {
    _generation++;
    final repo = _repo;
    final salesRepo = _salesRepo;
    final adjustmentsRepo = _adjustmentsRepo;
    _repo = null;
    _salesRepo = null;
    _adjustmentsRepo = null;
    _repoTiendaId = null;
    _openFailed = false;
    if (repo == null) return;
    if (mounted) {
      setState(() {});
      // Let the store's screens go away before their storage is closed.
      await WidgetsBinding.instance.endOfFrame;
    }
    await repo.close();
    await salesRepo?.close();
    await adjustmentsRepo?.close();
  }

  /// Screens opened by one user, or under one role, must not stay on top
  /// for another: they were built with what that user could do (an admin's
  /// edit form left open after being made employee would let them edit
  /// until the server refuses).
  static bool _changesWhoIsIn(AuthState previous, AuthState next) {
    if (previous is! SignedIn || next is AuthLoading) return false;
    if (next is! SignedIn) return true;
    final before = previous.user;
    final after = next.user;
    return before.uid != after.uid ||
        before.role != after.role ||
        before.tienda?.id != after.tienda?.id ||
        before.activo != after.activo;
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
      LicenseInactive(:final tiendaNombre, :final license) => LicenseScreen(
        tiendaNombre: tiendaNombre,
        license: license,
        // The session listener is live; renewing on the server flips the
        // state on its own. "Retry" just reassures the user — re-reading is
        // automatic, so this only needs to not error.
        onRetry: _resubscribe,
        onSignOut: auth.signOut,
      ),
      SignedIn(:final user) when _openFailed => _OpenFailedScreen(
        onRetry: () => _openStore(user.tienda!),
        onSignOut: auth.signOut,
      ),
      SignedIn() when repo == null => _LoadingScreen(onSignOut: auth.signOut),
      SignedIn(:final user) => KeyedSubtree(
        key: ValueKey(user.uid),
        child: widget.signedInBuilder(
          context,
          user,
          repo!,
          _salesRepo!,
          _adjustmentsRepo!,
        ),
      ),
    };
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  'Abriendo tu tienda…',
                  style: textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'La primera vez en este teléfono necesita internet para '
                  'descargar el catálogo.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                // Escape hatch if the profile can't load (e.g. offline with
                // an empty cache).
                Text(
                  '¿Tarda demasiado?',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                TextButton(
                  onPressed: onSignOut,
                  child: const Text('Salir y entrar con otra cuenta'),
                ),
              ],
            ),
          ),
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
            'Revisa que tenga espacio libre y toca "Reintentar". Tus datos '
            'siguen guardados en la tienda.',
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
