import 'package:flutter/material.dart';

class PassengerHistoryScreen extends StatelessWidget {
  const PassengerHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Lista de ejemplo de viajes anteriores
    final List<Map<String, String>> pastTrips = [
      {
        'date': '26 Sep 2026, 04:15 PM',
        'origin': 'Jr. Ramirez Hurtado 120',
        'destination': 'Aeropuerto Cad. FAP Guillermo del Castillo Paredes',
        'fare': 'S/ 15.00',
        'status': 'Completado',
      },
      {
        'date': '24 Sep 2026, 09:30 AM',
        'origin': 'Plaza de Armas de Tarapoto',
        'destination': 'Universidad Nacional de San Martín',
        'fare': 'S/ 8.00',
        'status': 'Completado',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Historial de viajes',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFF9D408),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: pastTrips.isEmpty
          ? const Center(
              child: Text(
                'No tienes viajes registrados aún.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: pastTrips.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final trip = pastTrips[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}