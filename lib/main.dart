import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app_theme.dart';
import 'auth/app_user.dart';
import 'auth/user_directory.dart';
import 'backend.dart';
import 'data/clothing_repository.dart';
import 'data/settings_repository.dart';
import 'firebase_backend.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installErrorHandlers();
  await _start();
}

/// Opens storage and the backend, then shows the app. If any of that fails
/// (damaged storage, bad Firebase config) the person gets a message and a
/// retry button instead of a blank screen.
Future<void> _start() async {
  try {
    await Hive.initFlutter();

    final settings = await SettingsRepository.open();

    // Local config only, so this never waits on the network.
    final backend = await connectFirebase();

    // Without a backend there's no login: a single local catalog. With one,
    // each store's catalog is opened by the auth gate on sign-in.
    final localRepo = backend == null ? await ClothingRepository.open() : null;

    runApp(
      TiendaRopaApp(settings: settings, backend: backend, localRepo: localRepo),
    );
  } catch (e, stack) {
    debugPrint('No se pudo iniciar la app: $e\n$stack');
    runApp(_StartupErrorApp(onRetry: _start));
  }
}

/// Errors nobody caught are logged instead of killing the app, and a widget
/// that fails to build shows a short message rather than a grey box.
void _installErrorHandlers() {
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Error no controlado: $error\n$stack');
    return true;
  };
  if (kReleaseMode) {
    ErrorWidget.builder = (details) => const Material(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No se pudo mostrar esta parte.\nVuelve atrás e inténtalo de nuevo.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _StartupErrorApp extends StatefulWidget {
  const _StartupErrorApp({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  State<_StartupErrorApp> createState() => _StartupErrorAppState();
}

class _StartupErrorAppState extends State<_StartupErrorApp> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    await widget.onRetry();
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'No se pudo iniciar la app.\nRevisa que el teléfono tenga '
                    'espacio libre e inténtalo de nuevo.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _retrying ? null : _retry,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TiendaRopaApp extends StatefulWidget {
  final SettingsRepository settings;

  /// Null runs the app local-only, without login, on [localRepo].
  final Backend? backend;
  final ClothingRepository? localRepo;

  const TiendaRopaApp({
    super.key,
    required this.settings,
    this.backend,
    this.localRepo,
  }) : assert(
         (backend == null) != (localRepo == null),
         'Either a backend or a local catalog',
       );

  @override
  State<TiendaRopaApp> createState() => _TiendaRopaAppState();
}

class _TiendaRopaAppState extends State<TiendaRopaApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.settings.isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  void _toggleTheme() {
    final next = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    setState(() => _themeMode = next);
    widget.settings.setDarkMode(next == ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tienda de Ropa',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      home: switch (widget.backend) {
        null => _buildHome(AppUser.local, widget.localRepo!),
        final backend => AuthGate(
          backend: backend,
          signedInBuilder: (_, user, repo) => _buildHome(
            user,
            repo,
            onSignOut: backend.auth.signOut,
            users: backend.users,
          ),
        ),
      },
    );
  }

  Widget _buildHome(
    AppUser user,
    ClothingRepository repo, {
    VoidCallback? onSignOut,
    UserDirectory? users,
  }) {
    return HomeScreen(
      repo: repo,
      user: user,
      isDarkMode: _themeMode == ThemeMode.dark,
      onToggleTheme: _toggleTheme,
      onSignOut: onSignOut,
      users: users,
    );
  }
}
