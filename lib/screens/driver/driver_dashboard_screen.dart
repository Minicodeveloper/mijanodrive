import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/trip_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../theme.dart';

/// mapa interactivo, aceptar carrera y botón S.O.S.
class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({Key? key}) : super(key: key);

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final _fs = FirestoreService.instance;
  final _auth = AuthService.instance;
  bool _available = true;
  GoogleMapController? _mapController;

  // Tarapoto default position
  static const LatLng _defaultPosition = LatLng(-6.4869, -76.3654);
  LatLng _currentPosition = _defaultPosition;

  // Controlador y posición inicial para Google Maps
  final Completer<GoogleMapController> _mapController = Completer();
  
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(-6.48694, -76.36472), // Coordenadas predeterminadas (Tarapoto)
    zoom: 14.0,
  );

  String get _city => _auth.currentUser?.city ?? 'Tarapoto';
  String get _uid => _auth.currentUser?.uid ?? 'demo-driver';

  @override
  void initState() {
    super.initState();
    _refreshCurrentPosition();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _moveCameraToCurrentPosition();
  }

  Future<void> _refreshCurrentPosition() async {
    try {
      final pos = await LocationService.instance.current();
      if (!mounted) return;

      final target = LatLng(pos.latitude, pos.longitude);
      setState(() => _currentPosition = target);
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(target, 15),
      );

      // El mapa y el marcador no dependen de que Firestore esté disponible.
      // Guardamos la posición en segundo plano para el panel administrativo.
      try {
        await _fs.updateDriverLocation(_uid, pos.latitude, pos.longitude);
      } catch (_) {}
    } catch (_) {}
  }

  Future<void> _moveCameraToCurrentPosition() async {
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(_currentPosition, 15),
    );
  }

  void _toggleAvailability(bool v) {
    setState(() => _available = v);
    _fs.setDriverAvailability(_uid, v);
  }

  Future<void> _accept(Trip trip) async {
    await _fs.updateTrip(trip.id, {'driverId': _uid, 'status': 'accepted'});
    if (mounted) {
      Navigator.of(
        context,
      ).pushNamed('/driver-active-trip', arguments: {'tripId': trip.id});
    }
  }

  Future<void> _sos() async {
    try {
      final pos = await LocationService.instance.current();

      await _fs.createSosAlert(
        driverId: _uid,
        latitude: pos.latitude,
        longitude: pos.longitude,
        city: _city,
      );

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(
            Icons.emergency,
            color: MijanoTheme.signal,
            size: 40,
          ),
          title: const Text('Alerta S.O.S. enviada'),
          content: Text(
            'La alerta fue enviada al panel de administración '
            'con tu ubicación GPS.\n\n'
            'Ubicación: ${pos.latitude.toStringAsFixed(5)}, '
            '${pos.longitude.toStringAsFixed(5)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar la alerta S.O.S.')),
      );
    }
  }

  Future<void> _sos() async {
    try {
      final pos = await LocationService.instance.current();

      await _fs.createSosAlert(
        driverId: _uid,
        latitude: pos.latitude,
        longitude: pos.longitude,
        city: _city,
      );

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(
            Icons.emergency,
            color: MijanoTheme.signal,
            size: 40,
          ),
          title: const Text('Alerta S.O.S. enviada'),
          content: Text(
            'La alerta fue enviada al panel de administración '
            'con tu ubicación GPS.\n\n'
            'Ubicación: ${pos.latitude.toStringAsFixed(5)}, '
            '${pos.longitude.toStringAsFixed(5)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo enviar la alerta S.O.S.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel del conductor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: MijanoTheme.signal,
        foregroundColor: Colors.white,
        onPressed: _sos,
        icon: const Icon(Icons.emergency),
        label: const Text('S.O.S.'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Stack(
        children: [
          // ==========================================
          // GOOGLE MAP BACKGROUND
          // ==========================================
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition,
              zoom: 15,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            onMapCreated: _onMapCreated,
            markers: {
              Marker(
                markerId: const MarkerId('driver'),
                position: _currentPosition,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueYellow,
                ),
                infoWindow: const InfoWindow(title: 'Tu ubicación'),
              ),
            },
          ),

          // ==========================================
          // AVAILABILITY TOGGLE (top overlay)
          // ==========================================
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: MijanoTheme.sol,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Icon(
                      _available ? Icons.check_circle : Icons.pause_circle,
                      color: MijanoTheme.ink,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _available ? 'Disponible para viajes' : 'No disponible',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: MijanoTheme.ink,
                        ),
                      ),
                    ),
                    Switch(
                      value: _available,
                      activeColor: MijanoTheme.ink,
                      onChanged: _toggleAvailability,
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Encabezado de ciudad
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 18),
                const SizedBox(width: 6),
                Text('Viajes en $_city',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),

          
          Expanded(
            flex: 2, 
            child: GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: _initialPosition,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              onMapCreated: (GoogleMapController controller) {
                _mapController.complete(controller);
              },
            ),
          ),

          // Lista de viajes pendientes abajo
          Expanded(
            flex: 2,
            child: !_available
                ? const Center(
                    child: Text('Actívate para recibir viajes',
                        style: TextStyle(color: Colors.black54)))
                : StreamBuilder<List<Trip>>(
                    stream: _fs.pendingTripsForCity(_city),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final trips = snap.data ?? [];
                      if (trips.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.two_wheeler,
                                  size: 48, color: Colors.black26),
                              SizedBox(height: 12),
                              Text('No hay viajes por ahora',
                                  style: TextStyle(color: Colors.black54)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: !_available
                          ? const Center(
                              child: Text(
                                'Actívate para recibir viajes',
                                style: TextStyle(color: Colors.black54),
                              ),
                            )
                          : StreamBuilder<List<Trip>>(
                              stream: _fs.pendingTripsForCity(_city),
                              builder: (context, snap) {
                                if (snap.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                final trips = snap.data ?? [];
                                if (trips.isEmpty) {
                                  return const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.two_wheeler,
                                          size: 48,
                                          color: Colors.black26,
                                        ),
                                        SizedBox(height: 12),
                                        Text(
                                          'No hay viajes por ahora',
                                          style: TextStyle(
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return ListView.separated(
                                  controller: scrollController,
                                  padding: const EdgeInsets.all(16),
                                  itemCount: trips.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (_, i) => _tripCard(trips[i]),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _tripCard(Trip trip) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MijanoTheme.cream,
        border: Border.all(color: MijanoTheme.ink, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trip_origin, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(trip.originAddress ?? 'Origen')),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(left: 7),
            child: SizedBox(
              height: 16,
              child: VerticalDivider(color: MijanoTheme.ink, thickness: 1),
            ),
          ),
          Row(
            children: [
              const Icon(
                Icons.location_on,
                size: 16,
                color: MijanoTheme.signal,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  trip.destinationAddress ?? 'Destino',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'S/ ${trip.fareAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              ElevatedButton(
                onPressed: () => _accept(trip),
                child: const Text('Aceptar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}