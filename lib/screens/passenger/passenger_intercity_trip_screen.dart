import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/auth_service.dart';
import '../../services/directions_service.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../theme.dart';
import '../../utils/marker_icons.dart';
import '../../widgets/mijano_icon.dart';
import '../driver/driver_trip_chat_screen.dart';
import 'passenger_available_cars_screen.dart';

class PassengerIntercityTripScreen extends StatefulWidget {
  final String tripId;
  final Map<String, dynamic> tripData;
  final VoidCallback? onCancelTrip;

  const PassengerIntercityTripScreen({
    super.key,
    required this.tripId,
    required this.tripData,
    this.onCancelTrip,
  });

  @override
  State<PassengerIntercityTripScreen> createState() =>
      _PassengerIntercityTripScreenState();
}

class _PassengerIntercityTripScreenState
    extends State<PassengerIntercityTripScreen> {
  GoogleMapController? _mapController;
  Position? _passengerPosition;
  StreamSubscription<Position>? _locationSub;

  BitmapDescriptor? _mototaxiIcon;
  BitmapDescriptor? _carIcon;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  String? _linkedMototaxiTripId;
  StreamSubscription<DocumentSnapshot>? _mototaxiSub;
  StreamSubscription<List<Map<String, dynamic>>>? _chatMessagesSub;
  Map<String, dynamic>? _mototaxiData;

  bool _isRequestingMototaxi = false;
  bool _arrivedAtAgencyModalShown = false;
  bool _isSosSent = false;
  bool _arrivedAtAgency = false;

  late LatLng _agencyLatLng;

  @override
  void initState() {
    super.initState();
    _agencyLatLng = _resolveAgencyCoordinates(
      widget.tripData['originAddress'] ?? widget.tripData['originCity'] ?? 'Tarapoto',
      widget.tripData['agencyName'] ?? '',
    );
    _linkedMototaxiTripId =
        widget.tripData['linkedMototaxiTripId']?.toString();

    _loadCustomMarkers();
    _startLocationTracking();

    if (_linkedMototaxiTripId != null &&
        _linkedMototaxiTripId!.isNotEmpty) {
      _listenToMototaxiTrip(_linkedMototaxiTripId!);
    }

    _listenToCarDriverChatMessages();
  }

  void _listenToCarDriverChatMessages() {
    final currentUserId = AuthService.instance.currentUser?.uid ?? 'passenger';
    bool isInitial = true;
    _chatMessagesSub = FirestoreService.instance
        .chatMessagesForTrip(widget.tripId)
        .listen((messages) {
      if (!mounted) return;
      if (isInitial) {
        isInitial = false;
        return;
      }
      final newDriverMessages = messages
          .where((m) =>
              m['senderId'] != currentUserId &&
              m['senderId'] != 'passenger' &&
              m['senderId'] != null)
          .toList();
      if (newDriverMessages.isNotEmpty) {
        final last = newDriverMessages.last;
        final sender = last['senderName'] ?? 'Conductor de Auto';
        final text = (last['text'] ?? '').toString();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mensaje de $sender: "$text"'),
            backgroundColor: const Color(0xFF1E88E5),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'RESPONDER',
              textColor: const Color(0xFFF9D408),
              onPressed: _openChatWithCarDriver,
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _mototaxiSub?.cancel();
    _chatMessagesSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  static LatLng _resolveAgencyCoordinates(String city, String agency) {
    final norm = city.trim().toLowerCase();
    if (norm.contains('yurimaguas')) {
      return const LatLng(-5.9018, -76.1023);
    } else if (norm.contains('tarapoto')) {
      return const LatLng(-6.4869, -76.3654);
    } else if (norm.contains('moyobamba')) {
      return const LatLng(-6.0342, -76.9717);
    } else if (norm.contains('rioja')) {
      return const LatLng(-6.0586, -77.1667);
    } else if (norm.contains('juanjui') || norm.contains('juanjuí')) {
      return const LatLng(-7.1779, -76.7275);
    } else if (norm.contains('lima')) {
      return const LatLng(-12.0464, -77.0428);
    }
    return const LatLng(-6.4869, -76.3654);
  }

  Future<void> _loadCustomMarkers() async {
    final moto = await MarkerIcons.mototaxiWithWidth(36);
    final car = await MarkerIcons.autoMijanoWithWidth(40);
    if (!mounted) return;
    setState(() {
      _mototaxiIcon = moto;
      _carIcon = car;
    });
    _updateMapElements();
  }

  Future<void> _startLocationTracking() async {
    try {
      final pos = await LocationService.instance.current();
      if (!mounted) return;
      setState(() => _passengerPosition = pos);
      _updateMapElements();

      _locationSub = LocationService.instance.stream().listen((pos) {
        if (!mounted) return;
        setState(() => _passengerPosition = pos);
        _updateMapElements();
      });
    } catch (_) {}
  }

  void _listenToMototaxiTrip(String motoTripId) {
    _mototaxiSub?.cancel();
    _mototaxiSub = FirebaseFirestore.instance
        .collection('trips')
        .doc(motoTripId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists || !mounted) return;
      final data = snap.data();
      if (data == null) return;

      setState(() => _mototaxiData = data);
      _updateMapElements();

      final status = (data['status'] ?? '').toString();
      if (status == 'completed' && !_arrivedAtAgencyModalShown) {
        _arrivedAtAgencyModalShown = true;
        setState(() => _arrivedAtAgency = true);
        final motoFare = (data['fareAmount'] as num?)?.toDouble() ?? 4.50;
        final carFare =
            (widget.tripData['fareAmount'] as num?)?.toDouble() ?? 45.00;
        _showArrivedAtAgencyModal(motoFare, carFare);
      }
    });
  }

  Future<void> _updateMapElements() async {
    final pos = _passengerPosition;
    final Set<Marker> newMarkers = {};
    final Set<Polyline> newPolylines = {};

    // Usar siempre el GPS real del pasajero
    final LatLng passLatLng = pos != null
        ? LatLng(pos.latitude, pos.longitude)
        : _agencyLatLng;

    // Marcador del pasajero
    newMarkers.add(
      Marker(
        markerId: const MarkerId('passenger_marker'),
        position: passLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Tu ubicación'),
      ),
    );

    // Marcador de la Agencia de Autos
    newMarkers.add(
      Marker(
        markerId: const MarkerId('agency_marker'),
        position: _agencyLatLng,
        icon: _carIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Agencia ${widget.tripData['agencyName'] ?? 'Auto'}',
          snippet: widget.tripData['originAddress'] ?? 'Punto de salida',
        ),
      ),
    );

    final motoData = _mototaxiData;
    final motoStatus = motoData?['status']?.toString();

    // Si hay mototaxi asignada
    if (motoData != null &&
        (motoStatus == 'accepted' ||
            motoStatus == 'arrived' ||
            motoStatus == 'active' ||
            motoStatus == 'in_progress')) {
      final driverId = motoData['driverId']?.toString();
      LatLng? motoLatLng;

      if (driverId != null && driverId.isNotEmpty) {
        try {
          final driverDoc = await FirebaseFirestore.instance
              .collection('drivers')
              .doc(driverId)
              .get();
          if (driverDoc.exists && driverDoc.data() != null) {
            final lat = (driverDoc.data()!['currentLatitude'] as num?)?.toDouble();
            final lng = (driverDoc.data()!['currentLongitude'] as num?)?.toDouble();
            if (lat != null && lng != null) {
              motoLatLng = LatLng(lat, lng);
            }
          }
        } catch (_) {}
      }

      if (motoLatLng != null) {
        newMarkers.add(
          Marker(
            markerId: const MarkerId('mototaxi_driver_marker'),
            position: motoLatLng,
            icon: _mototaxiIcon ??
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: InfoWindow(
              title: motoData['driverName'] ?? 'MotoTaxi',
              snippet: motoData['driverPlate'] ?? 'En camino',
            ),
          ),
        );
      }

      // Trazado 1: De la mototaxi al pasajero (cuando va a recogerlo)
      if (motoStatus == 'accepted' && motoLatLng != null) {
        final routeCoords = await DirectionsService.routeCoordinates(
          motoLatLng,
          passLatLng,
        );
        newPolylines.add(
          Polyline(
            polylineId: const PolylineId('route_mototaxi_to_passenger'),
            color: const Color(0xFF2196F3),
            width: 5,
            points: routeCoords,
          ),
        );
      }
      // Trazado 2: Del pasajero a la agencia (cuando ya lo recogió y van a la agencia)
      else if (motoStatus == 'arrived' ||
          motoStatus == 'active' ||
          motoStatus == 'in_progress') {
        final start = motoLatLng ?? passLatLng;
        final routeCoords = await DirectionsService.routeCoordinates(
          start,
          _agencyLatLng,
        );
        newPolylines.add(
          Polyline(
            polylineId: const PolylineId('route_passenger_to_agency'),
            color: const Color(0xFF4CAF50),
            width: 5,
            points: routeCoords,
          ),
        );
      }
    } else {
      // Sin mototaxi activa: trazado desde el punto del GPS del pasajero hasta la agencia
      final routeCoords = await DirectionsService.routeCoordinates(
        passLatLng,
        _agencyLatLng,
      );
      newPolylines.add(
        Polyline(
          polylineId: const PolylineId('route_to_agency_ref'),
          color: const Color(0xFF1E88E5),
          width: 5,
          points: routeCoords,
        ),
      );
    }

    if (mounted) {
      setState(() {
        _markers.clear();
        _markers.addAll(newMarkers);
        _polylines.clear();
        _polylines.addAll(newPolylines);
      });
    }

    _fitCameraBounds(passLatLng, _agencyLatLng);
  }

  void _fitCameraBounds(LatLng a, LatLng b) {
    if (_mapController == null) return;
    try {
      final bounds = LatLngBounds(
        southwest: LatLng(
          a.latitude < b.latitude ? a.latitude : b.latitude,
          a.longitude < b.longitude ? a.longitude : b.longitude,
        ),
        northeast: LatLng(
          a.latitude > b.latitude ? a.latitude : b.latitude,
          a.longitude > b.longitude ? a.longitude : b.longitude,
        ),
      );
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    } catch (_) {}
  }

  Future<void> _requestMotoTaxiToAgency() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    setState(() => _isRequestingMototaxi = true);

    try {
      final pos =
          _passengerPosition ?? await LocationService.instance.current();

      final actualDistance = LocationService.instance.distanceKm(
        pos.latitude,
        pos.longitude,
        _agencyLatLng.latitude,
        _agencyLatLng.longitude,
      );

      // Si el usuario está localmente en la ciudad (< 25 km), usamos su GPS real.
      // Si está probando desde otra ciudad (> 25 km), originamos a 1.5 km de la agencia.
      final bool isLocal = actualDistance < 25.0;
      // Para recoger al pasajero se usa siempre su posición real actual
      final GeoPoint originGeo = GeoPoint(pos.latitude, pos.longitude);
      final double effectiveDistanceKm = isLocal ? actualDistance : 1.8;
      final double motoFare = (effectiveDistanceKm * 1.5 + 3.0).clamp(4.0, 10.0);
      final agencyName =
          (widget.tripData['agencyName'] ?? 'Agencia de Autos').toString();
      final originCity =
          (widget.tripData['originAddress'] ?? 'Tarapoto').toString();

      final Map<String, dynamic> motoTripData = <String, dynamic>{
        'passengerId': user.uid,
        'passengerName': user.name ?? 'Pasajero',
        'passengerPhone': user.phone,
        'originAddress': isLocal ? 'Tu ubicación actual' : 'Cerca de la agencia',
        'destinationAddress': 'Agencia $agencyName ($originCity)',
        'origin': originGeo,
        'destination': GeoPoint(
          _agencyLatLng.latitude,
          _agencyLatLng.longitude,
        ),
        'fareAmount': double.parse(motoFare.toStringAsFixed(2)),
        'distanceKm': effectiveDistanceKm,
        'serviceType': 'Viaje a Agencia',
        'vehicleType': 'MotoTaxi',
        'category': 'moto',
        'linkedCarTripId': widget.tripId,
        'status': 'pending',
        'paymentMethod': 'Efectivo',
        'createdAtMs': DateTime.now().millisecondsSinceEpoch,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final docRef = await FirestoreService.instance.createTripWithDispatch(
        motoTripData,
        origin: originGeo,
      );

      // Vincular en el documento del auto
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.tripId)
          .set({
        'linkedMototaxiTripId': docRef.id,
      }, SetOptions(merge: true));

      _linkedMototaxiTripId = docRef.id;
      _listenToMototaxiTrip(docRef.id);

      if (!mounted) return;
      setState(() => _isRequestingMototaxi = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '¡Solicitud enviada! Buscando una MotoTaxi cercana para llevarte a la agencia...',
          ),
          backgroundColor: Color(0xFF1E88E5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRequestingMototaxi = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al solicitar MotoTaxi: $e')),
      );
    }
  }

  Future<void> _cancelMototaxiRequest() async {
    if (_linkedMototaxiTripId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(_linkedMototaxiTripId)
          .update({'status': 'cancelled'});
      _mototaxiSub?.cancel();
      setState(() {
        _linkedMototaxiTripId = null;
        _mototaxiData = null;
      });
      _updateMapElements();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud de MotoTaxi cancelada.')),
      );
    } catch (_) {}
  }

  Future<void> _confirmAndCancelReservation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Cancelar reserva de auto?'),
        content: Text(
          'Se cancelará tu reserva de asiento hacia ${widget.tripData['destinationAddress'] ?? 'destino'}. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 1. Cancelar viaje en Firestore
      try {
        await FirebaseFirestore.instance
            .collection('trips')
            .doc(widget.tripId)
            .update({
          'status': 'cancelled',
          'cancelledBy': 'passenger',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      // 2. Si tenía mototaxi vinculada, cancelarla
      if (_linkedMototaxiTripId != null) {
        try {
          await FirebaseFirestore.instance
              .collection('trips')
              .doc(_linkedMototaxiTripId)
              .update({'status': 'cancelled'});
        } catch (_) {}
      }

      // 3. Liberar asiento en el vehículo
      final carId = widget.tripData['carId']?.toString() ??
          widget.tripData['driverId']?.toString() ??
          '';
      final seatNumber =
          (widget.tripData['seatNumber'] as num?)?.toInt() ?? 2;
      if (carId.isNotEmpty) {
        await IntercityVehicleRepository.instance.cancelSeatReservation(
          carId: carId,
          seatNumber: seatNumber,
        );
      }

      if (mounted) {
        widget.onCancelTrip?.call();
      }
    }
  }

  void _showArrivedAtAgencyModal(double motoFare, double carFare) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '¡Llegaste a la agencia!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Has completado tu traslado en MotoTaxi hacia la agencia.',
              style: TextStyle(fontSize: 13.5, color: Colors.black87),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9C4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF9D408), width: 1.5),
              ),
              child: Column(
                children: [
                  const Text(
                    'Monto a pagar al MotoTaxi (Efectivo)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'S/ ${motoFare.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Nota: Este pago es independiente del pasaje del auto (S/ ${carFare.toStringAsFixed(2)}), el cual se cancela en la agencia o al subir al auto.',
                style: const TextStyle(fontSize: 11.5, color: Colors.black87),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF9D408),
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Entendido, estoy en la agencia',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _callDriver(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teléfono no disponible')),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: clean);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Llamando a $clean...')),
    );
  }

  void _openChatWithCarDriver() {
    final seatNumber = (widget.tripData['seatNumber'] as num?)?.toInt() ?? 2;
    final driverName =
        (widget.tripData['driverName'] ?? 'Conductor de Auto').toString();
    final user = AuthService.instance.currentUser;
    final passengerName = user?.name ?? 'Pasajero';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DriverTripChatScreen(
          tripId: widget.tripId,
          senderId: user?.uid ?? 'passenger',
          senderName: passengerName,
          conversationTitle: 'Chat con $driverName (Asiento $seatNumber)',
        ),
      ),
    );
  }

  void _openChatWithMototaxiDriver() {
    if (_linkedMototaxiTripId == null) return;
    final motoDriverName =
        _mototaxiData?['driverName']?.toString() ?? 'Conductor MotoTaxi';
    final user = AuthService.instance.currentUser;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DriverTripChatScreen(
          tripId: _linkedMototaxiTripId!,
          senderId: user?.uid ?? 'passenger',
          senderName: user?.name ?? 'Pasajero',
          conversationTitle: 'Chat con $motoDriverName (MotoTaxi)',
        ),
      ),
    );
  }

  Future<void> _sendSos() async {
    if (_isSosSent) return;
    try {
      final pos =
          _passengerPosition ?? await LocationService.instance.current();
      final user = AuthService.instance.currentUser;

      await FirestoreService.instance.createSosAlert(
        driverId: widget.tripData['driverId'] ?? 'Auto',
        latitude: pos.latitude,
        longitude: pos.longitude,
        city: user?.city ?? 'Tarapoto',
        name: user?.name,
        phone: user?.phone,
        plate: widget.tripData['driverVehiclePlate'],
        reportedBy: 'passenger',
      );

      if (!mounted) return;
      setState(() => _isSosSent = true);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.emergency, color: MijanoTheme.signal, size: 38),
          title: const Text('Alerta S.O.S. enviada'),
          content: const Text(
            'Tu alerta y ubicación fueron enviadas a soporte y al centro de control.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final originCity =
        (widget.tripData['originAddress'] ?? 'Tarapoto').toString();
    final destCity =
        (widget.tripData['destinationAddress'] ?? 'Yurimaguas').toString();
    final carFare =
        (widget.tripData['fareAmount'] as num?)?.toDouble() ?? 45.00;
    final seatNumber = (widget.tripData['seatNumber'] as num?)?.toInt() ?? 2;
    final departureLabel =
        (widget.tripData['departureLabel'] ?? 'Hoy, 14:30').toString();
    final agencyName =
        (widget.tripData['agencyName'] ?? 'Autos San Martín').toString();
    final carDriverName =
        (widget.tripData['driverName'] ?? 'Conductor Mijano').toString();
    final carDriverPhone =
        (widget.tripData['driverPhone'] ?? '+51987654321').toString();
    final vehicleModel =
        (widget.tripData['driverVehicleModel'] ?? 'Toyota Yaris').toString();
    final vehiclePlate =
        (widget.tripData['driverVehiclePlate'] ?? 'ABC-123').toString();

    final motoData = _mototaxiData;
    final motoStatus = motoData?['status']?.toString();
    final hasActiveMototaxi = motoData != null &&
        (motoStatus == 'pending' ||
            motoStatus == 'accepted' ||
            motoStatus == 'arrived' ||
            motoStatus == 'active' ||
            motoStatus == 'in_progress');
    final double motoFare =
        (motoData?['fareAmount'] as num?)?.toDouble() ?? 4.50;

    String headerStatus = 'Asiento Reservado • Dirígete a la agencia';
    String headerDestination = 'Ruta $originCity → $destCity';
    String headerFare =
        'Tarifa Auto: S/ ${carFare.toStringAsFixed(2)} • Asiento #$seatNumber';

    if (motoStatus == 'pending') {
      headerStatus = 'Buscando MotoTaxi para ir a la agencia...';
      headerDestination = 'Destino: Agencia $agencyName ($originCity)';
      headerFare = 'Tarifa MotoTaxi: S/ ${motoFare.toStringAsFixed(2)}';
    } else if (motoStatus == 'accepted') {
      headerStatus = 'MotoTaxi en camino a recogerte';
      headerDestination = 'Destino: Agencia $agencyName ($originCity)';
      headerFare = 'Tarifa MotoTaxi: S/ ${motoFare.toStringAsFixed(2)}';
    } else if (motoStatus == 'arrived' ||
        motoStatus == 'active' ||
        motoStatus == 'in_progress') {
      headerStatus = 'En viaje hacia la agencia en MotoTaxi';
      headerDestination = 'Destino: Agencia $agencyName ($originCity)';
      headerFare = 'Tarifa MotoTaxi: S/ ${motoFare.toStringAsFixed(2)}';
    } else if (_arrivedAtAgency) {
      headerStatus = '¡Estás en la agencia! Listo para abordar';
      headerDestination = 'Ruta $originCity → $destCity';
      headerFare =
          'Tarifa Auto: S/ ${carFare.toStringAsFixed(2)} • Asiento #$seatNumber';
    }

    return Scaffold(
      body: Stack(
        children: [
          // Mapa de Google
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _agencyLatLng,
              zoom: 15,
            ),
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (ctrl) {
              _mapController = ctrl;
              _updateMapElements();
            },
          ),

          // Tarjeta Superior (Exacta al estilo Screenshot 2)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          headerStatus,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      if (widget.onCancelTrip != null)
                        InkWell(
                          onTap: _confirmAndCancelReservation,
                          child: const Icon(
                            Icons.close,
                            size: 19,
                            color: Colors.black54,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    headerDestination,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        headerFare,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        departureLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Tarjeta Inferior de Conductor y Botones de Acción (Estilo Screenshot 2)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 12,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Si hay una MotoTaxi asignada en curso, mostrar info de la mototaxi
                  if (motoData != null &&
                      (motoStatus == 'accepted' ||
                          motoStatus == 'arrived' ||
                          motoStatus == 'active' ||
                          motoStatus == 'in_progress')) ...[
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFFF9D408),
                          child: const MototaxiIcon(size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                motoData['driverName'] ?? 'Conductor MotoTaxi',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9D408),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      motoData['driverPlate'] ?? 'MOTO',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Traslado a la agencia • S/ ${motoFare.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black87,
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            icon: const Icon(
                              Icons.chat_bubble_outline,
                              size: 17,
                              color: Color(0xFFF9D408),
                            ),
                            label: const Text(
                              'Chat Moto',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: _openChatWithMototaxiDriver,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black87,
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            icon: const Icon(
                              Icons.phone_outlined,
                              size: 17,
                              color: Color(0xFF1EE61E),
                            ),
                            label: const Text(
                              'Llamar Moto',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () => _callDriver(
                              motoData['driverPhone'] ?? '',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade400,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.warning, size: 16),
                          label: const Text(
                            'SOS',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: _sendSos,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ] else ...[
                    // Info del Conductor de Auto
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFFF9D408),
                          child: const AutoMijanoIcon(size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                carDriverName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9D408),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      vehiclePlate,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      '$vehicleModel • $agencyName',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black87,
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            icon: const Icon(
                              Icons.chat_bubble_outline,
                              size: 16,
                              color: Color(0xFFF9D408),
                            ),
                            label: const Text(
                              'Chat Auto',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: _openChatWithCarDriver,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black87,
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            icon: const Icon(
                              Icons.phone_outlined,
                              size: 17,
                              color: Color(0xFF1EE61E),
                            ),
                            label: const Text(
                              'Llamar Auto',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () => _callDriver(carDriverPhone),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade400,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.warning, size: 16),
                          label: const Text(
                            'SOS',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: _sendSos,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Botón Destacado para Solicitar MotoTaxi hacia la agencia
                  if (motoStatus == 'pending') ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFDE7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFF9D408)),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Buscando MotoTaxi para llevarte a la agencia...',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _cancelMototaxiRequest,
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (!hasActiveMototaxi) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF9D408),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _isRequestingMototaxi
                            ? null
                            : _requestMotoTaxiToAgency,
                        icon: const Icon(Icons.two_wheeler, size: 22),
                        label: Text(
                          _isRequestingMototaxi
                              ? 'Solicitando MotoTaxi...'
                              : 'Solicitar MotoTaxi hacia la agencia',
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],

                  if (_isSosSent) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'SOS activado. Soporte está en camino.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFC62828),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
