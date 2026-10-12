import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import '../models/trip_model.dart';
import '../models/driver_model.dart';
import '../services/firestore_service.dart';
import 'modules/users_module.dart';
import 'modules/tariffs_module.dart';
import 'modules/reports_module.dart';
import 'modules/alerts_module.dart';
import 'modules/security_module.dart';
import 'modules/ads_module.dart';
import 'modules/plans_module.dart';
import 'widgets/live_drivers_map.dart';
import 'utils/driver_docs.dart';
import '../widgets/mijano_icon.dart';
import '../admin/modules/drivers_module.dart';

enum AdminRole { superAdmin, operator, support, control }

/// Panel de administración web de Mijano Drive.
/// Mismo Firestore, mismo tema que la app móvil. Se muestra con kIsWeb.
class AdminApp extends StatelessWidget {
  final AdminRole role;

  const AdminApp({super.key, this.role = AdminRole.operator});

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
  bool _isLoadingRole = true;
  AdminRole? _actualRole;

  /// true cuando el mapa de conductores del Panel está ampliado.
  final ValueNotifier<bool> mapExpanded = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _verifyRole();
  }

  @override
  void dispose() {
    mapExpanded.dispose();
    super.dispose();
  }

  Future<void> _verifyRole() async {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) {
      _kickOut('No hay sesión activa.');
      return;
    }

    DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
    } catch (e) {
      _kickOut('Error al verificar permisos: $e');
      return;
    }

    if (!doc.exists) {
      _kickOut('Usuario no encontrado en la base de datos.');
      return;
    }

    final data = doc.data();
    if (data?['isBlocked'] == true) {
      _kickOut('Tu cuenta ha sido bloqueada.');
      return;
    }

    final roleStr = data?['role'] as String?;
    if (roleStr == null) {
      _kickOut('No tienes rol asignado.');
      return;
    }

    final normalized = roleStr.trim().toLowerCase();
    if (normalized == 'admin' || normalized == 'superadmin') {
      setState(() {
        _actualRole = AdminRole.superAdmin;
        _isLoadingRole = false;
        _currentView = 'Panel';
      });
    } else if (normalized == 'operator' ||
        normalized == 'operador' ||
        normalized == 'gerente') {
      setState(() {
        _actualRole = AdminRole.operator;
        _isLoadingRole = false;
        _currentView = 'Panel';
      });
    } else if (normalized == 'support' || normalized == 'soporte') {
      setState(() {
        _actualRole = AdminRole.support;
        _isLoadingRole = false;
        _currentView = 'Soporte';
      });
    } else if (normalized == 'control') {
      setState(() {
        _actualRole = AdminRole.control;
        _isLoadingRole = false;
        _currentView = 'Panel';
      });
    } else {
      _kickOut('Acceso denegado: no eres personal autorizado.');
    }
  }

  bool canAccess(AdminRole role, String view) {
    switch (role) {
      case AdminRole.superAdmin:
        return true; // Puede ver todo
      case AdminRole.operator:
        return view != 'Permisos';
      case AdminRole.support:
        return view == 'Soporte' || view == 'Alertas S.O.S.';
      case AdminRole.control:
        return view == 'Panel' || view == 'Pasajeros' || view == 'Conductores' || view == 'Publicidad' || view == 'Planes';
    }
  }

  void _kickOut([String? message]) {
    if (message != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
    final navigator = Navigator.of(context, rootNavigator: true);
    fb.FirebaseAuth.instance.signOut();
    navigator.pushNamedAndRemoveUntil('/login', (_) => false);
  }

  Future<void> _actualizarEstadoDocumento(
    BuildContext context,
    Driver driver,
    String campoEstado,
    String nuevoEstado,
    StateSetter setStateDialog,
  ) async {
    try {
      await FirestoreService.instance.updateDriverDocumentStatus(driver.uid, campoEstado, nuevoEstado);

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al actualizar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final role = _actualRole ?? widget.role;
    final wide = MediaQuery.of(context).size.width > 900;
    return Scaffold(
      appBar: wide
          ? null
          : AppBar(
              title: const Text('Mijano Drive · Panel'),
              backgroundColor: MijanoTheme.sol,
            ),
      drawer: wide ? null : Drawer(child: _sidebar(role, closeDrawer: true)),
      body: Row(
        children: [
          if (wide) SizedBox(width: 250, child: _sidebar(role)),
          Expanded(
            child: Container(
              color: const Color(0xFFF6F6F4),
              child: _body(role),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String title, {
    bool closeDrawer = false,
    Widget? trailing,
  }) {
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
        trailing: trailing,
        selected: isSelected,
        selectedTileColor: Colors.white.withValues(alpha: 0.06),
        onTap: () {
          mapExpanded.value = false;
          setState(() => _currentView = title);
          if (closeDrawer) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Widget _sidebar(AdminRole role, {bool closeDrawer = false}) {
    final showGeneral = canAccess(role, 'Panel') || canAccess(role, 'Pasajeros') || canAccess(role, 'Conductores') || canAccess(role, 'Tarifas') || canAccess(role, 'Publicidad');
    final showSecurity = canAccess(role, 'Soporte') || canAccess(role, 'Alertas S.O.S.') || canAccess(role, 'Permisos');
    
    String roleName = 'Operador';
    if (role == AdminRole.superAdmin) roleName = 'SuperAdmin';
    if (role == AdminRole.support) roleName = 'Soporte';
    if (role == AdminRole.control) roleName = 'Control';

    return Container(
      color: MijanoTheme.ink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: MijanoTheme.sol,
            child: Row(
              children: const [
                MototaxiIcon(size: 30),
                SizedBox(width: 10),
                Text(
                  'MIJANO DRIVE',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: MijanoTheme.ink,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                if (showGeneral)
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      iconColor: Colors.white70,
                      collapsedIconColor: Colors.white70,
                      title: const Text(
                        'GENERAL',
                        style: TextStyle(
                          color: Colors.white38,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                      children: [
                        if (canAccess(role, 'Panel'))
                          _buildNavItem(Icons.dashboard, 'Panel', closeDrawer: closeDrawer),
                        if (canAccess(role, 'Pasajeros'))
                          _buildNavItem(Icons.people, 'Pasajeros', closeDrawer: closeDrawer),
                        if (canAccess(role, 'Conductores'))
                          _buildNavItem(Icons.two_wheeler, 'Conductores', closeDrawer: closeDrawer),
                        if (canAccess(role, 'Tarifas'))
                          _buildNavItem(Icons.attach_money, 'Tarifas', closeDrawer: closeDrawer),
                        if (canAccess(role, 'Publicidad'))
                          _buildNavItem(Icons.campaign, 'Publicidad', closeDrawer: closeDrawer),
                        if (canAccess(role, 'Planes'))
                          _buildNavItem(
                            Icons.workspace_premium,
                            'Planes',
                            closeDrawer: closeDrawer,
                            trailing: StreamBuilder<List<Map<String, dynamic>>>(
                              stream: FirestoreService.instance.streamPendingPlanRequests(),
                              builder: (context, snap) {
                                final count = snap.data?.length ?? 0;
                                if (count == 0) return const SizedBox.shrink();
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: MijanoTheme.sol,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text('$count', style: const TextStyle(color: MijanoTheme.ink, fontSize: 11, fontWeight: FontWeight.bold)),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                if (showSecurity)
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      iconColor: Colors.white70,
                      collapsedIconColor: Colors.white70,
                      title: const Text(
                        'SEGURIDAD',
                        style: TextStyle(
                          color: Colors.white38,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                      children: [
                        if (canAccess(role, 'Soporte'))
                          _buildNavItem(Icons.chat, 'Soporte', closeDrawer: closeDrawer),
                        if (canAccess(role, 'Alertas S.O.S.'))
                          _buildNavItem(Icons.emergency, 'Alertas S.O.S.', closeDrawer: closeDrawer),
                        if (canAccess(role, 'Permisos'))
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
              'Rol: $roleName',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
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
                  final navigator = Navigator.of(context, rootNavigator: true);
                  await fb.FirebaseAuth.instance.signOut();
                  navigator.pushNamedAndRemoveUntil('/login', (_) => false);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(AdminRole role) {
    if (!canAccess(role, _currentView)) {
      return const _AccessDenied();
    }

    final bool canSeeMoney = role == AdminRole.superAdmin;

    switch (_currentView) {
      case 'Panel':
        return _DashboardModule(
          role: role,
          parentState: this,
          canSeeMoney: canSeeMoney,
        );
      case 'Pasajeros':
        return UsersModule(canSeeMoney: canSeeMoney);
      case 'Conductores':
        return DriversModule(
          onUpdateStatus: _actualizarEstadoDocumento,
          canSeeMoney: canSeeMoney,
        );
      case 'Tarifas':
        return const TariffsModule();
      case 'Publicidad':
        return const AdsModule();
      case 'Planes':
        return const PlansModule();
      case 'Soporte':
        return ReportsModule(canSeeMoney: canSeeMoney);
      case 'Alertas S.O.S.':
        return AlertsModule(canSeeMoney: canSeeMoney);
      case 'Permisos':
        return const SecurityModule();
      default:
        return const Center(child: Text('Módulo no encontrado'));
    }
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.security, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Acceso Denegado',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'No tienes permisos suficientes para ver este módulo',
            style: TextStyle(color: Colors.black45),
          ),
        ],
      ),
    );
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
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: MijanoTheme.ink,
          ),
        ),
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

class _Kpi {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Kpi(this.label, this.value, this.icon, this.color);
}

// ============ MÓDULO 1: PANEL ============
class _DashboardModule extends StatelessWidget {
  final AdminRole role;
  final _AdminShellState parentState;
  final bool canSeeMoney;
  const _DashboardModule({
    required this.role,
    required this.parentState,
    required this.canSeeMoney,
  });

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService.instance;
    // El mapa queda siempre en la misma posición del árbol: al ampliar solo se
    // ocultan (Offstage) los demás bloques y se agranda su alto, así el
    // GoogleMap no se recrea y conserva cámara, zoom y marcadores.
    return ValueListenableBuilder<bool>(
      valueListenable: parentState.mapExpanded,
      builder: (context, expanded, _) {
        return LayoutBuilder(
          builder: (context, viewport) {
            // 56 = padding vertical del scroll, 40 = padding de la tarjeta.
            double mapHeight = 350;
            if (expanded && viewport.hasBoundedHeight) {
              final available = viewport.maxHeight - 56 - 40 - 2;
              mapHeight = available < 300 ? 300 : available;
            }
            return SingleChildScrollView(
              physics: expanded ? const NeverScrollableScrollPhysics() : null,
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Offstage(
                    offstage: expanded,
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
                                  0.0,
                                  (total, t) => total + t.fareAmount,
                                );

                                final stats = <_Kpi>[
                                  _Kpi(
                                    'Viajes Activos',
                                    '${trips.length}',
                                    Icons.route,
                                    Colors.blue,
                                  ),
                                  _Kpi(
                                    'Conductores Libres',
                                    '$online',
                                    Icons.two_wheeler,
                                    Colors.green,
                                  ),
                                  _Kpi(
                                    'Total Conductores',
                                    '${drivers.length}',
                                    Icons.people,
                                    Colors.orange,
                                  ),
                                  if (canSeeMoney)
                                    _Kpi(
                                      'S/ en Curso',
                                      'S/ ${dineroEnCurso.toStringAsFixed(2)}',
                                      Icons.attach_money,
                                      Colors.purple,
                                    ),
                                ];

                                return LayoutBuilder(
                                  builder: (context, constraints) {
                                    const spacing = 16.0;
                                    final n = stats.length;
                                    final maxW = constraints.maxWidth;

                                    final cols = maxW >= 900 ? n : (maxW >= 380 ? 2 : 1);
                                    final cardW = ((maxW - spacing * (cols - 1)) / cols)
                                        .floorToDouble();

                                    return Wrap(
                                      spacing: spacing,
                                      runSpacing: spacing,
                                      children: [
                                        for (var i = 0; i < n; i++)
                                          _stat(
                                            stats[i].label,
                                            stats[i].value,
                                            stats[i].icon,
                                            stats[i].color,

                                            width: (cols > 1 && i == n - 1 && n % cols == 1)
                                                ? maxW
                                                : cardW,
                                          ),
                                      ],
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),

                        const SizedBox(height: 24),
                        const Text(
                          'Solicitudes Pendientes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: MijanoTheme.ink,
                          ),
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
                                    _pendingItem(context, fs, d),
                                ],
                              );
                            },
                          ),
                        ),

                      ],
                    ),
                  ),
                  if (!expanded) const SizedBox(height: 24),
                  _card(
                    child: LiveDriversMap(
                      expanded: expanded,
                      height: mapHeight,
                      onToggleExpanded: () =>
                          parentState.mapExpanded.value = !expanded,
                    ),
                  ),
                  Offstage(
                    offstage: expanded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        const SizedBox(height: 24),
                        const Text(
                          'Viajes en curso',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: MijanoTheme.ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _card(
                          child: StreamBuilder<List<Trip>>(
                            stream: fs.allActiveTrips(),
                            builder: (context, snap) {
                              if (snap.connectionState == ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Center(child: CircularProgressIndicator()),
                                );
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
                                        Text(
                                          'No hay viajes en curso',
                                          style: TextStyle(color: Colors.black54),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              return Column(
                                children: [
                                  for (final t in trips)
                                    ListTile(
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      hoverColor: Colors.grey.shade50,
                                      leading: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: _statusColor(
                                            t.status,
                                          ).withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const MototaxiIcon(size: 28),
                                      ),
                                      title: Text(
                                        '${t.originAddress ?? "Origen"} → ${t.destinationAddress ?? "Destino"}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '${t.passengerName ?? "Pasajero"} · ${_statusEs(t.status)}',
                                        ),
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          if (canSeeMoney)
                                            Text(
                                              'S/ ${t.fareAmount.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 16,
                                                color: MijanoTheme.ink,
                                              ),
                                            )
                                          else
                                            const Text(
                                              '—',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 16,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          const Text(
                                            'Efectivo',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
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
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Tarjeta de solicitud pendiente: en pantallas anchas datos + botones en fila,
  /// en pantallas angostas datos arriba y botones abajo (sin overflow).
  Widget _pendingItem(BuildContext context, FirestoreService fs, Driver d) {
    final avatar = CircleAvatar(
      radius: 28,
      backgroundColor: MijanoTheme.sol,
      backgroundImage: (d.photoUrl != null && d.photoUrl!.isNotEmpty)
          ? NetworkImage(d.photoUrl!)
          : null,
      child: (d.photoUrl == null || d.photoUrl!.isEmpty)
          ? const Icon(Icons.person, color: MijanoTheme.ink, size: 28)
          : null,
    );

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          d.name.isNotEmpty ? d.name : 'Conductor sin nombre',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: MijanoTheme.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          d.email.isNotEmpty ? d.email : 'Licencia: ${d.licenseNumber}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.black54, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          'Placa: ${d.plate} · Vehículo: ${d.vehicleModel}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: MijanoTheme.ink,
          ),
        ),
      ],
    );

    final bool allApp = DriverDocs.allApproved(d);

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.visibility_outlined, size: 16),
          label: const Text('Revisar Documentos'),
          onPressed: () => parentState._mostrarDialogoDocumentos(context, d),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade50,
            foregroundColor: Colors.red.shade700,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.close, size: 16),
          label: const Text('Rechazar solicitud'),
          onPressed: () async {
             final rejected = DriverDocs.rejectedDocs(d);
             if (rejected.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debes rechazar al menos un documento antes de rechazar la solicitud.')));
                return;
             }
             final body = 'Documentos rechazados: ${rejected.join(', ')}. Vuelve a subirlos para continuar con tu solicitud.';
             await fs.notifyDriver(d.uid, 'Solicitud de Conductor Rechazada', body);
             await fs.updateDriverStatus(d.uid, isRejected: true);
          },
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: allApp ? Colors.green.shade50 : Colors.grey.shade200,
            foregroundColor: allApp ? Colors.green.shade700 : Colors.black38,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.check, size: 16),
          label: Text(allApp ? 'Aprobar' : 'Faltan docs'),
          onPressed: allApp ? () => fs.approveDriver(d.uid, true) : null,
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= 700) {
            return Row(
              children: [
                avatar,
                const SizedBox(width: 16),
                Expanded(child: info),
                const SizedBox(width: 16),
                actions,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  avatar,
                  const SizedBox(width: 12),
                  Expanded(child: info),
                ],
              ),
              const SizedBox(height: 12),
              actions,
            ],
          );
        },
      ),
    );
  }

  Widget _stat(
    String label,
    String value,
    IconData icon,
    Color color, {
    required double width,
  }) {
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
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: MijanoIcon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: MijanoTheme.ink,
                    ),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(TripStatus s) {
  switch (s) {
    case TripStatus.active:
      return Colors.green;
    case TripStatus.accepted:
    case TripStatus.arrived:
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
    case TripStatus.arrived:
      return 'Conductor llegó';
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
          final docsList = DriverDocs.requiredDocs.entries.toList();

          return AlertDialog(
            title: const Text('Documentos del Conductor'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(docsList.length, (index) {
                    final key = docsList[index].key;
                    final label = docsList[index].value;
                    final url = driver.documents[key];
                    final rawStatus = driver.documents['${key}Status'];
                    final status = DriverDocs.normalizeStatus(rawStatus?.toString());

                    return Column(
                      children: [
                        _buildDocItem(
                          title: label,
                          url: url,
                          status: status,
                          onView: () => _showFullImage(context, url),
                          onApprove: () => _actualizarEstadoDocumento(
                            context,
                            driver,
                            '${key}Status',
                            'approved',
                            setStateDialog,
                          ),
                          onReject: () => _actualizarEstadoDocumento(
                            context,
                            driver,
                            '${key}Status',
                            'rejected',
                            setStateDialog,
                          ),
                        ),
                        if (index < docsList.length - 1)
                          const Divider(height: 16),
                      ],
                    );
                  }),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: Colors.black),
                child: const Text(
                  'Cerrar',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
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
                  const Text(
                    'Previsualización de Documento',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
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
      border: Border.all(color: Colors.brown.withValues(alpha: 0.12)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
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
                          child: const Icon(
                            Icons.broken_image,
                            size: 24,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : Container(
                        width: 65,
                        height: 65,
                        color: Colors.grey.shade200,
                        child: const Icon(
                          Icons.insert_drive_file_outlined,
                          size: 24,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: onReject,
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text(
                      'Rechazar',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE3FCEF),
                      foregroundColor: const Color(0xFF006644),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text(
                      'Aprobar',
                      style: TextStyle(fontSize: 13),
                    ),
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
