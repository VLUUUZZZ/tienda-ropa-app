import 'package:flutter/material.dart';

import '../auth/app_user.dart';
import '../auth/user_directory.dart';
import '../data/clothing_repository.dart';
import '../models/clothing_item.dart';
import '../utils/formato.dart';
import '../widgets/color_dot.dart';
import '../widgets/role_badge.dart';
import '../widgets/snackbars.dart';
import '../widgets/stock_badge.dart';
import 'item_form_screen.dart';
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

  const HomeScreen({
    super.key,
    required this.repo,
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

  /// The whole catalog, for the summary and the filter counts.
  List<ClothingItem> _all = [];

  /// What the list shows: [_all] narrowed by the search box and [_filtro].
  List<ClothingItem> _items = [];
  _Filtro _filtro = _Filtro.todas;

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

  void _onRepoChanged() {
    if (mounted) _reload();
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

  void _setFiltro(_Filtro filtro) {
    _filtro = filtro;
    _reload();
  }

  void _showSavedSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Theme.of(context).colorScheme.onInverseSurface,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text('Cambios guardados'),
          ],
        ),
        duration: const Duration(seconds: 2),
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
    _reload();
    if (!mounted) return;
    if (result == ItemFormResult.saved) _showSavedSnackBar();
    if (result == ItemFormResult.deleted) _showDeletedSnackBar(item);
  }

  Future<void> _quickEditStock(ClothingItem item) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QuickStockScreen(repo: widget.repo, item: item),
      ),
    );
    _reload();
    if (saved == true && mounted) _showSavedSnackBar();
  }

  Future<void> _addManually() async {
    final newItem = ClothingItem(
      id: widget.repo.nextId(),
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
    _reload();
    if (result == ItemFormResult.saved && mounted) _showSavedSnackBar();
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
    // Employees can only adjust stock, so there's nothing to choose.
    if (!widget.user.canEditCatalog) return _quickEditStock(existing);

    final action = await showModalBottomSheet<_ScanAction>(
      context: context,
      builder: (_) => _ScannedItemSheet(item: existing),
    );
    if (!mounted) return;
    switch (action) {
      case _ScanAction.stock:
        await _quickEditStock(existing);
      case _ScanAction.details:
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
    if (_filtro != _Filtro.todas && _all.isNotEmpty) {
      return _filtro.emptyMessage;
    }
    return widget.user.canEditCatalog
        ? 'Aún no hay prendas registradas.\nAgrega la primera con el botón +.'
        : 'Aún no hay prendas registradas.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _StoreTitle(user: widget.user),
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
          if (widget.onSignOut case final onSignOut?)
            _AccountMenu(
              user: widget.user,
              onManageUsers: _canOpenUsers
                  ? () => _openUsers(widget.users!)
                  : null,
              onSignOut: onSignOut,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, código, color o talla',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        tooltip: 'Borrar búsqueda',
                        onPressed: () => _searchCtrl.clear(),
                      ),
              ),
            ),
          ),
          if (_all.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _CatalogSummary(
                items: _all,
                showValue: widget.user.canEditCatalog,
              ),
            ),
            _FilterBar(selected: _filtro, all: _all, onSelected: _setFiltro),
          ],
          Expanded(
            child: _items.isEmpty
                ? _EmptyState(message: _emptyMessage)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 104),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _ClothingCard(
                      item: _items[index],
                      onTap: () => _openItem(_items[index]),
                      onQuickEdit: () => _quickEditStock(_items[index]),
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

/// The store's name, and who is in with their role next to it.
class _StoreTitle extends StatelessWidget {
  const _StoreTitle({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final tienda = user.tienda;
    if (tienda == null) return const Text('Tienda de Ropa');

    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tienda.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
        Row(
          children: [
            Flexible(
              child: Text(
                user.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 6),
            RoleBadge(role: user.role),
          ],
        ),
      ],
    );
  }
}

enum _AccountAction { users, signOut }

/// Who is signed in, plus the account actions their role allows.
class _AccountMenu extends StatelessWidget {
  const _AccountMenu({
    required this.user,
    required this.onManageUsers,
    required this.onSignOut,
  });

  final AppUser user;
  final VoidCallback? onManageUsers;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_AccountAction>(
      icon: const Icon(Icons.account_circle_outlined),
      tooltip: 'Cuenta',
      onSelected: (action) => switch (action) {
        _AccountAction.users => onManageUsers?.call(),
        _AccountAction.signOut => onSignOut(),
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(user.nombre),
            subtitle: Text('${user.role.label} · ${user.correo}'),
          ),
        ),
        const PopupMenuDivider(),
        if (onManageUsers != null)
          const PopupMenuItem(
            value: _AccountAction.users,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.group_outlined),
              title: Text('Usuarios'),
            ),
          ),
        const PopupMenuItem(
          value: _AccountAction.signOut,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout_rounded),
            title: Text('Cerrar sesión'),
          ),
        ),
      ],
    );
  }
}

