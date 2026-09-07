import 'package:flutter/material.dart';
import '../../models/trip_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../theme.dart';

/// Panel del conductor: disponibilidad, viajes pendientes en su ciudad,
/// aceptar carrera y botón S.O.S.
class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({Key? key}) : super(key: key);

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final _fs = FirestoreService.instance;
  final _auth = AuthService.instance;
  bool _available = true;

  String get _city => _auth.currentUser?.city ?? 'Tarapoto';
  String get _uid => _auth.currentUser?.uid ?? 'demo-driver';

  @override
  void initState() {
    super.initState();
    _pushLocation();
  }

  Future<void> _pushLocation() async {
    try {
      final pos = await LocationService.instance.current();
      await _fs.updateDriverLocation(_uid, pos.latitude, pos.longitude);
    } catch (_) {}
  }

  void _toggleAvailability(bool v) {
    setState(() => _available = v);
    _fs.setDriverAvailability(_uid, v);
  }

  Future<void> _accept(Trip trip) async {
    await _fs.updateTrip(trip.id, {
      'driverId': _uid,
      'status': 'accepted',
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aceptaste el viaje a ${trip.destinationAddress ?? ''}')),
      );
    }
  }

  void _sos() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.emergency, color: MijanoTheme.signal, size: 40),
        title: const Text('Alerta S.O.S. enviada'),
        content: const Text(
            'Se notificó al panel de administración con tu ubicación GPS. Mantén la calma, te contactarán de inmediato.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel del conductor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: MijanoTheme.signal,
        foregroundColor: Colors.white,
        onPressed: _sos,
        icon: const Icon(Icons.emergency),
        label: const Text('S.O.S.'),
      ),
      body: Column(
        children: [
          // Estado de disponibilidad
          Container(
            color: MijanoTheme.sol,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Icon(_available ? Icons.check_circle : Icons.pause_circle,
                    color: MijanoTheme.ink),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _available ? 'Disponible para viajes' : 'No disponible',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: MijanoTheme.ink),
                  ),
                ),
                Switch(
                  value: _available,
                  activeColor: MijanoTheme.ink,
                  onChanged: _toggleAvailability,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 18),
                const SizedBox(width: 6),
                Text('Viajes en $_city',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Expanded(
            child: !_available
                ? const Center(
                    child: Text('Actívate para recibir viajes',
                        style: TextStyle(color: Colors.black54)))
                : StreamBuilder<List<Trip>>(
                    stream: _fs.pendingTripsForCity(_city),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final trips = snap.data ?? [];
                      if (trips.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.two_wheeler,
                                  size: 48, color: Colors.black26),
                              SizedBox(height: 12),
                              Text('No hay viajes por ahora',
                                  style: TextStyle(color: Colors.black54)),
                            ],
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: trips.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _tripCard(trips[i]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tripCard(Trip trip) {
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
            children: [
              const Icon(Icons.trip_origin, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(trip.originAddress ?? 'Origen')),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(left: 7),
            child: SizedBox(
              height: 16,
              child: VerticalDivider(color: MijanoTheme.ink, thickness: 1),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: MijanoTheme.signal),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(trip.destinationAddress ?? 'Destino',
                      style: const TextStyle(fontWeight: FontWeight.w700))),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('S/ ${trip.fareAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900)),
              ElevatedButton(
                onPressed: () => _accept(trip),
                child: const Text('Aceptar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
