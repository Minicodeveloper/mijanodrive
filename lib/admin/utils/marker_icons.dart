import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Iconos personalizados de marcadores para Google Maps.
///
/// El mototaxi se genera UNA sola vez en varios tamaños (niveles) con un ancho
/// lógico fijo en píxeles. Así el icono nunca se ve gigante al alejar el mapa
/// y tampoco crece sin control al acercarlo: el tamaño siempre queda entre
/// [minWidth] y [maxWidth].
class MarkerIcons {
  MarkerIcons._();

  static const String _assetPath = 'assets/images/ic_mototaxi_marker.png';

  /// Ancho lógico (px en pantalla) por nivel, de más lejos a más cerca.
  static const List<double> _levelWidths = [26, 32, 38, 44];

  /// Zoom mínimo (inclusive) desde el cual aplica cada nivel.
  /// Debe tener la misma longitud que [_levelWidths].
  static const List<double> _levelMinZoom = [0, 12, 14, 16];

  static double get minWidth => _levelWidths.first;
  static double get maxWidth => _levelWidths.last;

  /// Nivel usado antes de conocer el zoom real del mapa.
  static const int defaultLevel = 1;

  static final List<BitmapDescriptor?> _icons =
      List<BitmapDescriptor?>.filled(_levelWidths.length, null);
  static Future<void>? _initFuture;

  /// Devuelve el nivel de icono que corresponde a un nivel de zoom.
  static int levelForZoom(double zoom) {
    var level = 0;
    for (var i = 0; i < _levelMinZoom.length; i++) {
      if (zoom >= _levelMinZoom[i]) level = i;
    }
    return level;
  }

  /// Icono del nivel indicado, o null si aún no se cargó.
  static BitmapDescriptor? iconForLevel(int level) {
    if (level < 0 || level >= _icons.length) return null;
    return _icons[level];
  }

  /// Compatibilidad: icono de tamaño medio.
  static BitmapDescriptor? get mototaxiIcon => iconForLevel(defaultLevel);

  /// Carga el asset y genera todos los niveles. Se puede llamar varias veces:
  /// la carga real ocurre una sola vez y se reutiliza (caché).
  static Future<void> init() => _initFuture ??= _load();

  static Future<void> _load() async {
    try {
      final ByteData data = await rootBundle.load(_assetPath);
      final Uint8List source = data.buffer.asUint8List();

      // Proporción original (alto / ancho) para no deformar el icono.
      final ui.Codec probe = await ui.instantiateImageCodec(source);
      final ui.FrameInfo probeFrame = await probe.getNextFrame();
      final double aspect =
          probeFrame.image.height / probeFrame.image.width;
      probeFrame.image.dispose();
      probe.dispose();

      // Se rasteriza a la densidad real de la pantalla para que se vea nítido,
      // pero se declara el tamaño LÓGICO (width/height) para que no dependa
      // del pixel ratio del dispositivo.
      final double rawDpr =
          ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1.0;
      final double dpr = rawDpr < 1.0 ? 1.0 : (rawDpr > 3.0 ? 3.0 : rawDpr);

      for (var i = 0; i < _levelWidths.length; i++) {
        final double w = _levelWidths[i];
        final ui.Codec codec = await ui.instantiateImageCodec(
          source,
          targetWidth: (w * dpr).round(),
        );
        final ui.FrameInfo frame = await codec.getNextFrame();
        final ByteData? png =
            await frame.image.toByteData(format: ui.ImageByteFormat.png);
        frame.image.dispose();
        codec.dispose();
        if (png == null) continue;

        // BitmapDescriptor.bytes (no .asset) para que funcione en Flutter Web.
        _icons[i] = BitmapDescriptor.bytes(
          png.buffer.asUint8List(),
          width: w,
          height: w * aspect,
        );
      }
    } catch (_) {
      // Si falla la carga, los niveles quedan en null y el mapa no dibuja
      // marcadores (no se usa el pin rojo por defecto como respaldo).
      _initFuture = null; // permite reintentar en la próxima llamada
    }
  }
}
