import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';

class DriverRatingPassengerScreen extends StatefulWidget {
  final String passengerName;
  final String tripId;
  final String passengerId;

  const DriverRatingPassengerScreen({
    super.key,
    required this.passengerName,
    required this.tripId,
    this.passengerId = '',
  });

  @override
  State<DriverRatingPassengerScreen> createState() =>
      _DriverRatingPassengerScreenState();
}

class _DriverRatingPassengerScreenState
    extends State<DriverRatingPassengerScreen> {
  double _rating = 0;
  final _feedbackController = TextEditingController();
  bool _isSubmitting = false;

  // Lista de comentarios rápidos predefinidos para calificar al pasajero
  final List<String> _quickComments = [
    'Puntual en el recojo 👍',
    'Excelente pasajero 🌟',
    'Muy amable y respetuoso 😊',
    'Pago exacto y rápido 💵',
    'Buena comunicación 📲',
    'Todo tranquilo 🤝',
    'Demoró en salir ⏳',
    'Ubicación confusa de llegar 📍',
    'Hizo esperar mucho tiempo ⏰',
  ];

  void _toggleQuickComment(String comment) {
    final currentText = _feedbackController.text.trim();
    if (currentText.isEmpty) {
      _feedbackController.text = comment;
    } else {
      if (!currentText.contains(comment)) {
        _feedbackController.text = '$currentText. $comment';
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona una calificación para el pasajero'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final feedback = _feedbackController.text.trim();

      // 1. Guardar la calificación del pasajero en el documento del viaje
      await FirestoreService.instance.updateTrip(widget.tripId, {
        'passengerRating': _rating,
        'passengerFeedback': feedback,
      });

      // 2. Si se tiene el ID del pasajero, actualizar su historial de calificaciones en 'users'
      if (widget.passengerId.isNotEmpty) {
        try {
          final userRef = FirebaseFirestore.instance
              .collection('users')
              .doc(widget.passengerId);
          final userDoc = await userRef.get();
          if (userDoc.exists) {
            final data = userDoc.data() ?? {};
            final currentAvg = (data['rating'] as num?)?.toDouble() ?? 5.0;
            final count = (data['ratingCount'] as num?)?.toInt() ?? 1;
            final newAvg = ((currentAvg * count) + _rating) / (count + 1);

            await userRef.update({
              'rating': double.parse(newAvg.toStringAsFixed(1)),
              'ratingCount': count + 1,
              'lastRatedAt': FieldValue.serverTimestamp(),
            });
          }
        } catch (_) {}
      }

      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/driver',
          (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Gracias por calificar al pasajero!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar calificación: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: const Color(0xFFF9D408),
          elevation: 0,
          leading: const SizedBox.shrink(),
          centerTitle: true,
          title: const Text(
            'Calificar al pasajero',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9D408).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 48,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Viaje finalizado con\n${widget.passengerName}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    children: [
                      const Text(
                        '¿Cómo fue tu experiencia con el pasajero?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final maxStarWidth =
                              ((constraints.maxWidth - 20) / 5)
                                  .clamp(20.0, 50.0);
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() => _rating = (index + 1).toDouble());
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: Icon(
                                    Icons.star_rounded,
                                    size: maxStarWidth,
                                    color: _rating > index
                                        ? Colors.amber
                                        : Colors.grey[300],
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _rating > 0
                            ? '${_rating.toStringAsFixed(0)} de 5 estrellas'
                            : 'Toca las estrellas para calificar',
                        style: TextStyle(
                          fontSize: 14,
                          color: _rating > 0 ? Colors.black87 : Colors.grey,
                          fontWeight:
                              _rating > 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // --- SECCIÓN DE COMENTARIOS RÁPIDOS (CHIPS) ---
                const Text(
                  'Comentarios rápidos para el pasajero',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 6.0,
                  children: _quickComments.map((comment) {
                    final isSelected =
                        _feedbackController.text.contains(comment);
                    return ActionChip(
                      backgroundColor: isSelected
                          ? const Color(0xFFF9D408).withValues(alpha: 0.3)
                          : Colors.grey[100],
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFFF9D408)
                            : Colors.grey[300]!,
                      ),
                      label: Text(
                        comment,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.black : Colors.black87,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      onPressed: () => _toggleQuickComment(comment),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Feedback textarea
                const Text(
                  'Comentarios adicionales (opcional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _feedbackController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText:
                        'Escribe algún detalle o selecciona opciones arriba...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit button
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRating,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF9D408),
                    disabledBackgroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.black),
                          ),
                        )
                      : const Text(
                          'Enviar calificación',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
