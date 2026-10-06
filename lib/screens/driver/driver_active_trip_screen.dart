import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/trip_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/directions_service.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../theme.dart';
import '../../config/app_config.dart';
import '../../utils/marker_icons.dart';
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
  BitmapDescriptor? _mototaxiIcon;
  StreamSubscription<Position>? _locationSubscription;
  final Set<Polyline> _polylines = {};
  bool _sendingSos = false;
  bool _sosSent = false;
  bool _updatingStatus = false;
  TripStatus? _optimisticStatus;
  TripStatus? _lastRouteStatus;
  LatLng? _lastRouteOrigin;
  int _routeRequestId = 0;

  String get _driverId => AuthService.instance.currentUser?.uid ?? '';

  String get _driverName =>
      AuthService.instance.currentUser?.name ?? 'Conductor';

  DateTime? _lastPublishedTime;

  @override
  void initState() {
    super.initState();
    _loadPassenger();
    _loadCustomMarker();
    _startLocationTracking();
  }

  Future<void> _loadCustomMarker() async {
    final icon = await MarkerIcons.mototaxiWithWidth(36);
    if (!mounted || icon == null) return;
    setState(() => _mototaxiIcon = icon);
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

      _publishLocation(position);

      _locationSubscription = LocationService.instance.stream().listen((
        position,
      ) {
        if (!mounted) return;
        setState(() => _driverPosition = position);
        _publishLocation(position);
      });
    } catch (_) {}
  }

  void _publishLocation(Position pos) {
    final now = DateTime.now();
    if (_lastPublishedTime != null) {
      final diff = now.difference(_lastPublishedTime!);
      if (diff < AppConfig.locationPublishInterval) {
        return; // Throttled
      }
    }

    _lastPublishedTime = now;
    // Dispara y olvida (throttle aplicado)
    FirestoreService.instance
        .updateDriverLocation(_driverId, pos.latitude, pos.longitude)
        .catchError((_) {});
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

  Future<void> _openGoogleMapsNavigation(LatLng destination) async {
    final navigationUri = Uri.parse(
      'google.navigation:q=${destination.latitude},${destination.longitude}&mode=d',
    );
    final webMapsUri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${destination.latitude},${destination.longitude}',
      'travelmode': 'driving',
    });

    try {
      // ignore: deprecated_member_use
      final canOpenNavigation = await canLaunchUrl(navigationUri);
      final uri = canOpenNavigation ? navigationUri : webMapsUri;
      // ignore: deprecated_member_use
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _showMessage('No se pudo abrir Google Maps');
      }
    } catch (e) {
      if (mounted) _showMessage('Error al abrir el mapa: $e');
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

  Set<Marker> _markers(Trip trip) {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('origin'),
        position: LatLng(trip.origin.latitude, trip.origin.longitude),
        infoWindow: InfoWindow(
          title: 'Recoger pasajero',
          snippet: trip.originAddress ?? 'Origen',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(trip.destination.latitude, trip.destination.longitude),
        infoWindow: InfoWindow(
          title: 'Destino',
          snippet: trip.destinationAddress ?? 'Destino',
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
          icon:
              _mototaxiIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }
    return markers;
  }

  String _statusLabel(TripStatus status) {
    switch (status) {
      case TripStatus.pending:
        return 'Esperando confirmación';
      case TripStatus.accepted:
        return 'En camino al pasajero';
      case TripStatus.arrived:
        return 'Llegaste al punto de recojo';
      case TripStatus.active:
        return 'Viaje en curso';
      case TripStatus.completed:
        return 'Viaje finalizado';
      case TripStatus.cancelled:
        return 'Viaje cancelado';
    }
  }

  String? _nextStatusButtonLabel(TripStatus status) {
    switch (status) {
      case TripStatus.accepted:
        return 'Indicar que llegué';
      case TripStatus.arrived:
        return 'Iniciar viaje';
      case TripStatus.active:
        return 'Finalizar viaje';
      case TripStatus.completed:
        return 'Viaje finalizado';
      case TripStatus.pending:
      case TripStatus.cancelled:
        return null;
    }
  }

  Future<void> _advanceTrip(Trip trip, TripStatus status) async {
    final nextStatus = switch (status) {
      TripStatus.accepted => TripStatus.arrived,
      TripStatus.arrived => TripStatus.active,
      TripStatus.active => TripStatus.completed,
      _ => null,
    };
    if (nextStatus == null || _updatingStatus) return;

    setState(() {
      _updatingStatus = true;
      _optimisticStatus = nextStatus;
    });
    try {
      await FirestoreService.instance.updateTrip(trip.id, {
        'status': nextStatus.name,
        if (nextStatus == TripStatus.completed) 'completedAt': DateTime.now(),
      });
    } catch (_) {
      if (mounted) {
        setState(() => _optimisticStatus = null);
        _showMessage('No se pudo actualizar el estado del viaje.');
      }
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  void _scheduleRouteUpdate(Trip trip, TripStatus status) {
    if (status != TripStatus.accepted && status != TripStatus.active) {
      _routeRequestId++;
      if (_polylines.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(_polylines.clear);
        });
      }
      _lastRouteStatus = status;
      return;
    }

    final pickup = LatLng(trip.origin.latitude, trip.origin.longitude);
    final destination = LatLng(
      trip.destination.latitude,
      trip.destination.longitude,
    );
    final driverPosition = _driverPosition;
    if (status == TripStatus.accepted && driverPosition == null) return;
    final routeOrigin = status == TripStatus.active
        ? pickup
        : driverPosition == null
        ? pickup
        : LatLng(driverPosition.latitude, driverPosition.longitude);

    final statusChanged = _lastRouteStatus != status;
    final driverMoved =
        status == TripStatus.accepted &&
        _lastRouteOrigin != null &&
        Geolocator.distanceBetween(
              _lastRouteOrigin!.latitude,
              _lastRouteOrigin!.longitude,
              routeOrigin.latitude,
              routeOrigin.longitude,
            ) >=
            250;
    if (!statusChanged && !driverMoved) return;

    _lastRouteStatus = status;
    _lastRouteOrigin = routeOrigin;
    final requestId = ++_routeRequestId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final route = await DirectionsService.routeCoordinates(
        routeOrigin,
        status == TripStatus.active ? destination : pickup,
      );
      if (!mounted || requestId != _routeRequestId) return;
      setState(() {
        _polylines
          ..clear()
          ..add(
            Polyline(
              polylineId: const PolylineId('driver_trip_route'),
              color: status == TripStatus.active ? Colors.green : Colors.blue,
              width: 5,
              points: route,
            ),
          );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Trip?>(
      stream: FirestoreService.instance.tripStream(widget.trip.id),
      initialData: widget.trip,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('No se pudo actualizar el viaje.')),
          );
        }
        final trip = snapshot.data ?? widget.trip;
        final status = _optimisticStatus ?? trip.status;
        _scheduleRouteUpdate(trip, status);
        final origin = LatLng(trip.origin.latitude, trip.origin.longitude);
        final navigationDestination = status == TripStatus.active
            ? LatLng(trip.destination.latitude, trip.destination.longitude)
            : LatLng(trip.origin.latitude, trip.origin.longitude);
        final canNavigate =
            status == TripStatus.accepted ||
            status == TripStatus.arrived ||
            status == TripStatus.active;

        return Scaffold(
          body: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(target: origin, zoom: 14),
                onMapCreated: (controller) {
                  final destination = LatLng(
                    trip.destination.latitude,
                    trip.destination.longitude,
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
                markers: _markers(trip),
                polylines: _polylines,
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
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  status == TripStatus.active
                                      ? trip.destinationAddress ?? 'Destino'
                                      : trip.originAddress ?? 'Punto de recojo',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ),
                              if (canNavigate)
                                IconButton(
                                  onPressed: () => _openGoogleMapsNavigation(
                                    navigationDestination,
                                  ),
                                  icon: const Icon(
                                    Icons.navigation,
                                    color: Colors.blue,
                                  ),
                                  tooltip: 'Navegar en Google Maps',
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _statusLabel(status),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: MijanoTheme.ink,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => DriverTripChatScreen(
                                        tripId: trip.id,
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
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed:
                                  _updatingStatus ||
                                      status == TripStatus.completed ||
                                      status == TripStatus.pending ||
                                      status == TripStatus.cancelled
                                  ? null
                                  : () => _advanceTrip(trip, status),
                              icon: Icon(
                                status == TripStatus.accepted
                                    ? Icons.location_on
                                    : status == TripStatus.arrived
                                    ? Icons.play_arrow
                                    : status == TripStatus.active
                                    ? Icons.flag
                                    : Icons.check_circle,
                              ),
                              label: Text(
                                _nextStatusButtonLabel(status) ??
                                    _statusLabel(status),
                              ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                          if (status == TripStatus.completed ||
                              status == TripStatus.cancelled) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Volver al panel'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
      case TripStatus.arrived:
        return 'Llegaste al punto de recojo';
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
        final isArrived = trip.status == TripStatus.arrived;
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
                    onPressed: () => _updateStatus(context, 'arrived'),
                    icon: const Icon(Icons.location_on),
                    label: const Text('Indicar que llegué'),
                  ),
                if (isArrived)
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
