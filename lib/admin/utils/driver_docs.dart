import '../../models/driver_model.dart';

class DriverDocs {
  static const Map<String, String> requiredDocs = {
    'docFront': 'DNI (Anverso)',
    'docBack': 'DNI (Reverso)',
    'licensedDocument': 'Licencia de Conducir',
    'soatPhoto': 'SOAT / Seguro',
    'propertyCardPhoto': 'Tarjeta de Propiedad',
    'vehiclePhoto': 'Foto del Vehículo',
  };

  /// Normaliza cualquier estado a uno estándar de base de datos.
  static String normalizeStatus(String? status) {
    if (status == null) return 'pending';
    final s = status.toLowerCase();
    if (s == 'aprobado' || s == 'approved') return 'approved';
    if (s == 'rechazado' || s == 'rejected') return 'rejected';
    return 'pending';
  }

  /// Devuelve true solo si los 6 documentos obligatorios existen y están aprobados.
  static bool allApproved(Driver driver) {
    for (final key in requiredDocs.keys) {
      final url = driver.documents[key];
      if (url == null || url.toString().isEmpty) return false;
      
      final status = driver.documents['${key}Status'];
      if (normalizeStatus(status?.toString()) != 'approved') return false;
    }
    return true;
  }

  /// Devuelve una lista con las etiquetas (en español) de los documentos rechazados.
  static List<String> rejectedDocs(Driver driver) {
    final rejected = <String>[];
    for (final entry in requiredDocs.entries) {
      final key = entry.key;
      final label = entry.value;
      
      final status = driver.documents['${key}Status'];
      if (normalizeStatus(status?.toString()) == 'rejected') {
        rejected.add(label);
      }
    }
    return rejected;
  }

  /// Devuelve cuántos documentos faltan por aprobar (útil para el UI).
  static int pendingOrRejectedCount(Driver driver) {
    int count = 0;
    for (final key in requiredDocs.keys) {
      final status = driver.documents['${key}Status'];
      if (normalizeStatus(status?.toString()) != 'approved') {
        count++;
      }
    }
    return count;
  }
}
