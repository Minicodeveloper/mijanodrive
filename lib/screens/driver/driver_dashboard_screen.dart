import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/trip_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../theme.dart';
import '../../widgets/mijano_icon.dart';
import '../../config/app_config.dart';
import 'driver_active_trip_screen.dart';
import 'driver_plan_payment_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final _fs = FirestoreService.instance;
  final _auth = AuthService.instance;

  bool _available = false;
  bool _hasActivePlan = false;
  bool _planPaymentPending = false;
  bool _planPaymentRejected = false;

  // Variable para almacenar el tipo de plan actual del conductor (ej. 'Mensual', 'Semanal', 'Diario')
  String _myPlanName = 'Diario'; 

  final Completer<GoogleMapController> _mapController = Completer();

  Position? _driverPosition;
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _driverPlanSubscription;
  Timer? _planExpiryTimer;

  static const double _maxTripDistanceKm = 300.0;

  final Set<String> _shownAlertTripIds = {};

  final Set<String> _rejectedTripIds = {};
  final Set<String> _shownNotificationIds = {};

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(-6.48694, -76.36472),
    zoom: 14.0,
  );

  String get _city => _auth.currentUser?.city ?? 'Tarapoto';

  String get _uid => _auth.currentUser?.uid ?? 'demo-driver';

  DateTime? _lastPublishedTime;

  @override
  void initState() {
    super.initState();
    _setInitialUnavailable();
    _watchDriverPlan();
    _startLocationTracking();
    _listenToPushAlerts();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _driverPlanSubscription?.cancel();
    _planExpiryTimer?.cancel();
    super.dispose();
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

  Future<void> _setInitialUnavailable() async {
    try {
      await _fs.setDriverAvailability(_uid, false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar tu disponibilidad: $error'),
        ),
      );
    }
  }

  void _watchDriverPlan() {
    _driverPlanSubscription = FirebaseFirestore.instance
        .collection('drivers')
        .doc(_uid)
        .snapshots()
        .listen(
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
            
            // Capturar el nombre del plan actual del conductor
            final fetchedPlanName = data?['planName'] ?? 'Diario';

            _planExpiryTimer?.cancel();
            if (hasActivePlan && expiryDate != null) {
              _planExpiryTimer = Timer(expiryDate.difference(DateTime.now()), () {
                if (!mounted) return;
                setState(() {
                  _hasActivePlan = false;
                  _available = false;
                });
                _fs.setDriverAvailability(_uid, false).catchError((error) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'No se pudo pausar tu disponibilidad al vencer el plan: $error',
                      ),
                    ),
                  );
                });
              });
            }

            if (!mounted) return;
            final wasAvailable = _available;
            setState(() {
              _hasActivePlan = hasActivePlan;
              _planPaymentPending = isPending;
              _planPaymentRejected = isRejected;
              _myPlanName = fetchedPlanName;
              if (!hasActivePlan) _available = false;
            });

            if (wasAvailable && !hasActivePlan) {
              _fs.setDriverAvailability(_uid, false).catchError((error) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'No se pudo pausar tu disponibilidad: $error',
                    ),
                  ),
                );
              });
            }
          },
          onError: (Object error) {
            if (!mounted) return;
            
            if (error.toString().contains('permission-denied')) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('No se pudo verificar tu plan: $error')),
            );
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

      _publishLocation(pos);

      _locationSubscription = LocationService.instance.stream().listen((pos) {
        if (!mounted) return;

        setState(() {
          _driverPosition = pos;
        });

        _publishLocation(pos);
      });
    } catch (_) {
      
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
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _available = false;
      });
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

  // Método actualizado para registrar el rechazo con soporte de Plan Mensual
  Future<void> _rejectMonthlyTrip(Trip trip) async {
    setState(() {
      _rejectedTripIds.add(trip.id);
    });

    final bool isMonthlyPlan = _myPlanName.toLowerCase().contains('mensual');
    if (isMonthlyPlan) {
      // Registrar su rechazo en la lista del viaje
      await FirebaseFirestore.instance.collection('trips').doc(trip.id).update({
        'rejectedMonthlyDriverIds': FieldValue.arrayUnion([_uid]),
      });

      // Invocar el método en Firestore para pasarle el turno al siguiente conductor mensual
      await _fs.advanceMonthlyQueue(trip.id);
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

  // Lógica de elegibilidad y prioridad para los 3 km y el Plan Mensual
  bool _isDriverEligibleForTrip(Trip trip) {
    if (_driverPosition == null) return false;

    // 1. Validar estrictamente el rango de distancia (ej. 300 km para tus pruebas)
    final distance = _tripDistanceKm(trip);
    if (distance == null || distance > _maxTripDistanceKm) return false;

    // 2. Verificar si este conductor ya rechazó este viaje previamente
    if (_rejectedTripIds.contains(trip.id)) return false;

    final tripMap = trip.toMap();
    final bool isMonthlyPlan = _myPlanName.toLowerCase().contains('mensual');
    final String? currentMonthlyDriverId = tripMap['currentMonthlyDriverId'] as String?;

    if (currentMonthlyDriverId != null) {
      // FASE 1: La cola mensual está activa. El viaje SOLO pertenece al conductor en turno exacto.
      if (!isMonthlyPlan) {
        return false; // Los planes semanales y diarios aún no ven el viaje
      }
      return currentMonthlyDriverId == _uid; // Solo es elegible si es SU turno
    } else {
      // FASE 2 (Overflow): Todos los mensuales rechazaron o expiró la cola. Abierto para Semanal y Diario.
      return true; 
    }
  }

  List<Trip> _nearbyTrips(List<Trip> trips) {
    if (_driverPosition == null) {
      return [];
    }

    return trips.where((trip) {
      return _isDriverEligibleForTrip(trip);
    }).toList();
  }

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

      // Enviar notificación local con banner flotante, sonido y vibración
      NotificationService.showNewTripRequestToDriver(
        tripId: trip.id,
        passengerName: trip.passengerName ?? 'Pasajero',
        price: trip.fareAmount,
        pickupAddress: trip.originAddress ?? 'Cerca de ti',
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_available) return;

        _showTripAlert(trip);
      });

      break;
    }
  }

  Future<void> _showTripAlert(Trip trip) async {
  final distance = _tripDistanceKm(trip);

  // Calcular segundos restantes basados en la fecha límite del viaje
  final tripMap = trip.toMap();
  final Timestamp? deadlineTs = tripMap['monthlyDeadline'] as Timestamp?;
  final DateTime deadline = deadlineTs?.toDate() ?? DateTime.now().add(const Duration(seconds: 30));
  
  int secondsRemaining = deadline.difference(DateTime.now()).inSeconds;
  if (secondsRemaining <= 0) secondsRemaining = 30; // Fallback predeterminado

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          Timer? alertTimer;

          // Iniciar el conteo regresivo si no se ha iniciado
          alertTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
            if (secondsRemaining > 1) {
              setDialogState(() {
                secondsRemaining--;
              });
            } else {
              timer.cancel();
              if (Navigator.canPop(dialogContext)) {
                Navigator.pop(dialogContext); // Cierra el cuadro automáticamente al llegar a 0
              }
              _rejectMonthlyTrip(trip); // Registra el rechazo automático por tiempo agotado
            }
          });

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.notifications_active, color: MijanoTheme.sol),
                const SizedBox(width: 8),
                const Expanded(child: Text('Nuevo viaje cercano')),
                // Contador visual decreciente
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${secondsRemaining}s',
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
                  alertTimer?.cancel();
                  Navigator.pop(dialogContext);
                  _rejectMonthlyTrip(trip);
                },
                child: const Text('Rechazar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  alertTimer?.cancel();
                  Navigator.pop(dialogContext);
                  await _accept(trip);
                },
                child: const Text('Aceptar'),
              ),
            ],
          );
        },
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
          // Notificaciones (banner)
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _fs.userNotifications(_uid),
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
              stream: FirebaseFirestore.instance
                  .collection('plan_requests')
                  .where('driverId', isEqualTo: _uid)
                  .where('status', isEqualTo: 'rejected')
                  .limit(1)
                  .snapshots(),
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
                      if (_hasActivePlan) ...[
                        const SizedBox(height: 2),
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance.collection('drivers').doc(_uid).snapshots(),
                          builder: (context, snapshot) {
                            final data = snapshot.data?.data();
                            final planName = data?['planName'] ?? 'Plan Activo';
                            final expiresAt = (data?['planExpiresAt'] as Timestamp?)?.toDate();
                            
                            String timeRemainingText = '';
                            if (expiresAt != null) {
                              final diff = expiresAt.difference(DateTime.now());
                              if (!diff.isNegative) {
                                final days = diff.inDays;
                                final hours = diff.inHours % 24;
                                timeRemainingText = days > 0 ? '$days d $hours h restantes' : '$hours horas restantes';
                              } else {
                                timeRemainingText = 'Plan expirado';
                              }
                            }

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$planName · $timeRemainingText',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
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
                    stream: _fs.pendingTrips(),
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

                      _checkForNewNearbyTripAlerts(trips);

                      if (nearbyTrips.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const MototaxiIcon(size: 56, opacity: 0.35),
                              const SizedBox(height: 12),
                              Text(
                                trips.isEmpty
                                    ? 'No hay solicitudes pendientes en $_city'
                                    : 'Hay ${trips.length} solicitud(es), pero ninguna está dentro de 3 km',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.black54),
                              ),
                              const SizedBox(height: 4),
                              const Text(
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
          Text(
            'Pasajero: ${trip.passengerName ?? "Cliente"}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
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