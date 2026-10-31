import 'package:flutter/material.dart';
import 'package:mijano_drive_app/services/auth_service.dart';
import 'package:mijano_drive_app/services/firestore_service.dart';
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
  bool _isPasswordObscure = true;
  int _failedAttempts = 0;
  String? _lastAttemptEmail;

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

    if (ok) {
      _failedAttempts = 0;
      _lastAttemptEmail = null;
      _snack(msg);
      _routeAfterAuth();
    } else {
      if (_lastAttemptEmail == email) {
        _failedAttempts++;
      } else {
        _lastAttemptEmail = email;
        _failedAttempts = 1;
      }

      if (_failedAttempts >= 3) {
        _showRecoveryDialog(email);
      } else {
        final remaining = 3 - _failedAttempts;
        _snack(
          '$msg (Intento $_failedAttempts/3. Tras $remaining ${remaining == 1 ? "fallo" : "fallos"} podrás recuperar tu cuenta)',
        );
      }
    }
  }

  void _showRecoveryDialog(String email) {
    final resetEmailController = TextEditingController(text: email);
    bool isSending = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: const [
              Icon(Icons.lock_reset, color: Color(0xFFF9D408), size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Recuperar Cuenta',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9C4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF9D408)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFF8A5300), size: 22),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Has superado los 3 intentos fallidos de inicio de sesión.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8A5300),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Confirma tu correo para enviarte un enlace de recuperación de contraseña:',
                style: TextStyle(fontSize: 13.5, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Correo electrónico',
                  hintText: 'ejemplo@gmail.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSending ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF9D408),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: isSending
                  ? null
                  : () async {
                      final targetEmail = resetEmailController.text.trim();
                      if (targetEmail.isEmpty) {
                        _snack('Ingresa tu correo');
                        return;
                      }
                      setModalState(() => isSending = true);
                      final (sent, message) =
                          await _auth.sendPasswordResetEmail(targetEmail);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      _failedAttempts = 0;
                      _showRecoverySuccessDialog(targetEmail, sent, message);
                    },
              child: isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.black),
                      ),
                    )
                  : const Text(
                      'Enviar enlace',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecoverySuccessDialog(String email, bool success, String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Row(
          children: [
            Icon(
              success ? Icons.mark_email_read_outlined : Icons.error_outline,
              color: success ? const Color(0xFF2E7D32) : Colors.red,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                success ? 'Enlace Enviado' : 'No se pudo enviar',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF9D408),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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

  Future<void> _routeAfterAuth() async {
    final user = _auth.currentUser;
    if (user == null || user.name == null || user.name!.trim().isEmpty) {
      Navigator.of(context).pushReplacementNamed('/profile-setup');
    } else if (user.role == UserRole.admin || user.role == UserRole.operator || user.role == UserRole.support || user.role == UserRole.control) {
      Navigator.of(context).pushNamedAndRemoveUntil('/admin', (r) => false);
    } else if (user.role == UserRole.driver) {
      if (user.status == 'approved') {
        await FirestoreService.instance.setDriverAvailability(user.uid, false);
        if (!mounted) return;
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

                Center(
  child: Image.asset(
    'assets/images/logo2.jpg',
    width: 150,
    height: 150,
    fit: BoxFit.contain,
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
                        obscureText: _isPasswordObscure,
                        validator: Validators.validatePassword,
                        decoration: InputDecoration(
                          hintText: '******',
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordObscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordObscure = !_isPasswordObscure;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            _showRecoveryDialog(_emailController.text.trim());
                          },
                          child: const Text(
                            '¿Olvidaste tu contraseña?',
                            style: TextStyle(
                              color: Color(0xFF8A5300),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
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