import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme.dart';
import '../models/trip_model.dart';
import '../models/driver_model.dart';
import '../services/firestore_service.dart';
import '../screens/auth/login_screen.dart';
import 'modules/users_module.dart';
import 'modules/tariffs_module.dart';
import 'modules/reports_module.dart';
import 'modules/alerts_module.dart';
import 'modules/security_module.dart';

enum AdminRole {
  superAdmin,
  operator,
}

/// Panel de administración web de Mijano Drive.
/// Mismo Firestore, mismo tema que la app móvil. Se muestra con kIsWeb.
class AdminApp extends StatelessWidget {
  final AdminRole role;

  const AdminApp({super.key, this.role = AdminRole.superAdmin});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mijano Drive · Panel',
      debugShowCheckedModeBanner: false,
      theme: MijanoTheme.light,
      home: AdminShell(role: role),
    );
  }
}

class AdminShell extends StatefulWidget {
  final AdminRole role;
  const AdminShell({super.key, required this.role});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  String _currentView = 'Panel';

  
  Future<void> _actualizarEstadoDocumento(BuildContext context, Driver driver, String campoEstado, String nuevoEstado, StateSetter setStateDialog) async {
    try {
      
      await FirebaseFirestore.instance.collection('drivers').doc(driver.uid).update({
        'documents.$campoEstado': nuevoEstado,
      });

      
      setStateDialog(() {
        driver.documents[campoEstado] = nuevoEstado;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Documento actualizado a: $nuevoEstado')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 900;
    return Scaffold(
      appBar: wide
          ? null
          : AppBar(
              title: const Text('Mijano Drive · Panel'),
              backgroundColor: MijanoTheme.sol,
            ),
      drawer: wide ? null : Drawer(child: _sidebar(closeDrawer: true)),
      body: Row(
        children: [
          if (wide) SizedBox(width: 250, child: _sidebar()),
          Expanded(
            child: Container(
              color: const Color(0xFFF6F6F4),
              child: _body(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String title, {bool closeDrawer = false}) {
    final isSelected = _currentView == title;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 32),
        leading: Icon(
          icon,
          color: isSelected ? MijanoTheme.sol : Colors.white70,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? MijanoTheme.sol : Colors.white70,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        selected: isSelected,
        selectedTileColor: Colors.white.withValues(alpha: 0.06),
        onTap: () {
          setState(() => _currentView = title);
          if (closeDrawer) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Widget _sidebar({bool closeDrawer = false}) {
    return Container(
      color: MijanoTheme.ink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: MijanoTheme.sol,
            child: Row(children: const [
              Icon(Icons.two_wheeler, color: MijanoTheme.ink),
              SizedBox(width: 10),
              Text('MIJANO DRIVE',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: MijanoTheme.ink,
                      letterSpacing: 0.5)),
            ]),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    iconColor: Colors.white70,
                    collapsedIconColor: Colors.white70,
                    title: const Text('GENERAL', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
                    children: [
                      _buildNavItem(Icons.dashboard, 'Panel', closeDrawer: closeDrawer),
                      _buildNavItem(Icons.people, 'Pasajeros', closeDrawer: closeDrawer),
                      _buildNavItem(Icons.two_wheeler, 'Conductores', closeDrawer: closeDrawer),
                      if (widget.role == AdminRole.superAdmin)
                        _buildNavItem(Icons.attach_money, 'Tarifas', closeDrawer: closeDrawer),
                    ],
                  ),
                ),
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    iconColor: Colors.white70,
                    collapsedIconColor: Colors.white70,
                    title: const Text('SEGURIDAD', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
                    children: [
                      _buildNavItem(Icons.chat, 'Soporte', closeDrawer: closeDrawer),
                      _buildNavItem(Icons.emergency, 'Alertas S.O.S.', closeDrawer: closeDrawer),
                      if (widget.role == AdminRole.superAdmin)
                        _buildNavItem(Icons.security, 'Permisos', closeDrawer: closeDrawer),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Rol: ',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Cerrar sesión'),
                onPressed: () async {
                  await fb.FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_currentView) {
      case 'Panel': return _DashboardModule(role: widget.role, parentState: this);
      case 'Pasajeros': return const UsersModule();
      case 'Conductores': return DriversModule(onUpdateStatus: _actualizarEstadoDocumento);
      case 'Tarifas': return const TariffsModule();
      case 'Soporte': return const ReportsModule();
      case 'Alertas S.O.S.': return const AlertsModule();
      case 'Permisos': return const SecurityModule();
      default: return const Center(child: Text('Módulo no encontrado'));
    }
  }
}

// Encabezado reutilizable de cada módulo.
class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  const _Header(this.title, this.subtitle);
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.w900, color: MijanoTheme.ink)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 20),
      ],
    );
  }
}

Widget _card({required Widget child}) => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: child,
    );

// ============ MÓDULO 1: PANEL ============
class _DashboardModule extends StatelessWidget {
  final AdminRole role;
  final _AdminShellState parentState;
  const _DashboardModule({required this.role, required this.parentState});
  
  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService.instance;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header('Panel de control', 'Visión general en tiempo real'),
          const SizedBox(height: 24),
          
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
                      0.0, (sum, t) => sum + t.fareAmount);
                  
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _stat('Viajes Activos', '${trips.length}', Icons.route, Colors.blue),
                      _stat('Conductores Libres', '$online', Icons.two_wheeler, Colors.green),
                      _stat('Total Conductores', '${drivers.length}', Icons.people, Colors.orange),
                      if (role == AdminRole.superAdmin)
                        _stat('S/ en Curso', 'S/ ${dineroEnCurso.toStringAsFixed(2)}', Icons.attach_money, Colors.purple),
                    ],
                  );
                },
              );
            },
          ),
          
          const SizedBox(height: 24),
          const Text(
            'Solicitudes Pendientes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: MijanoTheme.ink),
          ),
          const SizedBox(height: 12),
          _card(
            child: StreamBuilder<List<Driver>>(
              stream: fs.pendingDrivers(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final pendingDrivers = snap.data ?? [];
                if (pendingDrivers.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No hay solicitudes pendientes de nuevos conductores',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final d in pendingDrivers)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: MijanoTheme.sol,
                              backgroundImage: (d.photoUrl != null && d.photoUrl!.isNotEmpty)
                                  ? NetworkImage(d.photoUrl!)
                                  : null,
                              child: (d.photoUrl == null || d.photoUrl!.isEmpty)
                                  ? const Icon(Icons.person, color: MijanoTheme.ink, size: 28)
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d.name.isNotEmpty ? d.name : 'Conductor sin nombre',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: MijanoTheme.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    d.email.isNotEmpty ? d.email : 'Licencia: ${d.licenseNumber}',
                                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Placa: ${d.plate} · Vehículo: ${d.vehicleModel}',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: MijanoTheme.ink),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.visibility_outlined, size: 16),
                                  label: const Text('Ver Doc'),
                                  onPressed: () => parentState._mostrarDialogoDocumentos(context, d),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade50,
                                    foregroundColor: Colors.red.shade700,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.close, size: 16),
                                  label: const Text('Rechazar'),
                                  onPressed: () => fs.approveDriver(d.uid, false),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade50,
                                    foregroundColor: Colors.green.shade700,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.check, size: 16),
                                  label: const Text('Aprobar'),
                                  onPressed: () => fs.approveDriver(d.uid, true),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final mapWidget = _card(
                child: SizedBox(
                  height: 400,
                  width: double.infinity,
                  child: ClipRRect(
  borderRadius: BorderRadius.circular(12),
  child: Stack(
    children: [
      
      StreamBuilder<List<Driver>>(
        stream: fs.allDrivers(),
        builder: (context, snapshot) {
          final drivers = snapshot.data ?? [];
          
          
          final Set<Marker> markers = drivers.where((d) => d.currentLatitude != null && d.currentLongitude != null).map((d) {
            return Marker(
              markerId: MarkerId(d.uid),
              position: LatLng(d.currentLatitude!, d.currentLongitude!),
              infoWindow: InfoWindow(title: d.name, snippet: 'Placa: ${d.plate}'),
            );
          }).toSet();

          return GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(-12.0464, -77.0428), // Coordenadas centrado por defecto (ej. Lima)
              zoom: 13,
            ),
            markers: markers,
            myLocationButtonEnabled: false,
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
              );
              return mapWidget;
            },
          ),
          
          const SizedBox(height: 24),
          const Text('Viajes en curso',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: MijanoTheme.ink)),
          const SizedBox(height: 12),
          _card(
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
                            color: _statusColor(t.status).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.two_wheeler, color: _statusColor(t.status), size: 24),
                        ),
                        title: Text(
                            '${t.originAddress ?? "Origen"} → ${t.destinationAddress ?? "Destino"}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('${t.city} · ${_statusEs(t.status)}'),
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

  Widget _stat(String label, String value, IconData icon, Color color) {
    return Container(
      width: 240,
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
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: MijanoTheme.ink)),
            Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500)),
          ]),
        ),
      ]),
    );
  }
}

