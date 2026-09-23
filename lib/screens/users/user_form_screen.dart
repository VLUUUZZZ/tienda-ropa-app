import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../auth/credential_validators.dart';
import '../../auth/user_directory.dart';
import '../../widgets/async_submit.dart';
import '../../widgets/busy_button.dart';
import '../../widgets/error_text.dart';
import '../../widgets/password_field.dart';
import 'role_selector.dart';

/// Lets an admin create an employee's (or another admin's) account in their
/// store, with a temporary password to hand over.
class UserFormScreen extends StatefulWidget {
  const UserFormScreen({super.key, required this.users, required this.tienda});

  final UserDirectory users;
  final Tienda tienda;

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> with AsyncSubmit {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  UserRole _role = UserRole.empleado;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    final created = await submit(
      () => widget.users.create(
        tienda: widget.tienda,
        nombre: _nombreCtrl.text,
        correo: _correoCtrl.text,
        password: _passwordCtrl.text,
        role: _role,
      ),
    );
    if (created && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo usuario')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nombreCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: CredentialValidators.required,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _correoCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              validator: CredentialValidators.email,
              decoration: const InputDecoration(
                labelText: 'Correo',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
            const SizedBox(height: 14),
            PasswordField(
              controller: _passwordCtrl,
              label: 'Contraseña temporal',
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 20),
            Text('Rol', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            RoleSelector(
              value: _role,
              onChanged: (role) => setState(() => _role = role),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              ErrorText(error!),
            ],
            const SizedBox(height: 24),
            BusyButton(label: 'Crear cuenta', busy: busy, onPressed: _create),
          ],
        ),
      ),
    );
  }
}
