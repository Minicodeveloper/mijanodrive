import 'package:flutter/material.dart';
import '../../models/trip_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';

class DriverHistoryScreen extends StatelessWidget {
  const DriverHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService.instance;
    final auth = AuthService.instance;
    final driverId = auth.currentUser?.uid ?? 'demo-driver';

    return Scaffold(
      body: StreamBuilder<List<Trip>>(
        
        stream: fs.completedTripsForDriver(driverId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Error al cargar el historial de viajes'),
            );
          }

          final trips = snapshot.data ?? [];

          if (trips.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.history, size: 64, color: Colors.black26),
                  SizedBox(height: 16),
                  Text(
                    'Aún no tienes viajes completados',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: trips.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final trip = trips[index];
              return _buildHistoryCard(trip);
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryCard(Trip trip) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MijanoTheme.cream,
        border: Border.all(color: MijanoTheme.ink, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Completado',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              Text(
                'S/ ${trip.fareAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: MijanoTheme.ink,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              const Icon(Icons.trip_origin, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  trip.originAddress ?? 'Origen desconocido',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(left: 7),
            child: SizedBox(
              height: 14,
              child: VerticalDivider(color: MijanoTheme.ink, thickness: 1),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: MijanoTheme.signal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  trip.destinationAddress ?? 'Destino desconocido',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}