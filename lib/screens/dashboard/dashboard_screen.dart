// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../auth/app_user.dart';
import '../../auth/user_directory.dart';
import '../../data/adjustments_repository.dart';
import '../../data/clothing_repository.dart';
import '../../data/license_admin.dart';
import '../../data/sales_repository.dart';
import '../../models/clothing_item.dart';
import '../../app_theme.dart';
import '../../utils/formato.dart';
import '../../widgets/item_avatar.dart';
import '../home/store_account_menu.dart';
import '../home/store_title.dart';

/// Pantalla de Inicio: un resumen del día de un vistazo — ventas de hoy, la
/// semana en barras, las prendas que necesitan atención y lo más vendido.
/// Todo con datos reales de la tienda; nada simulado.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.repo,
    required this.salesRepo,
    required this.adjustmentsRepo,
    required this.user,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.onVerVentas,
    required this.onAbrirPrenda,
    this.users,
    this.licenseAdmin,
    this.onSignOut,
  });

  final ClothingRepository repo;
  final SalesRepository salesRepo;
  final AdjustmentsRepository adjustmentsRepo;
  final AppUser user;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  /// Ir a la pestaña de Ventas.
  final VoidCallback onVerVentas;

  /// Abrir una prenda desde "Necesitan atención".
  final ValueChanged<ClothingItem> onAbrirPrenda;

  final UserDirectory? users;
  final LicenseAdminService? licenseAdmin;
  final VoidCallback? onSignOut;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final Listenable _changes = Listenable.merge([
    widget.repo.listenable,
    widget.salesRepo.listenable,
  ]);
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _changes.addListener(_onChanged);
  }

  @override
  void dispose() {
    _changes.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _scheduled = false;
      if (mounted) setState(() {});
    });
  }

  /// Total vendido en cada uno de los últimos 7 días (más viejo primero).
  List<double> _ventasSemana(DateTime hoy) => [
    for (var i = 6; i >= 0; i--)
      widget.salesRepo.totalDe(hoy.subtract(Duration(days: i))),
  ];

  /// Prendas que necesitan atención: agotadas primero, luego las de poca
  /// existencia o con alguna talla baja.
  List<ClothingItem> _necesitanAtencion(List<ClothingItem> todas) {
    final agotadas = <ClothingItem>[];
    final bajas = <ClothingItem>[];
    for (final item in todas) {
      if (item.nivelExistencia == StockLevel.agotado) {
        agotadas.add(item);
      } else if (item.existenciaTotal > 0 &&
          (item.nivelExistencia == StockLevel.poca || item.tieneStockBajo)) {
        bajas.add(item);
      }
    }
    return [...agotadas, ...bajas];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hoy = DateTime.now();
    final todas = widget.repo.getAll();
    final esAdmin = widget.user.canEditCatalog;
    final atencion = _necesitanAtencion(todas);
    final masVendidos = widget.salesRepo.masVendidos(limit: 3);

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
                StoreAccountMenu(
                  user: widget.user,
                  repo: widget.repo,
                  adjustmentsRepo: widget.adjustmentsRepo,
                  isDarkMode: widget.isDarkMode,
                  onToggleTheme: widget.onToggleTheme,
                  users: widget.users,
                  licenseAdmin: widget.licenseAdmin,
                  onSignOut: widget.onSignOut,
                ),
                const SizedBox(width: 12),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
              sliver: SliverList.list(
                children: [
                  _VentasHero(
                    hoy: widget.salesRepo.totalDe(hoy),
                    semana: _ventasSemana(hoy),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatChip(
                          label: 'Esta semana',
                          valor: widget.salesRepo.totalSemanaDe(hoy),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatChip(
                          label: 'Este mes',
                          valor: widget.salesRepo.totalMesDe(hoy),
                        ),
                      ),
                    ],
                  ),
                  if (esAdmin) ...[
                    const SizedBox(height: 10),
                    _StatChip(
                      label: 'Valor del inventario',
                      valor: widget.repo.valorInventario,
                      ancho: true,
                    ),
                  ],
                  const SizedBox(height: 22),
                  Text('Necesitan atención', style: textTheme.titleMedium),
                  const SizedBox(height: 10),
                  if (atencion.isEmpty)
                    _InfoLinea(
                      icon: Icons.check_circle_rounded,
                      color: colorScheme.primary,
                      texto: todas.isEmpty
                          ? 'Aún no hay prendas en el catálogo.'
                          : 'Todo en orden: ninguna prenda con poca '
                                'existencia ni agotada.',
                    )
                  else
                    _TarjetaLista(
                      children: [
                        for (final item in atencion.take(5))
                          _AtencionTile(
                            item: item,
                            photoPath: widget.repo.photoPathFor(item.id),
                            onTap: () => widget.onAbrirPrenda(item),
                          ),
                      ],
                    ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Lo más vendido', style: textTheme.titleMedium),
                      TextButton(
                        onPressed: widget.onVerVentas,
                        child: const Text('Ver ventas'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (masVendidos.isEmpty)
                    _InfoLinea(
                      icon: Icons.receipt_long_rounded,
                      color: colorScheme.onSurfaceVariant,
                      texto: 'Cuando registres ventas, aquí verás lo que más '
                          'se vende.',
                    )
                  else
                    _TarjetaLista(
                      children: [
                        for (final v in masVendidos)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    v.nombre,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.titleSmall,
                                  ),
                                ),
                                Text(
                                  formatoPiezas(v.piezas),
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta grande con las ventas de hoy y una gráfica de barras de la semana.
class _VentasHero extends StatelessWidget {
  const _VentasHero({required this.hoy, required this.semana});

  final double hoy;
  final List<double> semana;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final maximo = semana.fold(0.0, (m, v) => v > m ? v : m);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            Color.lerp(colorScheme.primary, const Color(0xFF2A1208), 0.4)!,
          ],
        ),
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ventas de hoy',
            style: textTheme.labelLarge?.copyWith(
              color: colorScheme.onPrimary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatoPrecio(hoy),
            style: textTheme.displaySmall?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < semana.length; i++) ...[
                  if (i > 0) const SizedBox(width: 7),
                  Expanded(
                    child: _Barra(
                      fraccion: maximo == 0 ? 0 : semana[i] / maximo,
                      // La última barra (hoy) resaltada.
                      destacada: i == semana.length - 1,
                      onPrimary: colorScheme.onPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Últimos 7 días',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onPrimary.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _Barra extends StatelessWidget {
  const _Barra({
    required this.fraccion,
    required this.destacada,
    required this.onPrimary,
  });

  final double fraccion;
  final bool destacada;
  final Color onPrimary;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        // Una base mínima para que un día sin ventas no desaparezca.
        heightFactor: (0.08 + fraccion * 0.92).clamp(0.08, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: onPrimary.withValues(alpha: destacada ? 1 : 0.38),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.valor,
    this.ancho = false,
  });

  final String label;
  final double valor;
  final bool ancho;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: ancho ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatoPrecio(valor),
            style: textTheme.titleLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _TarjetaLista extends StatelessWidget {
  const _TarjetaLista({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const Divider(height: 1),
            child,
          ],
        ],
      ),
    );
  }
}

class _AtencionTile extends StatelessWidget {
  const _AtencionTile({
    required this.item,
    required this.photoPath,
    required this.onTap,
  });

  final ClothingItem item;
  final String? photoPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final stock = StockColors.of(context);
    final agotado = item.nivelExistencia == StockLevel.agotado;
    final (String estado, Color color) = agotado
        ? ('Agotada', colorScheme.error)
        : ('Quedan ${formatoPiezas(item.existenciaTotal)}', stock.low);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            ItemAvatar(nombre: item.nombre, photoPath: photoPath, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.nombre.isEmpty ? '(sin nombre)' : item.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall,
                  ),
                  Row(
                    children: [
                      Icon(
                        agotado
                            ? Icons.remove_shopping_cart_outlined
                            : Icons.warning_amber_rounded,
                        size: 14,
                        color: color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        estado,
                        style: textTheme.labelMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
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
    );
  }
}

class _InfoLinea extends StatelessWidget {
  const _InfoLinea({
    required this.icon,
    required this.color,
    required this.texto,
  });

  final IconData icon;
  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
