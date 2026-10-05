import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/driver_model.dart';
import '../../services/firestore_service.dart';
import '../../config/app_config.dart';
import '../utils/marker_icons.dart';

class _DriverMarkerTracker {
  Driver driver;
  LatLng currentPosition;
  double currentRotation;

  LatLng? startPosition;
  double? startRotation;
  LatLng? targetPosition;
  double? targetRotation;
  DateTime? animationStart;
  static const animationDuration = Duration(milliseconds: 2500);

  _DriverMarkerTracker({
    required this.driver,
    required this.currentPosition,
  }) : currentRotation = 0.0;

  void updateTarget(Driver newDriver) {
    driver = newDriver;
    final newPos = LatLng(newDriver.currentLatitude!, newDriver.currentLongitude!);
    
    // Si no se movió, no hacemos nada
    if (newPos.latitude == currentPosition.latitude && newPos.longitude == currentPosition.longitude) {
      return;
    }

    startPosition = currentPosition;
    targetPosition = newPos;
    
    // Calcular rumbo (bearing) hacia la nueva posición
    final bearing = Geolocator.bearingBetween(
      startPosition!.latitude, startPosition!.longitude,
      targetPosition!.latitude, targetPosition!.longitude,
    );
    
    startRotation = currentRotation;
    targetRotation = bearing;
    animationStart = DateTime.now();
  }

  bool tick(DateTime now) {
    if (animationStart == null || startPosition == null || targetPosition == null) return false;

    final elapsed = now.difference(animationStart!);
    double t = elapsed.inMilliseconds / animationDuration.inMilliseconds;
    
    if (t >= 1.0) {
      currentPosition = targetPosition!;
      currentRotation = targetRotation!;
      animationStart = null;
      return true; // Última actualización antes de detenerse
    }

    // Interpolación lineal de la posición
    final lat = startPosition!.latitude + (targetPosition!.latitude - startPosition!.latitude) * t;
    final lng = startPosition!.longitude + (targetPosition!.longitude - startPosition!.longitude) * t;
    currentPosition = LatLng(lat, lng);

    // Interpolación del ángulo por el camino más corto
    double diff = (targetRotation! - startRotation!) % 360.0;
    if (diff > 180.0) {
      diff -= 360.0;
    } else if (diff < -180.0) {
      diff += 360.0;
    }
    currentRotation = startRotation! + diff * t;

    return true; // Hubo cambios
  }
}

class LiveDriversMap extends StatefulWidget {
  /// true = el mapa está ampliado (lo controla el panel que lo contiene).
  final bool expanded;

  /// Alterna entre ampliado y normal. Si es null, no se muestra el botón.
  final VoidCallback? onToggleExpanded;

  /// Alto del mapa. El panel lo agranda cuando [expanded] es true.
  final double height;

  const LiveDriversMap({
    super.key,
    this.expanded = false,
    this.onToggleExpanded,
    this.height = 350,
  });

  @override
  State<LiveDriversMap> createState() => _LiveDriversMapState();
}

class _LiveDriversMapState extends State<LiveDriversMap> {
  final Completer<GoogleMapController> _mapController = Completer();
  StreamSubscription<List<Driver>>? _driversSub;
  Timer? _animTimer;
  
  final Map<String, _DriverMarkerTracker> _trackers = {};
  Driver? _selectedDriver;
  bool _firstFitBounds = true;

  // Nivel de tamaño del icono según el zoom actual del mapa.
  int _iconLevel = MarkerIcons.defaultLevel;

  static const CameraPosition _fallbackPosition = CameraPosition(
    target: LatLng(-5.8942, -76.1142), // Yurimaguas
    zoom: 13,
  );

