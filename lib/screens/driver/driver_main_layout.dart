import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../passenger/passenger_available_cars_screen.dart';
import 'driver_account_screen.dart';
import 'driver_dashboard_screen.dart';
import 'driver_history_screen.dart';
import 'driver_vehicle_screen.dart';

class DriverMainLayout extends StatefulWidget {
  const DriverMainLayout({super.key});

  @override
  State<DriverMainLayout> createState() => _DriverMainLayoutState();
}

class _DriverMainLayoutState extends State<DriverMainLayout> {
  int _currentIndex = 0;
  bool _isCarDriver = false;

  @override
  void initState() {
    super.initState();
    _resolveDriverVehicleType();
  }

  bool _checkIsCarType(String? rawType, String? rawAgency) {
    if (rawType != null && rawType.trim().isNotEmpty) {
      final normalized = rawType.trim().toLowerCase();
      if (normalized.contains('moto')) {
        return false;
      }
      if (normalized == 'carro' ||
          normalized == 'auto' ||
          normalized.contains('carro') ||
          normalized.contains('auto')) {
        return true;
      }
    }
    if (rawAgency != null && rawAgency.trim().isNotEmpty) {
      return true;
    }
    return false;
  }

  Future<void> _resolveDriverVehicleType() async {
    final current = AuthService.instance.currentUser;
    if (current != null) {
      final initialIsCar = _checkIsCarType(
        current.vehicleType,
        current.agencyName,
      );
      if (initialIsCar) {
        unawaited(
          IntercityVehicleRepository.instance.syncFromUserMap(
            current.uid,
            current.toMap(),
          ),
        );
      }
      if (mounted && _isCarDriver != initialIsCar) {
        setState(() => _isCarDriver = initialIsCar);
      }
    }

    final uid =
        current?.uid ?? fb.FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        final vType =
            (data['vehicleType'] ??
                    data['tipoVehiculo'] ??
                    (data['vehicle'] is Map
                        ? (data['vehicle'] as Map)['type']
                        : null))
                ?.toString();
        final agency = data['agencyName']?.toString();
        if (vType != null || agency != null) {
          final resolved = _checkIsCarType(vType, agency);
          if (resolved) {
            unawaited(
              IntercityVehicleRepository.instance.syncFromUserMap(uid, data),
            );
          }
          if (mounted && _isCarDriver != resolved) {
            setState(() {
              _isCarDriver = resolved;
              if (!_isCarDriver && _currentIndex > 2) {
                _currentIndex = 0;
              }
            });
          }
          return;
        }
      }

      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(uid)
          .get();
      if (driverDoc.exists) {
        final data = driverDoc.data() ?? {};
        final vType =
            (data['vehicleType'] ??
                    data['tipoVehiculo'] ??
                    (data['vehicle'] is Map
                        ? (data['vehicle'] as Map)['type']
                        : null))
                ?.toString();
        final agency = data['agencyName']?.toString();
        final resolved = _checkIsCarType(vType, agency);
        if (resolved) {
          unawaited(
            IntercityVehicleRepository.instance.syncFromUserMap(uid, data),
          );
        }
        if (mounted && _isCarDriver != resolved) {
          setState(() {
            _isCarDriver = resolved;
            if (!_isCarDriver && _currentIndex > 2) {
              _currentIndex = 0;
            }
          });
        }
      }
    } catch (_) {}
  }

  String _headerTitle(int index) {
    if (_isCarDriver) {
      switch (index) {
        case 0:
          return 'Panel del conductor';
        case 1:
          return 'Mijano Drive';
        case 2:
          return 'Historial de viajes';
        default:
          return 'Mi Cuenta';
      }
    } else {
      switch (index) {
        case 0:
          return 'Panel del conductor';
        case 1:
          return 'Historial de viajes';
        default:
          return 'Mi Cuenta';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      const DriverDashboardScreen(),
      if (_isCarDriver)
        DriverVehicleScreen(
          onTripStartedNavigateHome: () => setState(() => _currentIndex = 0),
        ),
      const DriverHistoryScreen(),
      const DriverAccountScreen(),
    ];

    final navItems = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.map_outlined),
        activeIcon: Icon(Icons.map),
        label: 'Inicio',
      ),
      if (_isCarDriver)
        const BottomNavigationBarItem(
          icon: Icon(Icons.directions_car_outlined),
          activeIcon: Icon(Icons.directions_car),
          label: 'Vehículo',
        ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.history_outlined),
        activeIcon: Icon(Icons.history),
        label: 'Historial',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        activeIcon: Icon(Icons.person),
        label: 'Cuenta',
      ),
    ];

    final safeIndex = _currentIndex >= screens.length ? 0 : _currentIndex;

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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isCarDriver && safeIndex == 1)
                      GestureDetector(
                        onTap: () => setState(() => _currentIndex = 0),
                        child: const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: Icon(
                            Icons.arrow_back,
                            color: MijanoTheme.ink,
                            size: 22,
                          ),
                        ),
                      ),
                    Text(
                      _headerTitle(safeIndex),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: MijanoTheme.ink,
                      ),
                    ),
                  ],
                ),
                if (safeIndex == 0)
                  IconButton(
                    icon: const Icon(
                      Icons.person,
                      color: MijanoTheme.ink,
                      size: 22,
                    ),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pushNamed(context, '/profile'),
                  ),
              ],
            ),
          ),
          // Contenido de las pestañas
          Expanded(
            child: IndexedStack(
              index: safeIndex,
              children: screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: safeIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: MijanoTheme.ink,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        items: navItems,
      ),
    );
  }
}
