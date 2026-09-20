import 'package:flutter/material.dart';

import '../data/clothing_repository.dart';
import '../models/clothing_item.dart';
import 'item_form_screen.dart';
import 'quick_stock_screen.dart';
import 'scanner_screen.dart';

class HomeScreen extends StatefulWidget {
  final ClothingRepository repo;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const HomeScreen({
    super.key,
    required this.repo,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchCtrl = TextEditingController();
  List<ClothingItem> _items = [];

  @override
  void initState() {
    super.initState();
    _reload();
    _searchCtrl.addListener(() => _reload());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _items = widget.repo.search(_searchCtrl.text));
  }

  void _showSavedSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Cambios guardados'),
          ],
        ),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openExisting(ClothingItem item) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ItemFormScreen(repo: widget.repo, item: item)),
    );
    _reload();
    if (saved == true && mounted) _showSavedSnackBar();
  }

  Future<void> _quickEditStock(ClothingItem item) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => QuickStockScreen(repo: widget.repo, item: item)),
    );
    _reload();
    if (saved == true && mounted) _showSavedSnackBar();
  }

  Future<void> _addManually() async {
    final id = await widget.repo.generateId();
    if (!mounted) return;
    final newItem = ClothingItem(id: id, nombre: '', precio: 0, variantes: const []);
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ItemFormScreen(repo: widget.repo, item: newItem, isNew: true)),
    );
    _reload();
    if (saved == true && mounted) _showSavedSnackBar();
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (code == null || !mounted) return;

    final existing = widget.repo.getById(code);
    if (existing == null) {
      await _showUnrecognizedQrDialog();
      return;
    }

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ItemFormScreen(repo: widget.repo, item: existing),
      ),
    );
    _reload();
    if (saved == true && mounted) _showSavedSnackBar();
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tienda de Ropa'),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            tooltip: widget.isDarkMode ? 'Tema claro' : 'Tema oscuro',
            onPressed: widget.onToggleTheme,
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
                        Icon(Icons.checkroom_rounded, size: 56, color: colorScheme.outline),
                        const SizedBox(height: 12),
                        Text(
                          'No hay prendas que coincidan.',
                          style: TextStyle(color: colorScheme.outline),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _ClothingCard(
                      item: _items[index],
                      onTap: () => _openExisting(_items[index]),
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
          const SizedBox(width: 12),
          FloatingActionButton(
            heroTag: 'add',
            onPressed: _addManually,
            tooltip: 'Agregar prenda',
            child: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _ClothingCard extends StatelessWidget {
  final ClothingItem item;
  final VoidCallback onTap;
  final VoidCallback onQuickEdit;

  const _ClothingCard({required this.item, required this.onTap, required this.onQuickEdit});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sinStock = item.existenciaTotal == 0;
    final colores = item.coloresDisponibles;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(Icons.checkroom_rounded, color: colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nombre.isEmpty ? '(sin nombre)' : item.nombre,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${item.precio.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                    if (colores.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        colores.join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Chip(
                      avatar: Icon(
                        sinStock ? Icons.error_outline : Icons.inventory_2_outlined,
                        size: 16,
                        color: sinStock ? colorScheme.error : null,
                      ),
                      label: Text(sinStock ? 'AGOTADO' : '${item.existenciaTotal} piezas'),
                      backgroundColor: sinStock
                          ? colorScheme.errorContainer.withValues(alpha: 0.6)
                          : null,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Editar existencia rápido',
                onPressed: onQuickEdit,
              ),
              Icon(Icons.chevron_right_rounded, color: colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