Color _statusColor(TripStatus s) {
  switch (s) {
    case TripStatus.active:
      return Colors.green;
    case TripStatus.accepted:
      return Colors.orange;
    default:
      return Colors.blueGrey;
  }
}

String _statusEs(TripStatus s) {
  switch (s) {
    case TripStatus.pending:
      return 'Buscando conductor';
    case TripStatus.accepted:
      return 'Conductor asignado';
    case TripStatus.active:
      return 'En curso';
    case TripStatus.completed:
      return 'Completado';
    case TripStatus.cancelled:
      return 'Cancelado';
  }
}

extension _DocumentDialogExtension on _AdminShellState {
  void _mostrarDialogoDocumentos(BuildContext context, Driver driver) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Documentos del Conductor'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. DNI (Frente)
                    _buildDocItem(
                      title: 'DNI (Frente)',
                      url: driver.documents['docFront'],
                      status: driver.documents['docFrontStatus'] ?? 'pendiente',
                      onView: () => _showFullImage(context, driver.documents['docFront']),
                      onApprove: () => _actualizarEstadoDocumento(context, driver, 'docFrontStatus', 'aprobado', setStateDialog),
                      onReject: () => _actualizarEstadoDocumento(context, driver, 'docFrontStatus', 'rechazado', setStateDialog),
                    ),
                    const Divider(height: 16),

