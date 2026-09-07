/// Configuración central de Mijano Drive.
/// La app es self-contained: solo usa Firebase (Firestore) y Google Maps.
class AppConfig {
  /// Google Maps / Places (misma key del AndroidManifest).
  static const String googleMapsKey =
      'AIzaSyD6cjdfoAhxKfZr--aCqvshyiS8jB7V_Sw';

  /// Modo demo: si una API externa falla, la app sigue con datos simulados
  /// en vez de crashear (ideal para primeras pruebas).
  static const bool demoFallback = true;

  /// Ciudades con geofencing (deben existir en Firestore/cities).
  static const List<String> cities = ['Yurimaguas', 'Tarapoto', 'Iquitos'];

  /// Tarifa base por ciudad (fallback si Firestore no responde).
  static const Map<String, Map<String, double>> cityTariffs = {
    'Yurimaguas': {'base': 3.5, 'perKm': 2.0},
    'Tarapoto': {'base': 3.0, 'perKm': 1.8},
    'Iquitos': {'base': 3.5, 'perKm': 2.1},
  };
}
