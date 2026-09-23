import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../auth/credential_validators.dart';
import '../../widgets/async_submit.dart';
import '../../widgets/auth_layout.dart';
import '../../widgets/busy_button.dart';
import '../../widgets/error_text.dart';
import '../../widgets/password_field.dart';

/// One-time setup of the store's first administrator, offered only while
/// the project has none.
class FirstAdminScreen extends StatefulWidget {
  const FirstAdminScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<FirstAdminScreen> createState() => _FirstAdminScreenState();
}

class _FirstAdminScreenState extends State<FirstAdminScreen> with AsyncSubmit {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? _validateConfirm(String? value) =>
      value == _passwordCtrl.text ? null : 'Las contraseñas no coinciden';

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    final created = await submit(
      () => widget.auth.createFirstAdmin(
        nombre: _nombreCtrl.text,
        correo: _correoCtrl.text,
        password: _passwordCtrl.text,
      ),
    );
    // Signed in now: back to the root, where the auth gate shows the store.
    if (created && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Primer administrador',
      subtitle:
          'Esta cuenta podrá gestionar el catálogo y crear las cuentas de '
          'los empleados.',
      showBack: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            PasswordField(
              controller: _confirmCtrl,
              label: 'Confirmar contraseña',
              validator: _validateConfirm,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _create(),
            ),
            if (error != null) ...[
              const SizedBox(height: 14),
              ErrorText(error!),
            ],
            const SizedBox(height: 20),
            BusyButton(
              label: 'Crear administrador',
              busy: busy,
              onPressed: _create,
            ),
          ],
        ),
      ),
    );
  }
}
