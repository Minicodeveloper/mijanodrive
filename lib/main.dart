import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
import 'screens/auth/role-select.dart';

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
    origin: args['origin'] ??
        const GeoPoint(-6.4869, -76.3654),
    destinationGeoPoint: args['destinationGeoPoint'] ??
        const GeoPoint(-6.4869, -76.3654),
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

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  // Animaciones para el logo superior
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  // Animaciones para el logo_title (animación principal de carga)
  late Animation<Offset> _titleSlide;
  late Animation<double> _titleScale;
  late Animation<double> _titleOpacity;

  @override
  void initState() {
    super.initState();

    // Controlador con duración total de 1.8 segundos para la secuencia de animaciones
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // 1. Animación para logo.png (Ocurre de 0.0s a 0.8s)
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

    // 2. Animación de carga para logo_title.png (Ocurre de 0.4s a 1.2s)
    // Desplazamiento desde abajo
    _titleSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.9, curve: Curves.easeOutBack),
      ),
    );

    // Escala y rebote suave al cargar
    _titleScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.9, curve: Curves.easeOutBack),
      ),
    );

    // Opacidad progresiva
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.7, curve: Curves.easeIn),
      ),
    );

    // Iniciar la secuencia de animaciones
    _controller.forward();

    // Navegar después de 3 segundos
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
      backgroundColor: MijanoTheme.sol, // Mantiene el fondo amarillo característico
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ==========================================
              // 1. LOGO PRINCIPAL SUPERIOR (logo.png)
              // ==========================================
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

              const Spacer(flex: 2),

              // ==========================================
              // 2. LOGO TÍTULO CON ANIMACIÓN (logo_title.png)
              // ==========================================
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

              const Spacer(flex: 3),

              // ==========================================
              // 3. INDICADOR DE CARGA
              // ==========================================
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