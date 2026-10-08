import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../auth/credential_validators.dart';
import '../../auth/user_directory.dart';
import '../../widgets/async_submit.dart';
import '../../widgets/feedback/app_snackbar.dart';
import '../../widgets/busy_button.dart';
import '../../widgets/error_text.dart';
import '../../widgets/password_field.dart';
import 'role_selector.dart';

/// Who was just given an account, for the confirmation that follows.
typedef NewAccount = ({String nombre, String correo, UserRole role});

/// Lets an admin create an employee's (or another admin's) account in their
/// store, with a temporary password to hand over. Pops with [NewAccount]
/// once the account exists.
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
    if (created && mounted) {
      Navigator.of(context).pop<NewAccount>((
        nombre: _nombreCtrl.text.trim(),
        correo: _correoCtrl.text.trim(),
        role: _role,
      ));
    }
  }

  void _blockLeaveWhileBusy(bool didPop, Object? result) {
    if (didPop) return;
    AppSnackBar.info(context, 'Espera a que termine de crear la cuenta.');
  }

  @override
  Widget build(BuildContext context) {
    // The account is already being created by the time this could fire (not
    // cancellable): leaving now would only make the admin think it was
    // cancelled while it keeps going in the background.
    return PopScope(
      canPop: !busy,
      onPopInvokedWithResult: _blockLeaveWhileBusy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Nuevo usuario')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nombreCtrl,
                maxLength: CredentialValidators.maxNombre,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: CredentialValidators.nombre,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  helperText: 'Así aparecerá en el historial de ajustes.',
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
                  helperText: 'Con este correo entrará a la app.',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
              ),
              const SizedBox(height: 14),
              PasswordField(
                controller: _passwordCtrl,
                label: 'Contraseña temporal',
                helperText:
                    'Al menos ${CredentialValidators.minPasswordLength} '
                    'caracteres. Compártela con la persona; después podrá '
                    'cambiarla con "¿Olvidaste tu contraseña?".',
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _create(),
                // No es la contraseña de quien usa este teléfono: no ofrecer
                // guardarla ni autocompletarla desde el administrador de
                // contraseñas del dispositivo.
                autofillHints: const [],
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
      ),
    );
  }
}
