// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth/license.dart';
import '../firestore_paths.dart';

/// Una tienda vista desde el panel del dueño de la app: su nombre y el estado
/// de su licencia.
class StoreLicense {
  const StoreLicense({
    required this.id,
    required this.nombre,
    required this.license,
  });

  final String id;
  final String nombre;
  final License license;
}

/// Administración de licencias de todas las tiendas. Solo funciona para el
/// dueño de la app; el servidor (reglas de Firestore) rechaza a cualquier
/// otra cuenta aunque llegara aquí.
abstract class LicenseAdminService {
  /// Todas las tiendas, en vivo, ordenadas por nombre.
  Stream<List<StoreLicense>> watchStores();

  /// Fija hasta cuándo es válida la licencia de una tienda. Null la deja sin
  /// licencia (bloqueada).
  Future<void> setLicense(String tiendaId, DateTime? hasta);
}

class FirestoreLicenseAdmin implements LicenseAdminService {
  FirestoreLicenseAdmin(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<StoreLicense>> watchStores() {
    return FirestorePaths.stores(_firestore).snapshots().map((snap) {
      final list = snap.docs.map((doc) {
        final data = doc.data();
        final raw = data['licenciaHasta'];
        final hasta = raw is Timestamp ? raw.toDate() : null;
        final nombre = data['nombre'];
        return StoreLicense(
          id: doc.id,
          nombre: nombre is String && nombre.trim().isNotEmpty
              ? nombre.trim()
              : '(sin nombre)',
          license: License.fromHasta(hasta),
        );
      }).toList();
      list.sort(
        (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
      );
      return list;
    });
  }

  @override
  Future<void> setLicense(String tiendaId, DateTime? hasta) {
    return FirestorePaths.stores(_firestore).doc(tiendaId).update({
      'licenciaHasta': hasta == null ? FieldValue.delete() : Timestamp.fromDate(hasta),
    });
  }
}
