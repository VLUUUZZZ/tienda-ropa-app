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

/// A store: its own catalog and its own staff, isolated from every other
/// store that uses the app.
class Tienda {
  const Tienda({required this.id, required this.nombre});

  final String id;
  final String nombre;
}

/// Someone who can use the app: the store they belong to and the role that
/// decides what they may do there.
///
/// Permissions are read from here by the UI; the same rules are enforced on
/// the server by `firestore.rules`.
class AppUser {
  const AppUser({
    required this.uid,
    required this.nombre,
    required this.correo,
    required this.role,
    this.tienda,
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

  /// Null only for [local].
  final Tienda? tienda;
  final bool activo;

  bool get isAdmin => role == UserRole.admin;

  /// Create, edit, price and delete garments. Employees only adjust stock.
  bool get canEditCatalog => isAdmin;

  bool get canManageUsers => isAdmin;

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    final tiendaId = map['tiendaId'] as String?;
    return AppUser(
      uid: uid,
      nombre: map['nombre'] as String? ?? '',
      correo: map['correo'] as String? ?? '',
      role: UserRole.fromId(map['rol'] as String?),
      tienda: tiendaId == null
          ? null
          : Tienda(id: tiendaId, nombre: map['tiendaNombre'] as String? ?? ''),
      activo: map['activo'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'nombre': nombre,
    'correo': correo,
    'rol': role.id,
    'activo': activo,
    if (tienda case final tienda?) ...{
      'tiendaId': tienda.id,
      'tiendaNombre': tienda.nombre,
    },
  };

  AppUser copyWith({UserRole? role, bool? activo}) => AppUser(
    uid: uid,
    nombre: nombre,
    correo: correo,
    role: role ?? this.role,
    tienda: tienda,
    activo: activo ?? this.activo,
  );
}