enum _ScanAction { stock, details }

/// What to do with a garment just scanned: at the counter it's usually a
/// stock change, so that comes first.
class _ScannedItemSheet extends StatelessWidget {
  const _ScannedItemSheet({required this.item});

  final ClothingItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              item.nombre.isEmpty ? '(sin nombre)' : item.nombre,
              style: textTheme.titleLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${item.id} · ${formatoPrecio(item.precio)}',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: StockBadge(existencia: item.existenciaTotal),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: item.variantes.isEmpty
                  ? null
                  : () => Navigator.pop(context, _ScanAction.stock),
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Ajustar existencia'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, _ScanAction.details),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Ver ficha completa'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Filtro {
  todas('Todas', ''),
  poca('Poca existencia', 'No hay prendas con poca existencia.'),
  agotadas('Agotadas', 'No hay prendas agotadas.');

  const _Filtro(this.label, this.emptyMessage);

  final String label;
  final String emptyMessage;

  bool includes(ClothingItem item) => switch (this) {
    _Filtro.todas => true,
    _Filtro.poca => item.nivelExistencia == StockLevel.poca,
    _Filtro.agotadas => item.nivelExistencia == StockLevel.agotado,
  };
}

/// Todas / Poca existencia / Agotadas, each with how many garments it holds.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.all,
    required this.onSelected,
  });

  final _Filtro selected;
  final List<ClothingItem> all;
  final ValueChanged<_Filtro> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          for (final filtro in _Filtro.values) ...[
            ChoiceChip(
              label: Text(
                '${filtro.label} (${all.where(filtro.includes).length})',
              ),
              selected: filtro == selected,
              showCheckmark: false,
              onSelected: (_) => onSelected(filtro),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// At-a-glance totals for the whole catalog. The money figure is only for
/// roles that manage the catalog.
class _CatalogSummary extends StatelessWidget {
  const _CatalogSummary({required this.items, required this.showValue});

  final List<ClothingItem> items;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    final piezas = items.fold(0, (sum, i) => sum + i.existenciaTotal);
    final agotadas = items
        .where((i) => i.nivelExistencia == StockLevel.agotado)
        .length;
    final valor = items.fold(0.0, (sum, i) => sum + i.valorInventario);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              _Stat(label: 'Prendas', value: '${items.length}'),
              const VerticalDivider(),
              _Stat(label: 'Piezas', value: '$piezas'),
              const VerticalDivider(),
              showValue
                  ? _Stat(label: 'Valor', value: formatoPrecio(valor))
                  : _Stat(label: 'Agotadas', value: '$agotadas'),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Semantics(
        label: '$label: $value',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: textTheme.titleLarge?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.checkroom_rounded,
                size: 44,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClothingCard extends StatelessWidget {
  final ClothingItem item;
  final VoidCallback onTap;
  final VoidCallback onQuickEdit;

  const _ClothingCard({
    required this.item,
    required this.onTap,
    required this.onQuickEdit,
  });

  /// Up to two letters from the name, e.g. "Playera Básica" → "PB".
  static String _initials(String nombre) {
    final words = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty);
    return words.take(2).map((w) => w.characters.first.toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final colores = item.coloresDisponibles;
    const maxColores = 4;
    final initials = _initials(item.nombre);

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: initials.isEmpty
                    ? Icon(
                        Icons.checkroom_rounded,
                        color: colorScheme.onPrimaryContainer,
                      )
                    : Text(
                        initials,
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nombre.isEmpty ? '(sin nombre)' : item.nombre,
                      style: textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: formatoPrecio(item.precio),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.primary,
                            ),
                          ),
                          TextSpan(
                            text: '  ·  ${item.id}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (colores.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          for (final color in colores.take(maxColores))
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ColorDot(nombre: color),
                                const SizedBox(width: 4),
                                Text(
                                  color,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          if (colores.length > maxColores)
                            Text(
                              '+${colores.length - maxColores}',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    StockBadge(existencia: item.existenciaTotal),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Editar existencia rápido',
                onPressed: onQuickEdit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
