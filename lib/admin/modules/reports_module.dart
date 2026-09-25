import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  int _currentTab = 0; 
  final fs = FirestoreService.instance;

  
  Widget _buildTabs() {
    final tabs = ['Viajes Activos', 'Usuarios', 'Conductores', 'Soporte '];
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

  // ==== VISTA 0: "TODOS" (Monitoreo de Chats Activos en Viajes) ====
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
                          color: const Color(0xFF1E1E1E), 
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

  
  Widget _buildReportsList(String filter) {
    return adminCard(
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: fs.allReports(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final reports = snap.data ?? [];
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

  
  Widget _buildDriverSupportSection() {
    return const AdminDriverSupportView();
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
      activeView = _buildDriverSupportSection(); 
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminHeader('Reportes y Soporte', 'Monitoreo de chats y bandeja de soporte'),
          _buildTabs(),
          const SizedBox(height: 24),
          activeView,
        ],
      ),
    );
  }
}


class _ChatMonitor extends StatefulWidget {
  final String tripId;
  const _ChatMonitor({required this.tripId});

  @override
  State<_ChatMonitor> createState() => _ChatMonitorState();
}

class _ChatMonitorState extends State<_ChatMonitor> {
  final _msgCtrl = TextEditingController();
  final fs = FirestoreService.instance;

  final List<String> _quickReplies = [
    'Hola, ¿en qué podemos ayudarte con tu viaje?',
    'Por favor, mantén la calma, ya estamos revisando tu caso.',
    'El conductor va en camino hacia tu ubicación.',
    'Gracias por reportarlo, lo verificaremos de inmediato.'
  ];

  void _send(String text) {
    if (text.trim().isEmpty) return;
    fs.sendSupportMessage(widget.tripId, text.trim());
    _msgCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
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
                          Text('[${m['senderId'] == 'support' ? 'Soporte/Admin' : 'Usuario'}]${m['senderName'] ?? ''}', 
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


class AdminDriverSupportView extends StatefulWidget {
  const AdminDriverSupportView({super.key});

  @override
  State<AdminDriverSupportView> createState() => _AdminDriverSupportViewState();
}

class _AdminDriverSupportViewState extends State<AdminDriverSupportView> {
  String? selectedDriverUid;
  String? selectedDriverName;
  final TextEditingController _replyController = TextEditingController();
  final fs = FirestoreService.instance;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  void _sendAdminReply(String driverUid, String driverName) async {
    if (_replyController.text.trim().isEmpty) return;

    final text = _replyController.text.trim();
    _replyController.clear();

    
    await fs.sendAdminOrDriverSupportMessage(
      driverUid: driverUid,
      driverName: driverName,
      text: text,
      isAdmin: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return adminCard(
      child: SizedBox(
        height: 600,
        child: Row(
          children: [
            // Columna izquierda: Lista de chats activos en 'support_chats'
            SizedBox(
              width: 320,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: Colors.black12)),
                ),
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: fs.allSupportChats(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final chats = snapshot.data ?? [];
                    if (chats.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'No hay chats de soporte activos.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.black54),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: chats.length,
                      itemBuilder: (context, index) {
                        final chat = chats[index];
                        final driverUid = chat['id'];
                        final name = chat['name'] ?? 'Conductor';
                        final lastMessage = chat['lastMessage'] ?? 'Sin mensajes';
                        final isSelected = selectedDriverUid == driverUid;

                        return ListTile(
                          selected: isSelected,
                          selectedTileColor: MijanoTheme.sol.withOpacity(0.2),
                          leading: const CircleAvatar(
                            backgroundColor: MijanoTheme.sol,
                            child: Icon(Icons.support_agent, color: MijanoTheme.ink),
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: () {
                            setState(() {
                              selectedDriverUid = driverUid;
                              selectedDriverName = name;
                            });
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),

            // Columna derecha: Historial de mensajes y campo de respuesta
            Expanded(
              child: selectedDriverUid == null
                  ? const Center(
                      child: Text(
                        'Selecciona un chat de soporte de la lista.',
                        style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                      ),
                    )
                  : Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: MijanoTheme.cream,
                            border: Border(bottom: BorderSide(color: Colors.black12)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person, color: MijanoTheme.ink),
                              const SizedBox(width: 12),
                              Text(
                                'Soporte con: $selectedDriverName',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: MijanoTheme.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: StreamBuilder<List<Map<String, dynamic>>>(
                            stream: fs.supportMessagesForDriver(selectedDriverUid!),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(child: CircularProgressIndicator());
                              }

                              final messages = snapshot.data ?? [];
                              if (messages.isEmpty) {
                                return const Center(
                                  child: Text('Aún no hay mensajes en este chat.'),
                                );
                              }

                              return ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  final msg = messages[index];
                                  final isAdmin = msg['isAdmin'] ?? false;
                                  final text = msg['text'] ?? '';

                                  return Align(
                                    alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(vertical: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      constraints: const BoxConstraints(maxWidth: 400),
                                      decoration: BoxDecoration(
                                        color: isAdmin ? MijanoTheme.sol.withOpacity(0.3) : Colors.white,
                                        border: Border.all(
                                          color: isAdmin ? MijanoTheme.ink : Colors.black26,
                                          width: 1.5,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isAdmin ? 'Soporte (Central)' : 'Conductor',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isAdmin ? MijanoTheme.ink : Colors.black54,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            text,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: MijanoTheme.ink,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(top: BorderSide(color: Colors.black12)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _replyController,
                                  onSubmitted: (_) => _sendAdminReply(selectedDriverUid!, selectedDriverName!),
                                  decoration: const InputDecoration(
                                    hintText: 'Escribe una respuesta para el conductor...',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: MijanoTheme.sol,
                                  foregroundColor: MijanoTheme.ink,
                                ),
                                icon: const Icon(Icons.send),
                                label: const Text('Enviar'),
                                onPressed: () => _sendAdminReply(selectedDriverUid!, selectedDriverName!),
                              ),
                            ],
                          ),
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