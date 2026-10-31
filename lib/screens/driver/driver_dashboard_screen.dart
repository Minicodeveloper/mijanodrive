import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../models/plan_model.dart';
import '../../models/trip_model.dart';
import '../../services/auth_service.dart';
import '../../services/directions_service.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../theme.dart';
import '../../utils/marker_icons.dart';
import '../../widgets/mijano_icon.dart';
import '../../config/app_config.dart';
import '../passenger/passenger_available_cars_screen.dart';
import 'driver_active_trip_screen.dart';
import 'driver_my_plan_screen.dart';
import 'driver_plan_payment_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> with WidgetsBindingObserver {
  final _fs = FirestoreService.instance;
  final _auth = AuthService.instance;

  bool _available = false;
  bool _hasActivePlan = false;
  bool _planPaymentPending = false;
  bool _planPaymentRejected = false;

  final Completer<GoogleMapController> _mapController = Completer();

  Position? _driverPosition;
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _driverPlanSubscription;
  Timer? _planExpiryTimer;

  static const double _maxTripDistanceKm = AppConfig.kMaxDispatchRadiusKm;

  final Set<String> _shownAlertTripIds = {};

  final Set<String> _shownNotificationIds = {};

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(-6.48694, -76.36472),
    zoom: 14.0,
  );

  String get _city => _auth.currentUser?.city ?? 'Tarapoto';

  String get _uid => _auth.currentUser?.uid ?? 'demo-driver';

  DateTime? _lastPublishedTime;

  late final Stream<List<Map<String, dynamic>>> _notificationsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _rejectedPlanRequestsStream;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _driverDocStream;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _driverPlanDocStream;
  late final Stream<List<Map<String, dynamic>>> _plansStream;
  late final Stream<List<Trip>> _pendingTripsStream;

  StreamSubscription<List<Trip>>? _tripAlertSub;
  bool _isAlertDialogOpen = false;

  BitmapDescriptor? _carMarkerIcon;
  final Set<Marker> _carMarkers = {};
  final Set<Polyline> _carPolylines = {};
  bool _isCarRouteDrawn = false;
  bool _isRouteOriginDefault = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _notificationsStream = _fs.userNotifications(_uid);
    _rejectedPlanRequestsStream = FirebaseFirestore.instance
        .collection('plan_requests')
        .where('driverId', isEqualTo: _uid)
        .where('status', isEqualTo: 'rejected')
        .limit(1)
        .snapshots();
    _driverDocStream = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .snapshots();
    _driverPlanDocStream = FirebaseFirestore.instance
        .collection('driver_plans')
        .doc(_uid)
        .snapshots();
    _plansStream = _fs.streamPlans();
    _pendingTripsStream = _fs.pendingTrips(city: _city);

    _watchDriverPlan();
    _startLocationTracking();
    _listenToPushAlerts();
    _loadCarMarker();
    _ensureDriverApprovedAndReady();
  }

  Future<void> _ensureDriverApprovedAndReady() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      final pos = _driverPosition ?? await LocationService.instance.current();

      // Guardar todo en 'users' (colección principal del conductor)
      await FirebaseFirestore.instance.collection('users').doc(_uid).set({
        'isApproved': true,
        'status': 'approved',
        'role': 'driver',
        'isAvailable': true,
        'planPaymentStatus': 'active',
        'planExpiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
        'planName': 'Plan Pruebas Activo',
        'currentLatitude': pos.latitude,
        'currentLongitude': pos.longitude,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Sincronizar en 'drivers' por compatibilidad
      await FirebaseFirestore.instance.collection('drivers').doc(_uid).set({
        'isAvailable': true,
        'planPaymentStatus': 'active',
        'planExpiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
        'planName': 'Plan Pruebas Activo',
        'currentLatitude': pos.latitude,
        'currentLongitude': pos.longitude,
        'vehicleType': user.vehicleType ?? 'MotoTaxi',
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _available = true;
          _hasActivePlan = true;
        });
        _updateTripAlertSubscription();
      }
    } catch (e) {
      debugPrint('Error en _ensureDriverApprovedAndReady: $e');
    }
  }

  Future<void> _loadCarMarker() async {
    final icon = await MarkerIcons.autoMijanoWithWidth(40);
    if (!mounted || icon == null) return;
    setState(() => _carMarkerIcon = icon);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tripAlertSub?.cancel();
    _locationSubscription?.cancel();
    _driverPlanSubscription?.cancel();
    _planExpiryTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[DRIVER-DISPATCH] App resumed: limpiando _shownAlertTripIds y reiniciando suscripción');
      _shownAlertTripIds.clear();
      _updateTripAlertSubscription();
    }
  }

  static String _normalizeCity(String? city) {
    if (city == null) return '';
    var s = city.trim().toLowerCase();
    s = s.replaceAll('á', 'a')
         .replaceAll('é', 'e')
         .replaceAll('í', 'i')
         .replaceAll('ó', 'o')
         .replaceAll('ú', 'u')
         .replaceAll('ü', 'u');
    return s;
  }

  static bool _areCitiesEqual(String? city1, String? city2) {
    final c1 = _normalizeCity(city1);
    final c2 = _normalizeCity(city2);
    if (c1.isEmpty || c2.isEmpty) return true;
    return c1 == c2;
  }

  bool _isDriverEligibleForTripWithLogging(Trip trip) {
    if (_driverPosition == null) {
      debugPrint('[DRIVER-DISPATCH] tripId: ${trip.id}, dispatchIndex: ${trip.dispatchIndex}, currentDispatchDriverId: ${trip.currentDispatchDriverId}, mi uid: $_uid -> inelegible: _driverPosition es null');
      return false;
    }
    if (!_available || (!_hasActivePlan && !AppConfig.demoFallback)) {
      debugPrint('[DRIVER-DISPATCH] tripId: ${trip.id}, dispatchIndex: ${trip.dispatchIndex}, currentDispatchDriverId: ${trip.currentDispatchDriverId}, mi uid: $_uid -> inelegible: _available ($_available) o _hasActivePlan ($_hasActivePlan) es falso');
      return false;
    }
    final bool isMyTurn = trip.currentDispatchDriverId == _uid;
    final bool isOpenRequest = trip.currentDispatchDriverId == null ||
        trip.dispatchExhausted ||
        trip.dispatchQueue.isEmpty;

    if (!isMyTurn && !isOpenRequest) {
      debugPrint('[DRIVER-DISPATCH] tripId: ${trip.id}, dispatchIndex: ${trip.dispatchIndex}, currentDispatchDriverId: ${trip.currentDispatchDriverId}, mi uid: $_uid -> inelegible: en turno de otro driver');
      return false;
    }

    if (trip.city != null && trip.city!.trim().isNotEmpty) {
      if (!_areCitiesEqual(trip.city, _city)) {
        debugPrint('[DRIVER-DISPATCH] tripId: ${trip.id} -> inelegible: trip.city (${trip.city}) no coincide con mi ciudad ($_city)');
        return false;
      }
    }

    final distance = _tripDistanceKm(trip);
    if (distance == null || distance > _maxTripDistanceKm) {
      debugPrint('[DRIVER-DISPATCH] tripId: ${trip.id}, dispatchIndex: ${trip.dispatchIndex}, currentDispatchDriverId: ${trip.currentDispatchDriverId}, mi uid: $_uid -> inelegible: distancia fuera de rango ($distance km)');
      return false;
    }

    debugPrint('[DRIVER-DISPATCH] tripId: ${trip.id}, dispatchIndex: ${trip.dispatchIndex}, currentDispatchDriverId: ${trip.currentDispatchDriverId}, mi uid: $_uid -> ¡Elegible!');
    return true;
  }

  void _updateTripAlertSubscription() {
    _tripAlertSub?.cancel();
    _tripAlertSub = null;

    if (!_available || _driverPosition == null) {
      debugPrint('[DRIVER-DISPATCH] Suscripción a alertas cancelada (available: $_available, position: $_driverPosition)');
      _shownAlertTripIds.clear();
      return;
    }

    debugPrint('[DRIVER-DISPATCH] Iniciando suscripción a alertas _tripAlertSub...');
    _tripAlertSub = _pendingTripsStream.listen((trips) {
      final activeTripIds = trips.where((t) => t.status == TripStatus.pending).map((t) => t.id).toSet();
      _shownAlertTripIds.removeWhere((key) {
        final tripId = key.split('_').first;
        if (!activeTripIds.contains(tripId)) {
          debugPrint('[DRIVER-DISPATCH] Limpiando clave obsoleta de _shownAlertTripIds: $key');
          return true;
        }
        return false;
      });

      for (final trip in trips) {
        final key = '${trip.id}_${trip.dispatchIndex}';
        final isEligible = _isDriverEligibleForTripWithLogging(trip);

        if (isEligible) {
          if (!_shownAlertTripIds.contains(key)) {
            if (_isAlertDialogOpen) {
              debugPrint('[DRIVER-DISPATCH] Viaje elegible $key detectado pero ya hay un diálogo abierto. Se reintentará.');
              continue;
            }

            debugPrint('[DRIVER-DISPATCH] Disparando notificación local para tripId: ${trip.id}, key: $key');
            NotificationService.showNewTripRequestToDriver(
              tripId: trip.id,
              passengerName: trip.passengerName ?? 'Pasajero',
              price: trip.fareAmount,
              pickupAddress: trip.originAddress ?? 'Cerca de ti',
            );

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                debugPrint('[DRIVER-DISPATCH] Widget no montado al intentar abrir diálogo para $key');
                return;
              }
              if (_isAlertDialogOpen) {
                debugPrint('[DRIVER-DISPATCH] Diálogo ya abierto al intentar procesar postFrameCallback para $key');
                return;
              }

              _shownAlertTripIds.add(key);
              _showTripAlert(trip);
            });
          }
        }
      }
    }, onError: (error) {
      debugPrint('[DRIVER-DISPATCH] Error en _tripAlertSub: $error');
    });
  }

  void _listenToPushAlerts() {
    debugPrint('🔔 [DEBUG] Iniciando escucha de push_campaigns...');
    
    _fs.streamPushCampaigns().listen((snapshot) {
      debugPrint('🔔 [DEBUG] Snapshot recibido con ${snapshot.docs.length} documentos.');
      
      for (var change in snapshot.docChanges) {
        debugPrint('🔔 [DEBUG] Cambio detectado: ${change.type} en doc ID: ${change.doc.id}');
        
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          final docId = change.doc.id;
          final audience = data?['audience'] ?? '';
          
          debugPrint('🔔 [DEBUG] Audiencia de la campaña: "$audience"');
          
          if (audience != 'DRIVER' && audience != 'ALL') {
            debugPrint('❌ [DEBUG] Campaña descartada por audiencia (no es para DRIVER ni ALL)');
            continue;
          }

          if (_shownNotificationIds.contains(docId)) {
            debugPrint('❌ [DEBUG] Esta campaña ya fue mostrada antes en esta sesión');
            continue;
          }

          final filterDetails = data?['filterDetails'] as Map<String, dynamic>?;
          final title = filterDetails?['title'] ?? data?['title'] ?? 'Nueva Campaña';
          final body = filterDetails?['message'] ?? filterDetails?['body'] ?? data?['body'] ?? '';

          debugPrint('✅ [DEBUG] ¡Campaña válida! Título: "$title" | Cuerpo: "$body"');
          
          _shownNotificationIds.add(docId);

          // Disparar la notificación nativa del sistema
          NotificationService.showGeneralCampaignNotification(
            title: title,
            body: body,
          );
        }
      }
    }, onError: (error) {
      debugPrint('🚨 [DEBUG ERROR en Stream]: $error');
    });
  }



  void _watchDriverPlan() {
    _driverPlanSubscription = _driverDocStream.listen(
          (snapshot) {
            final data = snapshot.data();
            final expiresAt = data?['planExpiresAt'];
            final expiryDate = expiresAt is Timestamp
                ? expiresAt.toDate()
                : null;
            final hasNotExpired = expiryDate?.isAfter(DateTime.now()) ?? false;
            final hasActivePlan =
                data?['planPaymentStatus'] == 'active' && hasNotExpired;
            final isPending = data?['planPaymentStatus'] == 'pending';
            final isRejected = data?['planPaymentStatus'] == 'rejected';
            final dbIsAvailable = data?['isAvailable'] ?? (AppConfig.demoFallback ? true : false);

            _planExpiryTimer?.cancel();
            if (hasActivePlan && expiryDate != null) {
              _planExpiryTimer = Timer(expiryDate.difference(DateTime.now()), () {
                if (!mounted) return;
                setState(() {
                  _hasActivePlan = false;
                  _available = false;
                });
                _fs.setDriverAvailability(_uid, false).catchError((error) {});
              });
            }

            if (!mounted) return;
            setState(() {
              _hasActivePlan = hasActivePlan || AppConfig.demoFallback;
              _planPaymentPending = isPending;
              _planPaymentRejected = isRejected;
              _available = (hasActivePlan || AppConfig.demoFallback) && dbIsAvailable;
            });
            _updateTripAlertSubscription();
          },
          onError: (Object error) {
            if (!mounted) return;
            
            if (error.toString().contains('permission-denied')) {
              return;
            }
          },
        );
  }

  /// La ubicación del conductor.
  Future<void> _startLocationTracking() async {
    try {
      final pos = await LocationService.instance.current();

      if (!mounted) return;

      setState(() {
        _driverPosition = pos;
      });
      _updateTripAlertSubscription();
      _publishLocation(pos);
      _fs.updateDriverLocation(_uid, pos.latitude, pos.longitude).catchError((_) {});
      _onDriverPositionUpdated(pos);

      _locationSubscription = LocationService.instance.stream().listen((pos) {
        if (!mounted) return;

        setState(() {
          _driverPosition = pos;
        });
        _updateTripAlertSubscription();
        _publishLocation(pos);
        _fs.updateDriverLocation(_uid, pos.latitude, pos.longitude).catchError((_) {});
        _onDriverPositionUpdated(pos);
      });
    } catch (_) {
      
    }
  }

  void _onDriverPositionUpdated(Position pos) {
    final repo = IntercityVehicleRepository.instance;
    final car = repo.driverPrimaryVehicle;
    final bool isCarDriver = _checkIsCarDriver();
    final bool isMyCar = (car.driverId == _uid || car.id == _uid);
    final bool isCarTripActive = isCarDriver && isMyCar && car.tripStarted;

    if (!isCarTripActive) return;

    final currentPos = LatLng(pos.latitude, pos.longitude);

    // Si la ruta aún no se había trazado o se trazó con origen predeterminado por falta de GPS:
    if (!_isCarRouteDrawn || _isRouteOriginDefault) {
      _drawCarTripRoute(car);
      return;
    }

    // Actualizar dinámicamente la posición del auto a medida que se desplaza
    if (mounted) {
      setState(() {
        _carMarkers.removeWhere((m) => m.markerId.value == 'car_driver_marker');
        _carMarkers.add(
          Marker(
            markerId: const MarkerId('car_driver_marker'),
            position: currentPos,
            icon: _carMarkerIcon ??
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
            infoWindow: InfoWindow(
              title: car.driverName,
              snippet: '${car.vehicleModel} - ${car.vehiclePlate}',
            ),
          ),
        );
      });
    }
  }

  void _publishLocation(Position pos) {
    if (!_available) return;

    final now = DateTime.now();
    if (_lastPublishedTime != null) {
      final diff = now.difference(_lastPublishedTime!);
      if (diff < AppConfig.locationPublishInterval) {
        return; // Throttled
      }
    }

    _lastPublishedTime = now;
    
    _fs
        .updateDriverLocation(_uid, pos.latitude, pos.longitude)
        .catchError((_) {});
  }

  Future<void> _toggleAvailability(bool value) async {
    if (value && !_hasActivePlan) {
      if (AppConfig.demoFallback) {
        setState(() {
          _hasActivePlan = true;
          _available = true;
        });
        final testPlanData = {
          'isAvailable': true,
          'planPaymentStatus': 'active',
          'planExpiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
          'planName': 'Plan Pruebas',
        };
        await FirebaseFirestore.instance.collection('users').doc(_uid).set(testPlanData, SetOptions(merge: true));
        await FirebaseFirestore.instance.collection('drivers').doc(_uid).set(testPlanData, SetOptions(merge: true));
        _updateTripAlertSubscription();
        return;
      }
      if (_planPaymentPending) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tu comprobante sigue pendiente de validación.'),
          ),
        );
        return;
      }
      final submitted = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => const DriverPlanPaymentScreen(),
        ),
      );
      if (submitted == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Comprobante enviado. Espera la validación del administrador.',
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _available = value;
    });

    try {
      await _fs.setDriverAvailability(_uid, value);
      _updateTripAlertSubscription();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _available = false;
      });
      _updateTripAlertSubscription();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cambiar tu disponibilidad: $error')),
      );
      return;
    }

    if (value && _driverPosition != null) {
      _lastPublishedTime = null;
      _publishLocation(_driverPosition!);
    }
  }

  Future<void> _accept(Trip trip) async {
    try {
      final tripDoc = await FirebaseFirestore.instance.collection('trips').doc(trip.id).get();
      if (!tripDoc.exists) return;
      final currentTrip = Trip.fromMap(tripDoc.data()!, tripDoc.id);

      if (currentTrip.status != TripStatus.pending || currentTrip.currentDispatchDriverId != _uid) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este viaje ya no está disponible')),
        );
        return;
      }

      final user = _auth.currentUser;
      await _fs.updateTrip(trip.id, {
        'driverId': _uid,
        'status': 'accepted',
        if (user != null) ...{
          'driverName': user.name,
          'driverPhone': user.phone,
          'driverPlate': user.vehiclePlate,
          'driverVehicleBrand': user.vehicleBrand,
          'driverVehicleModel': user.vehicleModel,
          'driverVehicleColor': user.vehicleColor,
        },
      });

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

  // Lógica de elegibilidad y prioridad
  bool _isDriverEligibleForTrip(Trip trip) {
    if (_driverPosition == null) return false;
    if (!_available || (!_hasActivePlan && !AppConfig.demoFallback)) return false;

    final bool isMyTurn = trip.currentDispatchDriverId == _uid;
    final bool isOpenRequest = trip.currentDispatchDriverId == null ||
        trip.dispatchExhausted ||
        trip.dispatchQueue.isEmpty;

    if (!isMyTurn && !isOpenRequest) return false;

    if (trip.city != null && trip.city!.trim().isNotEmpty) {
      if (!_areCitiesEqual(trip.city, _city)) return false;
    }

    final distance = _tripDistanceKm(trip);
    if (distance == null || distance > _maxTripDistanceKm) return false;

    return true;
  }

  List<Trip> _nearbyTrips(List<Trip> trips) {
    if (_driverPosition == null) {
      return [];
    }

    return trips.where((trip) {
      return _isDriverEligibleForTrip(trip);
    }).toList();
  }

  Future<void> _showTripAlert(Trip trip) async {
    final distance = _tripDistanceKm(trip);

    _isAlertDialogOpen = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return _TripAlertDialog(
            trip: trip,
            distance: distance,
            onAccept: () async {
              await _accept(trip);
            },
            onReject: () {
              _fs.rejectDispatch(trip.id, _uid);
            },
          );
        },
      );
    } finally {
      _isAlertDialogOpen = false;
    }
  }

  Future<void> _sos() async {
    try {
      final pos = await LocationService.instance.current();
      final user = _auth.currentUser;

      await _fs.createSosAlert(
        driverId: _uid,
        latitude: pos.latitude,
        longitude: pos.longitude,
        city: _city,
        name: user?.name,
        phone: user?.phone,
        plate:
            user?.vehiclePlate ??
            'Pendiente', 
        reportedBy: 'driver',
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

  static LatLng _resolveCityCoords(String city) {
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

  Future<void> _drawCarTripRoute(AvailableCarItem car) async {
    final bool hasGps = _driverPosition != null;
    final startLatLng = hasGps
        ? LatLng(_driverPosition!.latitude, _driverPosition!.longitude)
        : _resolveCityCoords(car.originCity);
    final destLatLng = _resolveCityCoords(car.destinationCity);

    final double dist = LocationService.instance.distanceKm(
      startLatLng.latitude,
      startLatLng.longitude,
      destLatLng.latitude,
      destLatLng.longitude,
    );

    final points = await DirectionsService.routeCoordinates(
      startLatLng,
      destLatLng,
    );

    final newMarkers = <Marker>{
      Marker(
        markerId: const MarkerId('car_driver_marker'),
        position: startLatLng,
        icon: _carMarkerIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
        infoWindow: InfoWindow(
          title: car.driverName,
          snippet: '${car.vehicleModel} - ${car.vehiclePlate}',
        ),
      ),
      Marker(
        markerId: const MarkerId('car_dest_marker'),
        position: destLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Destino: ${car.destinationCity}',
          snippet: 'Viaje interprovincial',
        ),
      ),
    };

    final newPolylines = <Polyline>{
      Polyline(
        polylineId: const PolylineId('car_intercity_route'),
        color: const Color(0xFF1E88E5),
        width: 5,
        points: points,
      ),
    };

    if (mounted) {
      setState(() {
        _carMarkers.clear();
        _carMarkers.addAll(newMarkers);
        _carPolylines.clear();
        _carPolylines.addAll(newPolylines);
        _isRouteOriginDefault = !hasGps;
        _isCarRouteDrawn = hasGps;
      });

      if (_mapController.isCompleted) {
        final ctrl = await _mapController.future;
        if (dist > 1.0) {
          final bounds = LatLngBounds(
            southwest: LatLng(
              startLatLng.latitude < destLatLng.latitude
                  ? startLatLng.latitude
                  : destLatLng.latitude,
              startLatLng.longitude < destLatLng.longitude
                  ? startLatLng.longitude
                  : destLatLng.longitude,
            ),
            northeast: LatLng(
              startLatLng.latitude > destLatLng.latitude
                  ? startLatLng.latitude
                  : destLatLng.latitude,
              startLatLng.longitude > destLatLng.longitude
                  ? startLatLng.longitude
                  : destLatLng.longitude,
            ),
          );
          ctrl.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
        } else {
          ctrl.animateCamera(CameraUpdate.newLatLngZoom(startLatLng, 15));
        }
      }
    }
  }

  Future<void> _openGoogleMapsFirstPerson(LatLng dest) async {
    final navUri = Uri.parse(
      'google.navigation:q=${dest.latitude},${dest.longitude}&mode=d',
    );
    final webUri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${dest.latitude},${dest.longitude}',
      'travelmode': 'driving',
      'dir_action': 'navigate',
    });

    try {
      if (await canLaunchUrl(navUri)) {
        await launchUrl(navUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo abrir el mapa: $e')),
          );
        }
      }
    }
  }

  bool _checkIsCarDriver() {
    final user = _auth.currentUser;
    if (user == null) return false;
    final vType = (user.vehicleType ?? '').trim().toLowerCase();
    if (vType.contains('moto')) return false;
    if (vType == 'carro' ||
        vType == 'auto' ||
        vType.contains('carro') ||
        vType.contains('auto')) {
      return true;
    }
    final agency = (user.agencyName ?? '').trim();
    if (agency.isNotEmpty) return true;
    return false;
  }

  Widget _buildActiveCarTripPanel(AvailableCarItem car) {
    final destLatLng = _resolveCityCoords(car.destinationCity);
    final totalFare = car.pricePerSeat * car.occupiedSeatsCount;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AutoMijanoIcon(size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'En viaje hacia ${car.destinationCity}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      'Ruta ${car.originCity} → ${car.destinationCity} • ${car.occupiedSeatsCount}/${car.totalSeatsCount} Pasajeros a bordo',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'S/ ${totalFare.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF9D408),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 13),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => _openGoogleMapsFirstPerson(destLatLng),
              icon: const Icon(Icons.navigation, size: 20),
              label: const Text(
                'Navegar en Google Maps (1ra Persona)',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 24),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '¿Completar viaje?',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    content: Text(
                      '¿Confirmas la llegada a ${car.destinationCity}? El viaje se marcará como completado, se guardará en tu historial y se liberarán los asientos para una nueva ruta.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Viaje completado'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await _completeCarTripAndSaveHistory(car);
                }
              },
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: const Text(
                'Viaje completado',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _completeCarTripAndSaveHistory(AvailableCarItem car) async {
    try {
      final startLatLng = _driverPosition != null
          ? LatLng(_driverPosition!.latitude, _driverPosition!.longitude)
          : _resolveCityCoords(car.originCity);
      final destLatLng = _resolveCityCoords(car.destinationCity);
      final totalFare = car.pricePerSeat * car.occupiedSeatsCount;

      final passengerNames = car.seatPassengers.values
          .map((p) => p.passengerName.trim())
          .where((name) => name.isNotEmpty)
          .join(', ');

      final String passengerId = car.seatPassengers.values
          .map((p) => p.passengerId.trim())
          .firstWhere((id) => id.isNotEmpty, orElse: () => 'pasajeros_interprovinciales');

      // 1. Guardar en la colección 'trips' de Firestore para que aparezca en el historial del conductor
      await FirebaseFirestore.instance.collection('trips').add({
        'passengerId': passengerId,
        'passengerName': passengerNames.isNotEmpty ? passengerNames : 'Pasajeros de ruta',
        'driverId': _uid,
        'driverName': car.driverName,
        'driverPlate': car.vehiclePlate,
        'driverVehicleModel': car.vehicleModel,
        'driverVehicleBrand': car.vehicleBrand,
        'origin': GeoPoint(startLatLng.latitude, startLatLng.longitude),
        'destination': GeoPoint(destLatLng.latitude, destLatLng.longitude),
        'originAddress': car.originCity.isNotEmpty ? car.originCity : 'Punto de partida',
        'destinationAddress': car.destinationCity,
        'status': 'completed',
        'fareAmount': totalFare > 0 ? totalFare : (car.pricePerSeat * 4),
        'paymentMethod': 'cash',
        'serviceType': 'Viaje Interprovincial',
        'category': 'auto',
        'totalPassengers': car.occupiedSeatsCount,
        'createdAt': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(),
        'distanceKm': 150.0,
      });

      // 2. Liberar el estado en el repositorio
      await IntercityVehicleRepository.instance.finishIntercityTrip(car.id);

      if (mounted) {
        setState(() {
          _carMarkers.clear();
          _carPolylines.clear();
          _isCarRouteDrawn = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Viaje hacia ${car.destinationCity} completado! Guardado en tu Historial.'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al completar viaje de auto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar viaje: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = IntercityVehicleRepository.instance;
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final car = repo.driverPrimaryVehicle;
        final bool isCarDriver = _checkIsCarDriver();
        final bool isMyCar = (car.driverId == _uid || car.id == _uid);
        final bool isCarTripActive = isCarDriver && isMyCar && car.tripStarted;

        if (isCarTripActive && !_isCarRouteDrawn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _drawCarTripRoute(car);
          });
        } else if (!isCarTripActive && _isCarRouteDrawn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _carMarkers.clear();
                _carPolylines.clear();
                _isCarRouteDrawn = false;
              });
            }
          });
        }

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
          // Notificaciones (banner)
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _notificationsStream,
            builder: (context, snapshot) {
              final notifs = snapshot.data ?? [];
              
              // Filtro explícito: solo 'plan_warning' para el banner interno
              final unread = notifs.where((n) => 
                n['isRead'] == false && n['type'] == 'plan_warning'
              ).toList();

              if (unread.isEmpty) return const SizedBox.shrink();

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.red.shade100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: unread.map((n) {
                    return Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(n['body'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.black87))),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () => _fs.markNotificationRead(n['id']),
                        )
                      ],
                    );
                  }).toList(),
                ),
              );
            },
          ),

          if (_planPaymentRejected) ...[
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _rejectedPlanRequestsStream,
              builder: (context, snap) {
                final docs = snap.data?.docs ?? [];
                String reason = '';
                if (docs.isNotEmpty) {
                  reason = docs.first.data()['rejectReason']?.toString() ?? '';
                }
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.red.shade50,
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reason.isNotEmpty
                              ? 'Solicitud de plan rechazada: $reason'
                              : 'Solicitud de plan rechazada.',
                          style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const DriverPlanPaymentScreen()),
                          );
                        },
                        child: const Text('Reenviar comprobante', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

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
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _available
                            ? 'Disponible para viajes'
                            : _planPaymentPending
                            ? 'Pago pendiente de validación'
                            : _planPaymentRejected
                                ? 'Pago rechazado · Intenta de nuevo'
                            : 'No disponible',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: MijanoTheme.ink,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: _driverDocStream,
                        builder: (context, driverSnap) {
                          return StreamBuilder<
                            DocumentSnapshot<Map<String, dynamic>>
                          >(
                            stream: _driverPlanDocStream,
                            builder: (context, driverPlanSnap) {
                              return StreamBuilder<List<Map<String, dynamic>>>(
                                stream: _plansStream,
                                builder: (context, plansSnap) {
                                  final driverData = driverSnap.data?.data();
                                  final driverPlanData =
                                      driverPlanSnap.data?.data();
                                  final rawPlans = plansSnap.data ?? [];
                                  final plans = rawPlans
                                      .map(
                                        (e) => PlanModel.fromMap(e, e['id']),
                                      )
                                      .toList();

                                  final expiresAt =
                                      (driverData?['planExpiresAt']
                                              as Timestamp?)
                                          ?.toDate() ??
                                      (driverPlanData?['expiresAt']
                                              as Timestamp?)
                                          ?.toDate();

                                  if (!_hasActivePlan) {
                                    return InkWell(
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const DriverMyPlanScreen(),
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.9,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          _planPaymentPending
                                              ? 'Solicitud en revisión · Ver mi plan'
                                              : 'Sin plan activo · Toca para ver planes',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: _planPaymentPending
                                                ? Colors.orange.shade900
                                                : Colors.red.shade700,
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  final planName =
                                      DriverPlanHelper.resolvePlanName(
                                        driverData: driverData,
                                        driverPlanData: driverPlanData,
                                        plans: plans,
                                      );
                                  final timeRemainingText =
                                      DriverPlanHelper.formatRemainingTime(
                                        expiresAt,
                                      );

                                  return InkWell(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const DriverMyPlanScreen(),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.workspace_premium,
                                            size: 13,
                                            color: Colors.green,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              timeRemainingText.isNotEmpty
                                                  ? '$planName · $timeRemainingText'
                                                  : planName,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ],
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
              markers: isCarTripActive ? _carMarkers : const {},
              polylines: isCarTripActive ? _carPolylines : const {},
              onMapCreated: (GoogleMapController controller) {
                if (!_mapController.isCompleted) {
                  _mapController.complete(controller);
                }
              },
            ),
          ),

          // Viajes pendientes o Viaje Interprovincial en curso
          Expanded(
            flex: 2,
            child: isCarTripActive
                ? _buildActiveCarTripPanel(car)
                : (!_available
                    ? const Center(
                        child: Text(
                          'Actívate para recibir viajes',
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    : StreamBuilder<List<Trip>>(
                        stream: _pendingTripsStream,
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (snap.hasError) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'No se pudieron cargar los viajes: ${snap.error}',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
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

                          if (nearbyTrips.isEmpty) {
                            final isCarAccount = _checkIsCarDriver();
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  isCarAccount
                                      ? const AutoMijanoIcon(size: 56, opacity: 0.45)
                                      : const MototaxiIcon(size: 56, opacity: 0.35),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No hay solicitudes por ahora',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.black54),
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
                      )),
          ),
        ],
      ),
    );
      },
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
          Text(
            'Pasajero: ${trip.passengerName ?? "Cliente"}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          if (trip.carriesCargo) ...[
            const SizedBox(height: 6),
            Row(
              children: const [
                Icon(Icons.inventory_2_outlined, size: 14),
                SizedBox(width: 6),
                Text(
                  'Carga adicional',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
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

class _TripAlertDialog extends StatefulWidget {
  final Trip trip;
  final double? distance;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _TripAlertDialog({
    required this.trip,
    this.distance,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<_TripAlertDialog> createState() => _TripAlertDialogState();
}

class _TripAlertDialogState extends State<_TripAlertDialog> {
  Timer? _alertTimer;
  late int _secondsRemaining;
  StreamSubscription<Trip?>? _tripSub;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = AppConfig.kDispatchTimeoutSeconds;

    if (_secondsRemaining > 0) {
      _alertTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        
        _secondsRemaining--;
        if (_secondsRemaining <= 0) {
          timer.cancel();
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          widget.onReject();
        } else {
          setState(() {}); // Actualiza la UI
        }
      });
    }

    _tripSub = FirestoreService.instance.tripStream(widget.trip.id).listen((updatedTrip) {
      if (!mounted) return;
      if (updatedTrip == null || 
          updatedTrip.status != TripStatus.pending || 
          updatedTrip.currentDispatchDriverId != AuthService.instance.currentUser?.uid) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    });
  }

  @override
  void dispose() {
    _alertTimer?.cancel();
    _tripSub?.cancel();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.notifications_active, color: MijanoTheme.sol),
          const SizedBox(width: 8),
          const Expanded(child: Text('Nuevo viaje cercano')),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_secondsRemaining}s',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
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
            widget.trip.originAddress ?? 'Origen no disponible',
          ),
          const SizedBox(height: 10),
          _alertInfoRow(
            Icons.location_on,
            'Destino',
            widget.trip.destinationAddress ?? 'Destino no disponible',
          ),
          const SizedBox(height: 10),
          _alertInfoRow(
            Icons.payments,
            'Tarifa',
            'S/ ${widget.trip.fareAmount.toStringAsFixed(2)}',
          ),
          if (widget.distance != null) ...[
            const SizedBox(height: 10),
            _alertInfoRow(
              Icons.near_me,
              'Distancia',
              '${widget.distance!.toStringAsFixed(2)} km',
            ),
          ],
          if (widget.trip.carriesCargo) ...[
            const SizedBox(height: 10),
            _alertInfoRow(
              Icons.inventory_2_outlined,
              'Carga',
              'Lleva carga adicional',
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _alertTimer?.cancel();
            if (Navigator.canPop(context)) Navigator.pop(context);
            widget.onReject();
          },
          child: const Text('Rechazar'),
        ),
        ElevatedButton(
          onPressed: () {
            _alertTimer?.cancel();
            if (Navigator.canPop(context)) Navigator.pop(context);
            widget.onAccept();
          },
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}