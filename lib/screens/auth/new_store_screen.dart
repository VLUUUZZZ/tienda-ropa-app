import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../auth/credential_validators.dart';
import '../../widgets/async_submit.dart';
import '../../widgets/feedback/app_snackbar.dart';
import '../../widgets/auth_layout.dart';
import '../../widgets/feedback/success_screen.dart';
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
    if (!created || !mounted) return;
    // Signed in now: the auth gate (at the root) is showing the new store.
    // The welcome goes on top of it, replacing this form, so closing it
    // lands straight in the catalog.
    final nombreTienda = 'Tienda de ${_nombreCtrl.text.trim()}';
    final navigator = Navigator.of(context);
    navigator.popUntil((route) => route.isFirst);
    await showSuccess<void>(
      navigator.context,
      title: '¡Tu tienda está lista!',
      message:
          '$nombreTienda ya está creada y tú eres su administrador. Empieza '
          'agregando tus prendas; después podrás dar de alta a tu personal '
          'desde Cuenta → Usuarios.',
      primary: const SuccessAction(
        label: 'Empezar',
        icon: Icons.storefront_outlined,
        value: null,
      ),
    );
  }

  void _blockLeaveWhileBusy(bool didPop, Object? result) {
    if (didPop) return;
    AppSnackBar.info(context, 'Espera a que termine de crear la tienda.');
  }

  @override
  Widget build(BuildContext context) {
    // The account is already being created by the time this could fire (not
    // cancellable), so leaving now would only make the user think they
    // backed out while it keeps going and signs them in moments later.
    return PopScope(
      canPop: !busy,
      onPopInvokedWithResult: _blockLeaveWhileBusy,
      child: AuthLayout(
        title: 'Crea tu tienda',
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
                  maxLength: CredentialValidators.maxNombre,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: CredentialValidators.nombre,
                  decoration: const InputDecoration(
                    labelText: 'Tu nombre',
                    helperText: 'Tu tienda se llamará "Tienda de" + tu nombre.',
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
                    helperText: 'Con este correo entrarás a la app.',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _passwordCtrl,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  helperText:
                      'Al menos ${CredentialValidators.minPasswordLength} '
                      'caracteres.',
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
      ),
    );
  }
}
