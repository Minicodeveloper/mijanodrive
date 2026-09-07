import 'package:geolocator/geolocator.dart';
import '../config/app_config.dart';

/// GPS del dispositivo. Con fallback a Tarapoto si el permiso falla,
/// para que la app nunca se quede colgada en una primera prueba.
class LocationService {
  static final LocationService instance = LocationService._();
  LocationService._();

  // Centro aproximado de Tarapoto (fallback demo).
  static const double _fbLat = -6.4869;
  static const double _fbLng = -76.3654;

  Future<bool> ensurePermission() async {
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return false;
      LocationPermission p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      return p == LocationPermission.always ||
          p == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  /// Devuelve la posición actual, o el fallback si algo falla y demoFallback=true.
  Future<Position> current() async {
    try {
      final ok = await ensurePermission();
      if (!ok) throw Exception('sin permiso');
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      if (AppConfig.demoFallback) {
        return Position(
          latitude: _fbLat,
          longitude: _fbLng,
          timestamp: DateTime.now(),
          accuracy: 50,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      }
      rethrow;
    }
  }

  /// Stream de posición en vivo (tracking del conductor/pasajero).
  Stream<Position> stream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }

  double distanceKm(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000.0;
  }
}
