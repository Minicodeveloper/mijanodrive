import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import 'shared_admin_widgets.dart';
import '../../theme.dart';

class ReportsModule extends StatelessWidget {
  const ReportsModule({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService.instance;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminHeader('Moderación y Reportes', 'Cola de perfiles reportados por mala conducta'),
          adminCard(
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
                    Text('No hay reportes pendientes de revisión'),
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
          )
        ],
      ),
    );
  }
}
