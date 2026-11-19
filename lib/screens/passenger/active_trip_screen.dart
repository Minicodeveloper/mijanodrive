import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../services/firestore_service.dart';
import '../../services/directions_service.dart';
import '../../services/location_service.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../models/trip_model.dart';
import '../../models/driver_model.dart';
import '../../theme.dart';
import '../../utils/marker_icons.dart';
import '../driver/driver_trip_chat_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  BitmapDescriptor? _mototaxiIcon; // Icono personalizado del mototaxi

  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};

  TripStatus? _lastStatus;
  double? _lastDriverLat;
  double? _lastDriverLng;

  StreamSubscription? _chatMessagesSub;
  bool _isChatOpen = false;
  bool _isInitialChatSnapshot = true;
  final Set<String> _notifiedMessageIds = {};
  bool _isShowingLuggageDialog = false;
  double? _lastNotifiedLuggageAmount;
  bool _hasCancelledNavigation = false;
  bool _hasShownCancelDialog = false;

  @override
  void initState() {
    super.initState();
    _loadCustomMarker();
    _listenToChatMessages();
  }

  @override
  void dispose() {
    _chatMessagesSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _listenToChatMessages() {
    if (widget.tripId.isEmpty) return;
    _chatMessagesSub?.cancel();
    _chatMessagesSub = FirebaseFirestore.instance
        .collection('trips')
        .doc(widget.tripId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .listen((snapshot) {
      if (_isInitialChatSnapshot) {
        _isInitialChatSnapshot = false;
        for (final doc in snapshot.docs) {
          _notifiedMessageIds.add(doc.id);
        }
        return;
      }

      final myUid = AuthService.instance.currentUser?.uid ??
          fb.FirebaseAuth.instance.currentUser?.uid ??
          '';

      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final docId = change.doc.id;
          final data = change.doc.data();
          if (data == null) continue;
          final senderId = data['senderId']?.toString() ?? '';

          if (_notifiedMessageIds.contains(docId)) continue;
          _notifiedMessageIds.add(docId);

          if (senderId.isNotEmpty && senderId != myUid && !_isChatOpen) {
            final senderName = data['senderName']?.toString() ??
                (_driver?.name != null && _driver!.name != 'Sin nombre' ? _driver!.name : 'Conductor');
            final text = data['text']?.toString() ?? 'Tienes un nuevo mensaje';

            NotificationService.showChatMessageNotification(
              tripId: widget.tripId,
              senderName: senderName,
              messageText: text,
              conversationTitle: senderName,
            );
          }
        }
      }
    });
  }

  // Ancho (px lógicos) del mototaxi en el mapa del pasajero.
  static const double _driverMarkerWidth = 36;

  Future<void> _loadCustomMarker() async {
    final icon = await MarkerIcons.mototaxiWithWidth(_driverMarkerWidth);
    if (!mounted || icon == null) return;
    setState(() {
      _mototaxiIcon = icon;
      // Fuerza a repintar los marcadores con el icono ya cargado.
      _lastStatus = null;
    });
  }

  String _statusLabel(TripStatus status) {
    switch (status) {
      case TripStatus.pending:
        return 'Buscando conductor...';
      case TripStatus.accepted:
        return 'Conductor en camino';
      case TripStatus.arrived:
        return 'El conductor ha llegado al punto de recojo';
      case TripStatus.active:
        return 'Viaje en curso hacia tu destino';
      case TripStatus.completed:
        return 'Viaje finalizado';
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

  void _showLuggageNegotiationDialog(Trip trip) {
    if (_isShowingLuggageDialog) return;
    _isShowingLuggageDialog = true;
    _lastNotifiedLuggageAmount = trip.luggageExtraAmount;

    final extra = trip.luggageExtraAmount ?? 0.0;
    final total = trip.fareAmount + extra;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        bool isProcessing = false;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: MijanoTheme.sol.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.luggage, color: MijanoTheme.ink),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Recargo por bulto / carga',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'El conductor ha indicado que llevas bulto o carga adicional y propone un costo extra acordado para la carrera.',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Tarifa inicial:'),
                            Text('S/ ${trip.fareAmount.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Adicional por bulto:'),
                            Text('+ S/ ${extra.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, color: Colors.orange)),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total a pagar:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('S/ ${total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: MijanoTheme.ink)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Si aceptas, la carrera iniciará con el nuevo precio. Si rechazas, el viaje se cancelará automáticamente.',
                    style: TextStyle(fontSize: 11.5, color: Colors.black54),
                  ),
                ],
              ),
              actions: [
                // ── RECHAZAR Y CANCELAR ──────────────────────────────
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  onPressed: isProcessing
                      ? null
                      : () async {
                          // Capturar todo ANTES del await
                          final rootNav = Navigator.of(context, rootNavigator: true);
                          final localNav = Navigator.of(ctx);
                          setModalState(() => isProcessing = true);
                          try {
                            await FirestoreService.instance.updateTrip(trip.id, {
                              'status': 'cancelled',
                              'cancellationReason':
                                  'No se llegó a un acuerdo por el costo del bulto',
                              'luggageExtraStatus': 'rejected',
                            });
                          } catch (_) {
                            setModalState(() => isProcessing = false);
                            return;
                          }
                          // Marcar flags ANTES de navegar
                          _isShowingLuggageDialog = false;
                          _hasCancelledNavigation = true;
                          _hasShownCancelDialog = true;
                          // Cerrar diálogo y volver al home
                          if (localNav.canPop()) localNav.pop();
                          rootNav.pushNamedAndRemoveUntil(
                              '/home', (route) => false);
                        },
                  child: const Text('Rechazar y cancelar'),
                ),
                // ── ACEPTAR ──────────────────────────────────────────
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MijanoTheme.sol,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: isProcessing
                      ? null
                      : () async {
                          final rootNav = Navigator.of(
                            context,
                            rootNavigator: true,
                          );
                          final messenger = ScaffoldMessenger.of(context);
                          setModalState(() => isProcessing = true);
                          try {
                            await FirestoreService.instance.updateTrip(trip.id, {
                              'fareAmount': total,
                              'carriesCargo': true,
                              'luggageExtraStatus': 'accepted',
                            });
                          } catch (e) {
                            if (ctx.mounted) {
                              setModalState(() => isProcessing = false);
                            }
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'No se pudo actualizar la tarifa: $e',
                                  ),
                                ),
                              );
                            }
                            return;
                          }
                          _isShowingLuggageDialog = false;
                          if (rootNav.canPop()) {
                            rootNav.pop();
                          }
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Recargo aceptado. Nueva tarifa: S/ ${total.toStringAsFixed(2)}',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                  child: isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Aceptar (S/ ${total.toStringAsFixed(2)})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      _isShowingLuggageDialog = false;
    });
  }

  Future<void> _triggerSos() async {
    setState(() => _isSendingSos = true);
    try {
      final pos = await LocationService.instance.current();
      final user = AuthService.instance.currentUser;

      await FirestoreService.instance.createSosAlert(
        driverId: _driver?.uid ?? 'Sin asignar',
        latitude: pos.latitude,
        longitude: pos.longitude,
        city: user?.city ?? 'Tarapoto',
        name: user?.name,
        phone: user?.phone,
        plate: _driver?.plate,
        emergencyPhone: user?.emergencyPhone,
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
    final reasons = [
      'El conductor tarda mucho',
      'Me equivoqué de destino',
      'Ya no lo necesito',
      'Otro'
    ];

    String? selectedReason = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancelar viaje'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('¿Por qué deseas cancelar el viaje?'),
              const SizedBox(height: 16),
              ...reasons.map((r) => ListTile(
                title: Text(r),
                onTap: () => Navigator.pop(context, r),
              )),
              ListTile(
                title: const Text('Cancelar sin motivo'),
                onTap: () => Navigator.pop(context, ''),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null), // Cancelar diálogo
              child: const Text('Atrás'),
            ),
          ],
        );
      },
    );

    if (selectedReason == null) return; // User didn't confirm cancellation

    try {
      await FirestoreService.instance.cancelTrip(widget.tripId, cancelledBy: 'passenger', reason: selectedReason.isEmpty ? null : selectedReason);
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cancelar: $e')));
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

  /// Abre Google Maps en modo navegación guiada de primera persona
  Future<void> _openGoogleMapsNavigation(double destLat, double destLng) async {
    final String navigationUrl = 'google.navigation:q=$destLat,$destLng&mode=d';
    final String webMapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng&travelmode=driving';

    final Uri navUri = Uri.parse(navigationUrl);
    final Uri webUri = Uri.parse(webMapsUrl);

    try {
      // ignore: deprecated_member_use
      if (await canLaunchUrl(navUri)) {
        // ignore: deprecated_member_use
        await launchUrl(navUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        // ignore: deprecated_member_use
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir Google Maps')),
          );
        }
      }
    } catch (e) {
      try {
        // ignore: deprecated_member_use
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al abrir el mapa: $e')),
          );
        }
      }
    }
  }

  void _updateMapElements(Trip? trip) async {
    if (trip == null) return;

    final originLatLng = LatLng(
      trip.origin.latitude,
      trip.origin.longitude,
    );
    final destLatLng = LatLng(
      trip.destination.latitude,
      trip.destination.longitude,
    );

    LatLng? driverLatLng;
    if (_driver != null) {
      double? lat = _driver!.currentLatitude;
      double? lng = _driver!.currentLongitude;
      if (lat != null && lng != null) {
        driverLatLng = LatLng(lat, lng);
      }
    }

    final Set<Marker> newMarkers = {};
    final Set<Polyline> newPolylines = {};

    if (driverLatLng != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('driver_marker'),
          position: driverLatLng,
          
          icon: _mototaxiIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(
            title: _driver?.name ?? 'Conductor',
            snippet: _driver?.plate,
          ),
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    List<LatLng> polylineCoordinates = [];
    Color polylineColor = Colors.blue;

    if (trip.status == TripStatus.accepted) {
      final startPoint = driverLatLng ?? originLatLng;
      polylineCoordinates = await DirectionsService.routeCoordinates(
        startPoint,
        originLatLng,
      );
      polylineColor = Colors.blue;
    } else if (trip.status == TripStatus.arrived || trip.status == TripStatus.active) {
      polylineCoordinates = await DirectionsService.routeCoordinates(
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

    newMarkers.add(
      Marker(
        markerId: const MarkerId('destination_marker'),
        position: destLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Destino final'),
      ),
    );

    if (mounted) {
      setState(() {
        _markers.clear();
        _markers.addAll(newMarkers);
        _polylines.clear();
        _polylines.addAll(newPolylines);
      });
    }

    if (_mapController != null &&
        driverLatLng != null &&
        trip.status == TripStatus.accepted) {
      _mapController!.animateCamera(CameraUpdate.newLatLng(driverLatLng));
    } else if (_mapController != null && trip.status == TripStatus.active) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              originLatLng.latitude < destLatLng.latitude ? originLatLng.latitude : destLatLng.latitude,
              originLatLng.longitude < destLatLng.longitude ? originLatLng.longitude : destLatLng.longitude,
            ),
            northeast: LatLng(
              originLatLng.latitude > destLatLng.latitude ? originLatLng.latitude : destLatLng.latitude,
              originLatLng.longitude > destLatLng.longitude ? originLatLng.longitude : destLatLng.longitude,
            ),
          ),
          70,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Trip?>(
      stream: FirestoreService.instance.tripStream(widget.tripId),
      builder: (context, snapshot) {
        final trip = snapshot.data;

        if (trip != null &&
            trip.status == TripStatus.completed &&
            !_hasNavigatedToRating) {
          _hasNavigatedToRating = true;
          
          String resolvedName = 'tu conductor';
          if (trip.driverName != null && trip.driverName!.isNotEmpty) {
            resolvedName = trip.driverName!;
          } else if (_driver != null && _driver!.name != 'Sin nombre') {
            resolvedName = _driver!.name;
          }

          WidgetsBinding.instance.addPostFrameCallback((_) async {
             final nav = Navigator.of(context);
             if (resolvedName == 'tu conductor' && trip.driverId != null) {
                try {
                  final doc = await FirebaseFirestore.instance.collection('users').doc(trip.driverId).get();
                  if (doc.exists) {
                    final n = doc.data()?['name'] ?? doc.data()?['fullName'];
                    if (n != null && n.toString().trim().isNotEmpty) {
                       resolvedName = n.toString();
                    }
                  }
                } catch (_) {}
             }
             if (!mounted) return;
             nav.pushReplacementNamed(
              '/rating',
              arguments: {
                'driverName': resolvedName,
                'tripId': widget.tripId,
              },
            );
          });
        }

        // ── Viaje cancelado por el CONDUCTOR (no por el pasajero) ───────
        if (trip != null &&
            trip.status == TripStatus.cancelled &&
            !_hasShownCancelDialog &&
            !_hasCancelledNavigation) {
          _hasShownCancelDialog = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final nav = Navigator.of(context);
            final reason = trip.cancellationReason;
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                title: const Text('Viaje Cancelado'),
                content: Text(reason ?? 'Tu conductor canceló el viaje.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      nav.pushNamedAndRemoveUntil('/home', (route) => false);
                    },
                    child: const Text('Aceptar'),
                  ),
                ],
              ),
            );
          });
        }

        // Si el conductor propone un adicional por bulto acordado
        // Solo mostrar si el viaje ya fue aceptado (conductor en camino o llegó)
        if (trip != null &&
            trip.luggageExtraStatus == 'pending' &&
            !_isShowingLuggageDialog &&
            !_hasCancelledNavigation &&
            _lastNotifiedLuggageAmount != trip.luggageExtraAmount &&
            (trip.status == TripStatus.accepted ||
                trip.status == TripStatus.arrived ||
                trip.status == TripStatus.active)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                trip.luggageExtraStatus == 'pending' &&
                !_isShowingLuggageDialog &&
                !_hasCancelledNavigation) {
              _showLuggageNegotiationDialog(trip);
            }
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

        // Siempre usar el fareAmount actualizado del stream (incluye recargo aceptado)
        final displayFare = trip?.fareAmount ?? fareValue;

        final destLat = trip?.destination.latitude ?? -6.4869;
        final destLng = trip?.destination.longitude ?? -76.3654;

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
              // Tarjeta superior con botón de navegación en primera persona
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
                          // Botón para abrir Google Maps en modo navegación guiada (1ra persona)
                          IconButton(
                            onPressed: () => _openGoogleMapsNavigation(destLat, destLng),
                            icon: const Icon(Icons.navigation, color: Colors.blue),
                            tooltip: 'Navegar en Google Maps',
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
                        'Tarifa: S/. ${displayFare.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      if (trip?.luggageExtraStatus == 'accepted')
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '✓ Incluye recargo de bulto: +S/ ${(trip?.luggageExtraAmount ?? 0).toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 12, color: Colors.green.shade800, fontWeight: FontWeight.w600),
                          ),
                        )
                      else if (trip?.carriesCargo == true)
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text(
                            '📦 Lleva bulto / carga adicional',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
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
                                      : (_driver != null && _driver!.name != 'Sin nombre')
                                          ? _driver!.name
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
                            child: OutlinedButton(
                              onPressed: () async {
                                _isChatOpen = true;
                                await Navigator.of(context).push(
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
                                      conversationTitle: (trip?.driverName != null &&
                                              trip!.driverName!.isNotEmpty)
                                          ? trip.driverName!
                                          : (_driver != null && _driver!.name != 'Sin nombre')
                                              ? _driver!.name
                                              : 'Conductor',
                                    ),
                                  ),
                                );
                                _isChatOpen = false;
                              },
                              child: const Icon(Icons.chat),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                // 1. Intentar buscar si ya lo tenemos en tripData, trip o _driver
                                String phone = widget.tripData['driverPhone'] ??
                                    widget.tripData['phone'] ??
                                    _driver?.phone ??
                                    '';

                                // 2. Si no está, buscarlo en Firestore en la colección 'users' usando el driverId
                                if (phone.isEmpty) {
                                  final driverId = widget.tripData['driverId'] ?? trip?.driverId;
                                  if (driverId != null && driverId.toString().isNotEmpty) {
                                    try {
                                      final driverDoc = await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(driverId.toString())
                                          .get();
                                      
                                      if (driverDoc.exists) {
                                        phone = driverDoc.data()?['phone'] ?? '';
                                      }
                                    } catch (e) {
                                      // Error silently handled
                                    }
                                  }
                                }

                                if (phone.isEmpty) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('El teléfono del conductor no está disponible')),
                                  );
                                  return;
                                }

                                _makePhoneCall(phone);
                              },
                              child: const Icon(Icons.call),
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
                      if (trip != null && (trip.status == TripStatus.pending || trip.status == TripStatus.accepted || trip.status == TripStatus.arrived))
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