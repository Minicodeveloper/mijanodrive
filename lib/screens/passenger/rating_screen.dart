import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';

class RatingScreen extends StatefulWidget {
  final String driverName;
  final String tripId;

  const RatingScreen({
    super.key,
    required this.driverName,
    required this.tripId,
  });

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  double _rating = 0;
  final _feedbackController = TextEditingController();
  bool _isSubmitting = false;

  // Lista de comentarios rápidos predefinidos
  final List<String> _quickComments = [
    'Cumpita Gracias!!🌟',
    'Chévere chochera!!',
    'Te falta cumpa!! ',
    'Muchas gracias…!',
    'Excelente servicio!!',
    'Mas o menos…',
    'No pasa nada cumpa…',
  ];

  // Método para agregar o alternar comentarios rápidos en el TextField
  void _toggleQuickComment(String comment) {
    final currentText = _feedbackController.text.trim();
    if (currentText.isEmpty) {
      _feedbackController.text = comment;
    } else {
      // Si ya contiene texto, lo agregamos separado por una coma o espacio
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
        const SnackBar(content: Text('Por favor selecciona una calificación')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await FirestoreService.instance.updateTrip(widget.tripId, {
        'rating': _rating,
        'feedback': _feedbackController.text.trim(),
      });

      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/home',
          (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gracias por tu calificación')),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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
          title: const Text(
            'Calificar viaje',
            style: TextStyle(color: Colors.black),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // Driver name
                Center(
                  child: Text(
                    'Viaje con ${widget.driverName}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // Star rating
                Center(
                  child: Column(
                    children: [
                      const Text(
                        'Califica el viaje',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final maxStarWidth = ((constraints.maxWidth - 20) / 5).clamp(20.0, 50.0);
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
                                    Icons.star,
                                    size: maxStarWidth,
                                    color: _rating > index
                                        ? Colors.amber
                                        : Colors.grey[300],
                                  ),
                                ),
                              );
                            }),
                          );
                        }
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _rating > 0
                            ? '${_rating.toStringAsFixed(0)} de 5 estrellas'
                            : 'Selecciona una calificación',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                
                // --- SECCIÓN DE COMENTARIOS RÁPIDOS (CHIPS) ---
                const Text(
                  'Comentarios rápidos',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: _quickComments.map((comment) {
                    return ActionChip(
                      backgroundColor: Colors.grey[100],
                      side: BorderSide(color: Colors.grey[300]!),
                      label: Text(
                        comment,
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
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
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Comparte tu experiencia o selecciona arriba...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
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