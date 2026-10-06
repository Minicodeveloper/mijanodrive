import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Iconos personalizados de marcadores para Google Maps (panel web y app móvil).
///
/// Regla clave: el tamaño del marcador se declara SIEMPRE en píxeles lógicos
/// (width/height). Si se pasa el PNG crudo (480x630) sin tamaño, Android lo
/// dibuja a su tamaño real y el marcador sale gigante.
///
/// Para el panel admin se pre-generan varios niveles según el zoom; para la app
/// del pasajero se usa [mototaxiWithWidth] con un ancho fijo.
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

  // Caché del PNG original y de los iconos ya generados por ancho.
  static Uint8List? _source;
  static double _aspect = 1.0; // alto / ancho del PNG
  static final Map<int, BitmapDescriptor> _byWidth = {};

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

  /// Genera todos los niveles (panel admin). Se puede llamar varias veces:
  /// la carga real ocurre una sola vez y se reutiliza (caché).
  static Future<void> init() => _initFuture ??= _loadLevels();

  static Future<void> _loadLevels() async {
    for (var i = 0; i < _levelWidths.length; i++) {
      _icons[i] = await mototaxiWithWidth(_levelWidths[i]);
    }
    // Si alguno falló, permite reintentar en la próxima llamada.
    if (_icons.any((icon) => icon == null)) _initFuture = null;
  }

  /// Marcador del mototaxi con ancho lógico fijo [width] (el alto sale de la
  /// proporción del PNG). Resultado cacheado por ancho. Devuelve null si el
  /// asset no se pudo cargar (el llamador decide el respaldo).
  static Future<BitmapDescriptor?> mototaxiWithWidth(double width) async {
    final key = width.round();
    final cached = _byWidth[key];
    if (cached != null) return cached;

    try {
      await _ensureSource();
      final Uint8List source = _source!;

      // Se rasteriza a la densidad real de la pantalla para que se vea nítido,
      // pero se declara el tamaño LÓGICO para que no dependa del pixel ratio.
      final double rawDpr =
          ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1.0;
      final double dpr = rawDpr < 1.0 ? 1.0 : (rawDpr > 3.0 ? 3.0 : rawDpr);

      final ui.Codec codec = await ui.instantiateImageCodec(
        source,
        targetWidth: (width * dpr).round(),
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ByteData? png =
          await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      if (png == null) return null;

      // BitmapDescriptor.bytes (no .asset) para que funcione también en web.
      final icon = BitmapDescriptor.bytes(
        png.buffer.asUint8List(),
        width: width,
        height: width * _aspect,
      );
      _byWidth[key] = icon;
      return icon;
    } catch (_) {
      // Sin icono: el mapa no dibuja el marcador personalizado.
      return null;
    }
  }

  static Future<void> _ensureSource() async {
    if (_source != null) return;
    final ByteData data = await rootBundle.load(_assetPath);
    final Uint8List bytes = data.buffer.asUint8List();

    // Proporción original (alto / ancho) para no deformar el icono.
    final ui.Codec probe = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo probeFrame = await probe.getNextFrame();
    _aspect = probeFrame.image.height / probeFrame.image.width;
    probeFrame.image.dispose();
    probe.dispose();

    _source = bytes;
  }
}