                    // 2. DNI (Reverso)
                    _buildDocItem(
                      title: 'DNI (Reverso)',
                      url: driver.documents['docBack'],
                      status: driver.documents['docBackStatus'] ?? 'pendiente',
                      onView: () => _showFullImage(context, driver.documents['docBack']),
                      onApprove: () => _actualizarEstadoDocumento(context, driver, 'docBackStatus', 'aprobado', setStateDialog),
                      onReject: () => _actualizarEstadoDocumento(context, driver, 'docBackStatus', 'rechazado', setStateDialog),
                    ),
                    const Divider(height: 16),

                    // 3. Licencia de Conducir
                    _buildDocItem(
                      title: 'Licencia de Conducir',
                      url: driver.licensePhotoUrl ?? driver.documents['licensedDocument'],
                      status: driver.documents['licensedDocumentStatus'] ?? driver.documents['licenseStatus'] ?? 'pendiente',
                      onView: () => _showFullImage(context, driver.licensePhotoUrl ?? driver.documents['licensedDocument']),
                      onApprove: () => _actualizarEstadoDocumento(context, driver, 'licensedDocumentStatus', 'aprobado', setStateDialog),
                      onReject: () => _actualizarEstadoDocumento(context, driver, 'licensedDocumentStatus', 'rechazado', setStateDialog),
                    ),
                    const Divider(height: 16),

                    // 4. SOAT / Revisión Técnica
                    _buildDocItem(
                      title: 'SOAT / Revisión Técnica',
                      url: driver.soatPhotoUrl ?? driver.documents['soatPhoto'],
                      status: driver.documents['soatPhotoStatus'] ?? driver.documents['soatStatus'] ?? 'pendiente',
                      onView: () => _showFullImage(context, driver.soatPhotoUrl ?? driver.documents['soatPhoto']),
                      onApprove: () => _actualizarEstadoDocumento(context, driver, 'soatPhotoStatus', 'aprobado', setStateDialog),
                      onReject: () => _actualizarEstadoDocumento(context, driver, 'soatPhotoStatus', 'rechazado', setStateDialog),
                    ),
                    const Divider(height: 16),

