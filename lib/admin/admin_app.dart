import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/trip_model.dart';
import '../models/driver_model.dart';
import '../services/firestore_service.dart';

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
                            'GPS: ${a['lat'] ?? '?'}, ${a['lng'] ?? '?'}'),
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

// ============ MÓDULO 6: SEGURIDAD ============
class _SecurityModule extends StatelessWidget {
  const _SecurityModule();
  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header('Seguridad y permisos',
              'Roles: SuperAdmin (dueños) y Operador (gerente)'),
          SizedBox(height: 8),
          // TODO(Equipo): Implementar control de Firebase Auth (Custom Claims).
          // Aquí se debería permitir crear nuevos operadores o revocar sus accesos.
          Text('Gestión de accesos y revocación de tokens.',
              style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}