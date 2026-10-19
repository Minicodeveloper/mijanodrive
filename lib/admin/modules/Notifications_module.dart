import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/notification_service.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  // Mostrar modal para crear nueva campaña
  void _showNewCampaignModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const NewCampaignDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.notifications, color: Colors.blueAccent, size: 28),
                ),
                const SizedBox(width: 16),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notificaciones',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Gestiona notificaciones push y campañas masivas',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 30),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[850]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Text('📢 ', style: TextStyle(fontSize: 18)),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Campañas Push Masivas',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Envía notificaciones push masivas a clientes o conductores con segmentación avanzada',
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showNewCampaignModal(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Nueva Campaña'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.grey, height: 1),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('push_campaigns')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(40.0),
                          child: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(40.0),
                          child: Center(
                            child: Text(
                              'No hay campañas masivas registradas.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        );
                      }

                      final docs = snapshot.data!.docs;

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => Divider(color: Colors.grey[850], height: 1),
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final docId = docs[index].id;
                          final title = data['title'] ?? '';
                          final message = data['message'] ?? '';
                          final audience = data['audience'] ?? 'PASSENGER';
                          final timestamp = data['createdAt'] as Timestamp?;
                          final dateStr = timestamp != null
                              ? DateFormat('dd/MM/yyyy hh:mm a').format(timestamp.toDate())
                              : 'Reciente';

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    children: [
                                      const Text('📱', style: TextStyle(fontSize: 16)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              message,
                                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: audience == 'PASSENGER' ? Colors.blue[900] : Colors.orange[900],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        audience,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    dateStr,
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ),
                                SizedBox(
                                  width: 60,
                                  child: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    onPressed: () async {
                                      await FirebaseFirestore.instance
                                          .collection('push_campaigns')
                                          .doc(docId)
                                          .delete();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// MODAL PARA CONFIGURAR LA NUEVA CAMPAÑA Y FILTROS AVANZADOS DIFERENCIADOS
// ===========================================================================
class NewCampaignDialog extends StatefulWidget {
  const NewCampaignDialog({super.key});

  @override
  State<NewCampaignDialog> createState() => _NewCampaignDialogState();
}

class _NewCampaignDialogState extends State<NewCampaignDialog> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  
  String _selectedAudience = 'PASSENGER'; // PASSENGER o DRIVER
  String _filterType = 'none'; // none, age_range, time_in_app, inactive_time
  
  // 1. Campos específicos para Rango de Edad
  double _minAge = 18;
  double _maxAge = 50;

  // 2. Campos específicos para Tiempo en la App
  String _selectedTimeUnit = 'Meses';
  final _timeValueController = TextEditingController();

  // 3. Campos específicos para Tiempo sin solicitar viajes (Inactividad)
  int _daysWithoutTrips = 7;

  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _timeValueController.dispose();
    super.dispose();
  }

  Future<void> _sendCampaign() async {
    if (_titleController.text.isEmpty || _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa el título y el mensaje')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final title = _titleController.text.trim();
      final body = _messageController.text.trim();
      final audience = _selectedAudience; // 'DRIVER' o 'PASSENGER'

      // 1. Guardar el registro general de la campaña
      await FirebaseFirestore.instance.collection('push_campaigns').add({
        'title': title,
        'message': body,
        'audience': audience,
        'filterType': _filterType,
        'filterDetails': _getFilterDetailsMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Obtener usuarios objetivo y registrar la notificación
      final usersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: audience == 'DRIVER' ? 'driver' : 'passenger')
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (var userDoc in usersQuery.docs) {
        final userId = userDoc.id;

        final notifRef = FirebaseFirestore.instance.collection('notifications').doc();
        batch.set(notifRef, {
          'userId': userId,
          'title': title,
          'body': body,
          'type': 'push_alert', // Tipo diferenciado para que no se dibuje como banner intrusivo
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Ejecutar todas las notificaciones en lote
      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Campaña creada y enviada con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar la campaña: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Map<String, dynamic> _getFilterDetailsMap() {
    switch (_filterType) {
      case 'age_range':
        return {'minAge': _minAge, 'maxAge': _maxAge};
      case 'time_in_app':
        return {'value': _timeValueController.text.trim(), 'unit': _selectedTimeUnit};
      case 'inactive_time':
        return {'daysWithoutTrips': _daysWithoutTrips};
      default:
        return {'description': 'Sin filtros adicionales'};
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text(
        'Nueva Campaña Push Masiva',
        style: TextStyle(color: Colors.white, fontSize: 18),
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Título de la notificación', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ej. ¡Promoción especial fin de semana!',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),

              const Text('Mensaje', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: _messageController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Escribe el cuerpo del mensaje...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),

              // Audiencia Principal
              const Text('Audiencia Principal', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedAudience,
                dropdownColor: const Color(0xFF2C2C2C),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: const [
                  DropdownMenuItem(value: 'PASSENGER', child: Text('Pasajeros (Clientes)')),
                  DropdownMenuItem(value: 'DRIVER', child: Text('Conductores')),
                ],
                onChanged: (val) => setState(() => _selectedAudience = val!),
              ),
              const SizedBox(height: 16),

              // Filtro principal de segmentación
              const Text('Segmentación y Filtros Avanzados', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _filterType,
                dropdownColor: const Color(0xFF2C2C2C),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('1. Todos (Sin filtro adicional)')),
                  DropdownMenuItem(value: 'age_range', child: Text('2. Filtrar por Rango de Edad')),
                  DropdownMenuItem(value: 'time_in_app', child: Text('3. Filtrar por Tiempo en la App')),
                  DropdownMenuItem(value: 'inactive_time', child: Text('4. Filtrar por Inactividad (Sin solicitar viajes)')),
                ],
                onChanged: (val) => setState(() => _filterType = val!),
              ),

              // ===============================================================
              // CAMPOS DINÁMICOS DIFERENTES Y ESPECÍFICOS PARA CADA OPCIÓN
              // ===============================================================

              // OPCIÓN 2: Rango de edad (Sliders interactivos)
              if (_filterType == 'age_range') ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🎯 Configuración de Rango de Edad:', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 10),
                      Text('Edad Mínima: ${_minAge.toInt()} años', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Slider(
                        value: _minAge,
                        min: 18,
                        max: 80,
                        divisions: 62,
                        activeColor: Colors.blueAccent,
                        label: _minAge.toInt().toString(),
                        onChanged: (val) => setState(() => _minAge = val),
                      ),
                      Text('Edad Máxima: ${_maxAge.toInt()} años', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Slider(
                        value: _maxAge,
                        min: 18,
                        max: 80,
                        divisions: 62,
                        activeColor: Colors.blueAccent,
                        label: _maxAge.toInt().toString(),
                        onChanged: (val) => setState(() => _maxAge = val),
                      ),
                    ],
                  ),
                ),
              ],

              // OPCIÓN 3: Tiempo en la app (Campo numérico + Selector de unidad)
              if (_filterType == 'time_in_app') ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('⏳ Configuración de Antigüedad en la App:', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _timeValueController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Ej. 6',
                                hintStyle: const TextStyle(color: Colors.grey),
                                filled: true,
                                fillColor: Colors.black45,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              value: _selectedTimeUnit,
                              dropdownColor: const Color(0xFF2C2C2C),
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.black45,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Días', child: Text('Días en la app')),
                                DropdownMenuItem(value: 'Meses', child: Text('Meses en la app')),
                                DropdownMenuItem(value: 'Años', child: Text('Años en la app')),
                              ],
                              onChanged: (val) => setState(() => _selectedTimeUnit = val!),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              // OPCIÓN 4: Tiempo sin solicitar viajes (Inactividad)
              if (_filterType == 'inactive_time') ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🚗 Configuración de Inactividad:', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 10),
                      const Text('Seleccione el tiempo mínimo sin pedir servicios:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        value: _daysWithoutTrips,
                        dropdownColor: const Color(0xFF2C2C2C),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.black45,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 7, child: Text('Al menos 7 días sin solicitar viajes')),
                          DropdownMenuItem(value: 15, child: Text('Al menos 15 días sin solicitar viajes')),
                          DropdownMenuItem(value: 30, child: Text('Al menos 1 mes sin solicitar viajes')),
                          DropdownMenuItem(value: 90, child: Text('Más de 3 meses sin solicitar viajes')),
                        ],
                        onChanged: (val) => setState(() => _daysWithoutTrips = val!),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendCampaign,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Crear y Enviar', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}