import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/trip_model.dart';
import '../../../theme.dart';

class _TripAlertDialog extends StatefulWidget {
  final Trip trip;
  final double? distance;
  final int initialSeconds;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onTimeout;
  final VoidCallback onInit;
  final VoidCallback onDispose;

  const _TripAlertDialog({
    Key? key,
    required this.trip,
    this.distance,
    required this.initialSeconds,
    required this.onAccept,
    required this.onReject,
    required this.onTimeout,
    required this.onInit,
    required this.onDispose,
  }) : super(key: key);

  @override
  State<_TripAlertDialog> createState() => _TripAlertDialogState();
}

class _TripAlertDialogState extends State<_TripAlertDialog> {
  Timer? _alertTimer;
  late int _secondsRemaining;

  @override
  void initState() {
    super.initState();
    widget.onInit();
    _secondsRemaining = widget.initialSeconds;
    if (_secondsRemaining > 0) {
      _alertTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_secondsRemaining > 1) {
          if (mounted) {
            setState(() {
              _secondsRemaining--;
            });
          }
        } else {
          timer.cancel();
          if (mounted) {
            widget.onTimeout();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _alertTimer?.cancel();
    widget.onDispose();
    super.dispose();
  }

  Widget _alertInfoRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 14),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.notifications_active, color: MijanoTheme.sol),
          const SizedBox(width: 8),
          const Expanded(child: Text('Nuevo viaje cercano')),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_secondsRemaining}s',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hay un pasajero solicitando un viaje cerca de tu ubicación.',
          ),
          const SizedBox(height: 16),
          _alertInfoRow(
            Icons.trip_origin,
            'Origen',
            widget.trip.originAddress ?? 'Origen no disponible',
          ),
          const SizedBox(height: 10),
          _alertInfoRow(
            Icons.location_on,
            'Destino',
            widget.trip.destinationAddress ?? 'Destino no disponible',
          ),
          const SizedBox(height: 10),
          _alertInfoRow(
            Icons.payments,
            'Tarifa',
            'S/ ${widget.trip.fareAmount.toStringAsFixed(2)}',
          ),
          if (widget.distance != null) ...[
            const SizedBox(height: 10),
            _alertInfoRow(
              Icons.near_me,
              'Distancia',
              '${widget.distance!.toStringAsFixed(2)} km',
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onReject,
          child: const Text('Rechazar'),
        ),
        ElevatedButton(
          onPressed: widget.onAccept,
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}
