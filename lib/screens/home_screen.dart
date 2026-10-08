import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:share_plus/share_plus.dart';

import '../auth/app_user.dart';
import '../auth/user_directory.dart';
import '../data/clothing_repository.dart';
import '../data/adjustments_repository.dart';
import '../data/catalog_export.dart';
import '../data/sales_repository.dart';
import 'adjustments/adjustments_screen.dart';
import 'sales/register_sale_screen.dart';
import 'sales/sales_screen.dart';
import '../models/clothing_item.dart';
import '../widgets/feedback/app_snackbar.dart';
import '../widgets/feedback/confirm_dialog.dart';
import '../widgets/feedback/success_screen.dart';
import '../widgets/item_summary.dart';
import 'home/account_menu.dart';
import 'home/catalog_filters.dart';
import 'home/catalog_hero.dart';
import 'home/clothing_card.dart';
import 'home/empty_catalog.dart';
import 'home/scanned_item_sheet.dart';
import 'home/store_title.dart';
import 'item_form_screen.dart';
import 'qr_screen.dart';
import 'quick_stock_screen.dart';
import 'scanner_screen.dart';
import 'users/users_screen.dart';

/// The catalog. What it offers depends on [user]'s role: admins get the full
/// edit form, adding and deleting; employees only adjust stock.
class HomeScreen extends StatefulWidget {
  final ClothingRepository repo;
  final AppUser user;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  /// Null when there's no session to end (local-only mode).
  final VoidCallback? onSignOut;

  /// Null when there are no accounts to manage (local-only mode).
  final UserDirectory? users;

  final SalesRepository salesRepo;
  final AdjustmentsRepository adjustmentsRepo;

