import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:share_plus/share_plus.dart';

import '../auth/app_user.dart';
import '../auth/user_directory.dart';
import '../data/catalog_export.dart';
import '../data/clothing_repository.dart';
import '../data/sales_repository.dart';
import '../models/clothing_item.dart';
import '../widgets/snackbars.dart';
import 'home/account_menu.dart';
import 'home/clothing_card.dart';
import 'home/store_title.dart';
import 'item_form_screen.dart';
import 'quick_stock_screen.dart';
import 'sales/register_sale_screen.dart';
import 'sales/sales_screen.dart';
import 'scanner_screen.dart';
import 'users/users_screen.dart';

/// The catalog. What it offers depends on [user]'s role: admins get the full
/// edit form, adding and deleting; employees only adjust stock.
class HomeScreen extends StatefulWidget {
  final ClothingRepository repo;
  final SalesRepository salesRepo;
  final AppUser user;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  /// Null when there's no session to end (local-only mode).
  final VoidCallback? onSignOut;

  /// Null when there are no accounts to manage (local-only mode).
  final UserDirectory? users;

  const HomeScreen({
    super.key,
    required this.repo,
    required this.salesRepo,
    required this.user,
    required this.isDarkMode,
    required this.onToggleTheme,
    this.onSignOut,
    this.users,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchCtrl = TextEditingController();
  late final Listenable _repoChanges = widget.repo.listenable;
  List<ClothingItem> _items = [];
  bool _reloadScheduled = false;

  @override
  void initState() {
    super.initState();
    _reload();
    _searchCtrl.addListener(() => _reload());
    // Picks up changes synced from other devices.
    _repoChanges.addListener(_onRepoChanged);
  }

  @override
  void dispose() {
    _repoChanges.removeListener(_onRepoChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Sync can change many garments at once, each one notifying separately:
  /// refresh the list once per frame instead of once per garment.
  void _onRepoChanged() {
    if (_reloadScheduled) return;
    _reloadScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _reloadScheduled = false;
      if (mounted) _reload();
    });
  }

  void _reload() {
    setState(() => _items = widget.repo.search(_searchCtrl.text));
  }

  void _showSavedSnackBar() {
    // Explicit colors instead of the default SnackBar look: the default
    // background flips between dark (light theme) and light (dark theme),
    // so a hardcoded white icon would turn invisible in dark mode.
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: colorScheme.onInverseSurface,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Cambios guardados',
              style: TextStyle(color: colorScheme.onInverseSurface),
            ),
          ],
        ),
        backgroundColor: colorScheme.inverseSurface,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showDeletedSnackBar(ClothingItem item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${item.nombre.isEmpty ? 'Prenda' : item.nombre} eliminada',
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () => _restore(item),
        ),
      ),
    );
  }

  Future<void> _restore(ClothingItem item) async {
    try {
      await widget.repo.save(item);
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'No se pudo restaurar la prenda.');
      }
      return;
    }
    if (mounted) _reload();
  }

  /// Admins get the full form; employees go straight to stock adjustment,
  /// the only change their role allows.
  Future<void> _openItem(ClothingItem item) async {
    if (!widget.user.canEditCatalog) return _quickEditStock(item);

    final result = await Navigator.of(context).push<ItemFormResult>(
      MaterialPageRoute(
        builder: (_) => ItemFormScreen(repo: widget.repo, item: item),
      ),
    );
    if (!mounted) return;
    _reload();
    if (result is ItemFormSaved) _showSavedSnackBar();
    if (result is ItemFormDeleted) _showDeletedSnackBar(result.item);
  }

  Future<void> _quickEditStock(ClothingItem item) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QuickStockScreen(repo: widget.repo, item: item),
      ),
    );
    if (!mounted) return;
    _reload();
    if (saved == true) _showSavedSnackBar();
  }

  Future<void> _registerSale(ClothingItem item) async {
    final registrada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RegisterSaleScreen(
          repo: widget.repo,
          salesRepo: widget.salesRepo,
          item: item,
        ),
      ),
    );
    if (!mounted) return;
    _reload();
    if (registrada == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Venta registrada'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openSales() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SalesScreen(salesRepo: widget.salesRepo),
      ),
    );
  }

  /// A CSV of the whole catalog, for a backup outside the app or to hand to
  /// someone (a spreadsheet, the accountant, a paper inventory).
  Future<void> _exportCatalog() async {
    final csv = catalogToCsv(widget.repo.getAll());
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              // BOM so Excel opens the accented names correctly.
              const Utf8Encoder().convert('﻿$csv'),
              mimeType: 'text/csv',
              name: 'catalogo.csv',
            ),
          ],
          fileNameOverrides: ['catalogo.csv'],
        ),
      );
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'No se pudo exportar el catálogo.');
      }
    }
  }

  bool _creatingNew = false;

  Future<void> _addManually() async {
    // A double-tap on the "+" button would otherwise open two "Nueva
    // prenda" forms stacked on top of each other.
    if (_creatingNew) return;
    _creatingNew = true;
    try {
      final String id;
      try {
        id = await widget.repo.generateId();
      } catch (e) {
        if (mounted) {
          showErrorSnackBar(
            context,
            'No se pudo crear la prenda. Inténtalo de nuevo.',
          );
        }
        return;
      }
      if (!mounted) return;
      final newItem = ClothingItem(
        id: id,
        nombre: '',
        precio: 0,
        variantes: const [],
      );
      final result = await Navigator.of(context).push<ItemFormResult>(
        MaterialPageRoute(
          builder: (_) =>
              ItemFormScreen(repo: widget.repo, item: newItem, isNew: true),
        ),
      );
      if (!mounted) return;
      _reload();
      if (result is ItemFormSaved) _showSavedSnackBar();
    } finally {
      _creatingNew = false;
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const ScannerScreen()));
    if (code == null || !mounted) return;

    final existing = widget.repo.getById(code);
    if (existing == null) {
      await _showUnrecognizedQrDialog();
      return;
    }
    await _openItem(existing);
  }

  void _openUsers(UserDirectory users) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UsersScreen(users: users, currentUser: widget.user),
      ),
    );
  }

  Future<void> _showUnrecognizedQrDialog() {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('QR no reconocido'),
        content: const Text(
          'Este código no corresponde a una prenda registrada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  bool get _canOpenUsers => widget.users != null && widget.user.canManageUsers;

  String get _emptyMessage {
    if (_searchCtrl.text.trim().isNotEmpty) {
      return 'No hay prendas que coincidan.';
    }
    return widget.user.canEditCatalog
        ? 'Aún no hay prendas registradas.\nAgrégala con el botón +.'
        : 'Aún no hay prendas registradas.';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: StoreTitle(user: widget.user),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_rounded),
            tooltip: 'Ventas',
            onPressed: _openSales,
          ),
          IconButton(
            icon: Icon(
              widget.isDarkMode
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            tooltip: widget.isDarkMode ? 'Tema claro' : 'Tema oscuro',
            onPressed: widget.onToggleTheme,
          ),
          AccountMenu(
            user: widget.user,
            onManageUsers: _canOpenUsers
                ? () => _openUsers(widget.users!)
                : null,
            onExport: _exportCatalog,
            onSignOut: widget.onSignOut,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar prenda por nombre...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        tooltip: 'Limpiar búsqueda',
                        onPressed: () => _searchCtrl.clear(),
                      ),
              ),
            ),
          ),
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.checkroom_rounded,
                          size: 56,
                          color: colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _emptyMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.outline),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => ClothingCard(
                      item: _items[index],
                      onTap: () => _openItem(_items[index]),
                      onQuickEdit: () => _quickEditStock(_items[index]),
                      onSell: () => _registerSale(_items[index]),
                      photoPath: widget.repo.photoPathFor(_items[index].id),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'scan',
            onPressed: _scan,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Escanear'),
          ),
          if (widget.user.canEditCatalog) ...[
            const SizedBox(width: 12),
            FloatingActionButton(
              heroTag: 'add',
              onPressed: _addManually,
              tooltip: 'Agregar prenda',
              child: const Icon(Icons.add_rounded),
            ),
          ],
        ],
      ),
    );
  }
}
