import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/firestore_service.dart';
import 'passenger_account_screen.dart';
import 'passenger_history_screen.dart';
import 'passenger_reserved_trips_screen.dart';
import 'active_trip_screen.dart';
import '../../services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../models/tariff_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  GoogleMapController? _mapController;

  static const LatLng _tarapoto = LatLng(-6.4869, -76.3654);
  static const CameraPosition _initialCamera = CameraPosition(
    target: _tarapoto,
    zoom: 15,
  );

  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  final FocusNode _originFocus = FocusNode();
  final FocusNode _destinationFocus = FocusNode();

  bool _isSearchingOrigin = false;
  bool _isSearchingDestination = false;

  List<String> _originSuggestions = [];
  List<String> _destinationSuggestions = [];

  LatLng? _originLatLng;
  LatLng? _destinationLatLng;
  String? _mapPickTarget; // 'origin' o 'destination'
  LatLng _mapCameraTarget = _tarapoto;
  String _mapPickedAddress = '';
  bool _isReverseGeocoding = false;
  Timer? _reverseGeocodeDebounce;

  bool _tripSelected = false;
  bool _isSearchingDriver = false;
  String _selectedPaymentMethod = 'Efectivo';
  String _selectedServiceType = 'Viaje';
  PricingSettings _pricingSettings = PricingSettings.fromMap(null);
  StreamSubscription<PricingSettings>? _pricingSubscription;
  double _estimatedFare = 4.00;
  double _distanceKm = 0.0;
  double _durationMinutes = 0.0;
  String _durationText = '';

  String? _activeTripId;
  StreamSubscription<DocumentSnapshot>? _activeTripSubscription;
  bool _hasNotifiedAccepted = false;

  Timer? _searchTimer;
  Timer? _dispatchTimer;
  String? _lastDispatchKey;
  bool _dispatchExhaustedUI = false;
  int _dispatchQueueLength = 0;
  int _currentDispatchIndex = 0;
  int _remainingSeconds = 549;

  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};

  static const String _apiKey = 'AIzaSyCMhmdJobdeH1aUJ87XLw3yRnqm-ufWLGc';

  @override
  void initState() {
    super.initState();
    _originController.text = '';

    _originFocus.addListener(() {
      setState(() {
        _isSearchingOrigin = _originFocus.hasFocus;
      });
    });

    _destinationFocus.addListener(() {
      setState(() {
        _isSearchingDestination = _destinationFocus.hasFocus;
      });
    });

    _checkActiveTrip();

    _pricingSubscription = FirestoreService.instance
        .streamPricingSettings()
        .listen((settings) {
          if (!mounted) return;
          setState(() {
            _pricingSettings = settings;
            if (_tripSelected || _distanceKm > 0) {
              _estimatedFare = _pricingSettings
                  .quote(
                    category: VehicleCategory.moto,
                    distanceKm: _distanceKm,
                    durationMin: _durationMinutes,
                  )
                  .total;
            } else {
              _estimatedFare = _pricingSettings
                  .tariffFor(VehicleCategory.moto)
                  .minFare;
            }
          });
        });

    // Verificamos y mostramos los pop-ups programados para nuevos usuarios al iniciar
    _checkAndShowPopupAds();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _originFocus.dispose();
    _destinationFocus.dispose();
    _searchTimer?.cancel();
    _dispatchTimer?.cancel();
    _reverseGeocodeDebounce?.cancel();
    _pricingSubscription?.cancel();
    _activeTripSubscription?.cancel();
    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();
    _checkAndShowPopupAds();
  }

  // Método para verificar y mostrar el pop-up flotante segmentado
  Future<void> _checkAndShowPopupAds() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('ads')
          .get();

      debugPrint('[ADS] Documentos encontrados en coleccion ads: ${querySnapshot.docs.length}');
      if (querySnapshot.docs.isEmpty || !mounted) return;

      for (var doc in querySnapshot.docs) {
        final adId = doc.id;
        final adData = doc.data();
        if (adData['isActive'] == false) continue;
        final String adType =
            (adData['type'] ?? 'banner').toString().toLowerCase();
        if (adType != 'popup') continue;

        final String audience =
            adData['targetAudience'] ?? 'Todos los usuarios';

        bool shouldShow = false;

        if (audience == 'Todos los usuarios' ||
            audience == 'Recién registrados' ||
            audience == 'Usuarios con viajes previos') {
          shouldShow = true;
        } else {
          shouldShow = true;
        }

        if (shouldShow) {
          Future.delayed(const Duration(milliseconds: 1200), () {
            if (mounted) {
              FirestoreService.instance.trackAdView(adId);
              _showFloatingPopupDialog(adId, adData);
            }
          });
          break;
        }
      }
    } catch (e) {
      // Error silencioso
    }
  }

  // Diálogo flotante del Pop-up con botón 'X' e imagen interactiva a WhatsApp
  void _showFloatingPopupDialog(String adId, Map<String, dynamic> adData) {
    final String title = adData['companyName'] ?? '';
    final String description = adData['description'] ?? '';
    final String phone = adData['phone'] ?? '';
    final String imageUrl = adData['imageUrl'] ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topRight,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    if (title.isNotEmpty)
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (imageUrl.isNotEmpty)
                      GestureDetector(
                        onTap: () async {
                          // Registramos el clic real en el Pop-up
                          await FirestoreService.instance.trackAdClick(adId);
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          if (phone.isNotEmpty) {
                            final cleanPhone = phone.replaceAll(
                              RegExp(r'\D'),
                              '',
                            );
                            final uri = Uri.parse(
                              'https://wa.me/51$cleanPhone',
                            );
                            launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 280),
                            width: double.infinity,
                            color: Colors.black26,
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox(height: 150),
                            ),
                          ),
                        ),
                      ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                top: -10,
                right: -10,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF9D408),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black38, blurRadius: 6),
                      ],
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.black,
                      size: 20,
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

  Future<void> _checkActiveTrip() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('trips')
          .where('passengerId', isEqualTo: user.uid)
          .where(
            'status',
            whereIn: [
              'pending',
              'accepted',
              'arrived',
              'active',
              'in_progress',
            ],
          )
          .get();

      final activeDocs = querySnapshot.docs.where((d) {
        final map = d.data();
        final isScheduled =
            map['serviceType'] == 'Programar viaje' ||
            map['scheduledAt'] != null;
        if (isScheduled && map['status'] == 'pending') {
          return false;
        }
        return true;
      }).toList();

      if (activeDocs.isNotEmpty && mounted) {
        final doc = activeDocs.first;
        final data = doc.data();

        setState(() {
          _activeTripId = doc.id;
          _originController.text = data['originAddress'] ?? '';
          _destinationController.text = data['destinationAddress'] ?? '';
          _estimatedFare = (data['fareAmount'] ?? 15.0).toDouble();
          _distanceKm = (data['distanceKm'] ?? 0.0).toDouble();
          _durationText = data['durationText'] ?? '';
          _selectedPaymentMethod = data['paymentMethod'] ?? 'Efectivo';
          // Los viajes antiguos de paquetería se normalizan a viaje normal.
          _selectedServiceType = data['serviceType'] == 'Encomienda'
              ? 'Viaje'
              : (data['serviceType'] ?? 'Viaje');

          if (data['status'] == 'pending') {
            _isSearchingDriver = true;
            _startSearchTimer();
            _listenToTripUpdates(doc.id);
          }
          _tripSelected = true;
        });

        if (_destinationController.text.isNotEmpty) {
          _selectDestination(_destinationController.text);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al verificar viaje activo')),
        );
      }
    }
  }

  void _startSearchTimer() {
    _searchTimer?.cancel();
    setState(() {
      _remainingSeconds = 180;
    });

    _searchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        _cancelSearch();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('La solicitud expiró. No se encontró conductor.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  String get _formattedTimer {
    int minutes = _remainingSeconds ~/ 60;
    int seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _goToCurrentLocation();
  }

  Future<void> _goToCurrentLocation() async {
    try {
      final pos = await LocationService.instance.current();
      if (!mounted) return;
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 16),
      );
    } catch (e) {}
  }

  Future<void> _signOut() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Future<void> _navigateToAccount() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PassengerAccountScreen()),
    );
    if (mounted) {
      setState(() => _selectedIndex = 0);
    }
  }

  void _onOriginSearchChanged(String query) async {
    if (query.isEmpty) {
      setState(() {
        _originSuggestions = [];
        _isSearchingOrigin = false;
      });
      return;
    }

    setState(() {
      _isSearchingOrigin = true;
    });

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&key=$_apiKey'
        '&language=es'
        '&components=country:pe',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List predictions = data['predictions'] ?? [];

        List<String> resultados = predictions
            .map<String>((prediction) => prediction['description'].toString())
            .toList();

        setState(() {
          _originSuggestions = resultados;
        });
      }
    } catch (e) {
      setState(() {
        _originSuggestions = [];
      });
    }
  }

  void _onDestinationSearchChanged(String query) async {
    if (query.isEmpty) {
      setState(() {
        _destinationSuggestions = [];
        _isSearchingDestination = false;
      });
      return;
    }

    setState(() {
      _isSearchingDestination = true;
    });

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&key=$_apiKey'
        '&language=es'
        '&components=country:pe',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List predictions = data['predictions'] ?? [];

        List<String> resultados = predictions
            .map<String>((prediction) => prediction['description'].toString())
            .toList();

        setState(() {
          _destinationSuggestions = resultados;
        });
      }
    } catch (e) {
      setState(() {
        _destinationSuggestions = [];
      });
    }
  }

  void _selectOrigin(String place) async {
    setState(() {
      _originController.text = place;
      _originLatLng = null;
      _isSearchingOrigin = false;
      _originSuggestions = [];
      _originFocus.unfocus();
    });
    final coords = await _getLatLngFromAddress(place);
    if (coords != null && mounted) {
      setState(() {
        _originLatLng = coords;
      });
      if (_destinationController.text.isNotEmpty) {
        await _calculateAndDrawRoute();
      } else {
        setState(() {
          _markers.removeWhere((m) => m.markerId.value == 'origin');
          _markers.add(
            Marker(
              markerId: const MarkerId('origin'),
              position: coords,
              infoWindow: const InfoWindow(title: 'Origen'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen,
              ),
            ),
          );
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(coords, 16));
      }
    }
  }

  Future<LatLng?> _getLatLngFromAddress(String address) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$_apiKey',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          return LatLng(location['lat'], location['lng']);
        }
      }
    } catch (e) {}
    return null;
  }

  Future<String> _getAddressFromLatLng(LatLng position) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=${position.latitude},${position.longitude}'
        '&key=$_apiKey'
        '&language=es',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && (data['results'] as List).isNotEmpty) {
          return data['results'][0]['formatted_address'].toString();
        }
      }
    } catch (_) {}
    return 'Ubicación (${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)})';
  }

  Future<void> _startPickingOnMap(
    String target, {
    LatLng? initialPoint,
  }) async {
    _originFocus.unfocus();
    _destinationFocus.unfocus();

    LatLng startTarget = initialPoint ?? _mapCameraTarget;
    if (initialPoint == null) {
      if (target == 'origin' && _originLatLng != null) {
        startTarget = _originLatLng!;
      } else if (target == 'destination' && _destinationLatLng != null) {
        startTarget = _destinationLatLng!;
      } else {
        try {
          final pos = await LocationService.instance.current();
          startTarget = LatLng(pos.latitude, pos.longitude);
        } catch (_) {}
      }
    }

    if (!mounted) return;
    setState(() {
      _mapPickTarget = target;
      _mapCameraTarget = startTarget;
      _isSearchingOrigin = false;
      _isSearchingDestination = false;
      _isReverseGeocoding = true;
      _mapPickedAddress = 'Obteniendo dirección...';
    });

    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(startTarget, 16.5),
    );
    _triggerReverseGeocode(startTarget);
  }

  void _triggerReverseGeocode(LatLng target) {
    _reverseGeocodeDebounce?.cancel();
    setState(() {
      _isReverseGeocoding = true;
    });
    _reverseGeocodeDebounce = Timer(const Duration(milliseconds: 350), () async {
      final address = await _getAddressFromLatLng(target);
      if (!mounted || _mapPickTarget == null) return;
      setState(() {
        _mapPickedAddress = address;
        _isReverseGeocoding = false;
      });
    });
  }

  Future<void> _confirmMapPickedLocation() async {
    final target = _mapPickTarget;
    if (target == null) return;

    final chosenLatLng = _mapCameraTarget;
    String address = _mapPickedAddress;
    if (_isReverseGeocoding ||
        address.isEmpty ||
        address == 'Obteniendo dirección...') {
      address = await _getAddressFromLatLng(chosenLatLng);
    }

    if (!mounted) return;

    if (target == 'origin') {
      setState(() {
        _originLatLng = chosenLatLng;
        _originController.text = address;
        _mapPickTarget = null;
        _markers.removeWhere((m) => m.markerId.value == 'origin');
        _markers.add(
          Marker(
            markerId: const MarkerId('origin'),
            position: chosenLatLng,
            infoWindow: const InfoWindow(title: 'Origen'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
          ),
        );
      });

      if (_destinationController.text.isNotEmpty ||
          _destinationLatLng != null) {
        await _calculateAndDrawRoute();
      }
    } else {
      setState(() {
        _destinationLatLng = chosenLatLng;
        _destinationController.text = address;
        _mapPickTarget = null;
      });
      await _calculateAndDrawRoute();
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  void _selectDestination(String place) async {
    setState(() {
      _destinationController.text = place;
      _destinationLatLng = null;
      _isSearchingDestination = false;
      _destinationSuggestions = [];
      _destinationFocus.unfocus();
    });

    await _calculateAndDrawRoute();
  }

  Future<void> _calculateAndDrawRoute() async {
    final originText = _originController.text.isNotEmpty
        ? _originController.text
        : 'Mi ubicación actual';
    final destText = _destinationController.text;

    LatLng? originLatLng = _originLatLng;
    if (originLatLng == null &&
        originText != 'Mi ubicación actual' &&
        originText.isNotEmpty) {
      originLatLng = await _getLatLngFromAddress(originText);
    }
    if (originLatLng == null) {
      try {
        final pos = await LocationService.instance.current();
        originLatLng = LatLng(pos.latitude, pos.longitude);
      } catch (e) {}
    }

    LatLng? destLatLng = _destinationLatLng;
    if (destLatLng == null && destText.isNotEmpty) {
      destLatLng = await _getLatLngFromAddress(destText);
    }

    if (originLatLng != null && destLatLng != null) {
      _originLatLng = originLatLng;
      _destinationLatLng = destLatLng;
      try {
        final directionsUrl = Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${originLatLng.latitude},${originLatLng.longitude}'
          '&destination=${destLatLng.latitude},${destLatLng.longitude}'
          '&mode=driving'
          '&key=$_apiKey',
        );

        final response = await http.get(directionsUrl);
        List<LatLng> routePoints = [];

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['routes'].isNotEmpty) {
            final route = data['routes'][0];
            final encodedPoints = route['overview_polyline']['points'];
            routePoints = _decodePolyline(encodedPoints);

            if (route['legs'] != null && route['legs'].isNotEmpty) {
              final leg = route['legs'][0];
              final distanceMeters = (leg['distance']?['value'] as num?)?.toDouble() ?? 0.0;
              final durationSeconds = (leg['duration']?['value'] as num?)?.toDouble() ?? 0.0;
              _distanceKm = distanceMeters / 1000.0;
              _durationMinutes = durationSeconds / 60.0;
              _durationText = leg['duration']?['text'] ?? '${_durationMinutes.round()} min';

              _estimatedFare = _pricingSettings
                  .quote(
                    category: VehicleCategory.moto,
                    distanceKm: _distanceKm,
                    durationMin: _durationMinutes,
                  )
                  .total;
            }
          }
        }

        if (routePoints.isEmpty) {
          routePoints = [originLatLng, destLatLng];
          final fallbackKm = LocationService.instance.distanceKm(
            originLatLng.latitude,
            originLatLng.longitude,
            destLatLng.latitude,
            destLatLng.longitude,
          );
          _distanceKm = fallbackKm > 0 ? fallbackKm : 2.5;
          _durationMinutes = (_distanceKm * 3.0).clamp(3.0, 120.0);
          _durationText = '${_durationMinutes.round()} min';
          _estimatedFare = _pricingSettings
              .quote(
                category: VehicleCategory.moto,
                distanceKm: _distanceKm,
                durationMin: _durationMinutes,
              )
              .total;
        }

        if (!mounted) return;
        setState(() {
          _tripSelected = true;

          _markers.clear();
          _markers.add(
            Marker(
              markerId: const MarkerId('origin'),
              position: originLatLng!,
              infoWindow: const InfoWindow(title: 'Origen'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen,
              ),
            ),
          );
          _markers.add(
            Marker(
              markerId: const MarkerId('destination'),
              position: destLatLng!,
              infoWindow: const InfoWindow(title: 'Destino'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
            ),
          );

          _polylines.clear();
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              points: routePoints,
              color: Colors.black,
              width: 5,
            ),
          );
        });

        _mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(
                originLatLng.latitude < destLatLng.latitude
                    ? originLatLng.latitude
                    : destLatLng.latitude,
                originLatLng.longitude < destLatLng.longitude
                    ? originLatLng.longitude
                    : destLatLng.longitude,
              ),
              northeast: LatLng(
                originLatLng.latitude > destLatLng.latitude
                    ? originLatLng.latitude
                    : destLatLng.latitude,
                originLatLng.longitude > destLatLng.longitude
                    ? originLatLng.longitude
                    : destLatLng.longitude,
              ),
            ),
            80,
          ),
        );
      } catch (e) {}
    }
  }

  void _showRequestModal() {
    DateTime scheduledTripAt = DateTime.now().add(const Duration(hours: 1));
    bool isSubmitting = false;
    bool carriesCargo = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StreamBuilder<PricingSettings>(
          stream: FirestoreService.instance.streamPricingSettings(),
          initialData: _pricingSettings,
          builder: (context, pricingSnapshot) {
            final livePricing = pricingSnapshot.data ?? _pricingSettings;
            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                final int? quoteHour =
                    _selectedServiceType == 'Programar viaje'
                    ? scheduledTripAt.hour
                    : null;
                final FareQuote activeQuote = livePricing.quote(
                  category: VehicleCategory.moto,
                  distanceKm: _distanceKm,
                  durationMin: _durationMinutes,
                  hour: quoteHour,
                );
                _estimatedFare = activeQuote.total;

                return Container(
                  padding: const EdgeInsets.fromLTRB(20, 25, 20, 25),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.local_taxi, color: Color(0xFFF9D408)),
                            SizedBox(width: 10),
                            Text(
                              'Solicitar motoTaxi',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFF9D408),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Precio sugerido por el sistema',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'S/ ${activeQuote.total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF9D408),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${_distanceKm.toStringAsFixed(1)} km  •  $_durationText',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Base S/ ${activeQuote.baseFare.toStringAsFixed(2)}'
                                ' + Ruta S/ ${activeQuote.distanceCost.toStringAsFixed(2)}'
                                ' + Tiempo S/ ${activeQuote.timeCost.toStringAsFixed(2)}'
                                '${activeQuote.isNight ? ' + Nocturno S/ ${activeQuote.nightSurcharge.toStringAsFixed(2)}' : ''}'
                                '${activeQuote.minFareApplied ? ' (Tarifa mínima)' : ''}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                    const SizedBox(height: 20),
                    const Text(
                      'Tipo de servicio:',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Viaje')),
                            selected: _selectedServiceType == 'Viaje',
                            selectedColor: const Color(0xFFF9D408),
                            backgroundColor: const Color(0xFF2A2A2A),
                            labelStyle: TextStyle(
                              color: _selectedServiceType == 'Viaje'
                                  ? Colors.black
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (bool selected) {
                              setModalState(() {
                                _selectedServiceType = 'Viaje';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Programar viaje')),
                            selected: _selectedServiceType == 'Programar viaje',
                            selectedColor: const Color(0xFFF9D408),
                            backgroundColor: const Color(0xFF2A2A2A),
                            labelStyle: TextStyle(
                              color: _selectedServiceType == 'Programar viaje'
                                  ? Colors.black
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (bool selected) {
                              setModalState(() {
                                _selectedServiceType = 'Programar viaje';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    if (_selectedServiceType == 'Programar viaje') ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Fecha y hora del viaje:',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                  color: Color(0xFFF9D408),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              onPressed: () async {
                                final today = DateTime.now();
                                final selectedDate = await showDatePicker(
                                  context: context,
                                  initialDate: scheduledTripAt,
                                  firstDate: DateTime(
                                    today.year,
                                    today.month,
                                    today.day,
                                  ),
                                  lastDate: DateTime(
                                    today.year,
                                    today.month,
                                    today.day + 7,
                                  ),
                                  helpText: 'Selecciona el día del viaje',
                                );
                                if (selectedDate != null) {
                                  setModalState(() {
                                    scheduledTripAt = DateTime(
                                      selectedDate.year,
                                      selectedDate.month,
                                      selectedDate.day,
                                      scheduledTripAt.hour,
                                      scheduledTripAt.minute,
                                    );
                                  });
                                }
                              },
                              icon: const Icon(Icons.calendar_today),
                              label: Text(
                                MaterialLocalizations.of(
                                  context,
                                ).formatMediumDate(scheduledTripAt),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                  color: Color(0xFFF9D408),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              onPressed: () async {
                                final selectedTime = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.fromDateTime(
                                    scheduledTripAt,
                                  ),
                                  helpText: 'Selecciona la hora del viaje',
                                );
                                if (selectedTime != null) {
                                  setModalState(() {
                                    scheduledTripAt = DateTime(
                                      scheduledTripAt.year,
                                      scheduledTripAt.month,
                                      scheduledTripAt.day,
                                      selectedTime.hour,
                                      selectedTime.minute,
                                    );
                                  });
                                }
                              },
                              icon: const Icon(Icons.access_time),
                              label: Text(
                                MaterialLocalizations.of(
                                  context,
                                ).formatTimeOfDay(
                                  TimeOfDay.fromDateTime(scheduledTripAt),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Puedes programar desde hoy hasta dentro de 7 días.',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const Text(
                      '¿Llevas carga adicional?',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: carriesCargo
                              ? const Color(0xFFF9D408)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: SwitchListTile(
                        value: carriesCargo,
                        onChanged: (value) {
                          setModalState(() => carriesCargo = value);
                        },
                        activeThumbColor: const Color(0xFFF9D408),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                        ),
                        title: const Text(
                          'Sí, llevo carga adicional',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        subtitle: const Text(
                          'Opcional',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Método de pago:',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: ['Efectivo', 'Yape', 'Plin'].map((method) {
                        bool isSelected = _selectedPaymentMethod == method;
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              _selectedPaymentMethod = method;
                            });
                          },
                          child: Container(
                            width: 95,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFF9D408)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  method == 'Efectivo'
                                      ? Icons.money
                                      : Icons.phone_android,
                                  color: isSelected
                                      ? const Color(0xFFF9D408)
                                      : Colors.grey,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  method,
                                  style: TextStyle(
                                    color: isSelected
                                        ? const Color(0xFFF9D408)
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF9D408),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: isSubmitting
                                ? null
                                : () async {
                              if (_selectedServiceType == 'Programar viaje' &&
                                  !scheduledTripAt.isAfter(DateTime.now())) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Selecciona una hora futura para tu viaje.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              final user = AuthService.instance.currentUser;
                              if (user == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Inicia sesión para solicitar un viaje.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              setModalState(() => isSubmitting = true);
                              final isScheduled =
                                  _selectedServiceType == 'Programar viaje';

                              try {
                                LatLng? originCoords =
                                    _originLatLng ??
                                    await _getLatLngFromAddress(
                                      _originController.text,
                                    );
                                LatLng? destCoords =
                                    _destinationLatLng ??
                                    await _getLatLngFromAddress(
                                      _destinationController.text,
                                    );

                                if (originCoords == null) {
                                  final currentPos = await LocationService
                                      .instance
                                      .current();
                                  originCoords = LatLng(
                                    currentPos.latitude,
                                    currentPos.longitude,
                                  );
                                }

                              final tripData = {
                                'passengerId': user.uid,
                                'passengerName': user.name,
                                'passengerPhone': user.phone,
                                'originAddress':
                                    _originController.text.isNotEmpty
                                    ? _originController.text
                                    : 'Mi ubicación actual',
                                'destinationAddress':
                                    _destinationController.text,
                                'origin': GeoPoint(
                                  originCoords.latitude,
                                  originCoords.longitude,
                                ),
                                'destination': destCoords != null
                                    ? GeoPoint(
                                        destCoords.latitude,
                                        destCoords.longitude,
                                      )
                                    : null,
                                'fareAmount': activeQuote.total,
                                'distanceKm': _distanceKm,
                                'durationMinutes': _durationMinutes,
                                'durationText': _durationText,
                                'paymentMethod': _selectedPaymentMethod,
                                'serviceType': _selectedServiceType,
                                'carriesCargo': carriesCargo,
                                if (_selectedServiceType ==
                                    'Programar viaje')
                                  'scheduledAt': Timestamp.fromDate(
                                    scheduledTripAt,
                                  ),
                                'status': 'pending',
                                'driverId': null,
                                'completedAt': null,
                                'createdAt': FieldValue.serverTimestamp(),
                              };
                              
                              DocumentReference tripRef;
                              if (_selectedServiceType == 'Programar viaje') {
                                // TODO: Las reservas necesitan su propio flujo de despacho
                                tripRef = await FirebaseFirestore.instance.collection('trips').add(tripData);
                              } else {
                                tripRef = await FirestoreService.instance.createTripWithDispatch(
                                  tripData,
                                  origin: GeoPoint(originCoords.latitude, originCoords.longitude),
                                );
                              }

                                if (!mounted || !context.mounted) return;
                                Navigator.pop(context);

                                if (isScheduled) {
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Viaje reservado correctamente.',
                                      ),
                                    ),
                                  );
                                  setState(() => _selectedIndex = 1);
                                  return;
                                }

                                if (!mounted) return;
                                setState(() {
                                  _activeTripId = tripRef.id;
                                  _isSearchingDriver = true;
                                });

                                _listenToTripUpdates(tripRef.id);

                                // Notificación flotante de confirmación para el pasajero
                                NotificationService.showSearchingDriverToPassenger(
                                  tripId: tripRef.id,
                                  destinationAddress:
                                      _destinationController.text.isNotEmpty
                                      ? _destinationController.text
                                      : 'Destino solicitado',
                                );

                                _startSearchTimer();
                              } catch (e) {
                                if (context.mounted) {
                                  setModalState(() => isSubmitting = false);
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'No se pudo guardar el viaje: $e',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            child: Text(
                              isSubmitting
                                  ? _selectedServiceType == 'Programar viaje'
                                        ? 'Reservando viaje...'
                                        : 'Solicitando viaje...'
                                  : 'Solicitar viaje',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
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
    );
  }

  void _listenToTripUpdates(String tripId) {
    _activeTripSubscription?.cancel();
    _hasNotifiedAccepted = false;

    _activeTripSubscription = FirebaseFirestore.instance
        .collection('trips')
        .doc(tripId)
        .snapshots()
        .listen((snapshot) {
          if (!snapshot.exists || !mounted) return;
          final data = snapshot.data();
          if (data == null) return;

          final status = data['status'];

          // Notificar al pasajero en cuanto el conductor acepta el viaje
          if (status == 'accepted' && !_hasNotifiedAccepted) {
            _hasNotifiedAccepted = true;
            _searchTimer?.cancel();

            final driverName = data['driverName'] ?? 'Tu conductor';
            final vehicleBrand = data['driverVehicleBrand'] ?? '';
            final vehicleModel = data['driverVehicleModel'] ?? '';
            final vehiclePlate = data['driverPlate'] ?? '';
            final parts = [
              vehicleBrand,
              vehicleModel,
              if (vehiclePlate.isNotEmpty) '($vehiclePlate)',
            ].where((s) => s.isNotEmpty).join(' ');
            final vehicleInfo = parts.isNotEmpty ? parts : 'MotoTaxi asignado';
            final pickupAddress = data['originAddress'] ?? 'Tu ubicación';

            NotificationService.showTripAcceptedToPassenger(
              tripId: tripId,
              driverName: driverName,
              vehicleInfo: vehicleInfo,
              pickupAddress: pickupAddress,
            );

            if (mounted) {
              setState(() {
                _isSearchingDriver = false;
                _dispatchExhaustedUI = false;
              });
            }
          } else if (status == 'pending') {
            final dispatchExhausted = data['dispatchExhausted'] ?? false;
            final queue = data['dispatchQueue'] as List<dynamic>? ?? [];
            final dIndex = data['dispatchIndex'] ?? 0;
            
            if (mounted) {
              setState(() {
                _dispatchQueueLength = queue.length;
                _currentDispatchIndex = dIndex;
              });
            }
            
            final requiredSeconds = queue.length * 33;
            if (_remainingSeconds < requiredSeconds && !dispatchExhausted) {
              _remainingSeconds = requiredSeconds < 180 ? 180 : requiredSeconds;
            }

            if (dispatchExhausted || queue.isEmpty) {
              _dispatchTimer?.cancel();
              _searchTimer?.cancel();
              if (mounted) {
                setState(() {
                  _dispatchExhaustedUI = true;
                });
              }
            } else {
              if (mounted) {
                setState(() {
                  _dispatchExhaustedUI = false;
                });
              }
              final tripId = snapshot.id;
              final dispatchKey = '${tripId}_$dIndex';
              if (_lastDispatchKey != dispatchKey) {
                _dispatchTimer?.cancel();
                _lastDispatchKey = dispatchKey;
                _dispatchTimer = Timer(const Duration(seconds: AppConfig.kDispatchTimeoutSeconds + 3), () {
                  FirestoreService.instance.advanceDispatch(tripId, expectedIndex: dIndex);
                });
              }
            }
          } else if (status == 'cancelled') {
             _dispatchTimer?.cancel();
             _searchTimer?.cancel();
          }
        });
  }

  void _cancelSearch() async {
    _searchTimer?.cancel();
    _dispatchTimer?.cancel();
    _activeTripSubscription?.cancel();

    if (_activeTripId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('trips')
            .doc(_activeTripId)
            .update({'status': 'cancelled'});
      } catch (e) {}
    }

    setState(() {
      _activeTripId = null;
      _isSearchingDriver = false;
      _tripSelected = false;
      _originLatLng = null;
      _destinationLatLng = null;
      _mapPickTarget = null;
      _originController.clear();
      _destinationController.clear();
      _markers.clear();
      _polylines.clear();
    });
  }

  void _clearRoute() {
    _searchTimer?.cancel();
    setState(() {
      _originLatLng = null;
      _destinationLatLng = null;
      _mapPickTarget = null;
      _originController.clear();
      _destinationController.clear();
      _markers.clear();
      _polylines.clear();
      _tripSelected = false;
      _isSearchingDriver = false;
      _estimatedFare = 0.00;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFFF9D408)),
              accountName: Text(
                user?.name ?? 'Usuario',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              accountEmail: Text(
                user?.email ?? 'correo@ejemplo.com',
                style: const TextStyle(color: Colors.black87),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage:
                    user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                    ? NetworkImage(user.photoUrl!)
                    : null,
                child: (user?.photoUrl == null || user?.photoUrl == '')
                    ? const Icon(Icons.person, size: 40, color: Colors.black)
                    : null,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.event_available),
              title: const Text(
                'Reservas de viajes',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedIndex = 1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Historial de viajes'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedIndex = 2);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Configuración'),
              onTap: () {
                Navigator.pop(context);
                _navigateToAccount();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Cerrar sesión',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                await _signOut();
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex.clamp(0, 2),
        children: [
          _activeTripId != null
              ? StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('trips')
                      .doc(_activeTripId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return _buildMainContent(user);
                    }

                    final tripData =
                        snapshot.data!.data() as Map<String, dynamic>;
                    final String status = tripData['status'] ?? 'pending';

                    if (status == 'accepted' ||
                        status == 'arrived' ||
                        status == 'active' ||
                        status == 'in_progress' ||
                        status == 'completed') {
                      return ActiveTripScreen(
                        tripId: _activeTripId!,
                        tripData: tripData,
                      );
                    }

                    return _buildMainContent(user);
                  },
                )
              : _buildMainContent(user),
          const PassengerReservedTripsScreen(),
          const PassengerHistoryScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFFF9D408),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 3) {
            _navigateToAccount();
          } else {
            setState(() => _selectedIndex = index);
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_available),
            label: 'Reservas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historial',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }

  Widget _buildMainContent(user) {
    final bool isPickingOnMap = _mapPickTarget != null && !_isSearchingDriver;
    final bool isPickingOrigin = _mapPickTarget == 'origin';

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: _initialCamera,
          onMapCreated: _onMapCreated,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          polylines: _polylines,
          markers: _markers,
          onCameraMove: (CameraPosition position) {
            _mapCameraTarget = position.target;
          },
          onCameraIdle: () {
            if (_mapPickTarget != null) {
              _triggerReverseGeocode(_mapCameraTarget);
            }
          },
          onTap: (LatLng tappedPoint) {
            if (_isSearchingDriver) return;
            if (_mapPickTarget != null) {
              _mapCameraTarget = tappedPoint;
              _mapController?.animateCamera(
                CameraUpdate.newLatLng(tappedPoint),
              );
              _triggerReverseGeocode(tappedPoint);
            } else {
              final target = _originFocus.hasFocus ? 'origin' : 'destination';
              _startPickingOnMap(target, initialPoint: tappedPoint);
            }
          },
        ),
        if (isPickingOnMap)
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 38),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFF9D408),
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 6),
                        ],
                      ),
                      child: Text(
                        isPickingOrigin
                            ? 'Mueve o toca el mapa para fijar el ORIGEN'
                            : 'Mueve o toca el mapa para fijar el DESTINO',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      Icons.location_on,
                      size: 46,
                      color: isPickingOrigin
                          ? Colors.green.shade600
                          : Colors.redAccent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          top: 45,
          left: 20,
          child: CircleAvatar(
            backgroundColor: Colors.white,
            child: IconButton(
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              icon: const Icon(Icons.menu, color: Colors.black),
            ),
          ),
        ),
        if (isPickingOnMap)
          Positioned(
            top: 45,
            right: 20,
            child: FloatingActionButton.small(
              heroTag: 'btn_my_loc_picker',
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              onPressed: () async {
                await _goToCurrentLocation();
              },
              tooltip: 'Mi ubicación actual',
              child: const Icon(Icons.my_location),
            ),
          ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            decoration: BoxDecoration(
              color: _isSearchingDriver
                  ? const Color(0xFF1E1E1E)
                  : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: _isSearchingDriver
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Icon(
                                  Icons.map,
                                  color: Color(0xFFF9D408),
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_distanceKm.toStringAsFixed(1)} km',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  'Distancia',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  color: Color(0xFFF9D408),
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _durationText.isNotEmpty
                                      ? _durationText
                                      : '15 min',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  'Tiempo',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                const Icon(
                                  Icons.payment,
                                  color: Color(0xFFF9D408),
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'S/ ${_estimatedFare.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  'Estimado',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 15,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'Ya tienes un viaje en curso',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFF9D408),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(
                                        Icons.search,
                                        color: Color(0xFFF9D408),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Buscando conductor',
                                        style: TextStyle(
                                          color: Color(0xFFF9D408),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Tu oferta: S/ ${_estimatedFare.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Color(0xFFF9D408),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (_dispatchExhaustedUI) ...[
                                const Text(
                                  'No hay conductores disponibles en este momento.',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 15),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          FirestoreService.instance.resetDispatch(_activeTripId!);
                                          _startSearchTimer();
                                          setState(() {
                                            _dispatchExhaustedUI = false;
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFF9D408),
                                          foregroundColor: Colors.black,
                                        ),
                                        child: const Text('Reintentar'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _cancelSearch,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.redAccent,
                                          side: const BorderSide(color: Colors.redAccent),
                                        ),
                                        child: const Text('Cancelar'),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                Text(
                                  _dispatchQueueLength > 0 
                                      ? 'Buscando conductor… (${_currentDispatchIndex + 1} de $_dispatchQueueLength)'
                                      : 'Buscando conductor cercano...',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 15),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1E1E),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.timer,
                                        color: Color(0xFFF9D408),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'La solicitud se cerrará en $_formattedTimer',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 15),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.trip_origin,
                                    color: Colors.green,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _originController.text.isNotEmpty
                                          ? _originController.text
                                          : 'Mi ubicación actual',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.flag,
                                    color: Colors.red,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _destinationController.text,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              if (!_dispatchExhaustedUI)
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: _cancelSearch,
                                    child: const Text(
                                      'Cancelar Viaje',
                                      style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : isPickingOnMap
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.pin_drop,
                                  color: isPickingOrigin
                                      ? Colors.green.shade600
                                      : Colors.redAccent,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isPickingOrigin
                                      ? 'Seleccionar origen en mapa'
                                      : 'Seleccionar destino en mapa',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.close, color: Colors.grey),
                              onPressed: () {
                                setState(() {
                                  _mapPickTarget = null;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(
                                  child: Text('Fijar Origen'),
                                ),
                                selected: isPickingOrigin,
                                selectedColor: const Color(0xFFF9D408),
                                backgroundColor: Colors.grey.shade100,
                                labelStyle: TextStyle(
                                  color: Colors.black,
                                  fontWeight: isPickingOrigin
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 12,
                                ),
                                onSelected: (_) =>
                                    _startPickingOnMap('origin'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(
                                  child: Text('Fijar Destino'),
                                ),
                                selected: !isPickingOrigin,
                                selectedColor: const Color(0xFFF9D408),
                                backgroundColor: Colors.grey.shade100,
                                labelStyle: TextStyle(
                                  color: Colors.black,
                                  fontWeight: !isPickingOrigin
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 12,
                                ),
                                onSelected: (_) =>
                                    _startPickingOnMap('destination'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              if (_isReverseGeocoding)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black87,
                                  ),
                                )
                              else
                                Icon(
                                  isPickingOrigin
                                      ? Icons.trip_origin
                                      : Icons.flag,
                                  size: 18,
                                  color: isPickingOrigin
                                      ? Colors.green.shade700
                                      : Colors.redAccent,
                                ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _mapPickedAddress.isNotEmpty
                                      ? _mapPickedAddress
                                      : 'Mueve el mapa para elegir un punto...',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.black87,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  side: BorderSide(color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _mapPickTarget = null;
                                  });
                                },
                                child: const Text(
                                  'Volver',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF9D408),
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: _confirmMapPickedLocation,
                                icon: const Icon(Icons.check_circle_outline),
                                label: Text(
                                  isPickingOrigin
                                      ? 'Confirmar origen'
                                      : 'Confirmar destino',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Apartado exclusivo de reservas posicionado al inicio para mantenerlo siempre visible
                        InkWell(
                          onTap: () => setState(() => _selectedIndex = 1),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFF9D408),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9D408),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.event_available,
                                    color: Colors.black,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Reservas de viajes',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        'Programa o revisa tus viajes anticipados aquí',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Color(0xFFF9D408),
                                  size: 15,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Introduce la ruta...',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.black87,
                                backgroundColor: const Color(
                                  0xFFF9D408,
                                ).withValues(alpha: 0.25),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () {
                                final target = _originFocus.hasFocus
                                    ? 'origin'
                                    : 'destination';
                                _startPickingOnMap(target);
                              },
                              icon: const Icon(
                                Icons.map_outlined,
                                size: 16,
                                color: Colors.black87,
                              ),
                              label: const Text(
                                'Elegir en mapa',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _originController,
                          focusNode: _originFocus,
                          onChanged: _onOriginSearchChanged,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            hintText: 'De: Mi ubicación actual',
                            hintStyle: const TextStyle(color: Colors.grey),
                            prefixIcon: const Icon(
                              Icons.trip_origin,
                              color: Colors.black,
                              size: 20,
                            ),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_originController.text.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      color: Colors.black54,
                                      size: 20,
                                    ),
                                    onPressed: _clearRoute,
                                  ),
                                IconButton(
                                  tooltip: 'Seleccionar origen en el mapa',
                                  icon: const Icon(
                                    Icons.pin_drop_outlined,
                                    color: Colors.green,
                                    size: 22,
                                  ),
                                  onPressed: () =>
                                      _startPickingOnMap('origin'),
                                ),
                              ],
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 12,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.black,
                                width: 1,
                              ),
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        if (_isSearchingOrigin) ...[
                          const SizedBox(height: 5),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 210),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _originSuggestions.length + 1,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(
                                      Icons.map,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                    title: const Text(
                                      'Seleccionar origen directamente en el mapa',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    onTap: () => _startPickingOnMap('origin'),
                                  );
                                }
                                final suggestion =
                                    _originSuggestions[index - 1];
                                return ListTile(
                                  leading: const Icon(
                                    Icons.location_on,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                  title: Text(
                                    suggestion,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  onTap: () => _selectOrigin(suggestion),
                                );
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        TextField(
                          controller: _destinationController,
                          focusNode: _destinationFocus,
                          onChanged: _onDestinationSearchChanged,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            hintText: 'A: ¿A dónde vas?',
                            hintStyle: const TextStyle(color: Colors.grey),
                            prefixIcon: const Icon(
                              Icons.flag,
                              color: Colors.black,
                              size: 20,
                            ),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_destinationController.text.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      color: Colors.black54,
                                      size: 20,
                                    ),
                                    onPressed: _clearRoute,
                                  ),
                                IconButton(
                                  tooltip: 'Seleccionar destino en el mapa',
                                  icon: const Icon(
                                    Icons.pin_drop_outlined,
                                    color: Colors.redAccent,
                                    size: 22,
                                  ),
                                  onPressed: () =>
                                      _startPickingOnMap('destination'),
                                ),
                              ],
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 12,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.black,
                                width: 1,
                              ),
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        if (_isSearchingDestination) ...[
                          const SizedBox(height: 5),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 210),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _destinationSuggestions.length + 1,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(
                                      Icons.map,
                                      color: Colors.redAccent,
                                      size: 20,
                                    ),
                                    title: const Text(
                                      'Seleccionar destino directamente en el mapa',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    onTap: () =>
                                        _startPickingOnMap('destination'),
                                  );
                                }
                                final suggestion =
                                    _destinationSuggestions[index - 1];
                                return ListTile(
                                  leading: const Icon(
                                    Icons.location_on,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                  title: Text(
                                    suggestion,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  onTap: () => _selectDestination(suggestion),
                                );
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: 15),
                        const Text(
                          'Lugares frecuentes',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                                onPressed: () => _selectDestination('Casa'),
                                icon: const Icon(
                                  Icons.home,
                                  color: Colors.amber,
                                ),
                                label: const Text(
                                  'Casa',
                                  style: TextStyle(color: Colors.black87),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                                onPressed: () => _selectDestination('Hospital'),
                                icon: const Icon(
                                  Icons.local_hospital,
                                  color: Colors.amber,
                                ),
                                label: const Text(
                                  'Hospital',
                                  style: TextStyle(color: Colors.black87),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        const AdCarouselBanner(),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF9D408),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () {
                              if (_destinationController.text.isNotEmpty) {
                                _showRequestModal();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Por favor, selecciona un destino',
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Text(
                              _tripSelected
                                  ? 'Continuar solicitud'
                                  : 'Seleccionar destino',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class AdCarouselBanner extends StatelessWidget {
  const AdCarouselBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ads')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('[ADS] Error en StreamBuilder de ads: ${snapshot.error}');
          return const SizedBox.shrink();
        }
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 75,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFF9D408),
                ),
              ),
            ),
          );
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final adType = (data['type'] ?? 'banner').toString().toLowerCase();
          return data['isActive'] != false && adType != 'popup';
        }).toList();

        if (docs.isEmpty) {
          return const SizedBox.shrink();
        }

        return _DynamicCarousel(ads: docs);
      },
    );
  }
}

class _DynamicCarousel extends StatefulWidget {
  final List<QueryDocumentSnapshot> ads;
  const _DynamicCarousel({required this.ads});

  @override
  State<_DynamicCarousel> createState() => _DynamicCarouselState();
}

class _DynamicCarouselState extends State<_DynamicCarousel> {
  final PageController _pageController = PageController();
  Timer? _carouselTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();

    // Al iniciar el carrusel, registramos la vista del primer banner por defecto
    if (widget.ads.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final firstAdId = widget.ads[0].id;
        FirestoreService.instance.trackAdView(firstAdId);
      });
    }

    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_pageController.hasClients && widget.ads.isNotEmpty) {
        if (widget.ads.length == 1) {
          FirestoreService.instance.trackAdView(widget.ads[0].id);
        } else {
          _currentPage = (_currentPage + 1) % widget.ads.length;
          _pageController.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _openWhatsApp(String phone) async {
    if (phone.isEmpty) return;
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/51$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showAdDetailModal(String adId, Map<String, dynamic> adData) async {
    await FirestoreService.instance.trackAdClick(adId);
    final String title = adData['companyName'] ?? '';
    final String description = adData['description'] ?? '';
    final String phone = adData['phone'] ?? '';
    final String imageUrl = adData['imageUrl'] ?? '';
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              if (imageUrl.isNotEmpty)
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(imageUrl, fit: BoxFit.contain),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                description,
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF9D408),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _openWhatsApp(phone);
                      },
                      child: const Text(
                        'Ir',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 75,
      child: PageView.builder(
        controller: _pageController,
        itemCount: widget.ads.length,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
          // Registra la vista cada vez que el carrusel cambia automáticamente o manualmente al banner siguiente
          final adId = widget.ads[index].id;
          FirestoreService.instance.trackAdView(adId);
        },
        itemBuilder: (context, index) {
          final doc = widget.ads[index];
          final adId = doc.id;
          final adData = doc.data() as Map<String, dynamic>;
          final String title = adData['companyName'] ?? '';
          final String subtitle = adData['description'] ?? '';
          final String imageUrl = adData['imageUrl'] ?? '';

          return GestureDetector(
            onTap: () => _showAdDetailModal(adId, adData),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF1E1E1E),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl.isNotEmpty)
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(color: const Color(0xFF2C5364)),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.75),
                            Colors.black.withOpacity(0.35),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFF9D408),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.local_offer,
                            color: Color(0xFFF9D408),
                            size: 30,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
