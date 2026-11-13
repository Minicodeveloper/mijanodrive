import 'dart:async';
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
        _showPhoneRecoveryDialog(email);
      } else {
        final remaining = 3 - _failedAttempts;
        _snack(
          '$msg (Intento $_failedAttempts/3. Tras $remaining ${remaining == 1 ? "fallo" : "fallos"} podrás recuperar tu cuenta)',
        );
      }
    }
  }

  void _showPhoneRecoveryDialog(String initialInput) {
    final digits = initialInput.replaceAll(RegExp(r'\D'), '');
    String phoneText = '';
    if (digits.length == 9) {
      phoneText = digits;
    } else if (digits.startsWith('51') && digits.length >= 11) {
      phoneText = digits.substring(2, 11);
    }

    final phoneController = TextEditingController(text: phoneText);
    final smsCodeController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    int currentStep = 1; // 1 = solicitar SMS, 2 = validar código y cambiar clave
    bool isProcessing = false;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;
    String? errorMessage;
    String sentPhone = '';
    int resendCooldown = 0;
    Timer? resendTimer;

    void startCooldown(StateSetter setModalState) {
      resendCooldown = 30;
      resendTimer?.cancel();
      resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!context.mounted) {
          t.cancel();
          return;
        }
        if (resendCooldown > 0) {
          setModalState(() {
            resendCooldown--;
          });
        } else {
          t.cancel();
        }
      });
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9C4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    currentStep == 1 ? Icons.sms_outlined : Icons.lock_reset_rounded,
                    color: const Color(0xFF8A5300),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    currentStep == 1 ? 'Recuperar Contraseña' : 'Nueva Contraseña',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (currentStep == 1) ...[
                    const Text(
                      'Ingresa tu número de teléfono celular registrado para enviarte un código de verificación por SMS:',
                      style: TextStyle(fontSize: 13.5, color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 9,
                      decoration: InputDecoration(
                        labelText: 'Número de celular',
                        hintText: '987654321',
                        prefixIcon: const Icon(Icons.phone_android_rounded),
                        prefixText: '+51 ',
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'SMS enviado al +51 $sentPhone',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Ingresa el código SMS de 6 dígitos:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: smsCodeController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: const TextStyle(
                        fontSize: 22,
                        letterSpacing: 6,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: '------',
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Define tu nueva contraseña:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureNewPassword,
                      decoration: InputDecoration(
                        labelText: 'Nueva contraseña',
                        hintText: 'Mínimo 6 caracteres',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setModalState(() {
                              obscureNewPassword = !obscureNewPassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirmar contraseña',
                        hintText: 'Repite la nueva contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setModalState(() {
                              obscureConfirmPassword = !obscureConfirmPassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: (isProcessing || resendCooldown > 0)
                            ? null
                            : () async {
                                setModalState(() {
                                  isProcessing = true;
                                  errorMessage = null;
                                });
                                final (sent, msg) = await _auth.sendPasswordResetOtp(sentPhone);
                                setModalState(() {
                                  isProcessing = false;
                                  if (sent) {
                                    errorMessage = null;
                                    startCooldown(setModalState);
                                  } else {
                                    errorMessage = msg;
                                  }
                                });
                                if (sent && mounted) {
                                  _snack('Nuevo código enviado por SMS');
                                }
                              },
                        child: Text(
                          resendCooldown > 0
                              ? 'Reenviar código en ${resendCooldown}s'
                              : '¿No te llegó el SMS? Reenviar código',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: resendCooldown > 0 ? Colors.grey : const Color(0xFF8A5300),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: TextStyle(fontSize: 12, color: Colors.red.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isProcessing
                    ? null
                    : () {
                        resendTimer?.cancel();
                        Navigator.pop(dialogCtx);
                      },
                child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
              ),
              if (currentStep == 1)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF9D408),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: isProcessing
                      ? null
                      : () async {
                          final phone = phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
                          if (phone.length != 9) {
                            setModalState(() {
                              errorMessage = 'Ingresa un número de celular de 9 dígitos';
                            });
                            return;
                          }

                          setModalState(() {
                            isProcessing = true;
                            errorMessage = null;
                          });

                          final (sent, message) = await _auth.sendPasswordResetOtp(phone);

                          if (!ctx.mounted) return;
                          setModalState(() {
                            isProcessing = false;
                            if (sent) {
                              sentPhone = phone;
                              currentStep = 2;
                              errorMessage = null;
                              startCooldown(setModalState);
                            } else {
                              errorMessage = message;
                            }
                          });
                        },
                  child: isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.black),
                          ),
                        )
                      : const Text(
                          'Enviar código SMS',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                )
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF9D408),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: isProcessing
                      ? null
                      : () async {
                          final code = smsCodeController.text.trim();
                          final newPass = newPasswordController.text;
                          final confirmPass = confirmPasswordController.text;

                          if (code.length != 6) {
                            setModalState(() {
                              errorMessage = 'Ingresa el código de 6 dígitos';
                            });
                            return;
                          }
                          if (newPass.length < 6) {
                            setModalState(() {
                              errorMessage = 'La contraseña debe tener mínimo 6 caracteres';
                            });
                            return;
                          }
                          if (newPass != confirmPass) {
                            setModalState(() {
                              errorMessage = 'Las contraseñas no coinciden';
                            });
                            return;
                          }

                          setModalState(() {
                            isProcessing = true;
                            errorMessage = null;
                          });

                          final (ok, msg) = await _auth.resetPasswordWithOtp(
                            phone: sentPhone,
                            smsCode: code,
                            newPassword: newPass,
                          );

                          if (!ctx.mounted) return;
                          setModalState(() => isProcessing = false);

                          if (ok) {
                            resendTimer?.cancel();
                            Navigator.pop(dialogCtx);
                            _failedAttempts = 0;
                            _emailController.text = sentPhone;
                            _passwordController.text = newPass;

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '¡Contraseña cambiada con éxito! Ya puedes iniciar sesión.',
                                  ),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 4),
                                ),
                              );
                            }
                          } else {
                            setModalState(() {
                              errorMessage = msg;
                            });
                          }
                        },
                  child: isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.black),
                          ),
                        )
                      : const Text(
                          'Cambiar Contraseña',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
            ],
          );
        },
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
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingresa tu correo o número de teléfono';
                          }
                          final trimmed = value.trim();
                          final isPhone = RegExp(r'^\d{9}$').hasMatch(trimmed);
                          if (!isPhone) {
                            return Validators.validateEmail(trimmed);
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'correo@ejemplo.com o 987654321',
                          labelText: 'Correo o Teléfono',
                          prefixIcon: const Icon(Icons.person_outline),
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
                            _showPhoneRecoveryDialog(_emailController.text.trim());
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