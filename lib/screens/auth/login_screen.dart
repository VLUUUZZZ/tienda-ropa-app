import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../auth/credential_validators.dart';
import '../../widgets/async_submit.dart';
import '../../widgets/auth_layout.dart';
import '../../widgets/busy_button.dart';
import '../../widgets/error_text.dart';
import '../../widgets/password_field.dart';
import 'first_admin_screen.dart';

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
  bool _needsFirstAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkFirstAdmin();
  }

  @override
  void dispose() {
    _correoCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkFirstAdmin() async {
    final needed = await widget.auth.needsFirstAdmin();
    if (mounted) setState(() => _needsFirstAdmin = needed);
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
    final correoError = CredentialValidators.email(_correoCtrl.text);
    if (correoError != null) {
      setState(() => error = 'Escribe tu correo para recuperar la contraseña.');
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

  void _openFirstAdmin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FirstAdminScreen(auth: widget.auth)),
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
              if (_needsFirstAdmin) ...[
                const Divider(height: 24),
                OutlinedButton.icon(
                  onPressed: _openFirstAdmin,
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: const Text('Configurar administrador'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
