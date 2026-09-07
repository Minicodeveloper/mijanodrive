import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _showOtpField = false;
  bool _isLoading = false;

  final _auth = AuthService.instance;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _snack('Por favor ingresa tu teléfono');
      return;
    }

    setState(() => _isLoading = true);
    final (ok, msg) = await _auth.sendOtp(phone);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (ok) _showOtpField = true;
    });
    _snack(msg);
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      _snack('Por favor ingresa el código');
      return;
    }

    setState(() => _isLoading = true);
    final (ok, msg) = await _auth.verifyOtp(_phoneController.text.trim(), otp);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!ok) {
      _snack(msg);
      return;
    }
    _routeAfterAuth();
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
      _snack('Primero inicia sesión con tu número una vez');
    }
  }

  void _routeAfterAuth() {
    final user = _auth.currentUser;
    // Usuario sin perfil completo → configurar perfil.
    if (user == null || user.name == null || user.name!.isEmpty) {
      Navigator.of(context).pushReplacementNamed('/profile-setup');
    } else if (user.role == UserRole.driver) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/driver', (r) => false);
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
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
              // Logo
              const Icon(
                Icons.two_wheeler,
                size: 80,
                color: Color(0xFFF9D408),
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
              // Phone input
              TextField(
                controller: _phoneController,
                enabled: !_showOtpField,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: '+51 999999999',
                  labelText: 'Número de teléfono',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // OTP input (conditional)
              if (_showOtpField)
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    hintText: '000000',
                    labelText: 'Código OTP',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              const SizedBox(height: 30),
              // Primary button
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : (_showOtpField ? _verifyOtp : _sendOtp),
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
                        _showOtpField ? 'Verificar' : 'Enviar OTP',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              // Back button (if OTP shown)
              if (_showOtpField)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showOtpField = false;
                      _otpController.clear();
                    });
                  },
                  child: const Text('Cambiar número'),
                ),
              const SizedBox(height: 30),
              // Divider
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
              // Biometric login button
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
              // Register link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('¿Nuevo usuario? '),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushReplacementNamed('/register');
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
