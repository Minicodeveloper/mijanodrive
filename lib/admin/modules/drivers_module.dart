import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../models/driver_model.dart';
import '../../services/firestore_service.dart';
import 'shared_admin_widgets.dart';

class DriversModule extends StatefulWidget {
  final Future<void> Function(BuildContext, Driver, String, String, StateSetter)? onUpdateStatus;

  const DriversModule({super.key, this.onUpdateStatus});

  @override
  State<DriversModule> createState() => _DriversModuleState();
}

class _DriversModuleState extends State<DriversModule> {
  int _currentTab = 0; // 0: Todos, 1: Pendientes, 2: Activos, 3: Inactivos
  final fs = FirestoreService.instance;
  final _searchCtrl = TextEditingController();
  String _query = '';

  Widget _buildTabs(int total, int pendientes, int activos, int inactivos) {
    final tabs = ['Todos ($total)', 'Pendientes ($pendientes)', 'Activos ($activos)', 'Inactivos ($inactivos)'];
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
        child: StreamBuilder<List<Driver>>(
            stream: fs.allDrivers(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final drivers = snap.data ?? [];
              final pendientes = drivers.where((d) => d.status == 'pending').toList();
              final activos = drivers.where((d) => d.status == 'approved').toList();
              final inactivos = drivers.where((d) => d.status == 'rejected' || d.isBlocked).toList();

              List<Driver> filtered = drivers;
              if (_currentTab == 1) filtered = pendientes;
              if (_currentTab == 2) filtered = activos;
              if (_currentTab == 3) filtered = inactivos;

              if (_query.isNotEmpty) {
                filtered = filtered.where((d) =>
                d.name.toLowerCase().contains(_query.toLowerCase()) ||
                    (d.email).toLowerCase().contains(_query.toLowerCase()) ||
                    (d.plate).toLowerCase().contains(_query.toLowerCase()) ||
                    (d.licenseNumber).toLowerCase().contains(_query.toLowerCase())
                ).toList();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AdminHeader('Gestión de Conductores', 'Supervisión y control de conductores registrados'),
                  const SizedBox(height: 16),
                  // Dashboard
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _stat('Total', '${drivers.length}', Icons.people, const Color(
                          0xFFFFFFFF)),
                      _stat('Pendientes', '${pendientes.length}', Icons.access_time, Colors.orange),
                      _stat('Activos', '${activos.length}', Icons.check_circle, Colors.green),
                      _stat('Inactivos', '${inactivos.length}', Icons.cancel, Colors.red),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: _buildTabs(drivers.length, pendientes.length, activos.length, inactivos.length)),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 250,
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Buscar conductor...',
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
                          DataColumn(label: Text('Conductor', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Vehículo', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Contacto', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Estado', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: filtered.map((d) {
                          return DataRow(cells: [
                            DataCell(
                                Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: MijanoTheme.sol,
                                        backgroundImage: (d.photoUrl != null && d.photoUrl!.isNotEmpty)
                                            ? NetworkImage(d.photoUrl!)
                                            : null,
                                        child: (d.photoUrl == null || d.photoUrl!.isEmpty)
                                            ? Text(d.name.isNotEmpty ? d.name[0].toUpperCase() : '?', style: const TextStyle(color: MijanoTheme.ink))
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(d.name.isNotEmpty ? d.name : 'Sin nombre', style: const TextStyle(fontWeight: FontWeight.bold)),
                                          Text(d.createdAt.toLocal().toString().split(' ')[0], style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                        ],
                                      )
                                    ]
                                )
                            ),
                            DataCell(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(d.vehicleModel),
                                    Text('Placa: ${d.plate}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                  ],
                                )
                            ),
                            DataCell(Text(d.email)),
                            DataCell(_buildStatusBadge(d.status)),
                            DataCell(
                                PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'approve') {
                                      await fs.approveDriver(d.uid, true);
                                    } else if (value == 'reject') {
                                      await fs.approveDriver(d.uid, false);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(value: 'approve', child: Text('Aprobar')),
                                    const PopupMenuItem(value: 'reject', child: Text('Rechazar / Desactivar')),
                                  ],
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
      case 'approved':
        color = Colors.green;
        text = 'Activo';
        break;
      case 'rejected':
        color = Colors.red;
        text = 'Rechazado';
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