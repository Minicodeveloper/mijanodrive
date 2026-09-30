import 'package:flutter/material.dart';
import '../../theme.dart';

class PassengerHistoryScreen extends StatelessWidget {
  const PassengerHistoryScreen({super.key});

  // Lista de viajes declarada correctamente fuera del método build
  final List<Map<String, String>> _pastTrips = const [
    {
      'date': '26 Sep 2026, 04:15 PM',
      'origin': 'Jr. Ramirez Hurtado 120',
      'destination': 'Aeropuerto Cad. FAP Guillermo del Castillo Paredes',
      'fare': 'S/ 15.00',
      'status': 'Completado',
      'driverName': 'Carlos Mendoza',
      'vehicle': 'Hyundai Accent (Placa: ABC-123)',
      'paymentMethod': 'Efectivo',
      'tripId': 'TRIP-84920',
    },
    {
      'date': '24 Sep 2026, 09:30 AM',
      'origin': 'Plaza de Armas de Tarapoto',
      'destination': 'Universidad Nacional de San Martín',
      'fare': 'S/ 8.00',
      'status': 'Completado',
      'driverName': 'Luis Paredes',
      'vehicle': 'Toyota Yaris (Placa: XYZ-789)',
      'paymentMethod': 'Yape / Plin',
      'tripId': 'TRIP-84112',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Historial de viajes',
          style: TextStyle(
            color: MijanoTheme.ink,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: MijanoTheme.sol,
        elevation: 0,
        iconTheme: const IconThemeData(color: MijanoTheme.ink),
      ),
      body: _pastTrips.isEmpty
          ? const Center(
              child: Text(
                'No tienes viajes registrados aún.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _pastTrips.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final trip = _pastTrips[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PassengerTripDetailScreen(tripData: trip),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                trip['date']!,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                trip['fare']!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 18, color: Colors.redAccent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Origen: ${trip['origin']}',
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.flag, size: 18, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Destino: ${trip['destination']}',
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Ver detalles',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueAccent,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_ios, size: 12, color: Colors.blueAccent),
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

/// Pantalla de detalles incrustada en el mismo archivo
class PassengerTripDetailScreen extends StatelessWidget {
  final Map tripData;

  const PassengerTripDetailScreen({super.key, required this.tripData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Detalle del Viaje',
          style: TextStyle(
            color: MijanoTheme.ink,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: MijanoTheme.sol,
        elevation: 0,
        iconTheme: const IconThemeData(color: MijanoTheme.ink),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MijanoTheme.cream,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MijanoTheme.ink.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ID: ${tripData['tripId']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tripData['status']!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    tripData['fare']!,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: MijanoTheme.ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Ruta del viaje',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: MijanoTheme.ink),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Origen', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text(tripData['origin']!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        height: 20,
                        child: VerticalDivider(color: Colors.black26, thickness: 2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.flag, color: Colors.green, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Destino', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text(tripData['destination']!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Información adicional',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: MijanoTheme.ink),
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.black12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildDetailRow(Icons.person, 'Conductor', tripData['driverName']!),
                    const Divider(height: 20),
                    _buildDetailRow(Icons.directions_car, 'Vehículo', tripData['vehicle']!),
                    const Divider(height: 20),
                    _buildDetailRow(Icons.payment, 'Método de pago', tripData['paymentMethod']!),
                    const Divider(height: 20),
                    _buildDetailRow(Icons.calendar_today, 'Fecha y hora', tripData['date']!),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: MijanoTheme.ink),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: MijanoTheme.ink)),
            ],
          ),
        ),
      ],
    );
  }
}