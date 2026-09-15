import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../services/firestore_service.dart';
import 'shared_admin_widgets.dart';

class AlertsModule extends StatelessWidget {
  const AlertsModule({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService.instance;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminHeader('Centro de alertas S.O.S.', 'Emergencias reportadas por conductores'),
          adminCard(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: fs.openAlerts(),
              builder: (context, snap) {
                final alerts = snap.data ?? [];
                if (alerts.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Row(children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 10),
                      Text('Sin emergencias activas'),
                    ]),
                  );
                }
                return Column(
                  children: [
                    for (final a in alerts)
                      ListTile(
                        leading: const CircleAvatar(
                            backgroundColor: MijanoTheme.signal,
                            child: Icon(Icons.emergency, color: Colors.white)),
                        title: Text('Alerta ${a['id']}'),
                        subtitle: Text('GPS: ${a['lat'] ?? '?'}, ${a['lng'] ?? '?'}'),
                        trailing: ElevatedButton(
                          onPressed: () => fs.resolveAlert(a['id']),
                          child: const Text('Atender'),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
