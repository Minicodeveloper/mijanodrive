import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/trip_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../theme.dart';
import 'driver_trip_chat_screen.dart';

class DriverActiveMapScreen extends StatefulWidget {
  final Trip trip;

  const DriverActiveMapScreen({super.key, required this.trip});

  @override
  State<DriverActiveMapScreen> createState() => _DriverActiveMapScreenState();
}

class _DriverActiveMapScreenState extends State<DriverActiveMapScreen> {
  Position? _driverPosition;
  User? _passenger;
  StreamSubscription<Position>? _locationSubscription;
  bool _sendingSos = false;
  bool _sosSent = false;

  String get _driverId => AuthService.instance.currentUser?.uid ?? '';

  String get _driverName =>
      AuthService.instance.currentUser?.name ?? 'Conductor';

  @override
  void initState() {
    super.initState();
    _loadPassenger();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadPassenger() async {
    final passenger = await FirestoreService.instance.getUser(
      widget.trip.passengerId,
    );
    if (mounted) setState(() => _passenger = passenger);
  }

  Future<void> _startLocationTracking() async {
    try {
      final position = await LocationService.instance.current();
      if (!mounted) return;
      setState(() => _driverPosition = position);
      _locationSubscription = LocationService.instance.stream().listen((
        position,
      ) {
        if (mounted) setState(() => _driverPosition = position);
      });
    } catch (_) {}
  }

  Future<void> _callPassenger() async {
    final phone = _passenger?.phone.trim() ?? '';
    if (phone.isEmpty) {
      _showMessage('El pasajero no tiene un teléfono registrado.');
      return;
    }

    final launched = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!launched && mounted) {
      _showMessage('No se pudo abrir la aplicación de llamadas.');
    }
  }

