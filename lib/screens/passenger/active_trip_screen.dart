import 'package:flutter/material.dart';


class ActiveTripScreen extends StatefulWidget {
  final String destination;
  final double fare;
  final String tripId;

  const ActiveTripScreen({
    super.key,
    required this.destination,
    required this.fare,
    required this.tripId,
  });

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  bool _isSosTriggered = false;
  bool _isSendingSos = false;
  bool _hasNavigatedToRating = false;

  Driver? _driver;
  String? _lastDriverId;

  String _statusLabel(TripStatus status) {
    switch (status) {
      case TripStatus.pending:
        return 'Buscando conductor...';
      case TripStatus.accepted:
        return 'Conductor en camino';
      case TripStatus.active:
        return 'Viaje en curso';
      default:
        return '';
    }
  }

  void _fetchDriverIfNeeded(String? driverId) {
    if (driverId == null || driverId == _lastDriverId) return;
    _lastDriverId = driverId;
    FirestoreService.instance.getDriver(driverId).then((driver) {
      if (mounted) setState(() => _driver = driver);
    });
  }

  Future<void> _triggerSos() async {
    setState(() => _isSendingSos = true);
    try {
      final pos = await LocationService.instance.current();
      await FirestoreService.instance.createSosAlert(
        driverId: AuthService.instance.currentUser?.uid ?? '',
        latitude: pos.latitude,
        longitude: pos.longitude,
        city: AuthService.instance.currentUser?.city ?? 'Tarapoto',
      );
      if (mounted) {
        setState(() {
          _isSendingSos = false;
          _isSosTriggered = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingSos = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al enviar SOS: $e')));
      }
    }
  }

  Future<void> _cancelTrip() async {
    try {
      await FirestoreService.instance.updateTrip(widget.tripId, {
        'status': 'cancelled',
      });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cancelar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Trip?>(
      stream: FirestoreService.instance.tripStream(widget.tripId),
      builder: (context, snapshot) {
        final trip = snapshot.data;

        // Auto-navigate to rating when trip is completed.
        if (trip != null &&
            trip.status == TripStatus.completed &&
            !_hasNavigatedToRating) {
          _hasNavigatedToRating = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacementNamed(
              '/rating',
              arguments: {'driverName': 'Conductor', 'tripId': widget.tripId},
            );
          });
        }

        // Fetch driver data when driverId appears.
        if (trip != null) {
          _fetchDriverIfNeeded(trip.driverId);
        }

        return Scaffold(
          body: Stack(
            children: [
              // Map placeholder
              Container(
                color: Colors.grey[300],
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map, size: 60, color: Colors.grey),
                      SizedBox(height: 10),
                      Text('Mapa de viaje activo'),
                    ],
                  ),
                ),
              ),
              // Top info card
              Positioned(
                top: 40,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 10),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              trip != null
                                  ? _statusLabel(trip.status)
                                  : 'Cargando...',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Destino: ${widget.destination}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tarifa: S/. ${widget.fare.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              // Driver info card (bottom)
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 10),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Driver info header
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.grey[300],
                            child: const Icon(Icons.person, size: 30),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _driver != null
                                      ? 'Conductor'
                                      : 'Buscando conductor...',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    if (_driver != null) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: MijanoTheme.sol,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          _driver!.plate,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Icon(
                                        Icons.location_city,
                                        size: 14,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _driver!.city,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ] else
                                      Text(
                                        'Sin asignar',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                // TODO: Open WhatsApp or phone call
                              },
                              icon: const Icon(Icons.chat),
                              label: const Text('Chat'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                
                              },
                              icon: const Icon(Icons.call),
                              label: const Text('Llamar'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isSosTriggered || _isSendingSos
                                  ? null
                                  : _triggerSos,
                              icon: const Icon(Icons.warning),
                              label: const Text('SOS'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isSosTriggered
                                    ? Colors.red
                                    : MijanoTheme.sol,
                                foregroundColor: _isSosTriggered
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_isSosTriggered)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              border: Border.all(color: Colors.red[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'SOS activado. Soporte está en camino.',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      // Cancel button (only when pending)
                      if (trip != null && trip.status == TripStatus.pending)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: OutlinedButton(
                            onPressed: _cancelTrip,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                            child: const Text('Cancelar viaje'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
