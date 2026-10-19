import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme.dart';

class PassengerReservedTripsScreen extends StatelessWidget {
  const PassengerReservedTripsScreen({super.key, this.initialTripId});

  final String? initialTripId;

  @override
  Widget build(BuildContext context) {
    final passengerId = AuthService.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Viajes reservados',
          style: TextStyle(
            color: MijanoTheme.ink,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: MijanoTheme.sol,
        elevation: 0,
        iconTheme: const IconThemeData(color: MijanoTheme.ink),
      ),
      body: passengerId.isEmpty
          ? const Center(
              child: Text(
                'Inicia sesión para ver tus viajes reservados.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('trips')
                  .where('passengerId', isEqualTo: passengerId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('No se pudieron cargar tus viajes reservados.'),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final reservations =
                    snapshot.data?.docs.where((doc) {
                      final data = doc.data();
                      return data['serviceType'] == 'Programar viaje' ||
                          data['scheduledAt'] is Timestamp;
                    }).toList() ??
                    [];

                reservations.sort((a, b) {
                  if (a.id == initialTripId) return -1;
                  if (b.id == initialTripId) return 1;
                  final dateA = a.data()['scheduledAt'];
                  final dateB = b.data()['scheduledAt'];
                  if (dateA is Timestamp && dateB is Timestamp) {
                    return dateA.compareTo(dateB);
                  }
                  return dateA is Timestamp ? -1 : dateB is Timestamp ? 1 : 0;
                });

                if (reservations.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Aún no tienes viajes reservados.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reservations.length,
                  itemBuilder: (context, index) {
                    final data = reservations[index].data();
                    final scheduledAt = data['scheduledAt'];
                    final scheduledDate = scheduledAt is Timestamp
                        ? scheduledAt.toDate()
                        : null;
                    final status = _statusLabel(data['status']?.toString());
                    final fare =
                        (num.tryParse(data['fareAmount']?.toString() ?? '') ??
                                0)
                            .toDouble();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.event,
                                  color: Color(0xFFF9D408),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    scheduledDate == null
                                        ? 'Fecha pendiente'
                                        : '${MaterialLocalizations.of(context).formatMediumDate(scheduledDate)} · '
                                              '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(scheduledDate))}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  status,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            _TripAddressRow(
                              icon: Icons.trip_origin,
                              label: 'Origen',
                              address:
                                  data['originAddress']?.toString() ??
                                  'Sin especificar',
                            ),
                            const SizedBox(height: 10),
                            _TripAddressRow(
                              icon: Icons.location_on,
                              label: 'Destino',
                              address:
                                  data['destinationAddress']?.toString() ??
                                  'Sin especificar',
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Tarifa estimada: S/ ${fare.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (data['driverName'] != null) ...[
                              const SizedBox(height: 6),
                              Text('Conductor: ${data['driverName']}'),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  static String _statusLabel(String? status) {
    switch (status?.toLowerCase()) {
      case 'accepted':
        return 'Conductor asignado';
      case 'cancelled':
        return 'Cancelado';
      case 'completed':
        return 'Completado';
      case 'pending':
        return 'Pendiente';
      default:
        return status ?? 'Pendiente';
    }
  }
}

class _TripAddressRow extends StatelessWidget {
  const _TripAddressRow({
    required this.icon,
    required this.label,
    required this.address,
  });

  final IconData icon;
  final String label;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 8),
        Expanded(
          child: Text('$label: $address'),
        ),
      ],
    );
  }
}