  Future<void> _sendSos() async {
    if (_sendingSos || _sosSent) return;
    setState(() => _sendingSos = true);
    try {
      final position =
          _driverPosition ?? await LocationService.instance.current();
      await FirestoreService.instance.createSosAlert(
        driverId: _driverId,
        latitude: position.latitude,
        longitude: position.longitude,
        city: AuthService.instance.currentUser?.city ?? 'Tarapoto',
      );
      if (mounted) setState(() => _sosSent = true);
    } catch (_) {
      _showMessage('No se pudo enviar la alerta S.O.S.');
    } finally {
      if (mounted) setState(() => _sendingSos = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Set<Marker> get _markers {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('origin'),
        position: LatLng(
          widget.trip.origin.latitude,
          widget.trip.origin.longitude,
        ),
        infoWindow: InfoWindow(
          title: 'Recoger pasajero',
          snippet: widget.trip.originAddress ?? 'Origen',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(
          widget.trip.destination.latitude,
          widget.trip.destination.longitude,
        ),
        infoWindow: InfoWindow(
          title: 'Destino',
          snippet: widget.trip.destinationAddress ?? 'Destino',
        ),
      ),
    };
    final position = _driverPosition;
    if (position != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(position.latitude, position.longitude),
          infoWindow: const InfoWindow(title: 'Tu ubicación'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final origin = LatLng(
      widget.trip.origin.latitude,
      widget.trip.origin.longitude,
    );

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: origin, zoom: 14),
            onMapCreated: (controller) {
              final destination = LatLng(
                widget.trip.destination.latitude,
                widget.trip.destination.longitude,
              );
              if (origin.latitude != destination.latitude ||
                  origin.longitude != destination.longitude) {
                controller.moveCamera(
                  CameraUpdate.newLatLngBounds(
                    LatLngBounds(
                      southwest: LatLng(
                        origin.latitude < destination.latitude
                            ? origin.latitude
                            : destination.latitude,
                        origin.longitude < destination.longitude
                            ? origin.longitude
                            : destination.longitude,
                      ),
                      northeast: LatLng(
                        origin.latitude > destination.latitude
                            ? origin.latitude
                            : destination.latitude,
                        origin.longitude > destination.longitude
                            ? origin.longitude
                            : destination.longitude,
                      ),
                    ),
                    72,
                  ),
                );
              }
            },
            markers: _markers,
            myLocationEnabled: _driverPosition != null,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topLeft,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  elevation: 3,
                  child: IconButton(
                    tooltip: 'Volver',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: Material(
                color: Colors.white,
                elevation: 8,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _passenger?.name ?? 'Pasajero',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.trip.originAddress ?? 'Punto de recojo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => DriverTripChatScreen(
                                    tripId: widget.trip.id,
                                    senderId: _driverId,
                                    senderName: _driverName,
                                    conversationTitle:
                                        _passenger?.name ?? 'Pasajero',
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: const Text('Chat'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _callPassenger,
                              icon: const Icon(Icons.call_outlined),
                              label: const Text('Llamar'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _sendingSos || _sosSent
                                  ? null
                                  : _sendSos,
                              icon: Icon(
                                _sosSent ? Icons.check : Icons.emergency,
                              ),
                              label: Text(_sosSent ? 'Enviado' : 'S.O.S.'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MijanoTheme.signal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pantalla del conductor para gestionar el viaje que acaba de aceptar.
class DriverActiveTripScreen extends StatelessWidget {
  final String tripId;

  const DriverActiveTripScreen({super.key, required this.tripId});

  String _statusLabel(TripStatus status) {
    switch (status) {
      case TripStatus.accepted:
        return 'Dirígete al punto de recojo';
      case TripStatus.active:
        return 'Viaje en curso';
      case TripStatus.completed:
        return 'Viaje completado';
      case TripStatus.cancelled:
        return 'Viaje cancelado';
      case TripStatus.pending:
        return 'Esperando confirmación';
    }
  }

  Future<void> _updateStatus(BuildContext context, String status) async {
    try {
      await FirestoreService.instance.updateTrip(tripId, {
        'status': status,
        if (status == 'completed') 'completedAt': DateTime.now(),
      });
      if (context.mounted && status == 'completed') {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar el viaje.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Trip?>(
      stream: FirestoreService.instance.tripStream(tripId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('No se pudo cargar el viaje.')),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final trip = snapshot.data;
        if (trip == null) {
          return const Scaffold(
            body: Center(child: Text('Este viaje ya no está disponible.')),
          );
        }

        final isAccepted = trip.status == TripStatus.accepted;
        final isActive = trip.status == TripStatus.active;
        final isFinished =
            trip.status == TripStatus.completed ||
            trip.status == TripStatus.cancelled;

        return Scaffold(
          appBar: AppBar(title: const Text('Viaje asignado')),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  isFinished ? Icons.check_circle : Icons.directions_car,
                  size: 72,
                  color: isFinished
                      ? Colors.green
                      : Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 24),
                Text(
                  _statusLabel(trip.status),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 32),
                _TripDetail(
                  label: 'Origen',
                  value: trip.originAddress ?? 'Ubicación de recojo',
                ),
                _TripDetail(
                  label: 'Destino',
                  value: trip.destinationAddress ?? 'Destino del pasajero',
                ),
                _TripDetail(
                  label: 'Tarifa',
                  value: 'S/. ${trip.fareAmount.toStringAsFixed(2)}',
                ),
                _TripDetail(label: 'Pago', value: trip.paymentMethod.name),
                const Spacer(),
                if (isAccepted)
                  FilledButton.icon(
                    onPressed: () => _updateStatus(context, 'active'),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Iniciar viaje'),
                  ),
                if (isActive)
                  FilledButton.icon(
                    onPressed: () => _updateStatus(context, 'completed'),
                    icon: const Icon(Icons.flag),
                    label: const Text('Finalizar viaje'),
                  ),
                if (isFinished)
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Volver al panel'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TripDetail extends StatelessWidget {
  final String label;
  final String value;

  const _TripDetail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}
