import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mijano_drive_app/models/user_model.dart';
import 'package:mijano_drive_app/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  final String initialRole; // Recibimos el rol inicial ('passenger' or 'driver')

  const RegisterScreen({super.key, required this.initialRole});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dniController = TextEditingController();
  final _cityController = TextEditingController();

  late String _selectedRole; // Se inicializará con el valor recibido
  bool _isLoading = false;

  // Variables para la foto de perfil
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  final _auth = AuthService.instance;

  @override
  void initState() {
    super.initState();
    // Fijamos el rol con el que el usuario llegó a esta pantalla
    _selectedRole = widget.initialRole;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _dniController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  // Función para abrir el menú flotante (Cámara o Galería)
  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galería'),
                onTap: () {
                  _pickImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Cámara'),
                onTap: () {
                  _pickImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Función para capturar la imagen
  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  // Paso 1: Validar campos y enviar SMS OTP
  Future<void> _register() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final dni = _dniController.text.trim();
    final city = _cityController.text.trim();

    // 1. Validar campos vacíos
    if (name.isEmpty || phone.isEmpty || email.isEmpty || password.isEmpty || dni.isEmpty || city.isEmpty) {
      _showSnackBar('Por favor completa todos los campos');
      return;
    }

    // 2. Validar formato de correo electrónico básico
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      _showSnackBar('Por favor ingresa un correo electrónico válido');
      return;
    }

    // 3. Validar Contraseña (mínimo 6 caracteres para Firebase)
    if (password.length < 6) {
      _showSnackBar('La contraseña debe tener al menos 6 caracteres');
      return;
    }

    // 4. Validar DNI (8 dígitos exactos)
    if (dni.length != 8 || int.tryParse(dni) == null) {
      _showSnackBar('El DNI debe tener exactamente 8 dígitos numéricos');
      return;
    }

    // 5. Validar Teléfono (9 dígitos exactos)
    if (phone.length != 9 || int.tryParse(phone) == null) {
      _showSnackBar('El teléfono debe tener exactamente 9 dígitos');
      return;
    }

    setState(() => _isLoading = true);

    // Enviamos el código OTP por SMS usando AuthService
    final (ok, msg) = await _auth.sendOtp(phone);

    if (!mounted) return;
    setState(() => _isLoading = false);

    _showSnackBar(msg);

    if (ok) {
      // Si el SMS se envió correctamente, mostramos el diálogo para ingresar el OTP
      _showOtpDialog();
    }
  }

  // Paso 2: Diálogo para ingresar el código OTP de 6 dígitos
  void _showOtpDialog() {
    final otpController = TextEditingController();
    final parentContext = context;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Verificar Teléfono'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ingresa el código de 6 dígitos enviado por SMS a tu celular:'),
            const SizedBox(height: 15),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                hintText: '123456',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF9D408)),
            onPressed: () async {
              final smsCode = otpController.text.trim();
              if (smsCode.length != 6) {
                _showSnackBar('Ingresa un código válido de 6 dígitos');
                return;
              }

              Navigator.pop(dialogContext);
              setState(() => _isLoading = true);

              final roleEnum = _selectedRole == 'driver' ? UserRole.driver : UserRole.passenger;

              // Verificamos el OTP y registramos la cuenta en Firebase y Firestore
              final (success, message) = await _auth.verifyOtpAndRegister(
                smsCode: smsCode,
                name: _nameController.text.trim(),
                email: _emailController.text.trim(),
                password: _passwordController.text.trim(),
                phone: _phoneController.text.trim(),
                dni: _dniController.text.trim(),
                city: _cityController.text.trim(),
                role: roleEnum,
              );

              if (!mounted) return;
              setState(() => _isLoading = false);

              _showSnackBar(message);

              if (success) {
                if (!parentContext.mounted) return;

                // Redirigir según el rol registrado
                if (roleEnum == UserRole.driver) {
                  Navigator.of(parentContext).pushNamedAndRemoveUntil('/driver', (r) => false);
                } else {
                  Navigator.of(parentContext).pushNamedAndRemoveUntil('/home', (r) => false);
                }
              }
            },
            child: const Text('Verificar', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDriver = _selectedRole == 'driver';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9D408),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isDriver ? 'Registro de Conductor' : 'Registro de Pasajero',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),

              // ==========================================
              // SELECTOR DE FOTO DE PERFIL
              // ==========================================
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFF9D408), width: 2),
                        image: _imageFile != null
                            ? DecorationImage(
                                image: FileImage(_imageFile!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _imageFile == null
                          ? const Icon(
                              Icons.person,
                              size: 50,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: () => _showImageSourceActionSheet(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF9D408),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Text(
                isDriver ? 'Crear cuenta de Conductor' : 'Crear cuenta de Pasajero',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Completa tu información personal para continuar',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 25),

              // Nombre completo
              TextField(
                controller: _nameController,
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(100)],
                decoration: InputDecoration(
                  hintText: 'Juan Pérez',
                  labelText: 'Nombre completo',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // Teléfono
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(9),
                ],
                decoration: InputDecoration(
                  hintText: '999999999',
                  labelText: 'Número de teléfono',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // Correo electrónico
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
              const SizedBox(height: 15),

              // Contraseña
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
              const SizedBox(height: 15),

              // DNI
              TextField(
                controller: _dniController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                decoration: InputDecoration(
                  hintText: '12345678',
                  labelText: 'DNI',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // Ciudad
              TextField(
                controller: _cityController,
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(50)],
                decoration: InputDecoration(
                  hintText: 'Ej. Tarapoto',
                  labelText: 'Ciudad',
                  prefixIcon: const Icon(Icons.location_city_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Botón de registro
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
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
                        'Registrarse',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
              ),
              const SizedBox(height: 20),

              // Enlace de inicio de sesión
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('¿Ya tienes cuenta? '),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushReplacementNamed('/login');
                    },
                    child: const Text(
                      'Inicia sesión',
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