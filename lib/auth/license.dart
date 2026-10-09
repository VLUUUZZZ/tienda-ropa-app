// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

/// Control de licencia por tienda. La licencia vive en el documento de la
/// tienda (`tiendas/{id}`) y solo el dueño de la app puede cambiarla (lo
/// hace cumplir `firestore.rules`); aquí solo se interpreta para decidir si
/// la tienda puede usar la app, nunca para borrar datos.
///
/// Configuración del dueño de las licencias: su UID de Firebase. El control
/// real está en las reglas de Firestore; esta constante es solo de
/// referencia (por ejemplo, para un panel de administración futuro).
/// Reemplázala por tu UID real.
abstract final class LicenseConfig {
  static const String duenoUid = 'REEMPLAZA_CON_TU_UID_DE_FIREBASE';

  /// Días que una tienda recién creada puede usar la app antes de que el
  /// dueño le fije una fecha de licencia (prueba inicial). Igual que en las
  /// reglas.
  static const int diasPrueba = 14;

  /// Días que una tienda vigente puede seguir trabajando sin poder
  /// reconfirmar su licencia con el servidor (sin internet, o con un error
  /// pasajero al leerla) antes de pedir reconexión.
  static const int diasGracia = 7;
}

enum LicenseState {
  /// Licencia vigente (su fecha aún no pasa).
  vigente,

  /// Tenía licencia pero su fecha ya pasó.
  vencida,

  /// La tienda no tiene fecha de licencia asignada.
  sinLicencia,
}

/// El estado de la licencia de una tienda y hasta cuándo es válida.
class License {
  const License({required this.state, this.hasta});

  final LicenseState state;
  final DateTime? hasta;

  bool get vigente => state == LicenseState.vigente;

  /// Calcula el estado a partir de la fecha límite guardada en la tienda.
  factory License.fromHasta(DateTime? hasta, {DateTime? ahora}) {
    if (hasta == null) {
      return const License(state: LicenseState.sinLicencia);
    }
    final now = ahora ?? DateTime.now();
    return License(
      state: now.isBefore(hasta) ? LicenseState.vigente : LicenseState.vencida,
      hasta: hasta,
    );
  }
}

/// Último estado de licencia visto para una tienda, para el período de
/// gracia cuando no se puede confirmar con el servidor.
class LicenseCacheEntry {
  const LicenseCacheEntry({required this.hasta, required this.validadaEn});

  /// Fecha de licencia que se vio la última vez.
  final DateTime hasta;

  /// Cuándo el servidor confirmó por última vez que estaba vigente.
  final DateTime validadaEn;
}

/// Guarda y lee el último estado de licencia confirmado, por tienda. Es solo
/// una conveniencia para el período de gracia sin conexión; si falla, el
/// control de licencia sigue dependiendo del servidor.
abstract class LicenseCache {
  LicenseCacheEntry? read(String tiendaId);
  Future<void> save(String tiendaId, LicenseCacheEntry entry);
}

/// Decide el estado de licencia cuando NO se pudo leer la tienda del
/// servidor ni de la caché de Firestore (error o arranque en frío sin
/// conexión), apoyándose en lo último confirmado y en el período de gracia.
License licenseFromGrace(
  LicenseCacheEntry? cache, {
  DateTime? ahora,
  int diasGracia = LicenseConfig.diasGracia,
}) {
  if (cache == null) return const License(state: LicenseState.sinLicencia);
  final now = ahora ?? DateTime.now();
  final dentroDeGracia =
      now.difference(cache.validadaEn).inDays <= diasGracia;
  final antesDeVencer = now.isBefore(cache.hasta);
  return License(
    state: dentroDeGracia && antesDeVencer
        ? LicenseState.vigente
        : LicenseState.vencida,
    hasta: cache.hasta,
  );
}
