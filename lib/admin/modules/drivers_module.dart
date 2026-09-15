import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../models/driver_model.dart';
import '../../services/firestore_service.dart';
import 'shared_admin_widgets.dart';

class DriversModule extends StatelessWidget {
  const DriversModule({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService.instance;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminHeader('Conductores', 'Aprobación y gestión de estado'),
          adminCard(
            child: StreamBuilder<List<Driver>>(
              stream: fs.allDrivers(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()));
                }
                final drivers = snap.data ?? [];
                if (drivers.isEmpty) {
                  return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No hay conductores registrados'));
                }
                return Column(
                  children: [
                    for (final d in drivers)
                      ListTile(
                        leading: CircleAvatar(
                            backgroundColor: d.isApproved ? Colors.green.withValues(alpha: 0.2) : MijanoTheme.sol,
                            child: Icon(Icons.person, color: d.isApproved ? Colors.green : MijanoTheme.ink)),
                        title: Row(
                          children: [
                            Text('Placa ${d.plate}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            if (!d.isApproved)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                                child: const Text('Pendiente', style: TextStyle(fontSize: 10, color: Colors.orange)),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Licencia ${d.licenseNumber} · ${d.city}'),
                            const SizedBox(height: 4),
                            // Se asume que el modelo Driver tiene soatPhotoUrl y licensePhotoUrl
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _PhotoBadge(label: 'SOAT', url: d.toMap()['soatPhotoUrl']),
                                _PhotoBadge(label: 'Licencia', url: d.toMap()['licensePhotoUrl']),
                                // Referencia de período de prueba (0 por ahora o dato si existe en el modelo)
                                Text('Viajes: ${d.toMap()['completedTrips'] ?? 0}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!d.isApproved) ...[
                              SizedBox(
                                height: 30,
                                child: TextButton(
                                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                                  onPressed: () => fs.updateDriverStatus(d.uid, isApproved: false),
                                  child: const Text('Rechazar', style: TextStyle(color: MijanoTheme.signal, fontSize: 12)),
                                ),
                              ),
                              SizedBox(
                                height: 30,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                                  onPressed: () => fs.updateDriverStatus(d.uid, isApproved: true),
                                  child: const Text('Aprobar', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                            ] else ...[
                              // Opciones de bloqueo
                              // Asumimos un campo isBlocked en Firestore (aunque no está estrictamente en el modelo base,
                              // se puede añadir dinámicamente o manejar como parte del estado).
                              if (d.toMap()['isBlocked'] == true)
                                SizedBox(
                                  height: 30,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8)),
                                    onPressed: () => fs.updateDriverStatus(d.uid, isBlocked: false),
                                    child: const Text('Activar', style: TextStyle(fontSize: 12)),
                                  ),
                                )
                              else
                                SizedBox(
                                  height: 30,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(foregroundColor: MijanoTheme.signal, padding: const EdgeInsets.symmetric(horizontal: 8)),
                                    onPressed: () => fs.updateDriverStatus(d.uid, isBlocked: true),
                                    child: const Text('Bloquear', style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                            ],
                          ],
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

class _PhotoBadge extends StatelessWidget {
  final String label;
  final String? url;
  const _PhotoBadge({required this.label, this.url});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = url != null && url!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: hasPhoto ? Colors.blue.shade50 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: hasPhoto ? Colors.blue.shade200 : Colors.grey.shade300)
      ),
      child: Text(
        '$label: ${hasPhoto ? 'Ver' : 'Sin subir'}',
        style: TextStyle(fontSize: 10, color: hasPhoto ? Colors.blue.shade700 : Colors.grey.shade600),
      ),
    );
  }
}
