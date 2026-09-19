import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../services/firestore_service.dart';
import 'shared_admin_widgets.dart';

class ReservationsModule extends StatefulWidget {
  const ReservationsModule({super.key});

  @override
  State<ReservationsModule> createState() => _ReservationsModuleState();
}

class _ReservationsModuleState extends State<ReservationsModule> {
  String _cityFilter = 'Todas';
  String _statusFilter = 'Todos';
  final fs = FirestoreService.instance;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminHeader('Reservas programadas', 'Viajes agendados a futuro'),
          adminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Ciudad', border: OutlineInputBorder()),
                        value: _cityFilter,
                        items: ['Todas', 'Lima', 'Trujillo'].map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) => setState(() => _cityFilter = val!),
                        isExpanded: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Estado', border: OutlineInputBorder()),
                        value: _statusFilter,
                        items: ['Todos', 'pending', 'assigned', 'completed', 'cancelled'].map((c) => DropdownMenuItem(value: c, child: Text(c.toUpperCase(), overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) => setState(() => _statusFilter = val!),
                        isExpanded: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: fs.allReservations(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final allRes = snap.data ?? [];
                    final filtered = allRes.where((r) {
                      final passCity = _cityFilter == 'Todas' || r['city'] == _cityFilter;
                      final passStatus = _statusFilter == 'Todos' || r['status'] == _statusFilter;
                      return passCity && passStatus;
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Text('No hay reservas agendadas.');
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final r = filtered[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: r['status'] == 'assigned' ? Colors.blue.shade100 : Colors.grey.shade200,
                            child: const Icon(Icons.schedule, color: MijanoTheme.ink),
                          ),
                          title: Text('${r['origin']} → ${r['destination']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Pasajero: ${r['passengerId']}\nCond: ${r['driverId'] ?? 'Sin asignar'}\nHora: ${r['scheduledAt']}',
                              style: const TextStyle(height: 1.3),
                            ),
                          ),
                          isThreeLine: true,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('S/ ${(r['fareAmount'] as num?)?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(r['status']?.toString().toUpperCase() ?? '', style: const TextStyle(fontSize: 9, color: Colors.black54)),
                            ],
                          ),
                        );
                      },
                    );
                  },
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
