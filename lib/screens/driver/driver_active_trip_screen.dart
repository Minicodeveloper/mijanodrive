import 'package:flutter/material.dart';

import '../../models/trip_model.dart';
import '../../services/firestore_service.dart';

/// Pantalla del conductor para gestionar el viaje que acaba de aceptar.
class DriverActiveTripScreen extends StatelessWidget {
  final String tripId;

  const DriverActiveTripScreen({super.key, required this.tripId});

  String _statusLabel(TripStatus status) {
    switch (status) {
      case TripStatus.accepted:
        return 'Dirígete al punto de recojo';
      case TripStatus.active:
        return 'Viaje en curso';
      case TripStatus.completed:
        return 'Viaje completado';
      case TripStatus.cancelled:
        return 'Viaje cancelado';
      case TripStatus.pending:
        return 'Esperando confirmación';
    }
  }

  Future<void> _updateStatus(BuildContext context, String status) async {
    try {
      await FirestoreService.instance.updateTrip(tripId, {
        'status': status,
        if (status == 'completed') 'completedAt': DateTime.now(),
      });
      if (context.mounted && status == 'completed') {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar el viaje.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Trip?>(
      stream: FirestoreService.instance.tripStream(tripId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('No se pudo cargar el viaje.')),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final trip = snapshot.data;
        if (trip == null) {
          return const Scaffold(
            body: Center(child: Text('Este viaje ya no está disponible.')),
          );
        }

        final isAccepted = trip.status == TripStatus.accepted;
        final isActive = trip.status == TripStatus.active;
        final isFinished =
            trip.status == TripStatus.completed ||
            trip.status == TripStatus.cancelled;

        return Scaffold(
          appBar: AppBar(title: const Text('Viaje asignado')),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  isFinished ? Icons.check_circle : Icons.directions_car,
                  size: 72,
                  color: isFinished
                      ? Colors.green
                      : Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 24),
                Text(
                  _statusLabel(trip.status),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 32),
                _TripDetail(
                  label: 'Origen',
                  value: trip.originAddress ?? 'Ubicación de recojo',
                ),
                _TripDetail(
                  label: 'Destino',
                  value: trip.destinationAddress ?? 'Destino del pasajero',
                ),
                _TripDetail(
                  label: 'Tarifa',
                  value: 'S/. ${trip.fareAmount.toStringAsFixed(2)}',
                ),
                _TripDetail(label: 'Pago', value: trip.paymentMethod.name),
                const Spacer(),
                if (isAccepted)
                  FilledButton.icon(
                    onPressed: () => _updateStatus(context, 'active'),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Iniciar viaje'),
                  ),
                if (isActive)
                  FilledButton.icon(
                    onPressed: () => _updateStatus(context, 'completed'),
                    icon: const Icon(Icons.flag),
                    label: const Text('Finalizar viaje'),
                  ),
                if (isFinished)
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Volver al panel'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TripDetail extends StatelessWidget {
  final String label;
  final String value;

  const _TripDetail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}
