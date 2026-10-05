import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../services/auth_service.dart';
import '../../models/trip_model.dart';
import '../../models/driver_model.dart';
import '../../theme.dart';
import '../driver/driver_trip_chat_screen.dart';

class ActiveTripScreen extends StatefulWidget {
  final String tripId;
  final Map<String, dynamic> tripData;

  const ActiveTripScreen({
    super.key,
    required this.tripId,
    required this.tripData,
  });

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  bool _isSosTriggered = false;
  bool _isSendingSos = false;
  bool _hasNavigatedToRating = false;

  Driver? _driver;
  String? _lastDriverId;
  GoogleMapController? _mapController;

  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};

  // Variables para control de optimización y evitar lag
  TripStatus? _lastStatus;
  double? _lastDriverLat;
  double? _lastDriverLng;

  // Colocar la api del mapa para que se haga el trazado
  final String _googleApiKey = 'AIzaSyBLQjIeANXfVOCw9l21nfJ_vp3DUzNzXYY';

  String _statusLabel(TripStatus status) {
    switch (status) {
      case TripStatus.pending:
        return 'Buscando conductor...';
      case TripStatus.accepted:
        return 'Conductor en camino';
      case TripStatus.active:
        return 'Viaje en curso';
      default:
        return '';
    }
  }

  void _fetchDriverIfNeeded(String? driverId) {
    if (driverId == null || driverId == _lastDriverId) return;
    _lastDriverId = driverId;
    FirestoreService.instance.getDriver(driverId).then((driver) {
      if (mounted) {
        setState(() {
          _driver = driver;
        });
      }
    });
  }

  Future<void> _triggerSos() async {
    setState(() => _isSendingSos = true);
    try {
      final pos = await LocationService.instance.current();
      final user = AuthService.instance.currentUser;

      await FirestoreService.instance.createSosAlert(
        driverId:
            _driver?.uid ?? 'Sin asignar', // Podría aún no tener conductor
        latitude: pos.latitude,
        longitude: pos.longitude,
        city: user?.city ?? 'Tarapoto',
        name: user?.name,
        phone: user?.phone,
        plate: _driver?.plate, // La placa del conductor si ya existe
        reportedBy: 'passenger',
      );
      if (mounted) {
        setState(() {
          _isSendingSos = false;
          _isSosTriggered = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingSos = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al enviar SOS: $e')));
      }
    }
  }

  Future<void> _cancelTrip() async {
    try {
      await FirestoreService.instance.updateTrip(widget.tripId, {
        'status': 'cancelled',
      });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cancelar: $e')));
      }
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri launchUri = Uri(scheme: 'tel', path: cleanedNumber);
    try {
      // ignore: deprecated_member_use
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo realizar la llamada: $e')),
        );
      }
    }
  }

  /// Método nativo para decodificar la polilínea de Google sin librerías externas
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = <LatLng>[];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  /// Método para consultar la Google Directions API y obtener los puntos reales de las calles
  Future<List<LatLng>> _getRouteCoordinates(
    LatLng origin,
    LatLng destination,
  ) async {
    List<LatLng> routePoints = [];
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&mode=driving&key=$_googleApiKey',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final pointsEncoded =
              data['routes'][0]['overview_polyline']['points'];
          routePoints = _decodePolyline(pointsEncoded);
        }
      }
    } catch (_) {
      // Si falla la red, respaldamos con línea recta
      routePoints = [origin, destination];
    }

    if (routePoints.isEmpty) {
      routePoints = [origin, destination];
    }

    return routePoints;
  }

  /// Actualización optimizada del mapa incorporando rutas de calles reales
  void _updateMapElements(Trip? trip) async {
    if (trip == null) return;

    // 1. Obtener coordenadas de Origen y Destino
    final originLatLng = LatLng(
      trip.origin.latitude,
      trip.origin.longitude,
    );
    final destLatLng = LatLng(
      trip.destination.latitude,
      trip.destination.longitude,
    );

    // 2. Ubicación del conductor
    LatLng? driverLatLng;
    if (_driver != null) {
      double? lat = _driver!.currentLatitude;
      double? lng = _driver!.currentLongitude;
      if (lat != null && lng != null) {
        driverLatLng = LatLng(lat, lng);
      }
    }

    // Conjuntos temporales para evitar parpadeos
    final Set<Marker> newMarkers = {};
    final Set<Polyline> newPolylines = {};

    // Marcador del conductor
    if (driverLatLng != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('driver_marker'),
          position: driverLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(
            title: _driver?.name ?? 'Conductor',
            snippet: _driver?.plate,
          ),
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    // 3. Obtener el trazado adaptado a las calles según el estado del viaje
    List<LatLng> polylineCoordinates = [];
    Color polylineColor = Colors.blue;

    if (trip.status == TripStatus.accepted) {
      final startPoint = driverLatLng ?? originLatLng;
      polylineCoordinates = await _getRouteCoordinates(
        startPoint,
        originLatLng,
      );
      polylineColor = Colors.blue;
    } else if (trip.status == TripStatus.active) {
      polylineCoordinates = await _getRouteCoordinates(
        originLatLng,
        destLatLng,
      );
      polylineColor = Colors.green;
    }

    if (polylineCoordinates.isNotEmpty) {
      newPolylines.add(
        Polyline(
          polylineId: const PolylineId('route_streets'),
          color: polylineColor,
          width: 5,
          points: polylineCoordinates,
        ),
      );
    }

    // Marcador de Origen
    newMarkers.add(
      Marker(
        markerId: const MarkerId('origin_marker'),
        position: originLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueGreen,
        ),
        infoWindow: const InfoWindow(title: 'Punto de recogida'),
      ),
    );

    // Marcador de Destino
    newMarkers.add(
      Marker(
        markerId: const MarkerId('destination_marker'),
        position: destLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Destino final'),
      ),
    );

    // Actualizamos los estados visuales en batch
    if (mounted) {
      setState(() {
        _markers.clear();
        _markers.addAll(newMarkers);
        _polylines.clear();
        _polylines.addAll(newPolylines);
      });
    }

    // Seguir suavemente al conductor con la cámara del mapa si está en camino
    if (_mapController != null &&
        driverLatLng != null &&
        trip.status == TripStatus.accepted) {
      _mapController!.animateCamera(CameraUpdate.newLatLng(driverLatLng));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Trip?>(
      stream: FirestoreService.instance.tripStream(widget.tripId),
      builder: (context, snapshot) {
        final trip = snapshot.data;

        // Auto-navegar a calificación al finalizar
        if (trip != null &&
            trip.status == TripStatus.completed &&
            !_hasNavigatedToRating) {
          _hasNavigatedToRating = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacementNamed(
              '/rating',
              arguments: {
                'driverName': _driver?.name ?? 'Conductor',
                'tripId': widget.tripId,
              },
            );
          });
        }

        if (trip != null) {
          _fetchDriverIfNeeded(trip.driverId);

          bool statusChanged = _lastStatus != trip.status;
          bool driverMoved =
              _driver != null &&
              (_lastDriverLat != _driver!.currentLatitude ||
                  _lastDriverLng != _driver!.currentLongitude);

          if (statusChanged || driverMoved || _markers.isEmpty) {
            _lastStatus = trip.status;
            if (_driver != null) {
              _lastDriverLat = _driver!.currentLatitude;
              _lastDriverLng = _driver!.currentLongitude;
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _updateMapElements(trip);
              }
            });
          }
        }

        final destinationText =
            trip?.destinationAddress ??
            widget.tripData['destinationAddress'] ??
            widget.tripData['destination']?.toString() ??
            'Sin destino';

        final rawFare =
            widget.tripData['fareAmount'] ?? widget.tripData['fare'] ?? 0.0;
        final fareValue = rawFare is num
            ? rawFare.toDouble()
            : double.tryParse(rawFare.toString()) ?? 0.0;

        return Scaffold(
          body: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: LatLng(-6.4869, -76.3654),
                  zoom: 15,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                polylines: _polylines,
                markers: _markers,
                onMapCreated: (controller) {
                  _mapController = controller;
                },
              ),
              // Tarjeta superior
              Positioned(
                top: 40,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 10),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              trip != null
                                  ? _statusLabel(trip.status)
                                  : 'Cargando...',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Destino: $destinationText',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tarifa: S/. ${fareValue.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              // Tarjeta inferior (Conductor y acciones)
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 10),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.grey[300],
                            child: const Icon(Icons.person, size: 30),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (trip?.driverName != null &&
                                          trip!.driverName!.isNotEmpty)
                                      ? trip.driverName!
                                      : 'Conductor asignado',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    if (trip?.driverPlate != null) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: MijanoTheme.sol,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          trip!.driverPlate!,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                    ],
                                    if (trip?.driverVehicleModel != null)
                                      Expanded(
                                        child: Text(
                                          trip!.driverVehicleModel!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      )
                                    else if (trip?.driverId == null)
                                      Text(
                                        'Sin asignar',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => DriverTripChatScreen(
                                    tripId: widget.tripId,
                                    senderId:
                                        AuthService.instance.currentUser?.uid ??
                                        '',
                                    senderName:
                                        AuthService
                                            .instance
                                            .currentUser
                                            ?.name ??
                                        'Pasajero',
                                    conversationTitle: _driver != null
                                        ? 'Conductor'
                                        : 'Chat del viaje',
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.chat),
                              label: const Text('Chat'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                print('--- BOTÓN LLAMAR PRESIONADO ---');
                                print('_driver object: $_driver');
                                print('_driver?.phone: ${_driver?.phone}');
                                print('widget.tripData["driverPhone"]: ${widget.tripData['driverPhone']}');

                                final phone = _driver?.phone ?? 
                                              widget.tripData['driverPhone'] ?? 
                                              '';
                                
                                print('Teléfono resultante para llamar: "$phone"');

                                if (phone.isEmpty) {
                                  print('-> El teléfono está vacío o nulo.');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('El teléfono del conductor está vacío')),
                                  );
                                  return;
                                }

                                print('-> Ejecutando llamada a: $phone');
                                _makePhoneCall(phone);
                              },
                              icon: const Icon(Icons.call),
                              label: const Text('Llamar'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isSosTriggered || _isSendingSos
                                  ? null
                                  : _triggerSos,
                              icon: const Icon(Icons.warning),
                              label: const Text('SOS'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isSosTriggered
                                    ? Colors.red
                                    : MijanoTheme.sol,
                                foregroundColor: _isSosTriggered
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_isSosTriggered)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              border: Border.all(color: Colors.red[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'SOS activado. Soporte está en camino.',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      if (trip != null && trip.status == TripStatus.pending)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: OutlinedButton(
                            onPressed: _cancelTrip,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                            child: const Text('Cancelar viaje'),
                          ),
                        ),
                    ],
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
