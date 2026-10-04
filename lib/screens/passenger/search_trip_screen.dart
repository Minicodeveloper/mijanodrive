import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';

import '../../config/app_config.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import 'package:geocoding/geocoding.dart' as geo;

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

  @override
  void dispose() {
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
      
      final originPosition = await LocationService.instance.current();
      final realOriginLat = _originLat ?? originPosition.latitude;
      final realOriginLng = _originLng ?? originPosition.longitude;

      
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

      
      final firestoreTariff = await FirestoreService.instance.getCityTariff(
        city,
      );

      final tariffData =
          firestoreTariff ??
          AppConfig.cityTariffs[city] ??
          AppConfig.cityTariffs['Tarapoto']!;

      final baseFare = (tariffData['base'] as num?)?.toDouble() ?? 3.0;
      final perKm = (tariffData['perKm'] as num?)?.toDouble() ?? 1.8;

      // 6. Calcular tarifa.
      final fare = baseFare + (distanceKm * perKm);

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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
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
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        itemClick: (Prediction prediction) {
                          _originController.text = prediction.description ?? "";
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
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        itemClick: (Prediction prediction) async {
                          _destinationController.text = prediction.description ?? "";
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

              const SizedBox(height: 20),

              // Lugares frecuentes.
              const Text(
                'Lugares frecuentes',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.5,
                children: [
                  _buildQuickButton('Casa', Icons.home),
                  _buildQuickButton('Trabajo', Icons.work),
                  _buildQuickButton('Supermercado', Icons.shopping_cart),
                  _buildQuickButton('Hospital', Icons.local_hospital),
                ],
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
    );
  }

  Widget _buildQuickButton(String label, IconData icon) {
    return InkWell(
      onTap: () async {
        _destinationController.text = label;
        
        _destinationLat = null;
        _destinationLng = null;
      },
      child: Container(
        margin: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFE5B800)),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}