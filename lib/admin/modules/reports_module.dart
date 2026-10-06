import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/trip_model.dart';
import 'shared_admin_widgets.dart';
import '../../theme.dart';

class ReportsModule extends StatefulWidget {
  final bool canSeeMoney;
  const ReportsModule({super.key, required this.canSeeMoney});

  @override
  State<ReportsModule> createState() => _ReportsModuleState();
}

class _ReportsModuleState extends State<ReportsModule> {
  int _currentTab = 0;
  final fs = FirestoreService.instance;


  Widget _buildTabs() {
    final tabs = ['Viajes Activos', 'Pasajeros', 'Conductores', 'Soporte', 'Reportes'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(tabs.length, (index) {
        final isSelected = _currentTab == index;
        return FilterChip(
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
        );
      }),
    );
  }

  // ==== VISTA 0: "TODOS" (Monitoreo de Chats Activos en Viajes) ====
  Widget _buildAllTripsChats(Map<String, Map<String, dynamic>> userCache) {
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
                  
                  final pName = t.passengerName ?? userCache[t.passengerId]?['name'] ?? 'Usuario eliminado';
                  final pPhoto = userCache[t.passengerId]?['photoUrl'];
                  
                  final driverId = t.driverId;
                  final dMap = driverId != null ? (userCache[driverId] ?? {}) : {};
                  final dName = driverId != null ? (t.driverName ?? dMap['name'] ?? 'Conductor') : 'Sin asignar';
                  final dPhoto = driverId != null ? dMap['photoUrl'] : null;
                  final dPlate = driverId != null ? (t.driverPlate ?? dMap['vehiclePlate'] ?? dMap['plate'] ?? 'Sin placa') : '';

                  final String title = 'Pasajero $pName ↔ Conductor $dName${dPlate.isNotEmpty ? ' · placa $dPlate' : ''}';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ExpansionTile(
                      shape: const RoundedRectangleBorder(side: BorderSide.none),
                      leading: SizedBox(
                        width: 56,
                        height: 40,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 0,
                              child: UserAvatar(photoUrl: pPhoto, name: pName, radius: 20),
                            ),
                            Positioned(
                              right: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: UserAvatar(photoUrl: dPhoto, name: dName, radius: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Ruta: ${t.originAddress} → ${t.destinationAddress} · Estado: ${getTripStatusEs(t.status)}', style: const TextStyle(fontSize: 12)),
                      children: [
                        Container(
                          height: 400,
                          color: const Color(0xFF1E1E1E),
                          child: _ChatMonitor(trip: t, userCache: userCache),
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


  Widget _buildReportsList(Map<String, Map<String, dynamic>> userCache) {
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
              Expanded(child: Text('No hay reportes pendientes de revisión en esta categoría')),
            ]);
          }

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: openReports.length,
            itemBuilder: (ctx, i) {
              final r = openReports[i];
              final reportedUserId = r['reportedUserId']?.toString() ?? '';
              final reportedBy = r['reportedByDriverId']?.toString() ?? '';

              final reportedName = userCache[reportedUserId]?['name'] ?? 'Sin nombre';
              final reporterName = userCache[reportedBy]?['name'] ?? 'Sin nombre';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.warning, color: Colors.white)),
                    title: Text('Reportado: $reportedName', maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('Razón: ${r['reason']} · Por: $reporterName', maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: MijanoTheme.sol, foregroundColor: MijanoTheme.ink),
                      onPressed: () => fs.resolveReport(r['id']),
                      child: const Text('Marcar Resuelto'),
                    ),
                  ),
                  const Divider(height: 24),
                ],
              );
            },
          );
        },
      ),
    );
  }


  Widget _buildSupportSection(String? roleFilter, Map<String, Map<String, dynamic>> userCache) {
    return AdminSupportView(roleFilter: roleFilter, userCache: userCache);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: fs.allUsers(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = userSnap.data ?? [];
        final Map<String, Map<String, dynamic>> userCache = {
          for (final u in users) u['uid']: u
        };

        Widget activeView;
        if (_currentTab == 0) {
          activeView = _buildAllTripsChats(userCache);
        } else if (_currentTab == 1) {
          activeView = _buildSupportSection('passenger', userCache);
        } else if (_currentTab == 2) {
          activeView = _buildSupportSection('driver', userCache);
        } else if (_currentTab == 3) {
          activeView = _buildSupportSection(null, userCache);
        } else {
          activeView = _buildReportsList(userCache);
        }

        return LayoutBuilder(builder: (context, c) {
          final compact = c.maxWidth < 720;
          return SingleChildScrollView(
            padding: EdgeInsets.all(compact ? 14 : 28),
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
        });
      },
    );
  }
}


