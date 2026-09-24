import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/trip_model.dart';
import 'shared_admin_widgets.dart';
import '../../theme.dart';

class ReportsModule extends StatefulWidget {
  const ReportsModule({super.key});

  @override
  State<ReportsModule> createState() => _ReportsModuleState();
}

class _ReportsModuleState extends State<ReportsModule> {
  int _currentTab = 0; // 0: Todos, 1: Usuarios, 2: Conductores, 3: Soporte
  final fs = FirestoreService.instance;

  // Filtros visuales como pestañas (botones)
  Widget _buildTabs() {
    final tabs = ['Todos', 'Usuarios', 'Conductores', 'Soporte'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _currentTab == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              label: Text(tabs[index]),
              selected: isSelected,
              onSelected: (_) => setState(() => _currentTab = index),
              selectedColor: MijanoTheme.sol,
              checkmarkColor: MijanoTheme.ink,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: isSelected ? MijanoTheme.ink : Colors.black12),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ==== VISTA 1: "TODOS" (Monitoreo de Chats Activos) ====
  Widget _buildAllTripsChats() {
    return adminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Monitoreo de Chats en Viajes Activos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Aquí puedes observar en tiempo real los mensajes entre pasajeros y conductores.', style: TextStyle(color: Colors.black54, fontSize: 13)),
          const Divider(height: 32),
          StreamBuilder<List<Trip>>(
            stream: fs.allActiveTrips(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final trips = snap.data ?? [];
              if (trips.isEmpty) return const Text('No hay viajes activos con chats en este momento.');

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: trips.length,
                itemBuilder: (ctx, i) {
                  final t = trips[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ExpansionTile(
                      shape: const RoundedRectangleBorder(side: BorderSide.none),
                      leading: CircleAvatar(
                        backgroundColor: MijanoTheme.cream,
                        child: const Icon(Icons.chat_bubble_outline, color: MijanoTheme.ink),
                      ),
                      title: Text('Viaje: ${t.originAddress} → ${t.destinationAddress}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Pasajero: ${t.passengerId} · Cond: ${t.driverId ?? "Sin asignar"} · Estado: ${t.status.name}', style: const TextStyle(fontSize: 12)),
                      children: [
                        Container(
                          height: 300,
                          color: const Color(0xFF1E1E1E), // Fondo oscuro temático para el chat
                          child: _ChatMonitor(tripId: t.id),
                        )
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ==== VISTAS RESTANTES (Reportes clásicos de usuarios y conductores) ====
  Widget _buildReportsList(String filter) {
    return adminCard(
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: fs.allReports(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final reports = snap.data ?? [];
          // Aquí se aplicaría el filtro si en Firestore estuviera definido el "tipo" de reporte
          // Por ahora mostramos todos en "Soporte" o según corresponda.
          final openReports = reports.where((r) => r['status'] == 'open').toList();

          if (openReports.isEmpty) {
            return const Row(children: [
              Icon(Icons.thumb_up, color: Colors.green),
              SizedBox(width: 10),
              Text('No hay reportes pendientes de revisión en esta categoría'),
            ]);
          }

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: openReports.length,
            itemBuilder: (ctx, i) {
              final r = openReports[i];
              return ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.warning, color: Colors.white)),
                title: Text('Reportado: ${r['reportedUserId']}'),
                subtitle: Text('Razón: ${r['reason']} · Por: ${r['reportedByDriverId']}'),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: MijanoTheme.sol, foregroundColor: MijanoTheme.ink),
                  onPressed: () => fs.resolveReport(r['id']),
                  child: const Text('Marcar Resuelto'),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget activeView;
    if (_currentTab == 0) {
      activeView = _buildAllTripsChats();
    } else if (_currentTab == 1) {
      activeView = _buildReportsList('passenger');
    } else if (_currentTab == 2) {
      activeView = _buildReportsList('driver');
    } else {
      activeView = _buildReportsList('all'); // Soporte (Cola general de reportes)
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminHeader('Reportes y Soporte', 'Monitoreo de chats y cola de moderación'),
          _buildTabs(),
          const SizedBox(height: 24),
          activeView,
        ],
      ),
    );
  }
}

/// Widget interno para visualizar y responder en el chat de un viaje específico
class _ChatMonitor extends StatefulWidget {
  final String tripId;
  const _ChatMonitor({required this.tripId});

  @override
  State<_ChatMonitor> createState() => _ChatMonitorState();
}

class _ChatMonitorState extends State<_ChatMonitor> {
  final _msgCtrl = TextEditingController();
  final fs = FirestoreService.instance;

  // Botones de mensajes predeterminados del administrador
  final List<String> _quickReplies = [
    'Hola, ¿en qué podemos ayudarte con tu viaje?',
    'Por favor, mantén la calma, ya estamos revisando tu caso.',
    'El conductor va en camino hacia tu ubicación.',
    'Gracias por reportarlo, lo verificaremos de inmediato.'
  ];

  void _send(String text) {
    if (text.trim().isEmpty) return;
    // TODO(Equipo): Aquí el admin inyecta un mensaje a la subcolección 'messages' del viaje.
    // Asegúrense de que las apps (Conductor/Pasajero) escuchen la misma subcolección.
    fs.sendSupportMessage(widget.tripId, text.trim());
    _msgCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Zona de Mensajes
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            // TODO(Equipo): Este Stream lee de trips/{tripId}/messages. 
            // Validar que coincida con la ruta donde el Conductor/Pasajero escriben.
            stream: fs.chatMessagesForTrip(widget.tripId),
            builder: (context, snap) {
              final msgs = snap.data ?? [];
              if (msgs.isEmpty) {
                return const Center(child: Text('No hay mensajes aún.', style: TextStyle(color: Colors.white54)));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: msgs.length,
                itemBuilder: (ctx, i) {
                  final m = msgs[i];
                  final isSupport = m['senderId'] == 'support';
                  
                  return Align(
                    alignment: isSupport ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(maxWidth: 400),
                      decoration: BoxDecoration(
                        color: isSupport ? Colors.blueGrey.shade800 : const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('[${m['senderId'] == 'support' ? 'Soporte/Admin' : 'Usuario'}] ${m['senderName'] ?? ''}', 
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isSupport ? Colors.white : Colors.white70)),
                          const SizedBox(height: 4),
                          Text(m['text'] ?? '', style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        
        // Zona de Respuestas Rápidas
        Container(
          height: 40,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _quickReplies.length,
            itemBuilder: (ctx, i) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                ),
                onPressed: () => _send(_quickReplies[i]),
                child: Text(_quickReplies[i], style: const TextStyle(fontSize: 12)),
              ),
            ),
          ),
        ),

        // Campo de texto
        Container(
          padding: const EdgeInsets.all(12),
          color: const Color(0xFF121212),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Escribe una respuesta como admin...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF2C2C2C),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                  ),
                  onSubmitted: _send,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send, color: MijanoTheme.sol),
                onPressed: () => _send(_msgCtrl.text),
              )
            ],
          ),
        )
      ],
    );
  }
}
