import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme.dart';
import '../../services/firestore_service.dart';
import 'shared_admin_widgets.dart';

/// Centro de alertas S.O.S.
/// Escucha las alertas abiertas en tiempo real (conductores y pasajeros),
/// muestra hora, ubicación, botones de contacto a autoridades/usuarios
/// y mantiene un historial (Términos y Condiciones - Seg. 5).
class AlertsModule extends StatefulWidget {
  final bool canSeeMoney;
  const AlertsModule({super.key, required this.canSeeMoney});

  @override
  State<AlertsModule> createState() => _AlertsModuleState();
}

class _AlertsModuleState extends State<AlertsModule> {
  final FirestoreService _fs = FirestoreService.instance;
  late final Stream<List<Map<String, dynamic>>> _alerts = _fs.openAlerts();
  late final Stream<List<Map<String, dynamic>>> _resolvedAlerts = _fs.resolvedAlerts();
  
  Timer? _ticker;
  int _currentTab = 0; // 0 = Activas, 1 = Historial

  @override
  void initState() {
    super.initState();
    // Refresca los "hace X min" sin volver a suscribirse al stream.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------- helpers

  DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    try {
      return (v as dynamic).toDate() as DateTime; // Timestamp de Firestore
    } catch (_) {
      return null;
    }
  }

  double? _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('${v ?? ''}');
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _fmt(DateTime d) {
    final l = d.toLocal();
    return '${_two(l.day)}/${_two(l.month)}/${l.year} ${_two(l.hour)}:${_two(l.minute)}';
  }

