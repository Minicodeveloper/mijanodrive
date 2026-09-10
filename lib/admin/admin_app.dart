import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/trip_model.dart';
import '../models/driver_model.dart';
import '../services/firestore_service.dart';

/// Panel de administración web de Mijano Drive.
/// Mismo Firestore, mismo tema que la app móvil. Se muestra con kIsWeb.
class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mijano Drive · Panel',
      debugShowCheckedModeBanner: false,
      theme: MijanoTheme.light,
      home: const AdminShell(),
    );
  }
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _tab = 0;

  static const _items = [
    (Icons.dashboard, 'Panel'),
    (Icons.verified_user, 'Conductores'),
    (Icons.attach_money, 'Tarifas'),
    (Icons.account_balance_wallet, 'Billetera'),
    (Icons.emergency, 'Alertas S.O.S.'),
    (Icons.security, 'Seguridad'),
  ];

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
      drawer: wide ? null : Drawer(child: _sidebar()),
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

  Widget _sidebar() {
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
            ListTile(
              leading: Icon(_items[i].$1,
                  color: _tab == i ? MijanoTheme.sol : Colors.white70),
              title: Text(_items[i].$2,
                  style: TextStyle(
                      color: _tab == i ? MijanoTheme.sol : Colors.white70,
                      fontWeight:
                          _tab == i ? FontWeight.w700 : FontWeight.w500)),
              selected: _tab == i,
              selectedTileColor: Colors.white.withValues(alpha: 0.06),
              onTap: () {
                setState(() => _tab = i);
                if (Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
              },
            ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Panel de administración',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_tab) {
      case 0:
        return const _DashboardModule();
      case 1:
        return const _DriversModule();
      case 2:
        return const _TariffsModule();
      case 3:
        return const _WalletModule();
      case 4:
        return const _AlertsModule();
      default:
        return const _SecurityModule();
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
  const _DashboardModule();
  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService.instance;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header('Panel de control', 'Viajes y conductores en vivo'),
          StreamBuilder<List<Driver>>(
            stream: fs.allDrivers(),
            builder: (context, dsnap) {
              final drivers = dsnap.data ?? [];
              final online = drivers.where((d) => d.isAvailable).length;
              return StreamBuilder<List<Trip>>(
                stream: fs.allActiveTrips(),
                builder: (context, tsnap) {
                  final trips = tsnap.data ?? [];
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _stat('Viajes activos', '${trips.length}', Icons.route),
                      _stat('Conductores libres', '$online', Icons.two_wheeler),
                      _stat('Conductores totales', '${drivers.length}',
                          Icons.people),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),
          const Text('Viajes en curso',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
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
                      padding: EdgeInsets.all(24),
                      child: Text('No hay viajes en curso'));
                }
                return Column(
                  children: [
                    for (final t in trips)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _statusColor(t.status),
                          child: const Icon(Icons.two_wheeler,
                              color: Colors.white, size: 18),
                        ),
                        title: Text(
                            '${t.originAddress ?? "Origen"} → ${t.destinationAddress ?? "Destino"}'),
                        subtitle: Text('${t.city} · ${_statusEs(t.status)}'),
                        trailing: Text('S/ ${t.fareAmount.toStringAsFixed(2)}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
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

  Widget _stat(String label, String value, IconData icon) => Container(
        width: 220,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(children: [
          CircleAvatar(
              backgroundColor: MijanoTheme.sol,
              child: Icon(icon, color: MijanoTheme.ink)),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          ]),
        ]),
      );
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
          Text('Gestión de accesos y revocación de tokens.',
              style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}
