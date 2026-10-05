import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Helper para cargar y gestionar iconos personalizados de marcadores en Google Maps.
class MarkerIcons {
  static BitmapDescriptor? _mototaxiIcon;
  static bool _isLoading = false;

  /// Obtiene el icono del mototaxi. Si aún no está cargado, devuelve null.
  /// 
  /// Para usarlo, llama a [init] al inicio de la aplicación o del mapa,
  /// y luego usa [mototaxiIcon] para obtener el icono en los marcadores.
  static BitmapDescriptor? get mototaxiIcon => _mototaxiIcon;

  /// Inicializa los iconos cargándolos desde los assets y redimensionándolos.
  /// Debe ser llamado antes de intentar usar [mototaxiIcon].
  static Future<void> init() async {
    if (_mototaxiIcon != null || _isLoading) return;
    
    _isLoading = true;
    try {
      // Cargar desde assets
      final ByteData data = await rootBundle.load('assets/images/ic_mototaxi_marker.png');
      
      // Decodificar y redimensionar. Un ancho de ~48 es adecuado para marcadores.
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 48,
      );
      final ui.FrameInfo fi = await codec.getNextFrame();
      
      // Volver a codificar a PNG para pasarlo a BitmapDescriptor
      final ByteData? resizedData = await fi.image.toByteData(format: ui.ImageByteFormat.png);
      
      if (resizedData != null) {
        final Uint8List resizedBytes = resizedData.buffer.asUint8List();
        // Usar bytes permite que funcione correctamente en Web
        _mototaxiIcon = BitmapDescriptor.bytes(resizedBytes);
      }
    } catch (e) {
      // Si falla la carga del asset, _mototaxiIcon quedará null
      // y la lógica de los mapas (ej: _mototaxiIcon == null) evitará dibujar el marcador.
    } finally {
      _isLoading = false;
    }
  }
}