  @override
  void initState() {
    super.initState();
    MarkerIcons.init().then((_) {
      if (mounted) setState(() {});
    });
    
    _driversSub = FirestoreService.instance.allDrivers().listen((drivers) {
      if (!mounted) return;
      _updateDrivers(drivers);
    });

    _animTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _tick();
    });

    // Esc restaura el mapa ampliado (a nivel de teclado global, sin foco propio).
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void didUpdateWidget(covariant LiveDriversMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded != widget.expanded) {
      // El contenedor cambió de tamaño: se avisa al mapa para que recalcule.
      WidgetsBinding.instance.addPostFrameCallback((_) => _notifyResize());
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _driversSub?.cancel();
    _animTimer?.cancel();
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (widget.expanded &&
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        widget.onToggleExpanded != null) {
      widget.onToggleExpanded!();
      return true;
    }
    return false;
  }

  /// Fuerza al mapa a recalcular su tamaño tras ampliar/restaurar sin perder
  /// cámara ni zoom (desplazamiento de 0 px).
  Future<void> _notifyResize() async {
    if (!mounted || !_mapController.isCompleted) return;
    try {
      final controller = await _mapController.future;
      await controller.moveCamera(CameraUpdate.scrollBy(0, 0));
    } catch (_) {
      // El mapa pudo cerrarse durante el cambio; no hay nada que recalcular.
    }
  }

  /// Al terminar de mover/zoomear el mapa se elige el nivel de tamaño del
  /// icono. Los bitmaps ya están generados (caché), así que aquí solo se
  /// cambia de nivel y solo se redibuja si el nivel realmente cambió.
  Future<void> _onCameraIdle() async {
    if (!_mapController.isCompleted) return;
    try {
      final controller = await _mapController.future;
      final zoom = await controller.getZoomLevel();
      final level = MarkerIcons.levelForZoom(zoom);
      if (mounted && level != _iconLevel) {
        setState(() => _iconLevel = level);
      }
    } catch (_) {
      // Si el mapa ya no existe, se conserva el nivel actual.
    }
  }

  void _updateDrivers(List<Driver> drivers) {
    // Solo conductores aprobados, no bloqueados y con ubicación válida
    final validDrivers = drivers.where((d) => 
      d.status == 'approved' && 
      !d.isBlocked && 
      d.currentLatitude != null && 
      d.currentLongitude != null
    ).toList();

    final currentUids = validDrivers.map((d) => d.uid).toSet();
    
    // Eliminar conductores inactivos/bloqueados/sin ubicación
    _trackers.removeWhere((uid, _) => !currentUids.contains(uid));
    if (_selectedDriver != null && !currentUids.contains(_selectedDriver!.uid)) {
      _selectedDriver = null;
    }

    // Agregar o actualizar posiciones objetivo
    for (final d in validDrivers) {
      if (_trackers.containsKey(d.uid)) {
        _trackers[d.uid]!.updateTarget(d);
        if (_selectedDriver?.uid == d.uid) {
          _selectedDriver = d;
        }
      } else {
        _trackers[d.uid] = _DriverMarkerTracker(
          driver: d, 
          currentPosition: LatLng(d.currentLatitude!, d.currentLongitude!)
        );
      }
    }

    if (_firstFitBounds && _trackers.isNotEmpty) {
      _firstFitBounds = false;
      _fitBounds();
    }

    setState(() {}); // Redibujar mapa si se agregaron/quitaron o actualizó la metadata
  }

  void _tick() {
    bool needsUpdate = false;
    final now = DateTime.now();
    for (final t in _trackers.values) {
      if (t.tick(now)) {
        needsUpdate = true;
      }
    }
    if (needsUpdate && mounted) {
      setState(() {});
    }
  }

  void _fitBounds() {
    if (_trackers.isEmpty) return;
    
    double minLat = 90.0;
    double maxLat = -90.0;
    double minLng = 180.0;
    double maxLng = -180.0;

    for (final t in _trackers.values) {
      if (t.currentPosition.latitude < minLat) minLat = t.currentPosition.latitude;
      if (t.currentPosition.latitude > maxLat) maxLat = t.currentPosition.latitude;
      if (t.currentPosition.longitude < minLng) minLng = t.currentPosition.longitude;
      if (t.currentPosition.longitude > maxLng) maxLng = t.currentPosition.longitude;
    }

    _mapController.future.then((controller) {
      controller.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50.0, // padding
      ));
    });
  }

  String _getStateText(Driver d) {
    final now = DateTime.now();
    if (d.locationUpdatedAt == null || now.difference(d.locationUpdatedAt!) > AppConfig.staleLocationThreshold) {
      return 'Desactualizado';
    }
    return d.isAvailable ? 'Disponible' : 'Ocupado';
  }

  Color _getStateColor(String state) {
    switch (state) {
      case 'Disponible': return Colors.green;
      case 'Ocupado': return Colors.orange;
      default: return Colors.grey;
    }
  }

  Widget _buildDriverCard(Driver d) {
    final stateText = _getStateText(d);
    final stateColor = _getStateColor(stateText);
    
    String timeAgo = '—';
    if (d.locationUpdatedAt != null) {
      final mins = DateTime.now().difference(d.locationUpdatedAt!).inMinutes;
      timeAgo = mins < 1 ? 'hace instantes' : 'hace $mins min';
    }

    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(d.name.isNotEmpty ? d.name : 'Sin nombre',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: stateColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: stateColor),
                  ),
                  child: Text(stateText, style: TextStyle(color: stateColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 4),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _selectedDriver = null),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('📞 ${d.phone.isNotEmpty ? d.phone : 'Sin teléfono'}', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Text('🛵 ${d.plate} · ${d.vehicleModel.isNotEmpty ? d.vehicleModel : 'Vehículo'}', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Text('⏱️ Ubicación: $timeAgo', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Set<Marker> _buildMarkers() {
    final icon = MarkerIcons.iconForLevel(_iconLevel);
    if (icon == null) return {};

    return _trackers.values.map((t) {
      return Marker(
        markerId: MarkerId(t.driver.uid),
        position: t.currentPosition,
        rotation: t.currentRotation,
        anchor: const Offset(0.5, 0.5),
        flat: true, // Para que rote junto con el mapa y tenga la dirección correcta
        icon: icon,
        onTap: () {
          setState(() {
            if (_selectedDriver?.uid == t.driver.uid) {
              _selectedDriver = null; 
            } else {
              _selectedDriver = t.driver;
            }
          });
        },
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: _fallbackPosition,
              markers: _buildMarkers(),
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
              onMapCreated: (c) {
                if (!_mapController.isCompleted) {
                  _mapController.complete(c);
                }
                if (_trackers.isNotEmpty) {
                  _fitBounds();
                }
              },
              onCameraIdle: _onCameraIdle,
              onTap: (_) {
                if (_selectedDriver != null) {
                  setState(() => _selectedDriver = null);
                }
              },
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                ),
                child: const Text('Conectado en vivo', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            if (widget.onToggleExpanded != null)
              Positioned(
                top: 10,
                right: 10,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.95),
                  elevation: 2,
                  borderRadius: BorderRadius.circular(8),
                  child: IconButton(
                    tooltip: widget.expanded
                        ? 'Restaurar tamaño (Esc)'
                        : 'Ampliar mapa',
                    icon: Icon(
                      widget.expanded
                          ? Icons.fullscreen_exit
                          : Icons.fullscreen,
                    ),
                    onPressed: widget.onToggleExpanded,
                  ),
                ),
              ),
            if (_selectedDriver != null)
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: _buildDriverCard(_selectedDriver!),
              ),
          ],
        ),
      ),
    );
  }
}
