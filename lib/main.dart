import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

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
  await Hive.initFlutter();

  final settings = SettingsRepository();
  await settings.init();

  // Local config only, so this never waits on the network.
  final backend = await connectFirebase();

  // Without a backend there's no login: a single local catalog. With one,
  // each store's catalog is opened by the auth gate on sign-in.
  final localRepo = backend == null ? await ClothingRepository.open() : null;

  runApp(
    TiendaRopaApp(settings: settings, backend: backend, localRepo: localRepo),
  );
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

/// Shared visual language for the whole app: a warm boutique palette,
/// rounded surfaces and soft elevation instead of plain Material defaults.
ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFB5754A),
    brightness: brightness,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: isDark
        ? const Color(0xFF161314)
        : const Color(0xFFFBF4EF),
    fontFamily: 'Roboto',
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(
        alpha: isDark ? 0.6 : 0.7,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
      elevation: 2,
      extendedTextStyle: const TextStyle(fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}
