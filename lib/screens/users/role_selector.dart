import 'package:flutter/material.dart';

import '../../auth/app_user.dart';

/// Choice between the two roles, with what each one may do.
class RoleSelector extends StatelessWidget {
  const RoleSelector({super.key, required this.value, required this.onChanged});

  final UserRole value;
  final ValueChanged<UserRole>? onChanged;

  static const Map<UserRole, String> _descriptions = {
    UserRole.admin: 'Todo: prendas, precios, borrar y gestionar usuarios.',
    UserRole.empleado: 'Consultar, escanear y ajustar existencias.',
  };

  @override
  Widget build(BuildContext context) {
    return RadioGroup<UserRole>(
      groupValue: value,
      onChanged: (role) {
        if (role != null) onChanged?.call(role);
      },
      child: Column(
        children: [
          for (final role in UserRole.values)
            RadioListTile<UserRole>(
              value: role,
              enabled: onChanged != null,
              title: Text(role.label),
              subtitle: Text(_descriptions[role]!),
            ),
        ],
      ),
    );
  }
}
