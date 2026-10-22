import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../models/trip_model.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import '../../widgets/mijano_icon.dart';

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
  Timer? _dispatchTimer;
  Trip? _currentTrip;
  bool _isRetrying = false;

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
    
    setState(() {
      _currentTrip = trip;
    });

    if (trip.status == TripStatus.accepted ||
        trip.status == TripStatus.arrived ||
        trip.status == TripStatus.active ||
        trip.status == TripStatus.completed) {
      _hasNavigated = true;
      _tripSub?.cancel();
      _dispatchTimer?.cancel();

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
      _dispatchTimer?.cancel();
      if (mounted) Navigator.of(context).pop();
    } else if (trip.status == TripStatus.pending) {
      _scheduleDispatchTimer(trip);
      if (trip.dispatchExhausted) {
        _pulseController.stop();
        _rotationController.stop();
      } else {
        if (!_pulseController.isAnimating) _pulseController.repeat();
        if (!_rotationController.isAnimating) _rotationController.repeat();
      }
    }
  }

  void _scheduleDispatchTimer(Trip trip) {
    _dispatchTimer?.cancel();
    if (trip.dispatchExhausted) return;

    final deadline = trip.dispatchDeadline;
    if (deadline == null) return;

    final delay = deadline.difference(DateTime.now());
    if (delay.isNegative) {
      // Si ya venció, avanzamos inmediatamente
      _advanceDispatch(trip.id, trip.dispatchIndex);
    } else {
      _dispatchTimer = Timer(delay, () {
        _advanceDispatch(trip.id, trip.dispatchIndex);
      });
    }
  }

  Future<void> _advanceDispatch(String tripId, int expectedIndex) async {
    try {
      await FirestoreService.instance.advanceDispatch(tripId, expectedIndex: expectedIndex);
    } catch (e) {
      debugPrint('Error advancing dispatch: $e');
    }
  }

  Future<void> _retryDispatch() async {
    setState(() => _isRetrying = true);
    try {
      await FirestoreService.instance.resetDispatch(widget.tripId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al reintentar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRetrying = false);
      }
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
      _dispatchTimer?.cancel();
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
    _dispatchTimer?.cancel();
    _tripSub?.cancel();
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  // ─── UI ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bool isExhausted = _currentTrip?.dispatchExhausted ?? false;
    final int queueLength = _currentTrip?.dispatchQueue.length ?? 0;
    final bool isQueueEmpty = queueLength == 0 && _currentTrip != null;

    final bool showExhaustedUI = isExhausted || isQueueEmpty;

    return PopScope(
      canPop: false, // Evita gestos de retroceso accidentales
      child: Scaffold(
        backgroundColor: MijanoTheme.cream,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 30),

              // ── Título ──
              Text(
                showExhaustedUI ? 'Sin conductores' : 'Buscando mototaxi cercano…',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: MijanoTheme.ink,
                ),
              ),

              const SizedBox(height: 8),
              if (showExhaustedUI)
                Text(
                  'No hay conductores disponibles en este momento.\nPuedes reintentar o cancelar tu solicitud.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                )
              else
                Text(
                  'Espera un momento, estamos buscando\nun conductor disponible para ti.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                
              if (!showExhaustedUI && _currentTrip != null && queueLength > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Buscando conductor… (${_currentTrip!.dispatchIndex + 1} de $queueLength)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
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
                        child: const MototaxiIcon(size: 60),
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

              if (showExhaustedUI)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isRetrying || _isCancelling ? null : _retryDispatch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MijanoTheme.sol,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isRetrying
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Text(
                              'Reintentar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),

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
