import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../auth/credential_validators.dart';
import '../../widgets/async_submit.dart';
import '../../widgets/auth_layout.dart';
import '../../widgets/busy_button.dart';
import '../../widgets/error_text.dart';
import '../../widgets/password_field.dart';

/// Opens a new store: whoever registers here becomes its administrator and
/// can then add their employees. Each store is isolated from the others.
///
/// Asks only for the owner's name, email and password; from then on they
/// sign in with email and password.
class NewStoreScreen extends StatefulWidget {
  const NewStoreScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<NewStoreScreen> createState() => _NewStoreScreenState();
}

class _NewStoreScreenState extends State<NewStoreScreen> with AsyncSubmit {
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
      () => widget.auth.createStore(
        nombreTienda: 'Tienda de ${_nombreCtrl.text.trim()}',
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
      title: 'Inicia tu nueva tienda',
      subtitle:
          'Serás el administrador: gestionas el catálogo y registras a tus '
          'empleados.',
      showBack: true,
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nombreCtrl,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: CredentialValidators.required,
                decoration: const InputDecoration(
                  labelText: 'Tu nombre',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _correoCtrl,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
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
                autofillHints: const [AutofillHints.newPassword],
              ),
              const SizedBox(height: 14),
              PasswordField(
                controller: _confirmCtrl,
                label: 'Confirmar contraseña',
                validator: _validateConfirm,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _create(),
                autofillHints: const [AutofillHints.newPassword],
              ),
              if (error != null) ...[
                const SizedBox(height: 14),
                ErrorText(error!),
              ],
              const SizedBox(height: 20),
              BusyButton(
                label: 'Crear tienda',
                busy: busy,
                onPressed: _create,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