class _ChatMonitor extends StatefulWidget {
  final Trip trip;
  final Map<String, Map<String, dynamic>> userCache;
  const _ChatMonitor({required this.trip, required this.userCache});

  @override
  State<_ChatMonitor> createState() => _ChatMonitorState();
}

class _ChatMonitorState extends State<_ChatMonitor> {
  final _msgCtrl = TextEditingController();
  final fs = FirestoreService.instance;

  final List<String> _quickReplies = [
    'Hola, ¿en qué podemos ayudarte con tu viaje?'
  ];

  void _send(String text) {
    if (text.trim().isEmpty) return;
    fs.sendSupportMessage(widget.trip.id, text.trim());
    _msgCtrl.clear();
  }

  Widget _buildTripHeader() {
    final t = widget.trip;
    final driverId = t.driverId;
    final dMap = driverId != null ? (widget.userCache[driverId] ?? {}) : {};
    final pName = t.passengerName ?? widget.userCache[t.passengerId]?['name'] ?? 'Usuario eliminado';
    final pPhoto = widget.userCache[t.passengerId]?['photoUrl'];
    
    final dName = driverId != null ? (t.driverName ?? dMap['name'] ?? 'Conductor') : 'Sin asignar';
    final dPhoto = driverId != null ? dMap['photoUrl'] : null;
    final dPlate = driverId != null ? (t.driverPlate ?? dMap['vehiclePlate'] ?? dMap['plate'] ?? 'Sin placa') : '';
    final dModel = driverId != null ? (t.driverVehicleModel ?? dMap['vehicleModel'] ?? dMap['vehicleBrand'] ?? '') : '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF2C2C2C),
        border: Border(bottom: BorderSide(color: Colors.black26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.driverId == null 
              ? 'El pasajero $pName está esperando un conductor.'
              : 'El pasajero $pName está hablando con el conductor $dName (placa $dPlate, $dModel).',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _participantCard(pName, 'Pasajero', pPhoto, null),
              if (t.driverId != null) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(Icons.swap_horiz, color: Colors.white54),
                ),
                _participantCard(dName, 'Conductor', dPhoto, '$dPlate - $dModel'),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _participantCard(String name, String role, String? photo, String? extra) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            UserAvatar(photoUrl: photo, name: name, radius: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(role, style: TextStyle(color: role == 'Pasajero' ? Colors.blue.shade300 : Colors.green.shade300, fontSize: 11)),
                  if (extra != null && extra.length > 3)
                    Text(extra, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final driverId = t.driverId;
    final dMap = driverId != null ? (widget.userCache[driverId] ?? {}) : {};
    final pName = t.passengerName ?? widget.userCache[t.passengerId]?['name'] ?? 'Usuario eliminado';
    final pPhoto = widget.userCache[t.passengerId]?['photoUrl'];
    
    final dName = driverId != null ? (t.driverName ?? dMap['name'] ?? 'Conductor') : 'Sin asignar';
    final dPhoto = driverId != null ? dMap['photoUrl'] : null;
    final dPlate = driverId != null ? (t.driverPlate ?? dMap['vehiclePlate'] ?? dMap['plate'] ?? '') : '';

    return Column(
      children: [
        _buildTripHeader(),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: fs.chatMessagesForTrip(widget.trip.id),
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
                  final senderId = m['senderId']?.toString() ?? '';
                  final isSupport = senderId == 'support';
                  
                  bool isPassenger = senderId == t.passengerId;
                  bool isDriver = senderId == t.driverId;
                  
                  String displayName = isSupport ? 'Soporte (Central)' : (m['senderName']?.toString() ?? 'Usuario');
                  String? avatarUrl;
                  String roleLabel = '';
                  
                  if (isPassenger) {
                    displayName = pName;
                    avatarUrl = pPhoto;
                    roleLabel = 'Pasajero';
                  } else if (isDriver) {
                    displayName = dName;
                    avatarUrl = dPhoto;
                    roleLabel = dPlate.isNotEmpty ? 'Conductor ($dPlate)' : 'Conductor';
                  }

                  return Align(
                    alignment: isSupport ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: isSupport ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          if (!isSupport) ...[
                            UserAvatar(photoUrl: avatarUrl, name: displayName, radius: 14),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSupport ? Colors.blueGrey.shade800 : const Color(0xFF3A3A3A),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        roleLabel.isNotEmpty ? '$roleLabel · ' : '', 
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isPassenger ? Colors.blue.shade300 : Colors.green.shade300)
                                      ),
                                      Flexible(
                                        child: Text(displayName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white70),
                                            maxLines: 1, overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(m['text'] ?? '', style: const TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                          if (isSupport) ...[
                            const SizedBox(width: 8),
                            UserAvatar(photoUrl: null, name: 'Soporte', radius: 14),
                          ],
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
          color: const Color(0xFF959595),
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


class AdminSupportView extends StatefulWidget {
  final String? roleFilter;
  final Map<String, Map<String, dynamic>> userCache;

  const AdminSupportView({super.key, this.roleFilter, required this.userCache});

  @override
  State<AdminSupportView> createState() => _AdminSupportViewState();
}

class _AdminSupportViewState extends State<AdminSupportView> {
  String? selectedUserId;
  String? selectedUserName;
  final TextEditingController _replyController = TextEditingController();
  final fs = FirestoreService.instance;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _sendAdminReply() async {
    final uid = selectedUserId;
    if (uid == null || _replyController.text.trim().isEmpty) return;

    final text = _replyController.text.trim();
    _replyController.clear();

    await fs.sendAdminSupportMessage(
      userId: uid,
      userName: selectedUserName ?? '',
      text: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final compact = c.maxWidth < 720;
      final screenH = MediaQuery.of(context).size.height;
      final height = compact ? (screenH - 300).clamp(420.0, 720.0) : 600.0;

      Widget body;
      if (compact) {
        // Móvil / vertical: lista o conversación, nunca ambas.
        body = selectedUserId == null ? _buildChatList(compact) : _buildConversation(compact);
      } else {
        body = Row(
          children: [
            SizedBox(
              width: 300,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: Colors.black12)),
                ),
                child: _buildChatList(compact),
              ),
            ),
            Expanded(
              child: selectedUserId == null
                  ? const Center(
                child: Text(
                  'Selecciona un chat de soporte de la lista.',
                  style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                ),
              )
                  : _buildConversation(compact),
            ),
          ],
        );
      }

      return adminCard(
        padding: compact ? const EdgeInsets.all(8) : const EdgeInsets.all(20),
        child: SizedBox(height: height, child: body),
      );
    });
  }

  // ---------- Lista de chats ----------
  Widget _buildChatList(bool compact) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: fs.allSupportChats(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'Error de permisos o conexión:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 11),
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var chats = snapshot.data ?? [];
        
        // Filter by role if a filter is set
        if (widget.roleFilter != null) {
          chats = chats.where((chat) {
            String role = chat['role']?.toString() ?? widget.userCache[chat['id']]?['role']?.toString() ?? '';
            return role.toLowerCase() == widget.roleFilter!.toLowerCase();
          }).toList();
        }

        // Sort by updatedAt descending
        chats.sort((a, b) {
          final aTime = (a['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = (b['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });

        if (chats.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Aún no hay chats de soporte.',
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
            final userId = chat['id'] as String?;
            final lastMessage = (chat['lastMessage'] ?? 'Sin mensajes').toString();
            final isSelected = !compact && selectedUserId == userId;
            final isUnread = chat['unreadByAdmin'] == true;
            
            String role = chat['role']?.toString() ?? widget.userCache[userId]?['role']?.toString() ?? '';
            role = role.toLowerCase();
            final name = chat['name']?.toString() ?? widget.userCache[userId]?['name']?.toString() ?? 'Sin nombre';

            final photoUrl = widget.userCache[userId]?['photoUrl'];

            return Material(
              color: isSelected ? MijanoTheme.sol.withValues(alpha: 0.25) : Colors.transparent,
              child: ListTile(
                leading: SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      UserAvatar(photoUrl: photoUrl, name: name, radius: 24),
                      if (isUnread)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: isUnread ? FontWeight.w900 : FontWeight.bold)),
                    ),
                    if (role == 'passenger' || role == 'pasajero')
                      const AdminBadge('Pasajero', Colors.blue)
                    else if (role == 'driver')
                      const AdminBadge('Conductor', Colors.orange)
                  ],
                ),
                subtitle: Text(
                  lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: isUnread ? FontWeight.bold : FontWeight.normal, color: isUnread ? Colors.black87 : Colors.black54),
                ),
                trailing: compact ? const Icon(Icons.chevron_right, color: Colors.black38) : null,
                onTap: () {
                  setState(() {
                    selectedUserId = userId;
                    selectedUserName = name;
                  });
                  // Mark as read
                  if (isUnread && userId != null) {
                    fs.markSupportChatRead(userId);
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  // ---------- Conversación ----------
  Widget _buildConversation(bool compact) {
    final userData = selectedUserId != null ? widget.userCache[selectedUserId] : null;
    final photoUrl = userData?['photoUrl'];
    final rawRole = userData?['role']?.toString().toLowerCase() ?? '';
    final isDriver = rawRole == 'driver' || rawRole == 'conductor';
    final roleText = isDriver ? 'Conductor' : 'Pasajero';
    final roleColor = isDriver ? Colors.orange : Colors.blue;
    final plate = userData?['vehiclePlate'] ?? userData?['plate'];
    final vehicle = userData?['vehicleModel'] ?? userData?['vehicleBrand'];
    final extraInfo = isDriver && plate != null ? ' · $plate${vehicle != null ? ' ($vehicle)' : ''}' : '';

    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 16, vertical: compact ? 8 : 12),
          decoration: const BoxDecoration(
            color: MijanoTheme.cream,
            border: Border(bottom: BorderSide(color: Colors.black12)),
          ),
          child: Row(
            children: [
              if (compact)
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: MijanoTheme.ink),
                  onPressed: () => setState(() {
                    selectedUserId = null;
                    selectedUserName = null;
                  }),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: UserAvatar(photoUrl: photoUrl, name: selectedUserName ?? 'Usuario', radius: 20),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Soporte con: ${selectedUserName ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: MijanoTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        AdminBadge(roleText, roleColor),
                        if (extraInfo.isNotEmpty)
                          Flexible(
                            child: Text(
                              extraInfo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: fs.supportMessagesForUser(selectedUserId!),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final messages = snapshot.data ?? [];
              if (messages.isEmpty) {
                return const Center(child: Text('Aún no hay mensajes en este chat.'));
              }

              return LayoutBuilder(builder: (context, box) {
                final bubbleMax = (box.maxWidth * 0.8).clamp(0.0, 400.0);
                return ListView.builder(
                  padding: EdgeInsets.all(compact ? 10 : 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isAdmin = msg['isAdmin'] ?? false;
                    final text = (msg['text'] ?? '').toString();
                    final senderName = msg['senderName']?.toString() ?? 'Usuario';

                    return Align(
                      alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        constraints: BoxConstraints(maxWidth: bubbleMax),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: isAdmin ? MainAxisAlignment.end : MainAxisAlignment.start,
                          children: [
                            if (!isAdmin) ...[
                              UserAvatar(photoUrl: photoUrl, name: senderName, radius: 14),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isAdmin ? MijanoTheme.sol.withValues(alpha: 0.3) : Colors.white,
                                  border: Border.all(
                                    color: isAdmin ? MijanoTheme.ink : Colors.black26,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      isAdmin ? 'Soporte (Central)' : senderName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isAdmin ? MijanoTheme.ink : Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      text,
                                      style: const TextStyle(fontSize: 14, color: MijanoTheme.ink),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              });
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.black12)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replyController,
                  onSubmitted: (_) => _sendAdminReply(),
                  decoration: const InputDecoration(
                    hintText: 'Escribe una respuesta...',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (compact)
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: MijanoTheme.sol,
                    foregroundColor: MijanoTheme.ink,
                  ),
                  icon: const Icon(Icons.send),
                  onPressed: _sendAdminReply,
                )
              else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MijanoTheme.sol,
                    foregroundColor: MijanoTheme.ink,
                  ),
                  icon: const Icon(Icons.send),
                  label: const Text('Enviar'),
                  onPressed: _sendAdminReply,
                ),
            ],
          ),
        ),
      ],
    );
  }
}