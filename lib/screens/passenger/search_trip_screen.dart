import 'package:flutter/material.dart';

class SearchTripScreen extends StatefulWidget {
  const SearchTripScreen({Key? key}) : super(key: key);

  @override
  State<SearchTripScreen> createState() => _SearchTripScreenState();
}

class _SearchTripScreenState extends State<SearchTripScreen> {
  final _destinationController = TextEditingController();
  String _selectedPaymentMethod = 'cash';
  double _estimatedFare = 15.00;

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _searchAndBook() async {
    final destination = _destinationController.text;
    if (destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa un destino')),
      );
      return;
    }

    // TODO: Navigate to payment screen with trip data
    Navigator.of(context).pushNamed(
      '/payment',
      arguments: {
        'destination': destination,
        'fare': _estimatedFare,
        'paymentMethod': _selectedPaymentMethod,
      },
    );
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
              // Destination input
              TextField(
                controller: _destinationController,
                decoration: InputDecoration(
                  hintText: 'Ingresa destino',
                  labelText: 'A dónde vas?',
                  prefixIcon: const Icon(Icons.location_on),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Quick suggestions
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
                  _buildQuickButton('Supermercado', Icons.shopping_cart),
                  _buildQuickButton('Hospital', Icons.local_hospital),
                ],
              ),
              const SizedBox(height: 30),
              // Estimated fare
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
                        color: Color(0xFFF9D408),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Payment method selection
              const Text(
                'Forma de pago',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              RadioListTile(
                title: const Text('Efectivo'),
                value: 'cash',
                groupValue: _selectedPaymentMethod,
                onChanged: (value) {
                  setState(() => _selectedPaymentMethod = value as String);
                },
                activeColor: const Color(0xFFF9D408),
              ),
              RadioListTile(
                title: const Text('Billetera digital'),
                value: 'wallet',
                groupValue: _selectedPaymentMethod,
                onChanged: (value) {
                  setState(() => _selectedPaymentMethod = value as String);
                },
                activeColor: const Color(0xFFF9D408),
              ),
              const SizedBox(height: 30),
              // Search button
              ElevatedButton(
                onPressed: _searchAndBook,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF9D408),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
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
      onTap: () {
        _destinationController.text = label;
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
            Icon(icon, color: const Color(0xFFF9D408)),
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
