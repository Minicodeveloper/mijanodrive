import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme.dart';
import '../../services/auth_service.dart';

class PassengerHistoryScreen extends StatelessWidget {
  const PassengerHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = AuthService.instance.currentUser?.uid ?? '';

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
      body: currentUserId.isEmpty
          ? const Center(
              child: Text(
                'Inicia sesión para ver tu historial.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('trips')
                  .where('passengerId', isEqualTo: currentUserId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No tienes viajes registrados aún.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                // 1. Filtrar localmente los viajes que estén completados
                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status']?.toString().toLowerCase() ?? '';
                  return status == 'completed' || status.contains('completed') || status.contains('completado');
                }).toList();

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No tienes viajes completados todavía.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                // 2. Ordenar los documentos de forma descendente (del más reciente al más antiguo)
                docs.sort((a, b) {
                  final dataA = a.data() as Map<String, dynamic>;
                  final dataB = b.data() as Map<String, dynamic>;
                  
                  final dateA = dataA['createdAt'] ?? dataA['timestamp'];
                  final dateB = dataB['createdAt'] ?? dataB['timestamp'];

                  if (dateA is Timestamp && dateB is Timestamp) {
                    return dateB.compareTo(dateA); // Del más nuevo al más antiguo
                  }
                  return 0;
                });

                return ListView.builder(
                  itemCount: docs.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final tripId = docs[index].id;

                    // Extracción y formateo seguro de la fecha
                    final rawDate = data['createdAt'] ?? data['timestamp'];
                    String dateStr = 'Fecha reciente';
                    if (rawDate != null && rawDate is Timestamp) {
                      final dt = rawDate.toDate();
                      dateStr = '${dt.day}/${dt.month}/${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                    } else if (rawDate != null) {
                      dateStr = rawDate.toString();
                    }

                    // Direcciones exactas de Firestore
                    final origin = data['originAddress'] ?? 'Origen desconocido';
                    final destination = data['destinationAddress'] ?? 'Destino desconocido';
                    
                    // Tarifa
                    final rawFare = data['fareAmount'] ?? 0.0;
                    final fareValue = double.tryParse(rawFare.toString()) ?? 0.0;
                    final fareStr = 'S/ ${fareValue.toStringAsFixed(2)}';

                    // Datos del conductor y vehículo basados en tu estructura
                    final driverName = data['driverName'] ?? 'Conductor asignado';
                    final vehicleBrand = data['driverVehicleBrand'] ?? '';
                    final vehicleModel = data['driverVehicleModel'] ?? 'Vehículo';
                    final driverPlate = data['driverPlate'] ?? 'N/A';
                    final vehicle = '$vehicleBrand $vehicleModel (Placa: $driverPlate)';
                    final paymentMethod = data['paymentMethod'] ?? 'Efectivo';

                    final tripMap = {
                      'tripId': tripId,
                      'date': dateStr,
                      'origin': origin,
                      'destination': destination,
                      'fare': fareStr,
                      'status': 'Completado',
                      'driverName': driverName,
                      'vehicle': vehicle,
                      'paymentMethod': paymentMethod,
                    };

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
                              builder: (context) => PassengerTripDetailScreen(tripData: tripMap),
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
                                    dateStr,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    fareStr,
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
                                      'Origen: $origin',
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
                                      'Destino: $destination',
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
                );
              },
            ),
    );
  }
}

/// Pantalla de detalles del viaje para el pasajero
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