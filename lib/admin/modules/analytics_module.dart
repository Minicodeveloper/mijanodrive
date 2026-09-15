import 'package:flutter/material.dart';
import '../../theme.dart';
import 'shared_admin_widgets.dart';

class AnalyticsModule extends StatelessWidget {
  const AnalyticsModule({super.key});

  // TODO(Equipo): Reemplazar por consultas agrupadas reales a Firestore
  Map<String, dynamic> _fetchMockAnalytics() {
    return {
      'tripsPerDay': [
        {'day': 'Lun', 'count': 120},
        {'day': 'Mar', 'count': 150},
        {'day': 'Mie', 'count': 130},
        {'day': 'Jue', 'count': 170},
        {'day': 'Vie', 'count': 210},
        {'day': 'Sab', 'count': 250},
        {'day': 'Dom', 'count': 200},
      ],
      'revenueByCity': [
        {'city': 'Lima', 'revenue': 4500.0},
        {'city': 'Trujillo', 'revenue': 1200.0},
        {'city': 'Piura', 'revenue': 800.0},
      ],
      'topDrivers': [
        {'name': 'Carlos Ruiz', 'trips': 45},
        {'name': 'Miguel Ramos', 'trips': 38},
        {'name': 'Ana Silva', 'trips': 36},
      ]
    };
  }

  @override
  Widget build(BuildContext context) {
    final data = _fetchMockAnalytics();
    final tripsDay = data['tripsPerDay'] as List;
    final maxTrips = tripsDay.fold<int>(0, (max, e) => e['count'] > max ? e['count'] : max);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminHeader('Analítica', 'Métricas e indicadores de negocio'),
          
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              final col1 = adminCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Viajes (Últimos 7 días)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 20),
                    // Gráfico de barras simplificado sin dependencias externas
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: tripsDay.map((d) {
                        final height = (d['count'] / maxTrips) * 150;
                        return Column(
                          children: [
                            Text('${d['count']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Container(width: 20, height: height, color: MijanoTheme.sol),
                            const SizedBox(height: 4),
                            Text(d['day'], style: const TextStyle(fontSize: 12)),
                          ],
                        );
                      }).toList(),
                    )
                  ],
                ),
              );

              final col2 = adminCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ingresos por Ciudad (Hoy)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 20),
                    ...(data['revenueByCity'] as List).map((c) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(c['city']),
                          Text('S/ ${c['revenue'].toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ))
                  ],
                ),
              );

              final col3 = adminCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Top Conductores', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 20),
                    ...(data['topDrivers'] as List).map((d) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [const Icon(Icons.star, color: Colors.orange, size: 16), const SizedBox(width: 8), Text(d['name'])]),
                          Text('${d['trips']} viajes', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ))
                  ],
                ),
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: col1),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [col2, const SizedBox(height: 16), col3],
                      ),
                    )
                  ],
                );
              }
              return Column(
                children: [col1, const SizedBox(height: 16), col2, const SizedBox(height: 16), col3],
              );
            },
          )
        ],
      ),
    );
  }
}
