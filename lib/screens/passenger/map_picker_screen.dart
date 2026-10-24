import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart' as geo;
import '../../services/location_service.dart';
import '../../theme.dart';

class PickedLocation {
  final double lat;
  final double lng;
  final String address;

  PickedLocation({required this.lat, required this.lng, required this.address});
}

class MapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const MapPickerScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentCenter;
  String _currentAddress = 'Ubicación seleccionada';
  bool _isMoving = false;
  bool _isLoadingAddress = false;
  Timer? _debounceTimer;

  // Perú bounds (aprox) para evitar que se mueva por todo el mundo
  final CameraTargetBounds _peruBounds = CameraTargetBounds(
    LatLngBounds(
      southwest: const LatLng(-18.35, -81.33),
      northeast: const LatLng(-0.03, -68.65),
    ),
  );

  @override
  void initState() {
    super.initState();
    _currentCenter = (widget.initialLat != null && widget.initialLng != null) 
        ? LatLng(widget.initialLat!, widget.initialLng!) 
        : null;
        
    if (_currentCenter == null) {
      _loadCurrentLocation();
    } else {
      _fetchAddress(_currentCenter!);
    }
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final pos = await LocationService.instance.current();
      if (!mounted) return;
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _currentCenter = latLng;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
      _fetchAddress(latLng);
    } catch (_) {
      if (!mounted) return;
      // Fallback a Lima si falla la ubicación.
      const fallback = LatLng(-12.0464, -77.0428);
      setState(() {
        _currentCenter = fallback;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(fallback, 14));
      _fetchAddress(fallback);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo obtener la ubicación actual.')),
      );
    }
  }

  void _onCameraMoveStarted() {
    if (!mounted) return;
    setState(() {
      _isMoving = true;
    });
  }

  void _onCameraMove(CameraPosition position) {
    _currentCenter = position.target;
  }

  void _onCameraIdle() {
    if (!mounted) return;
    setState(() {
      _isMoving = false;
    });
    if (_currentCenter != null) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 600), () {
        _fetchAddress(_currentCenter!);
      });
    }
  }

  Future<void> _fetchAddress(LatLng latLng) async {
    if (!mounted) return;
    setState(() => _isLoadingAddress = true);
    try {
      final placemarks = await geo.placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        final parts = [p.street, p.subLocality, p.locality].where((e) => e != null && e.isNotEmpty).toList();
        setState(() {
          _currentAddress = parts.isNotEmpty ? parts.join(', ') : 'Ubicación seleccionada';
          _isLoadingAddress = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentAddress = '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}';
        _isLoadingAddress = false;
      });
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialPos = _currentCenter ?? const LatLng(-12.0464, -77.0428);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Elegir en el mapa'),
        backgroundColor: MijanoTheme.sol,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: initialPos, zoom: 16),
            onMapCreated: (ctrl) => _mapController = ctrl,
            onCameraMoveStarted: _onCameraMoveStarted,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            cameraTargetBounds: _peruBounds,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          
          // Pin central
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(0, _isMoving ? -15 : -10, 0),
              child: const Icon(
                Icons.location_on,
                size: 50,
                color: MijanoTheme.ink,
              ),
            ),
          ),
          
          // Botón Mi Ubicación
          Positioned(
            right: 16,
            bottom: 150,
            child: FloatingActionButton(
              backgroundColor: MijanoTheme.sol,
              foregroundColor: MijanoTheme.ink,
              onPressed: _loadCurrentLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
          
          // Tarjeta inferior
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.place, color: MijanoTheme.sol),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _isLoadingAddress || _isMoving
                            ? const Text('Buscando dirección...', style: TextStyle(color: Colors.black54))
                            : Text(
                                _currentAddress,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: (_isMoving || _isLoadingAddress || _currentCenter == null)
                        ? null
                        : () {
                            Navigator.of(context).pop(
                              PickedLocation(
                                lat: _currentCenter!.latitude,
                                lng: _currentCenter!.longitude,
                                address: _currentAddress,
                              ),
                            );
                          },
                    child: const Text('Confirmar ubicación'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
