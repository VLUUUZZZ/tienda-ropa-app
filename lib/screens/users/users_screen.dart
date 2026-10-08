import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../auth/auth_service.dart';
import '../../auth/user_directory.dart';
import '../../utils/texto.dart';
import '../../widgets/role_badge.dart';
import '../../widgets/snackbars.dart';
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
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            UserFormScreen(users: users, tienda: currentUser.tienda!),
      ),
    );
    if (created == true && context.mounted) {
      _showMessage(context, 'Cuenta creada');
    }
  }

  Future<void> _edit(BuildContext context, AppUser user) async {
    final updated = await showModalBottomSheet<AppUser>(
      context: context,
      showDragHandle: true,
      builder: (_) => _EditUserSheet(user: user),
    );
    if (updated == null) return;
    try {
      await users.update(updated);
    } on AuthException catch (e) {
      if (context.mounted) showErrorSnackBar(context, e.message);
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'No se pudo guardar el usuario.');
      }
    }
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
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
                onTap: isSelf ? null : () => _edit(context, user),
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
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: user.activo
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          foregroundColor: user.activo
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
          child: Text(
            iniciales(user.nombre).isEmpty ? '?' : iniciales(user.nombre),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
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
