import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mijano_drive_app/models/user_model.dart';
import 'package:mijano_drive_app/services/auth_service.dart';
import 'package:mijano_drive_app/services/document_service.dart';
import 'package:mijano_drive_app/screens/driver/pending_account_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String initialRole; 

  const RegisterScreen({super.key, required this.initialRole});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  
  int _currentStep = 0;
  final PageController _pageController = PageController();

  
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dniController = TextEditingController();
  final _cityController = TextEditingController();
  File? _imageFile;

  
  final _licenseController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _colorController = TextEditingController();
  final _yearController = TextEditingController();
  final _plateController = TextEditingController();
  final String _selectedVehicleType = 'Mototaxi'; 
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;

  
  final Map<int, File?> _documents = {
    0: null,
    1: null,
    2: null,
    3: null,
    4: null,
    5: null,
    6: null,
    7: null,
  };

  
  final Map<int, String> _docKeyMap = {
    0: 'docFront',
    1: 'docBack',
    2: 'vehiclePhoto',
    3: 'soatPhoto',
    4: 'propertyCardPhoto',
    5: 'licensedDocument',
    6: 'policeRecord',
    7: 'criminalRecord',
  };

  late String _selectedRole;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  final _auth = AuthService.instance;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _dniController.dispose();
    _cityController.dispose();
    _licenseController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _yearController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _pickImage({bool isProfile = true, int? docIndex}) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        if (isProfile) {
          _imageFile = File(pickedFile.path);
        } else if (docIndex != null) {
          _documents[docIndex] = File(pickedFile.path);
        }
      });
    }
  }

  void _showImageSourceActionSheet({bool isProfile = true, int? docIndex}) {
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
                  Navigator.of(context).pop();
                  _pickImage(isProfile: isProfile, docIndex: docIndex);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Cámara'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final XFile? pickedFile = await _picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 80,
                  );
                  if (pickedFile != null) {
                    setState(() {
                      if (isProfile) {
                        _imageFile = File(pickedFile.path);
                      } else if (docIndex != null) {
                        _documents[docIndex] = File(pickedFile.path);
                      }
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Validaciones del Paso 1
  bool _validateStep1() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final dni = _dniController.text.trim();
    final city = _cityController.text.trim();

    if (name.isEmpty || phone.isEmpty || email.isEmpty || password.isEmpty || dni.isEmpty || city.isEmpty) {
      _showSnackBar('Por favor completa todos los campos');
      return false;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      _showSnackBar('Por favor ingresa un correo electrónico válido');
      return false;
    }

    if (password.length < 6) {
      _showSnackBar('La contraseña debe tener al menos 6 caracteres');
      return false;
    }

    if (dni.length != 8 || int.tryParse(dni) == null) {
      _showSnackBar('El DNI debe tener exactamente 8 dígitos numéricos');
      return false;
    }

    if (phone.length != 9 || int.tryParse(phone) == null) {
      _showSnackBar('El teléfono debe tener exactamente 9 dígitos');
      return false;
    }

    return true;
  }

  
  bool _validateStep2() {
    if (!_acceptedTerms || !_acceptedPrivacy) {
      _showSnackBar('Debes aceptar los términos y condiciones y la política de privacidad');
      return false;
    }
    if (_licenseController.text.trim().isEmpty) {
      _showSnackBar('Ingresa el número de licencia');
      return false;
    }
    if (_brandController.text.trim().isEmpty ||
        _modelController.text.trim().isEmpty ||
        _colorController.text.trim().isEmpty ||
        _yearController.text.trim().isEmpty ||
        _plateController.text.trim().isEmpty) {
      _showSnackBar('Completa todos los datos del vehículo');
      return false;
    }
    return true;
  }

  
  void _onNextPressed() {
    if (_currentStep == 0) {
      if (!_validateStep1()) return;
      if (_selectedRole == 'passenger') {
        _register(); // Pasajero solo tiene 1 paso
      } else {
        setState(() => _currentStep = 1);
        _pageController.animateToPage(1, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
    } else if (_currentStep == 1) {
      if (!_validateStep2()) return;
      setState(() => _currentStep = 2);
      _pageController.animateToPage(2, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else if (_currentStep == 2) {
      _register();
    }
  }

  void _onPreviousPressed() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(_currentStep, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  
  Future<void> _register() async {
    setState(() => _isLoading = true);
    final phone = _phoneController.text.trim();

    final (ok, msg) = await _auth.sendOtp(phone);

    if (!mounted) return;
    setState(() => _isLoading = false);

    _showSnackBar(msg);

    if (ok) {
      _showOtpDialog();
    }
  }

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

              final (success, message) = await _auth.verifyOtpAndRegister(
                smsCode: smsCode,
                name: _nameController.text.trim(),
                email: _emailController.text.trim(),
                password: _passwordController.text.trim(),
                phone: _phoneController.text.trim(),
                dni: _dniController.text.trim(),
                city: _cityController.text.trim(),
                role: roleEnum,
                profileImage: _imageFile,
                vehiclePlate: _plateController.text.trim(),
                vehicleBrand: _brandController.text.trim(),
                vehicleModel: _modelController.text.trim(),
                vehicleColor: _colorController.text.trim(),
                vehicleYear: _yearController.text.trim(),
                licenseNumber: _licenseController.text.trim(),
              );

              if (!mounted) return;

              _showSnackBar(message);

              if (success) {
                if (!parentContext.mounted) return;
                
                if (roleEnum == UserRole.driver) {
                  for (var entry in _documents.entries) {
                    if (entry.value != null) {
                      final key = _docKeyMap[entry.key];
                      if (key != null) {
                        try {
                          await DocumentService.instance.uploadDriverDocument(
                            documentKey: key,
                            imageFile: entry.value!,
                          );
                        } catch (e) {
                          debugPrint('Error subiendo documento $key: $e');
                        }
                      }
                    }
                  }
                }

                setState(() => _isLoading = false);

                if (!parentContext.mounted) return;
                if (roleEnum == UserRole.driver) {
                  Navigator.of(parentContext).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const PendingAccountScreen()),
                    (route) => false,
                  );
                } else {
                  Navigator.of(parentContext).pushNamedAndRemoveUntil('/home', (r) => false);
                }
              } else {
                setState(() => _isLoading = false);
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
          onPressed: () {
            if (_currentStep > 0 && isDriver) {
              _onPreviousPressed();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          isDriver ? 'Registro de Conductor' : 'Registro de Pasajero',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          if (isDriver) ...[
            const SizedBox(height: 10),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  Expanded(child: Container(height: 4, color: _currentStep >= 0 ? const Color(0xFFF9D408) : Colors.grey[300])),
                  const SizedBox(width: 5),
                  Expanded(child: Container(height: 4, color: _currentStep >= 1 ? const Color(0xFFF9D408) : Colors.grey[300])),
                  const SizedBox(width: 5),
                  Expanded(child: Container(height: 4, color: _currentStep >= 2 ? const Color(0xFFF9D408) : Colors.grey[300])),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _currentStep == 0
                  ? 'Paso 1: Información Personal'
                  : _currentStep == 1
                      ? 'Paso 2: Información del Vehículo'
                      : 'Paso 3: Documentación',
              style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ],
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(), 
              children: [
                _buildStep1Personal(),
                if (isDriver) ...[
                  _buildStep2Vehicle(),
                  _buildStep3Documents(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= PASO 1 =================
  Widget _buildStep1Personal() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                        ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _imageFile == null ? const Icon(Icons.person, size: 50, color: Colors.grey) : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    onTap: () => _showImageSourceActionSheet(isProfile: true),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF9D408),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, size: 18, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Completa tu información personal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nombre completo', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
            decoration: const InputDecoration(labelText: 'Número de teléfono', prefixIcon: Icon(Icons.phone_outlined), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Contraseña', prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _dniController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
            decoration: const InputDecoration(labelText: 'DNI', prefixIcon: Icon(Icons.badge_outlined), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _cityController,
            decoration: const InputDecoration(labelText: 'Ciudad', prefixIcon: Icon(Icons.location_city_outlined), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _isLoading ? null : _onNextPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF9D408),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.black)
                : Text(widget.initialRole == 'driver' ? 'Siguiente' : 'Registrarse', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
          ),
        ],
      ),
    );
  }

  // ================= PASO 2: INFORMACIÓN DEL VEHÍCULO =================
  Widget _buildStep2Vehicle() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            title: const Text('He leído y acepto los términos y condiciones', style: TextStyle(fontSize: 13)),
            value: _acceptedTerms,
            activeColor: const Color(0xFFF9D408),
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (val) => setState(() => _acceptedTerms = val ?? false),
          ),
          CheckboxListTile(
            title: const Text('He leído y acepto la política de privacidad', style: TextStyle(fontSize: 13)),
            value: _acceptedPrivacy,
            activeColor: const Color(0xFFF9D408),
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (val) => setState(() => _acceptedPrivacy = val ?? false),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _licenseController,
            decoration: const InputDecoration(labelText: 'Número de licencia', prefixIcon: Icon(Icons.card_membership), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 15),
          const Text('Tipo de vehículo', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9D408).withOpacity(0.2),
              border: Border.all(color: const Color(0xFFF9D408)),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Text('Mototaxi', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _brandController,
            decoration: const InputDecoration(labelText: 'Marca del vehículo', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _modelController,
            decoration: const InputDecoration(labelText: 'Modelo del vehículo', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _colorController,
                  decoration: const InputDecoration(labelText: 'Color', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _yearController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Año', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _plateController,
            decoration: const InputDecoration(labelText: 'Placa del vehículo', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 25),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _onPreviousPressed,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                  child: const Text('Anterior', style: TextStyle(color: Colors.black)),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton(
                  onPressed: _onNextPressed,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF9D408), padding: const EdgeInsets.symmetric(vertical: 15)),
                  child: const Text('Siguiente', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= PASO 3: DOCUMENTACIÓN =================
  Widget _buildStep3Documents() {
    final List<String> docTitles = [
      'DNI Frente',
      'DNI Reverso',
      'Foto Vehículo',
      'SOAT',
      'Tarjeta Propiedad',
      'Licencia de Conducir',
      'Antecedentes Policiales',
      'Antecedentes Penales'
    ];

    int uploadedCount = _documents.values.where((v) => v != null).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Sube fotos claras de todos los documentos requeridos. Sin estas imágenes no se podrá aprobar tu cuenta.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Documentos cargados: $uploadedCount/8', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 15),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.3,
            ),
            itemCount: 8,
            itemBuilder: (context, index) {
              final file = _documents[index];
              return GestureDetector(
                onTap: () => _showImageSourceActionSheet(isProfile: false, docIndex: index),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: Border.all(color: file != null ? Colors.green : Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                    image: file != null ? DecorationImage(image: FileImage(file), fit: BoxFit.cover) : null,
                  ),
                  child: file == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_a_photo, color: Colors.grey),
                            const SizedBox(height: 5),
                            Text(docTitles[index], textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        )
                      : Align(
                          alignment: Alignment.topRight,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            color: Colors.green,
                            child: const Icon(Icons.check, size: 16, color: Colors.white),
                          ),
                        ),
                ),
              );
            },
          ),
          const SizedBox(height: 25),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _onPreviousPressed,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                  child: const Text('Anterior', style: TextStyle(color: Colors.black)),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _onNextPressed,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF9D408), padding: const EdgeInsets.symmetric(vertical: 15)),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text('Registrarse', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}