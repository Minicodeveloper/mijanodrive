import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/trip_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

class PaymentScreen extends StatefulWidget {
  final String destination;
  final double fare;
  final String paymentMethod;
  final double distanceKm;
  final String city;
  final GeoPoint origin;
  final GeoPoint destinationGeoPoint;

  const PaymentScreen({
    Key? key,
    required this.destination,
    required this.fare,
    required this.paymentMethod,
    required this.distanceKm,
    required this.city,
    required this.origin,
    required this.destinationGeoPoint,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;

  Future<void> _confirmPayment() async {
    setState(() => _isProcessing = true);

    try {
      final user = AuthService.instance.currentUser;

      if (user == null) {
        throw Exception('No hay un usuario autenticado');
      }

      final trip = Trip(
  id: '',
  passengerId: user.uid,
  origin: widget.origin,
  destination: widget.destinationGeoPoint,
  status: TripStatus.pending,
  fareAmount: widget.fare,
  paymentMethod: widget.paymentMethod == 'cash'
      ? PaymentMethod.cash
      : PaymentMethod.wallet,
  createdAt: DateTime.now(),
  city: widget.city,
  distanceKm: widget.distanceKm,
);

      await FirestoreService.instance.createTrip(trip);

      if (!mounted) return;

      Navigator.of(context).pushNamed(
        '/active-trip',
        arguments: {
          'destination': widget.destination,
          'fare': widget.fare,
        },
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isProcessing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo crear el viaje: $e'),
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
        title: const Text(
          'Confirmar pago',
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

              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resumen del viaje',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Destino:'),
                        Flexible(
                          child: Text(
                            widget.destination,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Distancia:'),
                        Text(
                          '${widget.distanceKm.toStringAsFixed(2)} km',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Forma de pago:'),
                        Text(
                          widget.paymentMethod == 'cash'
                              ? 'Efectivo'
                              : 'Billetera',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Desglose de tarifa',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 15),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total del viaje:'),
                        Text(
                          'S/. ${widget.fare.toStringAsFixed(2)}',
                        ),
                      ],
                    ),

                    const Divider(),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'S/. ${widget.fare.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF9D408),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              if (widget.paymentMethod == 'cash')
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    border: Border.all(
                      color: Colors.orange[300]!,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info,
                        color: Colors.orange,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Prepara el efectivo. El conductor no tiene cambio.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 30),

              ElevatedButton(
                onPressed:
                    _isProcessing ? null : _confirmPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFFF9D408),
                  disabledBackgroundColor: Colors.grey,
                  padding:
                      const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(8),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(
                            Colors.black,
                          ),
                        ),
                      )
                    : const Text(
                        'Confirmar y buscar conductor',
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
}