  const HomeScreen({
    super.key,
    required this.repo,
    required this.user,
    required this.isDarkMode,
    required this.onToggleTheme,
    this.onSignOut,
    this.users,
    required this.salesRepo,
    required this.adjustmentsRepo,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchCtrl = TextEditingController();
  late final Listenable _repoChanges = widget.repo.listenable;

  /// The whole catalog, for the summary and the filter counts.
  List<ClothingItem> _all = [];

  /// What the list shows: [_all] narrowed by the search box and [_filtro].
  List<ClothingItem> _items = [];
  CatalogFilter _filtro = CatalogFilter.todas;

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

  bool _reloadScheduled = false;

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
    setState(() {
      _all = widget.repo.getAll();
      _items = widget.repo
          .search(_searchCtrl.text, _all)
          .where(_filtro.includes)
          .toList();
    });
  }

  /// True while a screen opened from here is up, so a double tap on a card
  /// or button doesn't open it twice.
  bool _navigating = false;

  Future<void> _once(Future<void> Function() action) async {
    if (_navigating) return;
    _navigating = true;
    try {
      await action();
    } finally {
      _navigating = false;
    }
  }

  void _setFiltro(CatalogFilter filtro) {
    _filtro = filtro;
    _reload();
  }

  void _showSavedSnackBar() =>
      AppSnackBar.success(context, 'Cambios guardados');

  void _showDeletedSnackBar(ClothingItem item) => AppSnackBar.undo(
    context,
    '${item.nombre.isEmpty ? 'Prenda' : item.nombre} eliminada',
    onUndo: () => _restore(item),
  );

  Future<void> _restore(ClothingItem item) async {
    try {
      await widget.repo.save(item);
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'No se pudo restaurar la prenda.');
      }
      return;
    }
    if (!mounted) return;
    _reload();
    AppSnackBar.success(
      context,
      '${item.nombre.isEmpty ? 'Prenda' : item.nombre} restaurada',
    );
  }

  /// Admins get the full form; employees go straight to stock adjustment,
  /// the only change their role allows.
  Future<void> _openItem(ClothingItem item) async {
    if (!widget.user.canEditCatalog) return _quickEditStock(item);

    final result = await Navigator.of(context).push<ItemFormResult>(
      MaterialPageRoute(
        builder: (_) => ItemFormScreen(
          repo: widget.repo,
          adjustmentsRepo: widget.adjustmentsRepo,
          user: widget.user,
          item: item,
        ),
      ),
    );
    if (!mounted) return;
    _reload();
    switch (result) {
      case (outcome: ItemFormOutcome.saved, item: _):
        _showSavedSnackBar();
      case (outcome: ItemFormOutcome.deleted, :final item):
        _showDeletedSnackBar(item);
      case null:
        break;
    }
  }

  Future<void> _quickEditStock(ClothingItem item) async {
    final outcome = await Navigator.of(context).push<StockSaveOutcome>(
      MaterialPageRoute(
        builder: (_) => QuickStockScreen(
          repo: widget.repo,
          adjustmentsRepo: widget.adjustmentsRepo,
          user: widget.user,
          item: item,
        ),
      ),
    );
    if (!mounted) return;
    _reload();
    switch (outcome) {
      case StockSaveOutcome.saved:
        AppSnackBar.success(context, 'Existencia actualizada');
      case StockSaveOutcome.savedPartially:
        AppSnackBar.info(
          context,
          'Existencia actualizada. Alguien más vendió o ajustó esas piezas, '
          'así que se restó solo lo que quedaba.',
        );
      case null:
        break;
    }
  }

  Future<void> _registerSale(ClothingItem item) async {
    final venta = await Navigator.of(context).push<SaleResult>(
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
    switch (venta) {
      case (:final vendidas, :final pedidas) when vendidas < pedidas:
        AppSnackBar.info(
          context,
          'Solo quedaban $vendidas de $pedidas piezas: se registró lo '
          'disponible.',
        );
      case (:final vendidas, pedidas: _):
        AppSnackBar.success(
          context,
          vendidas == 1
              ? 'Venta registrada'
              : 'Venta registrada · $vendidas piezas',
        );
      case null:
        break;
    }
  }

  void _openSales() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            SalesScreen(salesRepo: widget.salesRepo, repo: widget.repo),
      ),
    );
  }

  void _openAdjustments() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            AdjustmentsScreen(adjustmentsRepo: widget.adjustmentsRepo),
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
              const Utf8Encoder().convert('\uFEFF$csv'),
              mimeType: 'text/csv',
              name: 'catalogo.csv',
            ),
          ],
          fileNameOverrides: ['catalogo.csv'],
        ),
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'No se pudo exportar el catálogo.');
      }
    }
  }

  Future<void> _addManually() async {
    final String id;
    try {
      id = await widget.repo.generateId();
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(
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
        builder: (_) => ItemFormScreen(
          repo: widget.repo,
          adjustmentsRepo: widget.adjustmentsRepo,
          user: widget.user,
          item: newItem,
          isNew: true,
        ),
      ),
    );
    if (!mounted) return;
    _reload();
    if (result case (outcome: ItemFormOutcome.saved, :final item)) {
      await _celebrateCreated(item);
    }
  }

  /// A new garment is a finished process: say so, and offer the usual next
  /// steps (printing its label, or adding the next one).
  Future<void> _celebrateCreated(ClothingItem item) async {
    final next = await showSuccess<_AfterCreate>(
      context,
      title: 'Prenda agregada',
      message:
          'Ya está en el catálogo con el código ${item.id}. Imprime su '
          'etiqueta QR y pégala en la prenda para encontrarla al escanear.',
      detail: ItemSummary(item: item),
      primary: const SuccessAction(
        label: 'Imprimir etiqueta QR',
        icon: Icons.qr_code_2_rounded,
        value: _AfterCreate.qr,
      ),
      secondary: const SuccessAction(
        label: 'Agregar otra prenda',
        icon: Icons.add_rounded,
        value: _AfterCreate.another,
      ),
    );
    if (!mounted) return;
    switch (next) {
      case _AfterCreate.qr:
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => QrScreen(item: item)));
      case _AfterCreate.another:
        await _addManually();
      case null:
        break;
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const ScannerScreen()));
    if (code == null || !mounted) return;

    // The app's own QR, or the barcode the supplier printed on the garment.
    final existing =
        widget.repo.getById(code) ?? widget.repo.getByProviderCode(code);
    if (existing == null) {
      await _showUnrecognizedQrDialog();
      return;
    }
    // Employees can only adjust stock, so there's nothing to choose.
    if (!widget.user.canEditCatalog) return _quickEditStock(existing);

    final action = await showModalBottomSheet<ScanAction>(
      context: context,
      builder: (_) => ScannedItemSheet(item: existing),
    );
    if (!mounted) return;
    switch (action) {
      case ScanAction.stock:
        await _quickEditStock(existing);
      case ScanAction.details:
        await _openItem(existing);
      case null:
        break;
    }
  }

  void _openUsers(UserDirectory users) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UsersScreen(users: users, currentUser: widget.user),
      ),
    );
  }

  Future<void> _showUnrecognizedQrDialog() => showNotice(
    context,
    icon: Icons.qr_code_scanner_rounded,
    title: 'Código no reconocido',
    message:
        'Este código no corresponde a ninguna prenda de esta tienda, ni por '
        'su QR ni por su código de proveedor. Si la prenda es nueva, '
        'agrégala primero.',
  );

  Future<void> _confirmSignOut(VoidCallback signOut) async {
    final confirmed = await confirmAction(
      context,
      icon: Icons.logout_rounded,
      title: '¿Cerrar sesión?',
      message:
          'Para volver a entrar necesitarás tu correo y contraseña. Lo que ya '
          'guardaste se conserva y se sincroniza al entrar de nuevo.',
      confirmLabel: 'Cerrar sesión',
    );
    if (confirmed) signOut();
  }

  bool get _canOpenUsers => widget.users != null && widget.user.canManageUsers;

  Widget _emptyState() {
    if (_searchCtrl.text.trim().isNotEmpty) {
      return EmptyCatalog(
        icon: Icons.search_off_rounded,
        title: 'Sin resultados',
        message:
            'Ninguna prenda coincide con "${_searchCtrl.text.trim()}". '
            'Prueba con el código, un color o una talla.',
      );
    }
    if (_filtro != CatalogFilter.todas && _all.isNotEmpty) {
      return EmptyCatalog(
        icon: Icons.check_circle_outline_rounded,
        title: 'Todo en orden',
        message: _filtro.emptyMessage,
      );
    }
    final canAdd = widget.user.canEditCatalog;
    return EmptyCatalog(
      icon: Icons.checkroom_rounded,
      title: 'Tu catálogo está vacío',
      message: canAdd
          ? 'Agrega tu primera prenda; después imprime su código QR y '
                'pégalo en la etiqueta.'
          : 'Cuando un administrador agregue prendas aparecerán aquí.',
      actionLabel: canAdd ? 'Agregar prenda' : null,
      onAction: canAdd ? () => _once(_addManually) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCatalog = _all.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              toolbarHeight: 76,
              titleSpacing: 20,
              title: StoreTitle(user: widget.user),
              actions: [
                IconButton(
                  icon: Icon(
                    widget.isDarkMode
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                  ),
                  tooltip: widget.isDarkMode ? 'Tema claro' : 'Tema oscuro',
                  onPressed: widget.onToggleTheme,
                ),
                IconButton(
                  icon: const Icon(Icons.receipt_long_rounded),
                  tooltip: 'Ventas',
                  onPressed: () => _once(() async => _openSales()),
                ),
                AccountMenu(
                  user: widget.user,
                  onManageUsers: _canOpenUsers
                      ? () => _openUsers(widget.users!)
                      : null,
                  onExport: widget.user.canEditCatalog ? _exportCatalog : null,
                  onViewAdjustments: widget.user.canManageUsers
                      ? _openAdjustments
                      : null,
                  onSignOut: switch (widget.onSignOut) {
                    final signOut? => () => _confirmSignOut(signOut),
                    null => null,
                  },
                ),
                const SizedBox(width: 12),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: SearchBar(
                  controller: _searchCtrl,
                  hintText: 'Buscar por nombre, código, color o talla',
                  leading: const Icon(Icons.search_rounded),
                  textInputAction: TextInputAction.search,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  trailing: [
                    if (_searchCtrl.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Limpiar búsqueda',
                        onPressed: _searchCtrl.clear,
                      ),
                  ],
                ),
              ),
            ),
            if (hasCatalog) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: CatalogHero(
                    items: _all,
                    showValue: widget.user.canEditCatalog,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 4),
                  child: CatalogFilterBar(
                    selected: _filtro,
                    all: _all,
                    onSelected: _setFiltro,
                  ),
                ),
              ),
            ],
            if (_items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: _emptyState()),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                sliver: SliverList.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return ClothingCard(
                      key: ValueKey(item.id),
                      item: item,
                      onTap: () => _once(() => _openItem(item)),
                      onQuickEdit: () => _once(() => _quickEditStock(item)),
                      onSell: () => _once(() => _registerSale(item)),
                      photoPath: widget.repo.photoPathFor(item.id),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.user.canEditCatalog) ...[
            FloatingActionButton(
              heroTag: 'add',
              onPressed: () => _once(_addManually),
              tooltip: 'Agregar prenda',
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              foregroundColor: Theme.of(
                context,
              ).colorScheme.onSecondaryContainer,
              child: const Icon(Icons.add_rounded),
            ),
            const SizedBox(width: 12),
          ],
          FloatingActionButton.extended(
            heroTag: 'scan',
            onPressed: () => _once(_scan),
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Escanear'),
          ),
        ],
      ),
    );
  }
}

enum _AfterCreate { qr, another }
