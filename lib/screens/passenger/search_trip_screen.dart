import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';

import '../../config/app_config.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../models/tariff_model.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'map_picker_screen.dart';
import '../../widgets/frequent_places_sheet.dart';

class SearchTripScreen extends StatefulWidget {
  const SearchTripScreen({super.key});

  @override
  State<SearchTripScreen> createState() => _SearchTripScreenState();
}

class _SearchTripScreenState extends State<SearchTripScreen> {
  final _originController = TextEditingController(text: 'Mi ubicación actual');
  final _destinationController = TextEditingController();

  String _selectedPaymentMethod = 'cash';
  double _estimatedFare = 15.00;
  bool _isSearching = false;

  double? _destinationLat;
  double? _destinationLng;
  double? _originLat;
  double? _originLng;

  String _lastOriginText = 'Mi ubicación actual';
  String _lastDestinationText = '';

  @override
  void initState() {
    super.initState();
    _originController.addListener(_onOriginChanged);
    _destinationController.addListener(_onDestinationChanged);
  }

  void _onOriginChanged() {
    if (_originController.text != _lastOriginText) {
      _originLat = null;
      _originLng = null;
    }
  }

  void _onDestinationChanged() {
    if (_destinationController.text != _lastDestinationText) {
      _destinationLat = null;
      _destinationLng = null;
    }
  }

  void _setOrigin(double lat, double lng, String address) {
    _originLat = lat;
    _originLng = lng;
    _lastOriginText = address;
    _originController.text = address;
    _originController.selection = TextSelection.fromPosition(
      TextPosition(offset: _originController.text.length),
    );
  }

  void _setDestination(double lat, double lng, String address) {
    _destinationLat = lat;
    _destinationLng = lng;
    _lastDestinationText = address;
    _destinationController.text = address;
    _destinationController.selection = TextSelection.fromPosition(
      TextPosition(offset: _destinationController.text.length),
    );
  }

  @override
  void dispose() {
    _originController.removeListener(_onOriginChanged);
    _destinationController.removeListener(_onDestinationChanged);
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _searchAndBook() async {
    final destinationText = _destinationController.text.trim();

    if (destinationText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa un destino')),
      );
      return;
    }

    setState(() => _isSearching = true);

    try {
      double realOriginLat = _originLat ?? 0.0;
      double realOriginLng = _originLng ?? 0.0;
      
      if (realOriginLat == 0.0 || realOriginLng == 0.0) {
        if (_originController.text.trim().toLowerCase() == 'mi ubicación actual' || _originController.text.trim().isEmpty) {
          final originPosition = await LocationService.instance.current();
          realOriginLat = originPosition.latitude;
          realOriginLng = originPosition.longitude;
        } else {
          final locs = await geo.locationFromAddress(_originController.text.trim());
          if (locs.isEmpty) throw Exception('Dirección de origen no encontrada');
          realOriginLat = locs.first.latitude;
          realOriginLng = locs.first.longitude;
        }
      }

      double destLat = _destinationLat ?? 0.0;
      double destLng = _destinationLng ?? 0.0;

      if (destLat == 0.0 || destLng == 0.0) {
        final locations = await geo.locationFromAddress(destinationText);
        if (locations.isEmpty) {
          throw Exception('Dirección no encontrada');
        }
        destLat = locations.first.latitude;
        destLng = locations.first.longitude;
      }

      final distanceKm = LocationService.instance.distanceKm(
        realOriginLat,
        realOriginLng,
        destLat,
        destLng,
      );

      final user = AuthService.instance.currentUser;
      final city = user?.city ?? 'Tarapoto';

      // Estimar duración basada en velocidad promedio (ej: 30 km/h)
      final durationMin = (distanceKm / AppConfig.estimatedCitySpeedKmh) * 60.0;

      // Obtener settings de precios de Firestore
      final settings = await FirestoreService.instance.getPricingSettings();
      
      // Calcular tarifa usando quote
      final quote = settings.quote(
        category: VehicleCategory.moto,
        distanceKm: distanceKm,
        durationMin: durationMin,
        hour: DateTime.now().hour,
      );

      final fare = quote.total;

      if (!mounted) return;

      setState(() {
        _estimatedFare = fare;
        _isSearching = false;
      });

      // 7. Pasar todos los datos reales a la pantalla de pago con GeoPoints garantizados.
      Navigator.of(context).pushNamed(
        '/payment',
        arguments: {
          'destination': destinationText,
          'fare': fare,
          'paymentMethod': _selectedPaymentMethod,
          'distanceKm': distanceKm,
          'city': city,
          'origin': GeoPoint(realOriginLat, realOriginLng),
          'destinationGeoPoint': GeoPoint(
            destLat,
            destLng,
          ),
        },
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSearching = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo localizar el destino. '
            'Intenta escribir una dirección más específica.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9D408),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Nuevo viaje', style: TextStyle(color: Colors.black)),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 20.0, bottom: 120.0), // Padding extra abajo para el sheet
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),

