import 'package:flutter/material.dart';
import 'package:mijano_drive_app/services/auth_service.dart';
import 'package:mijano_drive_app/models/user_model.dart';
import 'package:mijano_drive_app/screens/driver/pending_account_screen.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  UserRole? _selectedRole;

  final _auth = AuthService.instance;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['role'] != null) {
      _selectedRole = (args['role'] as String) == 'driver' ? UserRole.driver : UserRole.passenger;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _snack('Por favor completa todos los campos');
      return;
    }

    setState(() => _isLoading = true);
    
    final (ok, msg, role, status) = await _auth.login(email, password);
    
    if (!mounted) return;
    setState(() => _isLoading = false);

    _snack(msg);

    if (ok) {
      if (role == UserRole.admin) { 
        Navigator.of(context).pushNamedAndRemoveUntil('/admin', (r) => false); 
      } else if (role == UserRole.driver) {
        if (status == 'approved') {
          Navigator.of(context).pushNamedAndRemoveUntil('/driver', (r) => false);
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const PendingAccountScreen()),
            (r) => false,
          );
        }
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
      }
    }
  }

  Future<void> _biometricLogin() async {
    final can = await _auth.canUseBiometrics();
    if (!can) {
      _snack('Tu dispositivo no tiene biometría configurada');
      return;
    }
    final ok = await _auth.authenticateBiometric();
    if (!mounted) return;
    if (ok && _auth.currentUser != null) {
      _routeAfterAuth();
    } else if (ok) {
      _snack('Primero inicia sesión con tu correo una vez');
    }
  }

  void _routeAfterAuth() {
    final user = _auth.currentUser;
    if (user == null || user.name == null || user.name!.isEmpty) {
      Navigator.of(context).pushReplacementNamed('/profile-setup');
    } else if (user.role == UserRole.admin) { 
      Navigator.of(context).pushNamedAndRemoveUntil('/admin', (r) => false);
    } else if (user.role == UserRole.driver) {
      if (user.status == 'approved') {
        Navigator.of(context).pushNamedAndRemoveUntil('/driver', (r) => false);
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const PendingAccountScreen()),
          (r) => false,
        );
      }
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
    }
  }

  
  void _mostrarModalClaveAdmin(BuildContext context) {
    final TextEditingController pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Acceso Restringido'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ingrese la clave maestra de administrador para continuar:'),
            const SizedBox(height: 12),
            TextField(
              controller: pinController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Clave Secreta',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF9D408)),
            onPressed: () {
              
              const String claveMaestra = 'MijanoDriveAdmin2026*';

              if (pinController.text == claveMaestra) {
                Navigator.pop(context); // Cierra el diálogo
                
                
                Navigator.of(context).pushNamed('/register-admin'); 

                _snack('Acceso concedido.');
              } else {
                Navigator.pop(context);
                _snack('Clave incorrecta. Acceso denegado.');
              }
            },
            child: const Text('Verificar', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final currentRole = args?['role'] ?? 'passenger'; 

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.1),
              
              
              Center(
                child: GestureDetector(
                  onLongPress: () => _mostrarModalClaveAdmin(context),
                  child: const Icon(
                    Icons.two_wheeler,
                    size: 80,
                    color: Color(0xFFF9D408),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              const Text(
                'Mijano Drive',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 40),
              
              // Email input
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'correo@ejemplo.com',
                  labelText: 'Correo electrónico',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: '******',
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF9D408),
                  disabledBackgroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.black),
                        ),
                      )
                    : const Text(
                        'Iniciar Sesión',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
              ),
              const SizedBox(height: 30),

              
              const Row(
                children: [
                  Expanded(child: Divider()),
                  SizedBox(width: 10),
                  Text('o'),
                  SizedBox(width: 10),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),

              
              OutlinedButton.icon(
                onPressed: _biometricLogin,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Usar huella dactilar'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: const BorderSide(color: Color(0xFFF9D408)),
                ),
              ),
              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('¿Nuevo usuario? '),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushNamed(
                        '/register',
                        arguments: {'initialRole': currentRole},
                      );
                    },
                    child: const Text(
                      'Registrate',
                      style: TextStyle(
                        color: Color(0xFFF9D408),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}