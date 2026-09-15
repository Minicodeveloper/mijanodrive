import 'package:flutter/material.dart';
import '../theme.dart';

// Importando todos los módulos desde la nueva estructura
import 'modules/dashboard_module.dart';
import 'modules/users_module.dart';
import 'modules/drivers_module.dart';
import 'modules/reservations_module.dart';
import 'modules/tariffs_module.dart';
import 'modules/wallet_module.dart';
import 'modules/reports_module.dart';
import 'modules/analytics_module.dart';
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
  int _tab = 0;

  List<(IconData, String)> get _items {
    if (widget.role == AdminRole.operator) {
      return [
        (Icons.dashboard, 'Panel'),
        (Icons.people, 'Usuarios'),
        (Icons.verified_user, 'Conductores'),
        (Icons.schedule, 'Reservas'),
        (Icons.warning, 'Reportes'),
        (Icons.emergency, 'Alertas S.O.S.'),
      ];
    }
    return [
      (Icons.dashboard, 'Panel'),
      (Icons.people, 'Usuarios'),
      (Icons.verified_user, 'Conductores'),
      (Icons.schedule, 'Reservas'),
      (Icons.attach_money, 'Tarifas'),
      (Icons.account_balance_wallet, 'Billetera'),
      (Icons.warning, 'Reportes'),
      (Icons.bar_chart, 'Analítica'),
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
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (ctx, i) => Material(
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
                      fontWeight: _tab == i ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  selected: _tab == i,
                  selectedTileColor: Colors.white.withValues(alpha: 0.06),
                  onTap: () {
                    setState(() => _tab = i);
                    if (closeDrawer) {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ),
          ),
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
    switch (title) {
      case 'Panel': return DashboardModule(role: widget.role);
      case 'Usuarios': return const UsersModule();
      case 'Conductores': return const DriversModule();
      case 'Reservas': return const ReservationsModule();
      case 'Tarifas': return const TariffsModule();
      case 'Billetera': return const WalletModule();
      case 'Reportes': return const ReportsModule();
      case 'Analítica': return const AnalyticsModule();
      case 'Alertas S.O.S.': return const AlertsModule();
      case 'Seguridad': return const SecurityModule();
      default: return const Center(child: Text('Módulo no encontrado'));
    }
  }
}
