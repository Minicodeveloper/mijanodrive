import 'package:flutter/material.dart';
import 'package:mijano_drive_app/services/auth_service.dart';
import 'package:mijano_drive_app/models/user_model.dart';
import 'package:mijano_drive_app/screens/driver/pending_account_screen.dart';
import 'package:mijano_drive_app/utils/validators.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  
  
  bool _isDriver = false;

  final _auth = AuthService.instance;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text; 

    final (ok, msg, role, status) = await _auth.login(email, password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    _snack(msg);

    if (ok) {
      _routeAfterAuth();
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
    if (user == null || user.name == null || user.name!.trim().isEmpty) {
      Navigator.of(context).pushReplacementNamed('/profile-setup');
    } else if (user.role == UserRole.admin || user.role == UserRole.operator) {
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

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final currentRole = _isDriver ? 'driver' : 'passenger';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- BOTÓN SUPERIOR PARA ALTERNAR ROL ---
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _isDriver = !_isDriver;
                      });
                    },
                    child: Text(
                      _isDriver ? '¿Eres pasajero?' : '¿Eres conductor?',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                const Center(
                  child: Icon(
                    Icons.two_wheeler,
                    size: 80,
                    color: Color(0xFFF9D408),
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
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.validateEmail,
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

                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        validator: Validators.validatePassword,
                        decoration: InputDecoration(
                          hintText: '******',
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
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
                      : Text(
                    _isDriver ? 'Iniciar Sesión Conductor' : 'Iniciar Sesión',
                    style: const TextStyle(
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
                    Text(_isDriver ? '¿Nuevo conductor? ' : '¿Nuevo usuario? '),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pushNamed(
                          '/register',
                          arguments: {'initialRole': currentRole},
                        );
                      },
                      child: Text(
                        _isDriver ? 'Regístrate o solicita cuenta' : 'Regístrate',
                        style: const TextStyle(
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
      ),
    );
  }
}