  String _ago(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'hace instantes';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} d';
  }

  /// Quién reportó la alerta. Si el campo no existe, se asume conductor.
  String _who(Map<String, dynamic> a) =>
      a['reportedBy'] == 'passenger' ? 'Pasajero' : 'Conductor';

  /// Coordenadas de la alerta.
  ({double lat, double lng})? _coords(Map<String, dynamic> a) {
    final lat = _num(a['latitude'] ?? a['lat']);
    final lng = _num(a['longitude'] ?? a['lng']);
    if (lat == null || lng == null) return null;
    return (lat: lat, lng: lng);
  }

  Uri? _mapsUri(Map<String, dynamic> a) {
    final c = _coords(a);
    if (c == null) return null;
    return Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${c.lat},${c.lng}');
  }

  String _display(dynamic v) {
    final d = _toDate(v);
    return d != null ? _fmt(d) : '$v';
  }

  // ---------------------------------------------------------------- acciones

  Future<void> _openMap(Map<String, dynamic> a) async {
    final uri = _mapsUri(a);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el marcador telefónico.')),
      );
    }
  }

  Future<void> _attend(Map<String, dynamic> a) async {
    final TextEditingController notesCtrl = TextEditingController();
    
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Atender alerta (Resolución)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Confirmas que esta emergencia ya fue atendida? \n'
              'Saldrá de la lista de activas y pasará al historial (Auditoría).',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notas de resolución (Obligatorio)',
                border: OutlineInputBorder(),
                hintText: 'Ej. Falsa alarma, se envió 105, resuelto por llamada.',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () {
                if (notesCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Debes ingresar una nota de resolución')),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Guardar y Atender')),
        ],
      ),
    );

    if (ok == true) {
      await _fs.resolveAlert(
        a['id'], 
        notes: notesCtrl.text.trim(), 
        resolvedBy: 'Admin (Soporte)' // Aquí iría el ID del admin real
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alerta guardada en el historial.')),
        );
      }
    }
  }

  void _showDetail(Map<String, dynamic> a) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Detalle · S.O.S. de ${_who(a).toLowerCase()}'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in a.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 130,
                          child: Text(e.key,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54)),
                        ),
                        Expanded(child: SelectableText(_display(e.value))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          if (a['driverId'] != null || a['userId'] != null)
            TextButton.icon(
              icon: const Icon(Icons.person_outline, size: 18),
              label: const Text('Ver perfil'),
              onPressed: () {
                // TODO: Navegar a la vista de perfil del usuario/conductor
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Vista de perfil en desarrollo...'))
                );
              },
            ),
          if (_mapsUri(a) != null)
            TextButton.icon(
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copiar GPS'),
              onPressed: () async {
                final c = _coords(a);
                await Clipboard.setData(
                    ClipboardData(text: '${c?.lat}, ${c?.lng}'));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coordenadas copiadas')));
              },
            ),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  /// Solo para pruebas (modo debug): crea una alerta con el mismo método
  /// que usa la app del conductor.
  Future<void> _simulateAlert() async {
    try {
      await _fs.createSosAlert(
        driverId: 'PRUEBA_PANEL',
        latitude: -5.8942,
        longitude: -76.1142,
        city: 'Yurimaguas',
        phone: '999888777', // Simulación de info de identidad
        name: 'Juan Perez (Simulación)',
        plate: '1234-AB',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear la alerta de prueba: $e')),
      );
    }
  }

  // ---------------------------------------------------------------- UI

  Widget _statusChip(String text, bool isResolved) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: isResolved ? Colors.grey[600] : MijanoTheme.signal,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(text,
        style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
  );

  Widget _alertTile(Map<String, dynamic> a, {bool isResolved = false}) {
    final created = _toDate(a['createdAt']);
    final c = _coords(a);
    final hasGps = c != null;

    final name = a['name'] as String?;
    final phone = a['phone'] as String?;
    final plate = a['plate'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isResolved ? Colors.grey.withOpacity(0.06) : MijanoTheme.signal.withOpacity(0.06),
        border: Border(left: BorderSide(
          color: isResolved ? Colors.grey : MijanoTheme.signal, 
          width: 4
        )),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: isResolved ? Colors.grey : MijanoTheme.signal,
                child: const Icon(Icons.emergency, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('S.O.S. · ${_who(a)}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      _statusChip(isResolved ? 'ATENDIDA' : 'ACTIVA', isResolved),
                    ]),
                    const SizedBox(height: 8),
                    
                    // Fila de datos críticos (según cláusula de T&C)
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (name != null) Text('👤 $name', style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (phone != null) Text('📞 $phone', style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (plate != null) Text('🛵 Placa: $plate', style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (name == null && phone == null) 
                          const Text('⚠️ Datos de identidad no adjuntos en alerta', style: TextStyle(color: Colors.orange)),
                      ],
                    ),
                    const SizedBox(height: 6),

                    Text(created != null
                        ? '🕒 ${_fmt(created)} · ${_ago(created)}'
                        : '🕒 Hora no registrada'),
                    const SizedBox(height: 2),
                    Text(c != null
                        ? '📍 GPS: ${c.lat.toStringAsFixed(5)}, ${c.lng.toStringAsFixed(5)}'
                        : '📍 Sin ubicación GPS'),
                    if (a['city'] != null) ...[
                      const SizedBox(height: 2),
                      Text('🏙️ Ciudad: ${a['city']}'),
                    ],
                    
                    if (isResolved && a['resolutionNotes'] != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Resolución: ${a['resolutionNotes']}',
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!isResolved)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue[800],
                      side: BorderSide(color: Colors.blue[800]!),
                    ),
                    onPressed: () => _callPhone('105'),
                    icon: const Icon(Icons.local_police, size: 18),
                    label: const Text('Llamar 105 (Policía)'),
                  ),
                if (!isResolved && phone != null)
                  OutlinedButton.icon(
                    onPressed: () => _callPhone(phone),
                    icon: const Icon(Icons.phone, size: 18),
                    label: Text('Llamar ${_who(a).toLowerCase()}'),
                  ),
                OutlinedButton.icon(
                  onPressed: hasGps ? () => _openMap(a) : null,
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Ver mapa'),
                ),
                TextButton.icon(
                  onPressed: () => _showDetail(a),
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('Detalle'),
                ),
                if (!isResolved)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MijanoTheme.signal,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _attend(a),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Atender Alerta'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsList(Stream<List<Map<String, dynamic>>> stream, {bool isResolved = false}) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Row(children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 10),
              Expanded(child: Text('No se pudieron cargar las alertas.')),
            ]),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // Más recientes primero.
        final alerts = [...snap.data!];
        alerts.sort((x, y) {
          final dx = _toDate(x['createdAt']);
          final dy = _toDate(y['createdAt']);
          if (dx == null && dy == null) return 0;
          if (dx == null) return 1;
          if (dy == null) return -1;
          return dy.compareTo(dx);
        });

        if (alerts.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Row(children: [
              Icon(Icons.check_circle, color: isResolved ? Colors.grey : Colors.green),
              const SizedBox(width: 10),
              Text(isResolved ? 'No hay alertas en el historial.' : 'Sin emergencias activas en este momento.'),
            ]),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '${alerts.length} ${isResolved ? 'alertas resueltas' : 'emergencias activas'}',
                  style: TextStyle(
                      color: isResolved ? Colors.grey[800] : MijanoTheme.signal,
                      fontWeight: FontWeight.w700),
                ),
              ),
              for (final a in alerts) _alertTile(a, isResolved: isResolved),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminHeader('Centro de alertas S.O.S.',
              'Gestión de emergencias y protocolo de seguridad'),
          
          if (kDebugMode)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _simulateAlert,
                  icon: const Icon(Icons.bug_report_outlined, size: 18),
                  label: const Text('Simular alerta (solo debug)'),
                ),
              ),
            ),
            
          adminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pestañas / Selector de vistas
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Alertas Activas', style: TextStyle(fontWeight: FontWeight.bold)),
                        selected: _currentTab == 0,
                        selectedColor: MijanoTheme.signal.withOpacity(0.2),
                        onSelected: (val) {
                          if (val) setState(() => _currentTab = 0);
                        },
                      ),
                      const SizedBox(width: 12),
                      ChoiceChip(
                        label: const Text('Historial (Atendidas)', style: TextStyle(fontWeight: FontWeight.bold)),
                        selected: _currentTab == 1,
                        onSelected: (val) {
                          if (val) setState(() => _currentTab = 1);
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                
                // Vista dependiente del tab seleccionado
                _currentTab == 0
                    ? _buildAlertsList(_alerts, isResolved: false)
                    : _buildAlertsList(_resolvedAlerts, isResolved: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
