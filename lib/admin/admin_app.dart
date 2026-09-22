import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme.dart';
import '../models/trip_model.dart';
import '../models/driver_model.dart';
import '../services/firestore_service.dart';
import 'admin_login_screen.dart';

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
  int _tab = 0;

  List<(IconData, String)> get _items {
    if (widget.role == AdminRole.operator) {
      return [
        (Icons.dashboard, 'Panel'),
        (Icons.verified_user, 'Conductores'),
        (Icons.emergency, 'Alertas S.O.S.'),
      ];
    }
    return [
      (Icons.dashboard, 'Panel'),
      (Icons.verified_user, 'Conductores'),
      (Icons.attach_money, 'Tarifas'),
      (Icons.account_balance_wallet, 'Billetera'),
      (Icons.emergency, 'Alertas S.O.S.'),
      (Icons.security, 'Seguridad'),
    ];
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
        for (int i = 0; i < _items.length; i++)
            Material(
              color: Colors.transparent,
              child: ListTile(
                leading: Icon(
                  _items[i].$1,
                  color: _tab == i ? MijanoTheme.sol : Colors.white70,
                ),
                title: Text(
                  _items[i].$2,
                  style: TextStyle(
                    color: _tab == i ? MijanoTheme.sol : Colors.white70,
                    fontWeight:
                        _tab == i ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                selected: _tab == i,
                selectedTileColor:
                    Colors.white.withValues(alpha: 0.06),
                onTap: () {
                  setState(() => _tab = i);
                  if (closeDrawer) {
                    Navigator.pop(context);
                  }
                },
              ),
            ),

          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Rol: ${widget.role == AdminRole.superAdmin ? 'SuperAdmin' : 'Operador'}',
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
                          builder: (_) => const AdminLoginScreen()),
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
    final title = _items[_tab].$2;
    if (title == 'Panel') return _DashboardModule(role: widget.role);
    if (title == 'Conductores') return const _DriversModule();
    if (title == 'Tarifas') return const _TariffsModule();
    if (title == 'Billetera') return const _WalletModule();
    if (title == 'Alertas S.O.S.') return const _AlertsModule();
    if (title == 'Seguridad') return const _SecurityModule();
    
    return const Center(child: Text('Módulo no encontrado'));
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
  const _DashboardModule({required this.role});
  
  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService.instance;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header('Panel de control', 'Visión general en tiempo real'),
          
          StreamBuilder<List<Driver>>(
            stream: fs.allDrivers(),
            builder: (context, dsnap) {
              final drivers = dsnap.data ?? [];
              final online = drivers.where((d) => d.isAvailable).length;
              
              return StreamBuilder<List<Trip>>(
                stream: fs.allActiveTrips(),
                builder: (context, tsnap) {
                  final trips = tsnap.data ?? [];
                  
                  // Calculando datos reales a partir de los viajes activos (Sin datos inventados)
                  final dineroEnCurso = trips.fold<double>(
                      0.0, (sum, t) => sum + t.fareAmount);
                  
                  // KPIs principales
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
          
          // Sección de Mapas y Gráficos
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              
              final mapWidget = _card(
                child: SizedBox(
                  height: 350,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        // TODO(Equipo): Descomentar este bloque StreamBuilder y GoogleMap cuando se haya habilitado
                        // "Maps JavaScript API" en Google Cloud para el entorno Web y se haya configurado la facturación.
                        Container(
                          color: Colors.grey.shade200,
                          width: double.infinity,
                          height: double.infinity,
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.map_outlined, size: 48, color: Colors.grey),
                                SizedBox(height: 12),
                                Text(
                                  'Mapa en vivo inactivo\n(Requiere habilitar Maps JavaScript API)',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                        /*
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

                            // Si hay conductores, centrar en el primero, sino en Lima
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
                              onMapCreated: (GoogleMapController controller) {},
                            );
                          },
                        ),
                        */
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
              
              final chartWidget = role == AdminRole.superAdmin ? _card(
                child: Container(
                  height: 350,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bar_chart, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Actividad Semanal', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
                        SizedBox(height: 8),
                        Text('Este módulo se integrará en una fase posterior del desarrollo.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ) : const SizedBox.shrink();
              
              if (role == AdminRole.operator) {
                // Operador solo ve el mapa en ancho completo
                return mapWidget;
              }

              if (isWide) {
                return Row(
                  children: [
                    Expanded(flex: 2, child: mapWidget),
                    const SizedBox(width: 16),
                    Expanded(flex: 1, child: chartWidget),
                  ],
                );
              }
              return Column(
                children: [
                  mapWidget,
                  const SizedBox(height: 16),
                  chartWidget,
                ],
              );
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

// ============ MÓDULO 2: CONDUCTORES ============
class _DriversModule extends StatelessWidget {
  const _DriversModule();
  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService.instance;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header('Aprobación de conductores',
              'Revisa documentos y aprueba postulantes'),
          _card(
            child: StreamBuilder<List<Driver>>(
              stream: fs.pendingDrivers(),
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
                      child: Text('No hay conductores pendientes'));
                }
                return Column(
                  children: [
                    for (final d in drivers)
                      ListTile(
                        leading: const CircleAvatar(
                            backgroundColor: MijanoTheme.sol,
                            child: Icon(Icons.person, color: MijanoTheme.ink)),
                        title: Text('Placa ${d.plate}'),
                        subtitle: Text(
                            'Licencia ${d.licenseNumber} · ${d.city}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () =>
                                  fs.approveDriver(d.uid, false),
                              child: const Text('Rechazar',
                                  style: TextStyle(color: MijanoTheme.signal)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => fs.approveDriver(d.uid, true),
                              child: const Text('Aprobar'),
                            ),
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

// ============ MÓDULO 3: TARIFAS ============
class _TariffsModule extends StatefulWidget {
  const _TariffsModule();

  @override
  State<_TariffsModule> createState() => _TariffsModuleState();
}

class _TariffsModuleState extends State<_TariffsModule> {
  final _firestore = FirestoreService.instance;

  Future<void> _editTariff(Map<String, dynamic> city) async {
    final baseController = TextEditingController(
      text: city['tariff_base']?.toString() ?? '',
    );

    final perKmController = TextEditingController(
      text: city['tariff_per_km']?.toString() ?? '',
    );

    final commissionController = TextEditingController(
      text: city['commission_percent']?.toString() ?? '',
    );

    final cityName = city['name']?.toString() ?? city['id'].toString();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Editar tarifas - $cityName'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: baseController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Tarifa base (S/)',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: perKmController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Precio por km (S/)',
                        prefixIcon: Icon(Icons.route),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: commissionController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Comisión (%)',
                        prefixIcon: Icon(Icons.percent),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final base =
                              double.tryParse(baseController.text.trim());
                          final perKm =
                              double.tryParse(perKmController.text.trim());
                          final commission =
                              double.tryParse(
                            commissionController.text.trim(),
                          );

                          if (base == null ||
                              perKm == null ||
                              commission == null ||
                              base < 0 ||
                              perKm < 0 ||
                              commission < 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Ingresa valores numéricos válidos.',
                                ),
                              ),
                            );
                            return;
                          }

                          setDialogState(() => saving = true);

                          try {
                            await _firestore.updateCity(
                              city['id'].toString(),
                              {
                                'tariff_base': base,
                                'tariff_per_km': perKm,
                                'commission_percent': commission,
                              },
                            );

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext, true);
                            }
                          } catch (e) {
                            setDialogState(() => saving = false);

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'No se pudo guardar: $e',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MijanoTheme.sol,
                    foregroundColor: MijanoTheme.ink,
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    baseController.dispose();
    perKmController.dispose();
    commissionController.dispose();

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tarifas de $cityName actualizadas correctamente.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(
            'Tarifas y comisiones',
            'Configura precios por ciudad (geofencing)',
          ),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _firestore.allCities(),
            builder: (context, snap) {
              final cities = snap.data ?? [];

              if (cities.isEmpty) {
                return _card(
                  child: const Text(
                    'No hay ciudades configuradas en Firestore',
                  ),
                );
              }

              return Column(
                children: [
                  for (final city in cities)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _card(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_city,
                              color: MijanoTheme.ink,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                city['name']?.toString() ??
                                    city['id'].toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            _pill(
                              'Base S/ ${_num(city['tariff_base'])}',
                            ),
                            _pill(
                              'x Km S/ ${_num(city['tariff_per_km'])}',
                            ),
                            _pill(
                              'Comisión ${_num(city['commission_percent'])}%',
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Editar tarifas',
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editTariff(city),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _num(dynamic value) {
    if (value == null) return '—';

    if (value is num) {
      return value.toStringAsFixed(
        value == value.toInt() ? 0 : 2,
      );
    }

    return value.toString();
  }

  Widget _pill(String text) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: MijanoTheme.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ============ MÓDULO 4: BILLETERA ============
class _WalletModule extends StatelessWidget {
  const _WalletModule();
  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header('Billetera y recargas',
              'Pasarela digital (Culqi/Niubiz) y caja efectivo'),
          SizedBox(height: 8),
          // TODO(Equipo): Conectar pasarela de pago (Culqi/Niubiz) y listar aquí el Stream de transacciones.
          // Recomendado: Utilizar fs.transactions() para listar el historial financiero global o de comisiones.
          Text('Conecta Culqi/Niubiz para ver las transacciones aquí.',
              style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

// ============ MÓDULO 5: ALERTAS S.O.S. ============
class _AlertsModule extends StatelessWidget {
  const _AlertsModule();
  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService.instance;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header('Centro de alertas S.O.S.',
              'Emergencias reportadas por conductores'),
          _card(
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
                            child:
                                Icon(Icons.emergency, color: Colors.white)),
                        title: Text('Alerta ${a['id']}'),
                        subtitle: Text(
                            'GPS: ${a['latitude'] ?? '?'}, ${a['longitude'] ?? '?'}'),
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

// ============ MÓDULO 6: SEGURIDAD Y GESTIÓN DE ADMINS ============
class _SecurityModule extends StatefulWidget {
  const _SecurityModule();
  @override
  State<_SecurityModule> createState() => _SecurityModuleState();
}

class _SecurityModuleState extends State<_SecurityModule> {
  final _db = FirebaseFirestore.instance;

  // Formulario para crear nuevo admin
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _selectedRole = 'operator';
  bool _creating = false;
  String? _feedback;
  bool _feedbackIsError = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _createAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _creating = true;
      _feedback = null;
    });

    try {
      // Guardar la sesión actual del superAdmin.
      final currentUser = fb.FirebaseAuth.instance.currentUser;
      final currentEmail = currentUser?.email;

      // Crear el nuevo usuario en Firebase Auth.
      final cred =
          await fb.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      final uid = cred.user?.uid;
      if (uid == null) throw Exception('No se obtuvo UID');

      // Registrar en Firestore.
      await _db.collection('admins').doc(uid).set({
        'email': _emailCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'role': _selectedRole,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentEmail ?? 'unknown',
      });

      // Volver a iniciar sesión como el superAdmin actual.
      // Nota: createUserWithEmailAndPassword cambia la sesión activa.
      // Restauramos la sesión previa si conocemos las credenciales.
      // Como no almacenamos la contraseña, solo cerramos sesión del nuevo.
      await fb.FirebaseAuth.instance.signOut();

      // Indicar al usuario que debe volver a iniciar sesión.
      _nameCtrl.clear();
      _emailCtrl.clear();
      _passCtrl.clear();

      setState(() {
        _feedback =
            '✅ Admin "${_nameCtrl.text.isEmpty ? _emailCtrl.text : 'nuevo'}" creado. '
            'Nota: Tu sesión se ha cerrado. Vuelve a iniciar sesión.';
        _feedbackIsError = false;
      });

      // Re-login automático si tenemos el email (pedimos relogin manual)
      if (mounted) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
              (_) => false,
            );
          }
        });
      }
    } on fb.FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'Ya existe una cuenta con ese correo.';
        case 'weak-password':
          msg = 'Contraseña muy débil (mínimo 6 caracteres).';
        case 'invalid-email':
          msg = 'Correo no válido.';
        default:
          msg = 'Error: ${e.code}';
      }
      setState(() {
        _feedback = msg;
        _feedbackIsError = true;
      });
    } catch (e) {
      setState(() {
        _feedback = 'Error: $e';
        _feedbackIsError = true;
      });
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _deleteAdmin(String docId, String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar administrador?'),
        content: Text(
          'Se eliminará el acceso de "$email" al panel.\n'
          'La cuenta de Firebase Auth permanecerá pero sin rol de admin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MijanoTheme.signal,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _db.collection('admins').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Admin "$email" eliminado del panel.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: MijanoTheme.signal,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header('Seguridad y permisos',
              'Roles: SuperAdmin (dueños) y Operador (gerente)'),
          const SizedBox(height: 24),

          // ── Lista de admins existentes ──
          const Text('Administradores registrados',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: _db.collection('admins').snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No hay administradores registrados.',
                      style: TextStyle(color: Colors.black45)),
                );
              }

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < docs.length; i++) ...[
                      _adminTile(docs[i]),
                      if (i < docs.length - 1)
                        Divider(height: 1, color: Colors.grey.shade200),
                    ],
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 32),

          // ── Formulario crear nuevo admin ──
          const Text('Crear nuevo administrador',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),

          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Requerido'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Requerido';
                        if (!v.contains('@')) return 'Correo no válido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _passCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Requerido';
                        if (v.length < 6) return 'Mínimo 6 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Selector de rol
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Rol',
                        prefixIcon: Icon(Icons.shield_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'superAdmin',
                          child: Text('SuperAdmin (acceso total)'),
                        ),
                        DropdownMenuItem(
                          value: 'operator',
                          child: Text('Operador (acceso limitado)'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _selectedRole = v!),
                    ),
                    const SizedBox(height: 16),

                    // Feedback
                    if (_feedback != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _feedbackIsError
                              ? MijanoTheme.signal.withValues(alpha: 0.1)
                              : Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _feedback!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _feedbackIsError
                                ? MijanoTheme.signal
                                : Colors.green.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _creating ? null : _createAdmin,
                        icon: _creating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: MijanoTheme.sol),
                              )
                            : const Icon(Icons.person_add),
                        label: const Text('Crear administrador'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminTile(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final email = data['email'] ?? 'Sin correo';
    final name = data['name'] ?? 'Sin nombre';
    final role = data['role'] ?? 'operator';
    final isSuperAdmin = role == 'superAdmin';
    final currentUid = fb.FirebaseAuth.instance.currentUser?.uid;
    final isCurrentUser = doc.id == currentUid;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            isSuperAdmin ? MijanoTheme.sol : Colors.grey.shade200,
        child: Icon(
          isSuperAdmin ? Icons.shield : Icons.person,
          color: MijanoTheme.ink,
          size: 20,
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '$email · ${isSuperAdmin ? 'SuperAdmin' : 'Operador'}'
        '${isCurrentUser ? ' (tú)' : ''}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: isCurrentUser
          ? null
          : IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: MijanoTheme.signal, size: 20),
              tooltip: 'Eliminar admin',
              onPressed: () => _deleteAdmin(doc.id, email),
            ),
    );
  }
}