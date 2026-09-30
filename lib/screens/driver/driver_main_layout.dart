import 'package:flutter/material.dart';
import 'driver_dashboard_screen.dart';
import 'driver_history_screen.dart';
import 'driver_account_screen.dart';
import '../../theme.dart';

class DriverMainLayout extends StatefulWidget {
  const DriverMainLayout({super.key});

  @override
  State<DriverMainLayout> createState() => _DriverMainLayoutState();
}

class _DriverMainLayoutState extends State<DriverMainLayout> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DriverDashboardScreen(),
    const DriverHistoryScreen(),
    const DriverAccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Barra superior personalizada, elegante y delgada
          Container(
            color: MijanoTheme.sol,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 6,
              bottom: 8,
              left: 16,
              right: 16,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _currentIndex == 0
                      ? 'Panel del conductor'
                      : _currentIndex == 1
                          ? 'Historial de viajes'
                          : 'Mi Cuenta',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: MijanoTheme.ink,
                  ),
                ),
                if (_currentIndex == 0)
                  IconButton(
                    icon: const Icon(Icons.person, color: MijanoTheme.ink, size: 22),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    // Acción que te lleva al perfil al presionar la personita
                    onPressed: () => Navigator.pushNamed(context, '/profile'),
                  ),
              ],
            ),
          ),
          // Contenido de las pestañas
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: MijanoTheme.ink,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Historial',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Cuenta',
          ),
        ],
      ),
    );
  }
}