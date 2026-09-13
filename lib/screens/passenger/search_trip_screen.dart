import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../config/app_config.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';

class SearchTripScreen extends StatefulWidget {
  const SearchTripScreen({Key? key}) : super(key: key);

  @override
  State<SearchTripScreen> createState() => _SearchTripScreenState();
}

class _SearchTripScreenState extends State<SearchTripScreen> {
  final _destinationController = TextEditingController();

  String _selectedPaymentMethod = 'cash';
  double _estimatedFare = 15.00;
  bool _isSearching = false;

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _searchAndBook() async {
    final destination = _destinationController.text.trim();

    if (destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa un destino'),
        ),
      );
      return;
    }

    setState(() => _isSearching = true);

    try {
      // 1. Obtener ubicación actual del pasajero.
      final originPosition = await LocationService.instance.current();

      // 2. Coordenadas de demostración del destino.
const destinationLatitude = -6.4869;
const destinationLongitude = -76.3654;

      // 3. Calcular distancia real.
      final distanceKm = LocationService.instance.distanceKm(
  originPosition.latitude,
  originPosition.longitude,
  destinationLatitude,
  destinationLongitude,
);

      // 4. Obtener ciudad del usuario.
      final user = AuthService.instance.currentUser;
      final city = user?.city ?? 'Tarapoto';

      // 5. Obtener tarifa de Firestore.
      final firestoreTariff =
          await FirestoreService.instance.getCityTariff(city);

      final tariffData = firestoreTariff ??
          AppConfig.cityTariffs[city] ??
          AppConfig.cityTariffs['Tarapoto']!;

      final baseFare =
          (tariffData['base'] as num?)?.toDouble() ?? 3.0;

      final perKm =
          (tariffData['perKm'] as num?)?.toDouble() ?? 1.8;

      // 6. Calcular tarifa.
      final fare = baseFare + (distanceKm * perKm);

      if (!mounted) return;

      setState(() {
        _estimatedFare = fare;
        _isSearching = false;
      });

      // 7. Pasar todos los datos reales a la pantalla de pago.
      Navigator.of(context).pushNamed(
        '/payment',
        arguments: {
          'destination': destination,
          'fare': fare,
          'paymentMethod': _selectedPaymentMethod,
          'distanceKm': distanceKm,
          'city': city,
          'origin': GeoPoint(
            originPosition.latitude,
            originPosition.longitude,
          ),
          'destinationGeoPoint': GeoPoint(
            destinationLatitude,
            destinationLongitude,
         ),
        },
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSearching = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Nuevo viaje',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // Destino.
              TextField(
                controller: _destinationController,
                decoration: InputDecoration(
                  hintText: 'Ej. Plaza de Armas de Tarapoto',
                  labelText: '¿A dónde vas?',
                  prefixIcon: const Icon(Icons.location_on),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Lugares frecuentes.
              const Text(
                'Lugares frecuentes',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
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
                  _buildQuickButton(
                    'Supermercado',
                    Icons.shopping_cart,
                  ),
                  _buildQuickButton(
                    'Hospital',
                    Icons.local_hospital,
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Tarifa estimada.
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tarifa estimada',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'S/. ${_estimatedFare.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF9D408),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Forma de pago.
              const Text(
                'Forma de pago',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

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

              const SizedBox(height: 30),

              // Buscar conductor.
              ElevatedButton(
                onPressed: _isSearching
                    ? null
                    : _searchAndBook,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF9D408),
                  disabledBackgroundColor: Colors.grey,
                  padding:
                      const EdgeInsets.symmetric(vertical: 15),
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
                          valueColor:
                              AlwaysStoppedAnimation(
                            Colors.black,
                          ),
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

  Widget _buildQuickButton(
    String label,
    IconData icon,
  ) {
    return InkWell(
      onTap: () {
        _destinationController.text = label;
      },
      child: Container(
        margin: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: const Color(0xFFF9D408),
            ),
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