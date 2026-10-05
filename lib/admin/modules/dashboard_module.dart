import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../models/trip_model.dart';
import '../../models/driver_model.dart';
import '../../services/firestore_service.dart';
import 'shared_admin_widgets.dart';
import '../admin_app.dart' show AdminRole;
import '../widgets/live_drivers_map.dart';

class DashboardModule extends StatelessWidget {
  final AdminRole role;
  final bool canSeeMoney;
  const DashboardModule({super.key, required this.role, required this.canSeeMoney});

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

                  final dineroEnCurso = trips.fold<double>(
                      0.0, (total, t) => total + t.fareAmount);

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;

                      if (isMobile) {
                        final w = (constraints.maxWidth / 2) - 8;
                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          alignment: WrapAlignment.center,
                          children: [
                            _stat('Viajes Activos', '${trips.length}', Icons.route, Colors.blue, width: w),
                            _stat('Libres', '$online', Icons.two_wheeler, Colors.green, width: w),
                            _stat('Total', '${drivers.length}', Icons.people, Colors.orange, width: w),
                            if (canSeeMoney)
                              _stat('S/ en Curso', 'S/ ${dineroEnCurso.toStringAsFixed(2)}', Icons.attach_money, Colors.purple, width: w),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: _stat('Viajes Activos', '${trips.length}', Icons.route, Colors.blue)),
                          const SizedBox(width: 16),
                          Expanded(child: _stat('Libres', '$online', Icons.two_wheeler, Colors.green)),
                          const SizedBox(width: 16),
                          Expanded(child: _stat('Total Conductores', '${drivers.length}', Icons.people, Colors.orange)),
                          if (canSeeMoney) ...[
                            const SizedBox(width: 16),
                            Expanded(child: _stat('S/ en Curso', 'S/ ${dineroEnCurso.toStringAsFixed(2)}', Icons.attach_money, Colors.purple)),
                          ]
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),

          const SizedBox(height: 24),

          const AdminHeader('Solicitudes Pendientes', 'Revisión de documentos de nuevos conductores'),
          adminCard(
            child: StreamBuilder<List<Driver>>(
              stream: fs.pendingDrivers(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Error de permisos o conexión:\n${snap.error}',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  );
                }

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
                    final rawMap = d.toMap();

                    final name = rawMap['name'] ?? rawMap['fullName'] ?? rawMap['nombres'] ?? 'Sin nombre';
                    final email = rawMap['email'] ?? rawMap['correo'] ?? rawMap['mail'] ?? 'Sin correo';
                    final photoUrl = rawMap['photoUrl'];

                    final plate = d.plate.isNotEmpty ? d.plate : (rawMap['vehiclePlate'] ?? rawMap['plate'] ?? 'N/A');
                    final brand = rawMap['vehicleBrand'] ?? '';
                    final model = rawMap['vehicleModel'] ?? rawMap['vehicle'] ?? 'N/A';
                    final vehicle = brand.isNotEmpty ? '$brand $model' : model;

                    final Map<String, dynamic> documents = rawMap['documents'] ?? {};

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      leading: CircleAvatar(
                        backgroundColor: MijanoTheme.sol,
                        backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                            ? NetworkImage(photoUrl)
                            : null,
                        child: (photoUrl == null || photoUrl.isEmpty)
                            ? const Icon(Icons.person, color: MijanoTheme.ink)
                            : null,
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(email, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('Placa: $plate · Vehículo: $vehicle'),
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
                                  _mostrarDialogoDocumentos(context, d.uid, documents);
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

          adminCard(
            child: const LiveDriversMap(),
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
                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: fs.allUsers(),
                  builder: (context, userSnap) {
                    final users = userSnap.data ?? [];
                    final userCache = {for (final u in users) u['uid']: u};

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
                              child: Text('${t.passengerName ?? userCache[t.passengerId]?['name'] ?? "Usuario eliminado"} · ${getTripStatusEs(t.status)}'),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (canSeeMoney)
                                  Text('S/ ${t.fareAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: MijanoTheme.ink))
                                else
                                  const Text('—', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.grey)),
                                const Text('Efectivo', style: TextStyle(fontSize: 12, color: Colors.black54)),
                              ],
                            ),
                          ),
                      ],
                    );
                  }
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoDocumentos(BuildContext context, String driverUid, Map<String, dynamic> documents) {
    final Map<String, String> nombresDocumentos = {
      'docFront': 'DNI (Frente)',
      'docBack': 'DNI (Reverso)',
      'licensedDocument': 'Licencia de Conducir',
      'soatPhoto': 'SOAT',
      'propertyCardPhoto': 'Tarjeta de Propiedad',
      'policeRecord': 'Antecedentes Policiales',
      'criminalRecord': 'Antecedentes Penales',
      'vehiclePhoto': 'Foto del Vehículo',
    };

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Documentos del Conductor'),
          content: SizedBox(
            width: 500,
            height: 500,
            child: ListView(
              children: documents.entries.map((entry) {
                String key = entry.key;
                dynamic value = entry.value;
                String label = nombresDocumentos[key] ?? key;

                String url = '';
                String status = 'pending';

                if (value is Map) {
                  url = value['url'] ?? '';
                  status = value['status'] ?? 'pending';
                } else if (value is String) {
                  url = value;
                }

                if (url.isEmpty) return const SizedBox.shrink();

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            _buildStatusBadge(status),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            InkWell(
                              onTap: () => _mostrarImagenEnGrande(context, label, url),
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(6),
                                  image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                    icon: const Icon(Icons.close, size: 16),
                                    label: const Text('Rechazar', style: TextStyle(fontSize: 12)),
                                    onPressed: () async {
                                      await FirestoreService.instance.updateDriverDocumentStatus(driverUid, key, 'rejected');

                                      await FirestoreService.instance.notifyDriver(
                                          driverUid,
                                          'Documento Rechazado',
                                          'Tu documento "$label" fue rechazado. Por favor, vuelva a subirlo o tomar foto otra vez.'
                                      );

                                      setStateDialog(() {});
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade50,
                                      foregroundColor: Colors.green.shade700,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                    icon: const Icon(Icons.check, size: 16),
                                    label: const Text('Aprobar', style: TextStyle(fontSize: 12)),
                                    onPressed: () async {
                                      await FirestoreService.instance.updateDriverDocumentStatus(driverUid, key, 'approved');

                                      setStateDialog(() {});
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar', style: TextStyle(color: MijanoTheme.ink)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    switch (status) {
      case 'approved':
        color = Colors.green;
        text = 'Aprobado';
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _mostrarImagenEnGrande(BuildContext context, String titulo, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Text('No se pudo cargar la imagen del documento'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color, {double? width}) {
    return Container(
      width: width,
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
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87)),
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