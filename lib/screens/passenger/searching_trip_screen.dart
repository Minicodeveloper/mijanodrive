import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../models/trip_model.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';

/// Pantalla "radar" de espera que se muestra mientras el viaje está en
/// estado [TripStatus.pending].  Escucha en tiempo real el documento
/// `trips/{tripId}` y redirige automáticamente a `/active-trip` cuando
/// el conductor acepta el viaje.
class SearchingTripScreen extends StatefulWidget {
  final String tripId;
  final String destination;
  final double fare;

  const SearchingTripScreen({
    super.key,
    required this.tripId,
    required this.destination,
    required this.fare,
  });

  @override
  State<SearchingTripScreen> createState() => _SearchingTripScreenState();
}

class _SearchingTripScreenState extends State<SearchingTripScreen>
    with TickerProviderStateMixin {
  StreamSubscription<Trip?>? _tripSub;
  bool _isCancelling = false;
  bool _hasNavigated = false;

  // Animaciones del radar
  late AnimationController _pulseController;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();

    // Animación de pulsos concéntricos (2 s loop)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // Rotación suave del icono del mototaxi (4 s loop)
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    _listenTrip();
  }

  // ─── Escucha en tiempo real ──────────────────────────────────────
  void _listenTrip() {
    _tripSub = FirestoreService.instance
        .tripStream(widget.tripId)
        .listen(_onTripChanged);
  }

  void _onTripChanged(Trip? trip) {
    if (!mounted || _hasNavigated || trip == null) return;

    if (trip.status == TripStatus.accepted ||
        trip.status == TripStatus.arrived ||
        trip.status == TripStatus.active ||
        trip.status == TripStatus.completed) {
      _hasNavigated = true;
      _tripSub?.cancel();

      Navigator.of(context).pushReplacementNamed(
        '/active-trip',
        arguments: {
          'destination': widget.destination,
          'fare': widget.fare,
          'tripId': widget.tripId,
        },
      );
    } else if (trip.status == TripStatus.cancelled) {
      // Alguien canceló el viaje externamente
      _tripSub?.cancel();
      if (mounted) Navigator.of(context).pop();
    }
  }

  // ─── Cancelar solicitud ──────────────────────────────────────────
  Future<void> _cancelRequest() async {
    setState(() => _isCancelling = true);

    try {
      await FirestoreService.instance.updateTrip(widget.tripId, {
        'status': 'cancelled',
      });
      _tripSub?.cancel();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cancelar: $e')),
      );
    }
  }

  @override
  void dispose() {
    _tripSub?.cancel();
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  // ─── UI ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Evita gestos de retroceso accidentales
      child: Scaffold(
        backgroundColor: MijanoTheme.cream,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 30),

              // ── Título ──
              const Text(
                'Buscando mototaxi cercano…',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: MijanoTheme.ink,
                ),
              ),

              const SizedBox(height: 8),
              Text(
                'Espera un momento, estamos buscando\nun conductor disponible para ti.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),

              // ── Radar animado ──
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 260,
                    height: 260,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: _RadarPainter(
                            progress: _pulseController.value,
                          ),
                          child: child,
                        );
                      },
                      child: AnimatedBuilder(
                        animation: _rotationController,
                        builder: (context, child) {
                          final angle =
                              math.sin(_rotationController.value * 2 * math.pi) *
                                  0.15;
                          return Transform.rotate(
                            angle: angle,
                            child: child,
                          );
                        },
                        child: const Icon(
                          Icons.two_wheeler,
                          size: 52,
                          color: MijanoTheme.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Tarjeta de resumen ──
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: MijanoTheme.sol.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _infoRow(
                      Icons.location_on,
                      'Destino',
                      widget.destination,
                    ),
                    const SizedBox(height: 12),
                    _infoRow(
                      Icons.attach_money,
                      'Tarifa',
                      'S/. ${widget.fare.toStringAsFixed(2)}',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Botón cancelar ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isCancelling ? null : _cancelRequest,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MijanoTheme.signal,
                      side: const BorderSide(
                        color: MijanoTheme.signal,
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isCancelling
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(MijanoTheme.signal),
                            ),
                          )
                        : const Text(
                            'Cancelar solicitud',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: MijanoTheme.sol, size: 22),
        const SizedBox(width: 10),
        Text(
          '$label:',
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: MijanoTheme.ink,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Custom painter: pulsos de radar concéntricos ──────────────────
class _RadarPainter extends CustomPainter {
  final double progress;
  _RadarPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Dibujamos 3 anillos desfasados
    for (int i = 0; i < 3; i++) {
      final phase = (progress + i / 3) % 1.0;
      final radius = maxRadius * phase;
      final opacity = (1.0 - phase).clamp(0.0, 0.6);

      final paint = Paint()
        ..color = MijanoTheme.sol.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      canvas.drawCircle(center, radius, paint);
    }

    // Punto central sólido
    canvas.drawCircle(
      center,
      8,
      Paint()..color = MijanoTheme.sol,
    );
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
