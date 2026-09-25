import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'theme.dart';
import 'admin/admin_app.dart';
import 'admin/register_admin_screen.dart';

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
import 'screens/driver/driver_active_trip_screen.dart';
import 'screens/auth/role-select.dart';
import 'screens/driver/driver_main_layout.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
  try {
    await Hive.initFlutter();
  } catch (_) {}
  
  runApp(kIsWeb ? const AdminApp() : const MijanoDriveApp());
}

class MijanoDriveApp extends StatelessWidget {
  const MijanoDriveApp({super.key});

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
        final initialRole = args['initialRole'] ?? 'passenger';
        page = RegisterScreen(initialRole: initialRole);
        break;
      case '/register-admin':
        page = const RegisterAdminScreen();
        break;
      case '/role-select':
        page = const RoleSelectScreen();
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
          distanceKm: (args['distanceKm'] ?? 0).toDouble(),
          city: args['city'] ?? 'Tarapoto',
          origin: args['origin'] ?? const GeoPoint(-6.4869, -76.3654),
          destinationGeoPoint: args['destinationGeoPoint'] ?? const GeoPoint(-6.4869, -76.3654),
        );
        break;
      case '/active-trip':
        page = ActiveTripScreen(
          destination: args['destination'] ?? '',
          fare: (args['fare'] ?? 0).toDouble(),
          tripId: args['tripId'] ?? '',
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
        page = const DriverMainLayout();
        break;
      case '/admin': 
        final adminRole = args['role'] ?? AdminRole.superAdmin;
        page = AdminApp(role: adminRole);
        break;
      default:
        page = const LoginScreen();
    }
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  late Animation<Offset> _titleSlide;
  late Animation<double> _titleScale;
  late Animation<double> _titleOpacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.9, curve: Curves.easeOutBack),
      ),
    );

    _titleScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.9, curve: Curves.easeOutBack),
      ),
    );

    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.7, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
    _go();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    await Future.delayed(const Duration(milliseconds: 3000));
    if (mounted) Navigator.of(context).pushReplacementNamed('/role-select');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MijanoTheme.sol, 
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // 1. LOGO PRINCIPAL SUPERIOR (logo.png)
              FadeTransition(
                opacity: _logoOpacity,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 220,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Text(
                      'MIJANO DRIVE',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: MijanoTheme.ink,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // 2. LOGO TÍTULO CON ANIMACIÓN (logo_title.png)
              SlideTransition(
                position: _titleSlide,
                child: ScaleTransition(
                  scale: _titleScale,
                  child: FadeTransition(
                    opacity: _titleOpacity,
                    child: Image.asset(
                      'assets/images/logo_title.png',
                      width: MediaQuery.of(context).size.width * 0.85,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Text(
                        'LA APP OFICIAL DEL MOTOKAR',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: MijanoTheme.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 60),

              // 3. INDICADOR DE CARGA
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: MijanoTheme.ink,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
