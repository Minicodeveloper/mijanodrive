import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../services/firestore_service.dart';
import 'shared_admin_widgets.dart';

class UsersModule extends StatefulWidget {
  const UsersModule({super.key});

  @override
  State<UsersModule> createState() => _UsersModuleState();
}

class _UsersModuleState extends State<UsersModule> {
  int _currentTab = 0; // 0: Todos
  final _searchCtrl = TextEditingController();
  String _query = '';
  final fs = FirestoreService.instance;

  Widget _buildTabs(int total) {
    final tabs = ['Todos ($total)'];
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: fs.allUsers(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allUsers = snap.data ?? [];

              List<Map<String, dynamic>> filtered = allUsers;

              if (_query.isNotEmpty) {
                filtered = filtered.where((u) =>
                (u['name']?.toString().toLowerCase() ?? '').contains(_query.toLowerCase()) ||
                    (u['phone']?.toString() ?? '').contains(_query)
                ).toList();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AdminHeader('Gestión de Clientes', 'Supervisión y control de usuarios pasajeros'),
                  const SizedBox(height: 16),
                  // Dashboard
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _stat('Total Clientes', '${allUsers.length}', Icons.people, const Color(
                          0xFFFFFFFF)),
                      _stat('Pendientes', '0', Icons.access_time, Colors.orange),
                      _stat('Con Viajes', '0', Icons.location_on, Colors.green),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: _buildTabs(allUsers.length)),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 250,
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Buscar por nombre o teléfono...',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (val) => setState(() => _query = val),
                          ),
                        )
                      ]
                  ),
                  const SizedBox(height: 16),
                  adminCard(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Cliente', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Teléfono', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Viajes', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Estado', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Registro', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: filtered.map((u) {
                          final name = u['name'] ?? 'Sin nombre';
                          final phone = u['phone'] ?? 'Sin teléfono';
                          final status = u['isBlocked'] == true ? 'Bloqueado' : 'Activo';

                          return DataRow(cells: [
                            DataCell(
                                Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: MijanoTheme.sol,
                                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: MijanoTheme.ink)),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          Text(u['email'] ?? 'Sin correo', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                        ],
                                      )
                                    ]
                                )
                            ),
                            DataCell(Text(phone)),
                            DataCell(const Text('0 viajes')), // Dummy data
                            DataCell(_buildStatusBadge(status)),
                            DataCell(const Text('Reciente')),
                            DataCell(
                                IconButton(
                                  icon: const Icon(Icons.more_horiz),
                                  onPressed: () {},
                                )
                            ),
                          ]);
                        }).toList(),
                      ),
                    ),
                  )
                ],
              );
            }
        )
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    switch (status.toLowerCase()) {
      case 'activo':
        color = Colors.green;
        text = 'Activo';
        break;
      case 'bloqueado':
        color = Colors.red;
        text = 'Bloqueado';
        break;
      default:
        color = Colors.orange;
        text = 'Pendiente';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: MijanoTheme.ink)),
          ]),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ],
      ),
    );
  }
}