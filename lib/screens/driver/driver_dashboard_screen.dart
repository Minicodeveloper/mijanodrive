import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/trip_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../theme.dart';
import 'driver_active_trip_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final _fs = FirestoreService.instance;
  final _auth = AuthService.instance;

  bool _available = true;

  final Completer<GoogleMapController> _mapController = Completer();

  Position? _driverPosition;
  StreamSubscription<Position>? _locationSubscription;

  // Distancia máxima para recibir/mostrar un viaje.
  static const double _maxTripDistanceKm = 3.0;

  // Viajes que ya fueron mostrados como alerta a este conductor.
  final Set<String> _shownAlertTripIds = {};

  // Viajes que este conductor decidió rechazar.
  final Set<String> _rejectedTripIds = {};

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(-6.48694, -76.36472),
    zoom: 14.0,
  );

  String get _city => _auth.currentUser?.city ?? 'Tarapoto';

  String get _uid => _auth.currentUser?.uid ?? 'demo-driver';

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  /// Obtiene la ubicación inicial y luego mantiene actualizada
  /// la ubicación del conductor.
  Future<void> _startLocationTracking() async {
    try {
      final pos = await LocationService.instance.current();

      if (!mounted) return;

      setState(() {
        _driverPosition = pos;
      });

      await _fs.updateDriverLocation(_uid, pos.latitude, pos.longitude);

      _locationSubscription = LocationService.instance.stream().listen((
        pos,
      ) async {
        if (!mounted) return;

        setState(() {
          _driverPosition = pos;
        });

        try {
          await _fs.updateDriverLocation(_uid, pos.latitude, pos.longitude);
        } catch (_) {}
      });
    } catch (_) {
      // Si no hay permisos o GPS, LocationService manejará
      // el fallback de demostración cuando esté habilitado.
    }
  }

  void _toggleAvailability(bool value) {
    setState(() {
      _available = value;
    });

    _fs.setDriverAvailability(_uid, value);
  }

  Future<void> _accept(Trip trip) async {
    try {
      await _fs.updateTrip(trip.id, {'driverId': _uid, 'status': 'accepted'});

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DriverActiveMapScreen(trip: trip),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo aceptar el viaje')),
      );
    }
  }

  Future<void> _reject(Trip trip) async {
    setState(() {
      _rejectedTripIds.add(trip.id);
    });
  }

  /// Calcula la distancia entre el conductor y el origen del viaje.
  double? _tripDistanceKm(Trip trip) {
    final position = _driverPosition;

    if (position == null) {
      return null;
    }

    return LocationService.instance.distanceKm(
      position.latitude,
      position.longitude,
      trip.origin.latitude,
      trip.origin.longitude,
    );
  }

  /// Filtra únicamente los viajes cercanos al conductor.
  List<Trip> _nearbyTrips(List<Trip> trips) {
    if (_driverPosition == null) {
      return [];
    }

    return trips.where((trip) {
      if (_rejectedTripIds.contains(trip.id)) {
        return false;
      }

      final distance = _tripDistanceKm(trip);

      return distance != null && distance <= _maxTripDistanceKm;
    }).toList();
  }

  /// Muestra una alerta cuando aparece un nuevo viaje cercano.
  void _checkForNewNearbyTripAlerts(List<Trip> trips) {
    if (!_available || _driverPosition == null || trips.isEmpty) {
      return;
    }

    final nearbyTrips = _nearbyTrips(trips);

    for (final trip in nearbyTrips) {
      if (_shownAlertTripIds.contains(trip.id)) {
        continue;
      }

      _shownAlertTripIds.add(trip.id);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_available) return;

        _showTripAlert(trip);
      });

      // Solo mostramos una alerta por actualización para
      // evitar que aparezcan varios modales juntos.
      break;
    }
  }

  Future<void> _showTripAlert(Trip trip) async {
    final distance = _tripDistanceKm(trip);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.notifications_active, color: MijanoTheme.sol),
              SizedBox(width: 8),
              Expanded(child: Text('Nuevo viaje cercano')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hay un pasajero solicitando un viaje cerca de tu ubicación.',
              ),
              const SizedBox(height: 16),
              _alertInfoRow(
                Icons.trip_origin,
                'Origen',
                trip.originAddress ?? 'Origen no disponible',
              ),
              const SizedBox(height: 10),
              _alertInfoRow(
                Icons.location_on,
                'Destino',
                trip.destinationAddress ?? 'Destino no disponible',
              ),
              const SizedBox(height: 10),
              _alertInfoRow(
                Icons.payments,
                'Tarifa',
                'S/ ${trip.fareAmount.toStringAsFixed(2)}',
              ),
              if (distance != null) ...[
                const SizedBox(height: 10),
                _alertInfoRow(
                  Icons.near_me,
                  'Distancia',
                  '${distance.toStringAsFixed(2)} km',
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _reject(trip);
              },
              child: const Text('Rechazar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _accept(trip);
              },
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }

  Widget _alertInfoRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 14),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
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
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar la alerta S.O.S.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: MijanoTheme.signal,
        foregroundColor: Colors.white,
        onPressed: _sos,
        icon: const Icon(Icons.emergency),
        label: const Text('S.O.S.'),
      ),
      body: Column(
        children: [
          // Estado de disponibilidad.
          Container(
            color: MijanoTheme.sol,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  _available ? Icons.check_circle : Icons.pause_circle,
                  color: MijanoTheme.ink,
                  size: 20,
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
                  activeThumbColor: MijanoTheme.ink,
                  onChanged: _toggleAvailability,
                ),
              ],
            ),
          ),

          // Ciudad.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Viajes en $_city',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (_driverPosition != null)
                  const Row(
                    children: [
                      Icon(Icons.gps_fixed, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'GPS activo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Mapa.
          Expanded(
            flex: 2,
            child: GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: _initialPosition,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              onMapCreated: (GoogleMapController controller) {
                if (!_mapController.isCompleted) {
                  _mapController.complete(controller);
                }
              },
            ),
          ),

          // Viajes pendientes.
          Expanded(
            flex: 2,
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
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (_driverPosition == null) {
                        return const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text(
                                'Obteniendo ubicación GPS...',
                                style: TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        );
                      }

                      final trips = snap.data ?? [];

                      final nearbyTrips = _nearbyTrips(trips);

                      // Revisa si llegó un nuevo viaje cercano.
                      _checkForNewNearbyTripAlerts(trips);

                      if (nearbyTrips.isEmpty) {
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
                                'No hay viajes cercanos por ahora',
                                style: TextStyle(color: Colors.black54),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Se muestran viajes dentro de 3 km',
                                style: TextStyle(
                                  color: Colors.black38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: nearbyTrips.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          return _tripCard(nearbyTrips[i]);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tripCard(Trip trip) {
    final distance = _tripDistanceKm(trip);

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'S/ ${trip.fareAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (distance != null)
                    Text(
                      '${distance.toStringAsFixed(2)} km de distancia',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                ],
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
