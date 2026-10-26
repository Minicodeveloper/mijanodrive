import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mijano_drive_app/config/app_config.dart';
import 'package:mijano_drive_app/models/user_model.dart';
import 'package:mijano_drive_app/services/auth_service.dart';
import 'package:mijano_drive_app/services/document_service.dart';
import 'package:mijano_drive_app/services/firestore_service.dart';
import 'package:mijano_drive_app/screens/driver/pending_account_screen.dart';
import 'package:mijano_drive_app/utils/validators.dart';

class RegisterScreen extends StatefulWidget {
  final String initialRole; 

  const RegisterScreen({super.key, required this.initialRole});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  
  int _currentStep = 0;
  final PageController _pageController = PageController();

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dniController = TextEditingController();
  String _selectedCity = AppConfig.cities.first;
  final _birthDateController = TextEditingController();
  final _ageController = TextEditingController();
  DateTime? _selectedBirthDate;
  File? _imageFile;

  
  final _licenseController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _colorController = TextEditingController();
  final _yearController = TextEditingController();
  final _plateController = TextEditingController();
 
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;

  
  final Map<int, File?> _documents = {
    0: null,
    1: null,
    2: null,
    3: null,
    4: null,
    5: null,
  };

  final Map<int, String> _docKeyMap = {
    0: 'docFront',
    1: 'docBack',
    2: 'vehiclePhoto',
    3: 'soatPhoto',
    4: 'propertyCardPhoto',
    5: 'licensedDocument',
  };

  late String _selectedRole;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  final _auth = AuthService.instance;

  String? _phoneDuplicateError;
  String? _dniDuplicateError;
  String? _licenseDuplicateError;
  String? _plateDuplicateError;

  bool _checkingPhone = false;
  bool _checkingDni = false;
  bool _checkingLicense = false;
  bool _checkingPlate = false;

