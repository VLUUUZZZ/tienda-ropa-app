import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../auth/credential_validators.dart';
import '../../widgets/async_submit.dart';
import '../../widgets/auth_layout.dart';
import '../../widgets/busy_button.dart';
import '../../widgets/error_text.dart';
import '../../widgets/password_field.dart';
import 'new_store_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with AsyncSubmit {
  final _formKey = GlobalKey<FormState>();
  final _correoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  @override
  void dispose() {
    _correoCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    // On success the auth gate replaces this screen; nothing else to do.
    await submit(
      () => widget.auth.signIn(
        correo: _correoCtrl.text,
        password: _passwordCtrl.text,
      ),
    );
  }

  Future<void> _resetPassword() async {
    if (_correoCtrl.text.trim().isEmpty) {
      setState(() => error = 'Escribe tu correo para recuperar la contraseña.');
      return;
    }
    final correoError = CredentialValidators.email(_correoCtrl.text);
    if (correoError != null) {
      setState(() => error = correoError);
      return;
    }
    final sent = await submit(
      () => widget.auth.sendPasswordReset(_correoCtrl.text),
    );
    if (sent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Te enviamos un correo a ${_correoCtrl.text.trim()}.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openNewStore() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NewStoreScreen(auth: widget.auth)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Tienda de Ropa',
      subtitle: 'Inicia sesión para continuar',
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                validator: CredentialValidators.required,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _signIn(),
              ),
              if (error != null) ...[
                const SizedBox(height: 14),
                ErrorText(error!),
              ],
              const SizedBox(height: 20),
              BusyButton(label: 'Entrar', busy: busy, onPressed: _signIn),
              TextButton(
                onPressed: busy ? null : _resetPassword,
                child: const Text('¿Olvidaste tu contraseña?'),
              ),
              const Divider(height: 24),
              OutlinedButton.icon(
                onPressed: busy ? null : _openNewStore,
                icon: const Icon(Icons.add_business_outlined),
                label: const Text('Iniciar nueva tienda'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
