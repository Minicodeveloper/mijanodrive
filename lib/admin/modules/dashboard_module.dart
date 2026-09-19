import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../theme.dart';
import '../../models/trip_model.dart';
import '../../models/driver_model.dart';
import '../../services/firestore_service.dart';
import 'shared_admin_widgets.dart';
import '../admin_app.dart' show AdminRole;

class DashboardModule extends StatelessWidget {
  final AdminRole role;
  const DashboardModule({super.key, required this.role});
  
  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService.instance;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminHeader('Panel de control', 'Visión general en tiempo real'),
          
          StreamBuilder<List<Driver>>(
            stream: fs.allDrivers(),
            builder: (context, dsnap) {
              final drivers = dsnap.data ?? [];
              final online = drivers.where((d) => d.isAvailable).length;
              
              return StreamBuilder<List<Trip>>(
                stream: fs.allActiveTrips(),
                builder: (context, tsnap) {
                  final trips = tsnap.data ?? [];
                  
                  // Calculando datos reales a partir de los viajes activos
                  final dineroEnCurso = trips.fold<double>(
                      0.0, (sum, t) => sum + t.fareAmount);
                  
                  // KPIs principales
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      final cardWidth = isMobile ? (constraints.maxWidth / 2) - 8 : 240.0;
                      
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        alignment: WrapAlignment.center,
                        children: [
                          _stat('Viajes Activos', '${trips.length}', Icons.route, Colors.blue, width: cardWidth),
                          _stat('Libres', '$online', Icons.two_wheeler, Colors.green, width: cardWidth),
                          _stat('Total', '${drivers.length}', Icons.people, Colors.orange, width: cardWidth),
                          if (role == AdminRole.superAdmin)
                            _stat('S/ en Curso', 'S/ ${dineroEnCurso.toStringAsFixed(2)}', Icons.attach_money, Colors.purple, width: cardWidth),
                        ],
                      );
                    }
                  );
                },
              );
            },
          ),
          
          const SizedBox(height: 24),
          
          // SECCIÓN DE SOLICITUDES PENDIENTES
          const AdminHeader('Solicitudes Pendientes', 'Revisión de documentos de nuevos conductores'),
          adminCard(
            child: StreamBuilder<List<Driver>>(
              stream: fs.pendingDrivers(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final List<Driver> pending = snap.data ?? [];
                if (pending.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No hay solicitudes pendientes', style: TextStyle(color: Colors.black54)),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pending.length,
                  itemBuilder: (ctx, i) {
                    final d = pending[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: const CircleAvatar(
                        backgroundColor: MijanoTheme.sol,
                        child: Icon(Icons.person, color: MijanoTheme.ink),
                      ),
                      title: Text('Placa: ${d.plate} · Licencia: ${d.licenseNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ciudad: ${d.city}'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.visibility, size: 18),
                                label: const Text('Ver Doc'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: MijanoTheme.ink,
                                  side: const BorderSide(color: Colors.black26),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Documentos del Conductor'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('SOAT: ${d.toMap()['soatPhotoUrl'] ?? 'Sin subir'}'),
                                          const SizedBox(height: 8),
                                          Text('Licencia: ${d.toMap()['licensePhotoUrl'] ?? 'Sin subir'}'),
                                          const SizedBox(height: 16),
                                          const Text('(Las imágenes se previsualizarán aquí)', style: TextStyle(color: Colors.black54, fontStyle: FontStyle.italic)),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar', style: TextStyle(color: MijanoTheme.ink)))
                                      ],
                                    )
                                  );
                                },
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.close, size: 18),
                                label: const Text('Rechazar'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade50, 
                                  foregroundColor: Colors.red.shade700, 
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                onPressed: () async {
                                  await fs.updateDriverStatus(d.uid, isRejected: true);
                                  await fs.notifyDriver(d.uid, 'Solicitud Rechazada', 'Revisa tus documentos e inténtalo de nuevo.');
                                },
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text('Aprobar'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade50, 
                                  foregroundColor: Colors.green.shade700, 
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                onPressed: () async {
                                  await fs.updateDriverStatus(d.uid, isApproved: true, isRejected: false);
                                  await fs.notifyDriver(d.uid, '¡Aprobado!', 'Tus documentos han sido aprobados.');
                                },
                              ),
                            ],
                          )
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 24),
          const AdminHeader('Mapa en vivo', 'Ubicación actual de conductores libres y ocupados'),
          
          // MAPA
          adminCard(
            child: SizedBox(
              height: 350,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    StreamBuilder<List<Driver>>(
                      stream: fs.allDrivers(),
                      builder: (context, dsnap) {
                        final drivers = dsnap.data ?? [];
                        final activeDrivers = drivers.where((d) => d.currentLatitude != null && d.currentLongitude != null).toList();
                        
                        final markers = activeDrivers.map((d) => Marker(
                                  markerId: MarkerId(d.uid),
                                  position: LatLng(d.currentLatitude!, d.currentLongitude!),
                                  infoWindow: InfoWindow(title: 'Cond. ${d.plate}', snippet: d.isAvailable ? 'Libre' : 'Ocupado'),
                                  icon: BitmapDescriptor.defaultMarkerWithHue(d.isAvailable ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed),
                                )).toSet();

                        final initialLat = activeDrivers.isNotEmpty ? activeDrivers.first.currentLatitude! : -12.046374;
                        final initialLng = activeDrivers.isNotEmpty ? activeDrivers.first.currentLongitude! : -77.042793;

                        return GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(initialLat, initialLng),
                            zoom: 11,
                          ),
                          markers: markers,
                          myLocationEnabled: false,
                          zoomControlsEnabled: true,
                        );
                      },
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: const Text('Conectado en vivo', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          const Text('Viajes en curso',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: MijanoTheme.ink)),
          const SizedBox(height: 12),
          adminCard(
            child: StreamBuilder<List<Trip>>(
              stream: fs.allActiveTrips(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()));
                }
                final trips = snap.data ?? [];
                if (trips.isEmpty) {
                  return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.inbox, size: 40, color: Colors.black26),
                            SizedBox(height: 8),
                            Text('No hay viajes en curso', style: TextStyle(color: Colors.black54)),
                          ],
                        ),
                      ));
                }
                return Column(
                  children: [
                    for (final t in trips)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        hoverColor: Colors.grey.shade50,
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: getTripStatusColor(t.status).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.two_wheeler, color: getTripStatusColor(t.status), size: 24),
                        ),
                        title: Text(
                            '${t.originAddress ?? "Origen"} → ${t.destinationAddress ?? "Destino"}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('${t.city} · ${getTripStatusEs(t.status)}'),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('S/ ${t.fareAmount.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: MijanoTheme.ink)),
                            const Text('Efectivo', style: TextStyle(fontSize: 12, color: Colors.black54)),
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

  Widget _stat(String label, String value, IconData icon, Color color, {double width = 240}) {
    return Container(
      width: width,
      padding: EdgeInsets.all(width < 150 ? 12 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
        Container(
          padding: EdgeInsets.all(width < 150 ? 8 : 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: width < 150 ? 20 : 28),
        ),
        SizedBox(width: width < 150 ? 8 : 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: TextStyle(fontSize: width < 150 ? 18 : 24, fontWeight: FontWeight.w900, color: MijanoTheme.ink)),
            Text(label, style: TextStyle(color: Colors.black54, fontSize: width < 150 ? 11 : 13, fontWeight: FontWeight.w500, overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ]),
    );
  }
}