  Timer? _phoneDebounce;
  Timer? _dniDebounce;
  Timer? _licenseDebounce;
  Timer? _plateDebounce;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
  }

  @override
  void dispose() {
    _phoneDebounce?.cancel();
    _dniDebounce?.cancel();
    _licenseDebounce?.cancel();
    _plateDebounce?.cancel();
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _dniController.dispose();
    _birthDateController.dispose();
    _ageController.dispose();
    _licenseController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _yearController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  void _onPhoneChanged(String value) {
    _phoneDebounce?.cancel();
    final trimmed = value.trim();
    if (_phoneDuplicateError != null) {
      setState(() => _phoneDuplicateError = null);
    }
    if (trimmed.length != 9) {
      if (_checkingPhone) setState(() => _checkingPhone = false);
      return;
    }
    setState(() => _checkingPhone = true);
    _phoneDebounce = Timer(const Duration(milliseconds: 300), () async {
      final current = _phoneController.text.trim();
      if (current != trimmed) return;
      final taken = await _auth.isPhoneRegistered(current);
      if (!mounted || _phoneController.text.trim() != current) return;
      setState(() {
        _checkingPhone = false;
        _phoneDuplicateError =
            taken ? 'Este número ya está registrado.' : null;
      });
      if (taken) {
        _showSnackBar('Este número ya está registrado.');
      }
    });
  }

  void _onDniChanged(String value) {
    _dniDebounce?.cancel();
    final trimmed = value.trim();
    if (_dniDuplicateError != null) {
      setState(() => _dniDuplicateError = null);
    }
    if (trimmed.length != 8) {
      if (_checkingDni) setState(() => _checkingDni = false);
      return;
    }
    setState(() => _checkingDni = true);
    _dniDebounce = Timer(const Duration(milliseconds: 300), () async {
      final current = _dniController.text.trim();
      if (current != trimmed) return;
      final taken = await FirestoreService.instance.isDniTaken(current);
      if (!mounted || _dniController.text.trim() != current) return;
      setState(() {
        _checkingDni = false;
        _dniDuplicateError = taken ? 'Este DNI ya está registrado.' : null;
      });
      if (taken) {
        _showSnackBar('Este DNI ya está registrado.');
      }
    });
  }

  void _onLicenseChanged(String value) {
    _licenseDebounce?.cancel();
    final trimmed = value.trim();
    if (_licenseDuplicateError != null) {
      setState(() => _licenseDuplicateError = null);
    }
    if (trimmed.length < 6) {
      if (_checkingLicense) setState(() => _checkingLicense = false);
      return;
    }
    setState(() => _checkingLicense = true);
    _licenseDebounce = Timer(const Duration(milliseconds: 350), () async {
      final current = _licenseController.text.trim();
      if (current != trimmed) return;
      final taken = await _auth.isLicenseRegistered(current);
      if (!mounted || _licenseController.text.trim() != current) return;
      setState(() {
        _checkingLicense = false;
        _licenseDuplicateError =
            taken ? 'Este número de licencia ya está registrado.' : null;
      });
      if (taken) {
        _showSnackBar('Este número de licencia ya está registrado.');
      }
    });
  }

  void _onPlateChanged(String value) {
    _plateDebounce?.cancel();
    final trimmed = value.trim();
    if (_plateDuplicateError != null) {
      setState(() => _plateDuplicateError = null);
    }
    if (trimmed.length < 5) {
      if (_checkingPlate) setState(() => _checkingPlate = false);
      return;
    }
    setState(() => _checkingPlate = true);
    _plateDebounce = Timer(const Duration(milliseconds: 350), () async {
      final current = _plateController.text.trim();
      if (current != trimmed) return;
      final taken = await _auth.isPlateRegistered(current);
      if (!mounted || _plateController.text.trim() != current) return;
      setState(() {
        _checkingPlate = false;
        _plateDuplicateError =
            taken ? 'Esta placa de vehículo ya está registrada.' : null;
      });
      if (taken) {
        _showSnackBar('Esta placa de vehículo ya está registrada.');
      }
    });
  }

  /// Abre directamente la cámara para tomar la foto de perfil (obligatoria).
  Future<void> _takeProfilePhoto() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  /// Selecciona imagen desde galería (solo para documentos del conductor).
  Future<void> _pickDocumentImage(int docIndex) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      setState(() => _documents[docIndex] = File(pickedFile.path));
    }
  }

  /// Muestra opciones de galería/cámara solo para subir documentos.
  void _showImageSourceActionSheet({required int docIndex}) {
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
                  _pickDocumentImage(docIndex);
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
                    setState(() => _documents[docIndex] = File(pickedFile.path));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectBirthDate(BuildContext context) async {
    final now = DateTime.now();
    final defaultInitial = DateTime(now.year - 18, now.month, now.day);
    final initial = _selectedBirthDate ?? defaultInitial;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? initial : now,
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Selecciona tu fecha de nacimiento',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFF9D408),
              onPrimary: Colors.black,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedBirthDate = picked;
        final day = picked.day.toString().padLeft(2, '0');
        final month = picked.month.toString().padLeft(2, '0');
        _birthDateController.text = '$day/$month/${picked.year}';

        // Cálculo automático de la edad
        int calculatedAge = now.year - picked.year;
        if (now.month < picked.month || (now.month == picked.month && now.day < picked.day)) {
          calculatedAge--;
        }
        _ageController.text = '$calculatedAge';
      });
    }
  }

  bool _validateStep1() {
    if (_imageFile == null) {
      _showSnackBar('Toma tu foto de perfil para continuar');
      return false;
    }
    if (!_formKey.currentState!.validate()) {
      return false;
    }
    return true;
  }

  // Validaciones del Paso 2 con límites y campos obligatorios
  bool _validateStep2() {
    if (!_acceptedTerms || !_acceptedPrivacy) {
      _showSnackBar('Debes aceptar los términos y condiciones y la política de privacidad');
      return false;
    }
    
    final license = _licenseController.text.trim();
    if (license.isEmpty || license.length < 8) {
      _showSnackBar('Ingresa un número de licencia válido (mínimo 8 caracteres)');
      return false;
    }

    if (_brandController.text.trim().isEmpty ||
        _modelController.text.trim().isEmpty ||
        _colorController.text.trim().isEmpty ||
        _yearController.text.trim().isEmpty) {
      _showSnackBar('Completa todos los datos del vehículo');
      return false;
    }

    final plate = _plateController.text.trim();
    if (plate.isEmpty || plate.length < 6) {
      _showSnackBar('Ingresa una placa válida (mínimo 6 caracteres)');
      return false;
    }

    return true;
  }

  
  void _onNextPressed() async {
    if (_currentStep == 0) {
      if (!_validateStep1()) return;
      
      setState(() => _isLoading = true);

      // Validar DNI existente y Teléfono existente
      final dniText = _dniController.text.trim();
      final phoneText = _phoneController.text.trim();

      final dniTaken = await FirestoreService.instance.isDniTaken(dniText);
      final phoneTaken = await _auth.isPhoneRegistered(phoneText);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _phoneDuplicateError =
            phoneTaken ? 'Este número ya está registrado.' : null;
        _dniDuplicateError =
            dniTaken ? 'Este DNI ya está registrado.' : null;
      });
      
      if (phoneTaken && dniTaken) {
        _showAlert(
          'Datos ya registrados',
          'Este número de teléfono y este DNI ya están registrados.',
        );
        return;
      }

      if (phoneTaken) {
        _showAlert('Número ya registrado', 'Este número ya está registrado.');
        return;
      }

      if (dniTaken) {
        _showAlert('DNI ya registrado', 'Este DNI ya está registrado.');
        return;
      }

      if (_selectedRole == 'passenger') {
        _register(); 
      } else {
        setState(() => _currentStep = 1);
        _pageController.animateToPage(1, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
    } else if (_currentStep == 1) {
      if (!_validateStep2()) return;

      setState(() => _isLoading = true);

      // Validar Licencia existente y Placa existente en la base de datos
      final licenseText = _licenseController.text.trim();
      final plateText = _plateController.text.trim();

      final licenseTaken = await _auth.isLicenseRegistered(licenseText);
      final plateTaken = await _auth.isPlateRegistered(plateText);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _licenseDuplicateError =
            licenseTaken ? 'Este número de licencia ya está registrado.' : null;
        _plateDuplicateError =
            plateTaken ? 'Esta placa de vehículo ya está registrada.' : null;
      });

      if (licenseTaken && plateTaken) {
        _showAlert(
          'Datos ya registrados',
          'Este número de licencia y esta placa de vehículo ya están registrados.',
        );
        return;
      }

      if (licenseTaken) {
        _showAlert('Licencia ya registrada', 'Este número de licencia ya está registrado.');
        return;
      }

      if (plateTaken) {
        _showAlert('Placa ya registrada', 'Esta placa de vehículo ya está registrada.');
        return;
      }

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
    final dni = _dniController.text.trim();

    try {
      // Doble verificación antes de enviar cualquier SMS
      final phoneTaken = await _auth.isPhoneRegistered(phone);
      final dniTaken = await FirestoreService.instance.isDniTaken(dni);

      bool licenseTaken = false;
      bool plateTaken = false;
      if (_selectedRole == 'driver') {
        licenseTaken = await _auth.isLicenseRegistered(_licenseController.text.trim());
        plateTaken = await _auth.isPlateRegistered(_plateController.text.trim());
      }

      if (!mounted) return;
      if (phoneTaken || dniTaken || licenseTaken || plateTaken) {
        setState(() {
          _isLoading = false;
          _phoneDuplicateError =
              phoneTaken ? 'Este número ya está registrado.' : null;
          _dniDuplicateError =
              dniTaken ? 'Este DNI ya está registrado.' : null;
          _licenseDuplicateError =
              licenseTaken ? 'Este número de licencia ya está registrado.' : null;
          _plateDuplicateError =
              plateTaken ? 'Esta placa de vehículo ya está registrada.' : null;
        });

        if (phoneTaken && dniTaken) {
          _showAlert(
            'Datos ya registrados',
            'Este número de teléfono y este DNI ya están registrados.',
          );
        } else if (phoneTaken) {
          _showAlert('Número ya registrado', 'Este número ya está registrado.');
        } else if (dniTaken) {
          _showAlert('DNI ya registrado', 'Este DNI ya está registrado.');
        } else if (licenseTaken && plateTaken) {
          _showAlert(
            'Datos ya registrados',
            'Este número de licencia y esta placa de vehículo ya están registrados.',
          );
        } else if (licenseTaken) {
          _showAlert(
            'Licencia ya registrada',
            'Este número de licencia ya está registrado.',
          );
        } else if (plateTaken) {
          _showAlert(
            'Placa ya registrada',
            'Esta placa de vehículo ya está registrada.',
          );
        }
        return;
      }

      final (ok, msg) = await _auth.sendOtp(phone);

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Si Firebase devuelve un error interno o de demasiados intentos en el mensaje
      if (!ok && (msg.contains('Error code:39') || msg.contains('too-many-requests') || msg.contains('internal error'))) {
        _showSnackBar('Demasiados intentos con este número de celular. Por favor, inténtalo más tarde.');
      } else {
        _showSnackBar(msg);
      }

      if (ok) {
        _showOtpDialog();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      
      final errorStr = e.toString();
      if (errorStr.contains('Error code:39') || errorStr.contains('too-many-requests') || errorStr.contains('internal error')) {
        _showSnackBar('Demasiados intentos con este número de celular. Por favor, inténtalo más tarde.');
      } else {
        _showSnackBar('Ocurrió un error al enviar el código. Inténtalo de nuevo.');
      }
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
                password: _passwordController.text,
                phone: _phoneController.text.trim(),
                dni: _dniController.text.trim(),
                city: _selectedCity,
                role: roleEnum,
                birthDate: _selectedBirthDate,
                age: int.tryParse(_ageController.text.trim()),
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
                        } catch (e) {}
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

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF9D408)),
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
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
      child: Form(
        key: _formKey,
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
                    onTap: _takeProfilePhoto,
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
          const SizedBox(height: 6),
          Center(
            child: Text(
              _imageFile == null ? 'Foto obligatoria' : 'Foto lista',
              style: TextStyle(
                fontSize: 12,
                color: _imageFile == null ? Colors.red[400] : Colors.green[600],
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Completa tu información personal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextFormField(
            controller: _nameController,
            validator: Validators.validateName,
            decoration: const InputDecoration(labelText: 'Nombre completo', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            onChanged: _onPhoneChanged,
            validator: (v) => v == null || v.length != 9 ? 'Ingresa 9 dígitos válidos' : null,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
            decoration: InputDecoration(
              labelText: 'Número de teléfono',
              prefixIcon: const Icon(Icons.phone_outlined),
              errorText: _phoneDuplicateError,
              suffixIcon: _checkingPhone
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.validateEmail,
            decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            validator: Validators.validatePassword,
            decoration: const InputDecoration(labelText: 'Contraseña', prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: _dniController,
            keyboardType: TextInputType.number,
            onChanged: _onDniChanged,
            validator: (v) => v == null || v.length != 8 ? 'Ingresa exactamente 8 dígitos' : null,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
            decoration: InputDecoration(
              labelText: 'DNI',
              prefixIcon: const Icon(Icons.badge_outlined),
              errorText: _dniDuplicateError,
              suffixIcon: _checkingDni
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            initialValue: _selectedCity,
            validator: (value) => value == null ? 'Ciudad es obligatoria' : null,
            decoration: const InputDecoration(labelText: 'Ciudad', prefixIcon: Icon(Icons.location_city_outlined), border: OutlineInputBorder()),
            items: AppConfig.cities
                .map((city) => DropdownMenuItem(value: city, child: Text(city)))
                .toList(),
            onChanged: (city) {
              if (city != null) setState(() => _selectedCity = city);
            },
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: _birthDateController,
            readOnly: true,
            onTap: () => _selectBirthDate(context),
            validator: (v) => v == null || v.trim().isEmpty ? 'Selecciona tu fecha de nacimiento' : null,
            decoration: const InputDecoration(
              labelText: 'Fecha de nacimiento',
              hintText: 'DD/MM/AAAA',
              prefixIcon: Icon(Icons.calendar_month_outlined),
              suffixIcon: Icon(Icons.calendar_today, size: 18),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: _ageController,
            readOnly: true,
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'La edad es obligatoria';
              final ageNum = int.tryParse(v.trim());
              if (ageNum == null) return 'Edad no válida';
              if (widget.initialRole == 'driver' && ageNum < 18) {
                return 'Debes tener al menos 18 años para ser conductor';
              }
              if (ageNum < 14) {
                return 'Debes tener al menos 14 años';
              }
              return null;
            },
            decoration: const InputDecoration(
              labelText: 'Edad',
              prefixIcon: Icon(Icons.cake_outlined),
              suffixText: 'años',
              border: OutlineInputBorder(),
            ),
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
            maxLength: 10,
            textCapitalization: TextCapitalization.characters,
            onChanged: _onLicenseChanged,
            decoration: InputDecoration(
              labelText: 'Número de licencia', 
              prefixIcon: const Icon(Icons.card_membership), 
              errorText: _licenseDuplicateError,
              suffixIcon: _checkingLicense
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              border: const OutlineInputBorder(),
              counterText: '',
            ),
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
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                  decoration: const InputDecoration(labelText: 'Año', border: OutlineInputBorder(), counterText: ''),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _plateController,
            maxLength: 7,
            textCapitalization: TextCapitalization.characters,
            onChanged: _onPlateChanged,
            decoration: InputDecoration(
              labelText: 'Placa del vehículo', 
              errorText: _plateDuplicateError,
              suffixIcon: _checkingPlate
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              border: const OutlineInputBorder(),
              counterText: '',
            ),
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
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Text('Siguiente', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
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
            child: Text('Documentos cargados: $uploadedCount/6', style: const TextStyle(fontWeight: FontWeight.bold)),
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
            itemCount: docTitles.length,
            itemBuilder: (context, index) {
              final file = _documents[index];
              return GestureDetector(
                onTap: () => _showImageSourceActionSheet(docIndex: index),
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
                            Text(
                              docTitles[index], 
                              textAlign: TextAlign.center, 
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        )
                      : Align(
                          alignment: Alignment.topRight,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(8),
                                bottomLeft: Radius.circular(8),
                              ),
                            ),
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
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
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
