import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/clothing_repository.dart';
import '../models/clothing_item.dart';
import 'item_form_screen.dart';
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

  Future<void> _openExisting(ClothingItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ItemFormScreen(repo: widget.repo, item: item)),
    );
    _reload();
  }

  Future<void> _addManually() async {
    final newItem = ClothingItem(
      id: const Uuid().v4(),
      nombre: '',
      precio: 0,
      variantes: const [],
    );
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ItemFormScreen(repo: widget.repo, item: newItem, isNew: true)),
    );
    _reload();
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (code == null || !mounted) return;

    final existing = widget.repo.getById(code);
    final item = existing ??
        ClothingItem(id: code, nombre: '', precio: 0, variantes: const []);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ItemFormScreen(repo: widget.repo, item: item, isNew: existing == null),
      ),
    );
    _reload();
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

  const _ClothingCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sinStock = item.existenciaTotal == 0;

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
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.sell_outlined, size: 16),
                          label: Text('\$${item.precio.toStringAsFixed(2)}'),
                          visualDensity: VisualDensity.compact,
                        ),
                        Chip(
                          avatar: Icon(
                            sinStock ? Icons.error_outline : Icons.inventory_2_outlined,
                            size: 16,
                            color: sinStock ? colorScheme.error : null,
                          ),
                          label: Text('${item.existenciaTotal} en existencia'),
                          backgroundColor: sinStock
                              ? colorScheme.errorContainer.withValues(alpha: 0.6)
                              : null,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