                    // 5. Antecedentes Policiales
                    _buildDocItem(
                      title: 'Antecedentes Policiales',
                      url: driver.documents['policeRecord'],
                      status: driver.documents['policeRecordStatus'] ?? 'pendiente',
                      onView: () => _showFullImage(context, driver.documents['policeRecord']),
                      onApprove: () => _actualizarEstadoDocumento(context, driver, 'policeRecordStatus', 'aprobado', setStateDialog),
                      onReject: () => _actualizarEstadoDocumento(context, driver, 'policeRecordStatus', 'rechazado', setStateDialog),
                    ),
                    const Divider(height: 16),

                    // 6. Antecedentes Penales
                    _buildDocItem(
                      title: 'Antecedentes Penales',
                      url: driver.documents['criminalRecord'],
                      status: driver.documents['criminalRecordStatus'] ?? 'pendiente',
                      onView: () => _showFullImage(context, driver.documents['criminalRecord']),
                      onApprove: () => _actualizarEstadoDocumento(context, driver, 'criminalRecordStatus', 'aprobado', setStateDialog),
                      onReject: () => _actualizarEstadoDocumento(context, driver, 'criminalRecordStatus', 'rechazado', setStateDialog),
                    ),
                    const Divider(height: 16),

                    // 7. Tarjeta de Propiedad
                    _buildDocItem(
                      title: 'Tarjeta de Propiedad',
                      url: driver.documents['propertyCardPhoto'],
                      status: driver.documents['propertyCardPhotoStatus'] ?? 'pendiente',
                      onView: () => _showFullImage(context, driver.documents['propertyCardPhoto']),
                      onApprove: () => _actualizarEstadoDocumento(context, driver, 'propertyCardPhotoStatus', 'aprobado', setStateDialog),
                      onReject: () => _actualizarEstadoDocumento(context, driver, 'propertyCardPhotoStatus', 'rechazado', setStateDialog),
                    ),
                    const Divider(height: 16),

                    // 8. Foto del Vehículo
                    _buildDocItem(
                      title: 'Foto del Vehículo',
                      url: driver.documents['vehiclePhoto'],
                      status: driver.documents['vehiclePhotoStatus'] ?? 'pendiente',
                      onView: () => _showFullImage(context, driver.documents['vehiclePhoto']),
                      onApprove: () => _actualizarEstadoDocumento(context, driver, 'vehiclePhotoStatus', 'aprobado', setStateDialog),
                      onReject: () => _actualizarEstadoDocumento(context, driver, 'vehiclePhotoStatus', 'rechazado', setStateDialog),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black, 
                ),
                child: const Text('Cerrar', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showFullImage(BuildContext context, String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Previsualización de Documento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: InteractiveViewer(
                    child: Image.network(imageUrl, fit: BoxFit.contain),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildDocItem({
  required String title,
  required String? url,
  required String status,
  required VoidCallback onView,
  required VoidCallback onApprove,
  required VoidCallback onReject,
}) {
  Color statusColor;
  String statusText;

  switch (status.toLowerCase()) {
    case 'aprobado':
      statusColor = Colors.green;
      statusText = 'Aprobado';
      break;
    case 'rechazado':
      statusColor = Colors.red;
      statusText = 'Rechazado';
      break;
    default:
      statusColor = Colors.orange;
      statusText = 'Pendiente';
  }

  return Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFAF6EE),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.brown.withOpacity(0.12)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.4)),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            InkWell(
              onTap: (url != null && url.isNotEmpty) ? onView : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: (url != null && url.isNotEmpty)
                    ? Image.network(
                        url,
                        width: 65,
                        height: 65,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 65,
                          height: 65,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image, size: 24, color: Colors.grey),
                        ),
                      )
                    : Container(
                        width: 65,
                        height: 65,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.insert_drive_file_outlined, size: 24, color: Colors.grey),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onReject,
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Rechazar', style: TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE3FCEF),
                      foregroundColor: const Color(0xFF006644),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Aprobar', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}