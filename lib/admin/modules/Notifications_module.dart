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
  void _showNewCampaignModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const NewCampaignDialog(),
    );
  }

  void _showEditScheduleModal(BuildContext context, String docId, Map<String, dynamic> data) {
    // A simplified modal just to update the scheduled time, could be fully implemented later or just cancel and create new
  }

  Future<void> _updateCampaignStatus(String docId, String status) async {
    await FirebaseFirestore.instance.collection('push_campaigns').doc(docId).update({'status': status});
  }

  Future<void> _resendCampaign(Map<String, dynamic> data) async {
    final Map<String, dynamic> newData = {
      'title': data['title'] ?? '',
      'message': data['message'] ?? '',
      'audience': data['audience'] ?? 'PASSENGER',
      'filterType': data['filterType'] ?? 'none',
      'filterDetails': data['filterDetails'] ?? {},
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'sending',
      'scheduledAt': null,
      'repeat': 'none',
      'repeatDays': null,
    };
    
    try {
      await FirebaseFirestore.instance.collection('push_campaigns').add(newData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Campaña reenviada con éxito (Enviando...)!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al reenviar la campaña: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
                const Expanded(
                  child: Column(
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
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isSmall = constraints.maxWidth < 500;
                        final textBlock = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('📢 ', style: TextStyle(fontSize: 18)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
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
                            ),
                          ],
                        );
                        final btn = ElevatedButton.icon(
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
                        );

                        if (isSmall) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              textBlock,
                              const SizedBox(height: 16),
                              btn,
                            ],
                          );
                        } else {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: textBlock),
                              const SizedBox(width: 16),
                              btn,
                            ],
                          );
                        }
                      },
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

                          final status = data['status'] ?? 'sent';
                          final scheduledAt = data['scheduledAt'] as Timestamp?;
                          final repeat = data['repeat'] ?? 'none';
                          
                          final sentCount = data['sentCount'] as int? ?? 0;
                          final failedCount = data['failedCount'] as int? ?? 0;

                          String dateStr = '';
                          if (scheduledAt != null && status == 'scheduled') {
                            final limaTime = scheduledAt.toDate().toUtc().subtract(const Duration(hours: 5));
                            dateStr = 'Prog: ${DateFormat('dd/MM/yyyy hh:mm a').format(limaTime)}';
                          } else {
                            final timestamp = data['createdAt'] as Timestamp?;
                            dateStr = timestamp != null
                                ? DateFormat('dd/MM/yyyy hh:mm a').format(timestamp.toDate().toUtc().subtract(const Duration(hours: 5)))
                                : 'Reciente';
                          }

                          Color statusColor;
                          String statusText;
                          switch (status) {
                            case 'scheduled':
                              statusColor = Colors.orangeAccent;
                              statusText = 'Programada';
                              break;
                            case 'sending':
                              statusColor = Colors.blueAccent;
                              statusText = 'Enviando';
                              break;
                            case 'cancelled':
                              statusColor = Colors.redAccent;
                              statusText = 'Cancelada';
                              break;
                            case 'error':
                              statusColor = Colors.red;
                              statusText = 'Con errores';
                              break;
                            case 'sent':
                            default:
                              statusColor = Colors.green;
                              statusText = 'Enviada';
                              break;
                          }

                          String repeatStr = '';
                          if (repeat == 'daily') repeatStr = ' (Diario)';
                          if (repeat == 'weekly') repeatStr = ' (Semanal)';

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 260),
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
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: statusColor.withOpacity(0.5)),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: audience == 'PASSENGER' ? Colors.blue[900] : Colors.orange[900],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    audience,
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Text(
                                  '$dateStr$repeatStr',
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                                if (status == 'sent' || status == 'error' || status == 'sending') ...[
                                  Text(
                                    'Enviados: $sentCount | Errores: $failedCount',
                                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _resendCampaign(data),
                                    icon: const Icon(Icons.refresh, size: 16, color: Colors.blueAccent),
                                    label: const Text('Reenviar', style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
                                  ),
                                ],
                                if (status == 'scheduled') ...[
                                  TextButton.icon(
                                    onPressed: () => _updateCampaignStatus(docId, 'cancelled'),
                                    icon: const Icon(Icons.cancel, size: 16, color: Colors.redAccent),
                                    label: const Text('Cancelar', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                                  ),
                                ],
                                if (status != 'scheduled')
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    onPressed: () async {
                                      await FirebaseFirestore.instance.collection('push_campaigns').doc(docId).delete();
                                    },
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

class NewCampaignDialog extends StatefulWidget {
  const NewCampaignDialog({super.key});

  @override
  State<NewCampaignDialog> createState() => _NewCampaignDialogState();
}

class _NewCampaignDialogState extends State<NewCampaignDialog> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  String _selectedAudience = 'PASSENGER';
  String _filterType = 'none';

  double _minAge = 18;
  double _maxAge = 50;

  String _selectedTimeUnit = 'Meses';
  final _timeValueController = TextEditingController();

  int _daysWithoutTrips = 7;

  // Nuevos campos para programación
  String _scheduleType = 'now'; // now, scheduled
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;
  String _repeatType = 'none'; // none, daily, weekly
  final List<int> _repeatDays = []; // 1=Lun .. 7=Dom

  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _timeValueController.dispose();
    super.dispose();
  }

  DateTime get _limaTimeNow {
    return DateTime.now().toUtc().subtract(const Duration(hours: 5));
  }

  Future<void> _pickDate() async {
    final nowLima = _limaTimeNow;
    final initial = _scheduledDate ?? nowLima;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(nowLima) ? nowLima : initial,
      firstDate: nowLima,
      lastDate: nowLima.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.blueAccent,
            onPrimary: Colors.white,
            surface: Color(0xFF2C2C2C),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _scheduledDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final initial = _scheduledTime ?? TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.blueAccent,
            onPrimary: Colors.white,
            surface: Color(0xFF2C2C2C),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _scheduledTime = picked);
    }
  }

  DateTime? _getScheduledUtc() {
    if (_scheduleType == 'now') return null;
    if (_scheduledDate == null || _scheduledTime == null) return null;
    final limaSelected = DateTime(
      _scheduledDate!.year, _scheduledDate!.month, _scheduledDate!.day,
      _scheduledTime!.hour, _scheduledTime!.minute,
    );
    return limaSelected.add(const Duration(hours: 5)).toUtc();
  }

  String _getScheduleSummary() {
    if (_scheduleType == 'now') return 'Se enviará inmediatamente.';
    if (_scheduledDate == null || _scheduledTime == null) {
      return 'Seleccione fecha y hora.';
    }
    final limaSelected = DateTime(
      _scheduledDate!.year, _scheduledDate!.month, _scheduledDate!.day,
      _scheduledTime!.hour, _scheduledTime!.minute,
    );
    final dateStr = DateFormat('dd/MM/yyyy').format(limaSelected);
    final timeStr = DateFormat('hh:mm a').format(limaSelected);
    return 'Se enviará el $dateStr a las $timeStr (hora Perú).';
  }

  void _toggleRepeatDay(int day) {
    setState(() {
      if (_repeatDays.contains(day)) {
        _repeatDays.remove(day);
      } else {
        _repeatDays.add(day);
      }
    });
  }

  Future<void> _sendCampaign() async {
    if (_titleController.text.isEmpty || _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa el título y el mensaje')),
      );
      return;
    }

    DateTime? scheduledUtc;
    if (_scheduleType == 'scheduled') {
      scheduledUtc = _getScheduledUtc();
      if (scheduledUtc == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seleccione fecha y hora válidas')),
        );
        return;
      }
      final nowUtc = DateTime.now().toUtc();
      if (scheduledUtc.difference(nowUtc).inMinutes < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La hora programada debe ser al menos 2 minutos en el futuro')),
        );
        return;
      }
      if (_repeatType == 'weekly' && _repeatDays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seleccione al menos un día de la semana')),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final title = _titleController.text.trim();
      final body = _messageController.text.trim();
      final audience = _selectedAudience;

      final status = _scheduleType == 'now' ? 'sending' : 'scheduled';
      final scheduledAt = scheduledUtc != null ? Timestamp.fromDate(scheduledUtc) : null;

      await FirebaseFirestore.instance.collection('push_campaigns').add({
        'title': title,
        'message': body,
        'audience': audience,
        'filterType': _filterType,
        'filterDetails': _getFilterDetailsMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': status,
        'scheduledAt': scheduledAt,
        'repeat': _scheduleType == 'now' ? 'none' : _repeatType,
        'repeatDays': (_scheduleType == 'scheduled' && _repeatType == 'weekly') ? _repeatDays : null,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_scheduleType == 'now' ? '¡Campaña iniciada con éxito!' : '¡Campaña programada!'),
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text(
        'Nueva Campaña Push Masiva',
        style: TextStyle(color: Colors.white, fontSize: 18),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
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

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Audiencia Principal', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedAudience,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF2C2C2C),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'PASSENGER', child: Text('Pasajeros (Clientes)', maxLines: 1, overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'DRIVER', child: Text('Conductores', maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (val) => setState(() => _selectedAudience = val!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Momento de envío', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _scheduleType,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF2C2C2C),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'now', child: Text('Enviar ahora', maxLines: 1, overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'scheduled', child: Text('Programar', maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (val) => setState(() => _scheduleType = val!),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_scheduleType == 'scheduled') ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🗓 Programación', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickDate,
                              icon: const Icon(Icons.calendar_today, size: 16, color: Colors.white70),
                              label: Text(
                                _scheduledDate == null ? 'Elegir Fecha' : DateFormat('dd/MM/yyyy').format(_scheduledDate!),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickTime,
                              icon: const Icon(Icons.access_time, size: 16, color: Colors.white70),
                              label: Text(
                                _scheduledTime == null ? 'Elegir Hora' : _scheduledTime!.format(context),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(_getScheduleSummary(), style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      const Text('Repetición:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _repeatType,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF2C2C2C),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.black45,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'none', child: Text('Una sola vez', maxLines: 1, overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'daily', child: Text('Todos los días a esta hora', maxLines: 1, overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'weekly', child: Text('Días de la semana', maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (val) => setState(() => _repeatType = val!),
                      ),
                      if (_repeatType == 'weekly') ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (int i = 1; i <= 7; i++)
                              ChoiceChip(
                                label: Text(['L', 'M', 'X', 'J', 'V', 'S', 'D'][i - 1]),
                                selected: _repeatDays.contains(i),
                                onSelected: (_) => _toggleRepeatDay(i),
                                selectedColor: Colors.blueAccent.withOpacity(0.5),
                                backgroundColor: Colors.black45,
                                labelStyle: const TextStyle(color: Colors.white),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const Text('Segmentación y Filtros Avanzados', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _filterType,
                isExpanded: true,
                dropdownColor: const Color(0xFF2C2C2C),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('1. Todos (Sin filtro adicional)', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'age_range', child: Text('2. Filtrar por Rango de Edad', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'time_in_app', child: Text('3. Filtrar por Tiempo en la App', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'inactive_time', child: Text('4. Inactividad (sin pedir viajes)', maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (val) => setState(() => _filterType = val!),
              ),

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
                              isExpanded: true,
                              dropdownColor: const Color(0xFF2C2C2C),
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.black45,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Días', child: Text('Días en la app', maxLines: 1, overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Meses', child: Text('Meses en la app', maxLines: 1, overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Años', child: Text('Años en la app', maxLines: 1, overflow: TextOverflow.ellipsis)),
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
                        isExpanded: true,
                        dropdownColor: const Color(0xFF2C2C2C),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.black45,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 7, child: Text('Al menos 7 días sin viajes', maxLines: 1, overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 15, child: Text('Al menos 15 días sin viajes', maxLines: 1, overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 30, child: Text('Al menos 1 mes sin viajes', maxLines: 1, overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 90, child: Text('Más de 3 meses sin viajes', maxLines: 1, overflow: TextOverflow.ellipsis)),
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
        OverflowBar(
          alignment: MainAxisAlignment.end,
          overflowSpacing: 10,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : _sendCampaign,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              child: _isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_scheduleType == 'now' ? 'Crear y Enviar' : 'Programar', style: const TextStyle(color: Colors.white)),
            ),
          ],
        )
      ],
    );
  }
}
