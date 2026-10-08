import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../auth/auth_service.dart';
import '../../auth/user_directory.dart';
import '../../widgets/role_badge.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/feedback/app_snackbar.dart';
import '../../widgets/feedback/confirm_dialog.dart';
import '../../widgets/feedback/success_screen.dart';
import 'role_selector.dart';
import 'user_form_screen.dart';

/// Admin screen: everyone with an account in the admin's store, their role
/// and whether they can get in. Admins can't change their own account here,
/// so nobody locks the store out of administration by accident.
class UsersScreen extends StatefulWidget {
  const UsersScreen({
    super.key,
    required this.users,
    required this.currentUser,
  });

  final UserDirectory users;
  final AppUser currentUser;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  // Created once: building it in build() would re-subscribe to Firestore on
  // every rebuild.
  late final Stream<List<AppUser>> _staff = widget.users.watchStore(
    widget.currentUser.tienda!,
  );

  UserDirectory get users => widget.users;
  AppUser get currentUser => widget.currentUser;

  Future<void> _create(BuildContext context) async {
    final account = await Navigator.of(context).push<NewAccount>(
      MaterialPageRoute(
        builder: (_) =>
            UserFormScreen(users: users, tienda: currentUser.tienda!),
      ),
    );
    if (account == null || !context.mounted) return;

    final another = await showSuccess<bool>(
      context,
      title: 'Cuenta creada',
      message:
          'Comparte con ${account.nombre} su correo y la contraseña que '
          'escribiste para que entre. Si la olvida, puede recuperarla desde '
          '"¿Olvidaste tu contraseña?".',
      detail: _AccountSummary(account: account),
      primary: const SuccessAction(
        label: 'Listo',
        icon: Icons.check_rounded,
        value: false,
      ),
      secondary: const SuccessAction(
        label: 'Crear otra cuenta',
        icon: Icons.person_add_alt_rounded,
        value: true,
      ),
    );
    if (another == true && context.mounted) await _create(context);
  }

  /// The sheet opens from a list row, but everything after it uses this
  /// screen's context: the row may be rebuilt away while the sheet is open
  /// (the list updates live), and a confirmed change must still be saved.
  Future<void> _edit(AppUser user) async {
    final updated = await showModalBottomSheet<AppUser>(
      context: context,
      showDragHandle: true,
      builder: (_) => _EditUserSheet(user: user),
    );
    if (updated == null || !mounted) return;
    if (!await _confirmChange(context, user, updated) || !mounted) return;
    try {
      await users.update(updated);
      if (mounted) AppSnackBar.success(context, 'Cambios guardados');
    } on AuthException catch (e) {
      if (mounted) AppSnackBar.error(context, e.message);
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'No se pudo guardar el usuario.');
    }
  }

  /// Changes that grant or remove access are confirmed first, listing what
  /// each one means for that person (a single save can change both role
  /// and access).
  static Future<bool> _confirmChange(
    BuildContext context,
    AppUser before,
    AppUser after,
  ) {
    final consequences = <String>[
      if (before.activo && !after.activo)
        'Ya no podrá entrar a la app ni ver el catálogo. Puedes reactivar su '
            'cuenta cuando quieras.',
      if (!before.activo && after.activo) 'Podrá volver a entrar a la app.',
      if (before.role != UserRole.admin && after.role == UserRole.admin)
        'Como administrador podrá crear, editar y eliminar prendas, y '
            'gestionar las cuentas del personal.',
      if (before.role == UserRole.admin && after.role != UserRole.admin)
        'Como empleado solo podrá consultar el catálogo, escanear y ajustar '
            'existencias.',
    ];
    if (consequences.isEmpty) return Future.value(true);

    final pierdeAcceso = before.activo && !after.activo;
    final title = pierdeAcceso
        ? '¿Desactivar a ${before.nombre}?'
        : after.role != before.role
        ? '¿Cambiar a ${before.nombre} a ${after.role.label.toLowerCase()}?'
        : '¿Reactivar a ${before.nombre}?';
    return confirmAction(
      context,
      icon: pierdeAcceso
          ? Icons.person_off_outlined
          : Icons.admin_panel_settings_outlined,
      destructive: pierdeAcceso,
      title: title,
      message: consequences.join('\n\n'),
      confirmLabel: pierdeAcceso ? 'Desactivar' : 'Confirmar',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context),
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text('Nuevo'),
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: _staff,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('No se pudo cargar la lista.'));
          }
          final list = snapshot.data;
          if (list == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final user = list[index];
              final isSelf = user.uid == currentUser.uid;
              return _UserTile(
                user: user,
                isSelf: isSelf,
                onTap: isSelf ? null : () => _edit(user),
              );
            },
          );
        },
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.isSelf, this.onTap});

  final AppUser user;
  final bool isSelf;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        leading: UserAvatar(nombre: user.nombre, activo: user.activo),
        title: Text(
          isSelf ? '${user.nombre} (tú)' : user.nombre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          user.correo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            RoleBadge(role: user.role),
            if (!user.activo) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'Desactivado',
                  style: TextStyle(
                    color: colorScheme.onErrorContainer,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Edits another user's role and access; pops with the changed user, or
/// nothing if cancelled.
class _EditUserSheet extends StatefulWidget {
  const _EditUserSheet({required this.user});

  final AppUser user;

  @override
  State<_EditUserSheet> createState() => _EditUserSheetState();
}

class _EditUserSheetState extends State<_EditUserSheet> {
  late UserRole _role = widget.user.role;
  late bool _activo = widget.user.activo;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.user.nombre,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(widget.user.correo),
            const SizedBox(height: 12),
            RoleSelector(
              value: _role,
              onChanged: (role) => setState(() => _role = role),
            ),
            SwitchListTile(
              title: const Text('Puede entrar a la app'),
              value: _activo,
              onChanged: (value) => setState(() => _activo = value),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed:
                  _role == widget.user.role && _activo == widget.user.activo
                  ? null
                  : () => Navigator.of(
                      context,
                    ).pop(widget.user.copyWith(role: _role, activo: _activo)),
              child: const Text('Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountSummary extends StatelessWidget {
  const _AccountSummary({required this.account});

  final NewAccount account;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        UserAvatar(nombre: account.nombre, radius: 24),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(account.nombre, style: textTheme.titleMedium),
              Text(
                account.correo,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        RoleBadge(role: account.role),
      ],
    );
  }
}
