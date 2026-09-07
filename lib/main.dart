import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'firebase_options.dart';
import 'theme.dart';
import 'admin/admin_app.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/profile_setup_screen.dart';
import 'screens/passenger/home_screen.dart';
import 'screens/passenger/search_trip_screen.dart';
import 'screens/passenger/payment_screen.dart';
import 'screens/passenger/active_trip_screen.dart';
import 'screens/passenger/rating_screen.dart';
import 'screens/passenger/wallet_screen.dart';
import 'screens/shared/profile_screen.dart';
import 'screens/driver/driver_dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Si Firebase no inicializa, la app sigue en modo demo sin crashear.
  }
  try {
    await Hive.initFlutter();
  } catch (_) {}
  // En web se sirve el PANEL ADMIN; en móvil, la app de pasajero/conductor.
  runApp(kIsWeb ? const AdminApp() : const MijanoDriveApp());
}

class MijanoDriveApp extends StatelessWidget {
  const MijanoDriveApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mijano Drive',
      debugShowCheckedModeBanner: false,
      theme: MijanoTheme.light,
      home: const SplashScreen(),
      onGenerateRoute: _onGenerateRoute,
    );
  }

  static Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    final args = (settings.arguments as Map?) ?? const {};
    Widget page;
    switch (settings.name) {
      case '/login':
        page = const LoginScreen();
        break;
      case '/register':
        page = const RegisterScreen();
        break;
      case '/profile-setup':
        page = const ProfileSetupScreen();
        break;
      case '/home':
        page = const HomeScreen();
        break;
      case '/search-trip':
        page = const SearchTripScreen();
        break;
      case '/payment':
        page = PaymentScreen(
          destination: args['destination'] ?? '',
          fare: (args['fare'] ?? 0).toDouble(),
          paymentMethod: args['paymentMethod'] ?? 'cash',
        );
        break;
      case '/active-trip':
        page = ActiveTripScreen(
          destination: args['destination'] ?? '',
          fare: (args['fare'] ?? 0).toDouble(),
        );
        break;
      case '/rating':
        page = RatingScreen(
          driverName: args['driverName'] ?? 'Conductor',
          tripId: args['tripId'] ?? '',
        );
        break;
      case '/wallet':
        page = const WalletScreen();
        break;
      case '/profile':
        page = const ProfileScreen();
        break;
      case '/driver':
        page = const DriverDashboardScreen();
        break;
      default:
        page = const LoginScreen();
    }
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MijanoTheme.sol,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: MijanoTheme.ink,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.two_wheeler,
                  size: 64, color: MijanoTheme.sol),
            ),
            const SizedBox(height: 24),
            const Text('MIJANO DRIVE',
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: MijanoTheme.ink)),
            const SizedBox(height: 6),
            const Text('La App Oficial del Motokar',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MijanoTheme.ink)),
            const SizedBox(height: 40),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                  strokeWidth: 3, color: MijanoTheme.ink),
            ),
          ],
        ),
      ),
    );
  }
}
