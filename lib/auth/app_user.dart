enum UserRole {
  admin('admin', 'Administrador'),
  empleado('empleado', 'Empleado');

  const UserRole(this.id, this.label);

  /// Value stored in Firestore and checked by the security rules.
  final String id;
  final String label;

  static UserRole fromId(String? id) =>
      values.firstWhere((role) => role.id == id, orElse: () => empleado);
}

/// Someone who can use the app, with the role that decides what they may do.
///
/// Permissions are read from here by the UI; the same rules are enforced on
/// the server by `firestore.rules`.
class AppUser {
  const AppUser({
    required this.uid,
    required this.nombre,
    required this.correo,
    required this.role,
    this.activo = true,
  });

  /// The only user when the app runs without a backend (no login at all).
  static const AppUser local = AppUser(
    uid: 'local',
    nombre: 'Local',
    correo: '',
    role: UserRole.admin,
  );

  final String uid;
  final String nombre;
  final String correo;
  final UserRole role;
  final bool activo;

  bool get isAdmin => role == UserRole.admin;

  /// Create, edit, price and delete garments. Employees only adjust stock.
  bool get canEditCatalog => isAdmin;

  bool get canManageUsers => isAdmin;

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) => AppUser(
    uid: uid,
    nombre: map['nombre'] as String? ?? '',
    correo: map['correo'] as String? ?? '',
    role: UserRole.fromId(map['rol'] as String?),
    activo: map['activo'] as bool? ?? false,
  );

  Map<String, dynamic> toMap() => {
    'nombre': nombre,
    'correo': correo,
    'rol': role.id,
    'activo': activo,
  };

  AppUser copyWith({UserRole? role, bool? activo}) => AppUser(
    uid: uid,
    nombre: nombre,
    correo: correo,
    role: role ?? this.role,
    activo: activo ?? this.activo,
  );
}