                  // Contenedor unificado para Origen y Destino (De y A)
                  Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9D408).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF9D408), width: 1.5),
                ),
                child: Column(
                  children: [
                    // Campo de Origen (De:) con Autocompletado de Google Places
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: GooglePlaceAutoCompleteTextField(
                        textEditingController: _originController,
                        googleAPIKey: "AIzaSyD6cjdfoAhxKfZr--aCqvshyiS8jB7V_Sw",
                        debounceTime: 600,
                        isLatLngRequired: true,
                        countries: const ["pe"], // Restricción solo a Perú
                        inputDecoration: InputDecoration(
                          labelText: 'De:',
                          hintText: 'Mi ubicación actual',
                          prefixIcon: const Icon(Icons.trip_origin, color: Colors.black87),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.map_outlined),
                            tooltip: 'Elegir en el mapa',
                            onPressed: () async {
                              final picked = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MapPickerScreen(
                                    initialLat: _originLat,
                                    initialLng: _originLng,
                                  ),
                                ),
                              );
                              if (picked is PickedLocation) {
                                _setOrigin(picked.lat, picked.lng, picked.address);
                              }
                            },
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        itemClick: (Prediction prediction) {
                          final text = prediction.description ?? "";
                          _lastOriginText = text;
                          _originController.text = text;
                          _originController.selection = TextSelection.fromPosition(
                            TextPosition(offset: _originController.text.length),
                          );
                          
                          if (prediction.lat != null && prediction.lng != null) {
                            _originLat = double.tryParse(prediction.lat!);
                            _originLng = double.tryParse(prediction.lng!);
                          }
                        },
                        itemBuilder: (context, index, Prediction prediction) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on, color: Colors.blueAccent, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    prediction.description ?? "",
                                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        boxDecoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    // Campo de Destino (A:) con Autocompletado de Google Places
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: GooglePlaceAutoCompleteTextField(
                        textEditingController: _destinationController,
                        googleAPIKey: "AIzaSyD6cjdfoAhxKfZr--aCqvshyiS8jB7V_Sw",
                        debounceTime: 600,
                        isLatLngRequired: true,
                        countries: const ["pe"], // Restricción solo a Perú
                        inputDecoration: InputDecoration(
                          hintText: 'A: ¿A dónde vas?',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.map_outlined),
                            tooltip: 'Elegir en el mapa',
                            onPressed: () async {
                              final picked = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MapPickerScreen(
                                    initialLat: _destinationLat,
                                    initialLng: _destinationLng,
                                  ),
                                ),
                              );
                              if (picked is PickedLocation) {
                                _setDestination(picked.lat, picked.lng, picked.address);
                              }
                            },
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        itemClick: (Prediction prediction) async {
                          final text = prediction.description ?? "";
                          _lastDestinationText = text;
                          _destinationController.text = text;
                          _destinationController.selection = TextSelection.fromPosition(
                            TextPosition(offset: _destinationController.text.length),
                          );

                          // Capturar lat y lng si el componente las provee directamente
                          if (prediction.lat != null && prediction.lng != null) {
                            _destinationLat = double.tryParse(prediction.lat!);
                            _destinationLng = double.tryParse(prediction.lng!);
                          } else if (prediction.description != null) {
                            // Respaldo por geocodificación rápida si no vienen explícitas
                            try {
                              final locs = await geo.locationFromAddress(prediction.description!);
                              if (locs.isNotEmpty) {
                                _destinationLat = locs.first.latitude;
                                _destinationLng = locs.first.longitude;
                              }
                            } catch (_) {}
                          }
                        },
                        itemBuilder: (context, index, Prediction prediction) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on, color: Colors.redAccent, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    prediction.description ?? "",
                                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        boxDecoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // Tarifa estimada.
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tarifa estimada',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'S/. ${_estimatedFare.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE5B800),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Forma de pago.
              const Text(
                'Forma de pago',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 5),

              RadioListTile<String>(
                title: const Text('Efectivo'),
                value: 'cash',
                groupValue: _selectedPaymentMethod,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedPaymentMethod = value;
                  });
                },
                activeColor: const Color(0xFFF9D408),
              ),

              RadioListTile<String>(
                title: const Text('Billetera digital'),
                value: 'wallet',
                groupValue: _selectedPaymentMethod,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedPaymentMethod = value;
                  });
                },
                activeColor: const Color(0xFFF9D408),
              ),

              const SizedBox(height: 20),

              // Buscar conductor.
              ElevatedButton(
                onPressed: _isSearching ? null : _searchAndBook,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF9D408),
                  disabledBackgroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSearching
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.black),
                        ),
                      )
                    : const Text(
                        'Buscar conductor',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
        FrequentPlacesSheet(
          onPlaceSelected: (place) {
            _lastDestinationText = place;
            _destinationController.text = place;
            _destinationLat = null;
            _destinationLng = null;
          },
        ),
      ],
    ),
  );
}
}