// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'package:flutter/material.dart';

import '../auth/app_user.dart';
import '../auth/user_directory.dart';
import '../data/adjustments_repository.dart';
import '../data/clothing_repository.dart';
import '../data/license_admin.dart';
import '../data/sales_repository.dart';
import '../models/clothing_item.dart';
import 'dashboard/dashboard_screen.dart';
import 'home_screen.dart';
import 'sales/sales_screen.dart';

/// El armazón de la app con la barra inferior. Debajo conviven tres
/// pantallas (Inicio, Catálogo y Ventas) sin perder su estado al cambiar de
/// pestaña, y "Escanear" dispara el lector de la cámara desde donde estés.
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.repo,
    required this.salesRepo,
    required this.adjustmentsRepo,
    required this.user,
    required this.isDarkMode,
    required this.onToggleTheme,
    this.onSignOut,
    this.users,
    this.licenseAdmin,
  });

  final ClothingRepository repo;
  final SalesRepository salesRepo;
  final AdjustmentsRepository adjustmentsRepo;
  final AppUser user;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final VoidCallback? onSignOut;
  final UserDirectory? users;
  final LicenseAdminService? licenseAdmin;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const _inicio = 0;
  static const _catalogo = 1;
  static const _ventas = 2;
  static const _escanear = 3;

  int _index = _inicio;

  /// Cada incremento le pide al catálogo que abra la cámara. Un notificador
  /// en vez de un bool para que dos escaneos seguidos se distingan.
  final ValueNotifier<int> _scanTrigger = ValueNotifier(0);

  /// La prenda que el Inicio pide abrir en el catálogo (desde "Necesitan
  /// atención"). Se limpia al consumirla en el catálogo.
  final ValueNotifier<ClothingItem?> _abrirPrenda = ValueNotifier(null);

  @override
  void dispose() {
    _scanTrigger.dispose();
    _abrirPrenda.dispose();
    super.dispose();
  }

  void _irA(int index) {
    if (_index != index) setState(() => _index = index);
  }

  void _onDestino(int index) {
    // "Escanear" no es una pantalla: abre la cámara y deja la pestaña actual
    // resaltada en vez de moverse a ningún lado.
    if (index == _escanear) {
      _scanTrigger.value++;
      return;
    }
    _irA(index);
  }

  void _abrirEnCatalogo(ClothingItem item) {
    _abrirPrenda.value = item;
    _irA(_catalogo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(
            repo: widget.repo,
            salesRepo: widget.salesRepo,
            adjustmentsRepo: widget.adjustmentsRepo,
            user: widget.user,
            isDarkMode: widget.isDarkMode,
            onToggleTheme: widget.onToggleTheme,
            onVerVentas: () => _irA(_ventas),
            onAbrirPrenda: _abrirEnCatalogo,
            users: widget.users,
            licenseAdmin: widget.licenseAdmin,
            onSignOut: widget.onSignOut,
          ),
          HomeScreen(
            repo: widget.repo,
            salesRepo: widget.salesRepo,
            adjustmentsRepo: widget.adjustmentsRepo,
            user: widget.user,
            isDarkMode: widget.isDarkMode,
            onToggleTheme: widget.onToggleTheme,
            onSignOut: widget.onSignOut,
            users: widget.users,
            licenseAdmin: widget.licenseAdmin,
            scanTrigger: _scanTrigger,
            abrirPrenda: _abrirPrenda,
          ),
          SalesScreen(
            salesRepo: widget.salesRepo,
            repo: widget.repo,
            showInventoryValue: widget.user.canEditCatalog,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onDestino,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.checkroom_outlined),
            selectedIcon: Icon(Icons.checkroom_rounded),
            label: 'Catálogo',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Ventas',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_rounded),
            label: 'Escanear',
          ),
        ],
      ),
    );
  }
}
