import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mijano_drive_app/models/user_model.dart' as app_user;
import 'package:mijano_drive_app/services/auth_service.dart';
import 'package:mijano_drive_app/services/document_service.dart';
import 'package:mijano_drive_app/services/firestore_service.dart';

class PassengerDniVerificationScreen extends StatefulWidget {
  final app_user.User? user;

  const PassengerDniVerificationScreen({super.key, this.user});

  @override
  State<PassengerDniVerificationScreen> createState() =>
      _PassengerDniVerificationScreenState();
}

class _PassengerDniVerificationScreenState
    extends State<PassengerDniVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dniController = TextEditingController();
  final _nameController = TextEditingController();

  File? _frontImage;
  File? _backImage;

  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  String? _dniError;
  bool _isCheckingDni = false;
  Timer? _dniDebounce;

  @override
  void initState() {
    super.initState();
    final u = widget.user ?? AuthService.instance.currentUser;
    if (u != null) {
      _nameController.text = u.name ?? '';
      if (u.dni != null && u.dni!.isNotEmpty) {
        _dniController.text = u.dni!;
      }
    }
  }

  @override
  void dispose() {
    _dniDebounce?.cancel();
    _dniController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onDniChanged(String value) {
    _dniDebounce?.cancel();
    final trimmed = value.trim();
    if (_dniError != null) {
      setState(() => _dniError = null);
    }
    if (trimmed.length != 8) {
      if (_isCheckingDni) setState(() => _isCheckingDni = false);
      return;
    }

    setState(() => _isCheckingDni = true);
    _dniDebounce = Timer(const Duration(milliseconds: 300), () async {
      final taken = await FirestoreService.instance.isDniTaken(trimmed);
      if (!mounted || _dniController.text.trim() != trimmed) return;
      setState(() {
        _isCheckingDni = false;
        _dniError = taken ? 'Este DNI ya está registrado.' : null;
      });
    });
  }

  Future<void> _pickImage(bool isFront, ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked != null) {
        setState(() {
          if (isFront) {
            _frontImage = File(picked.path);
          } else {
            _backImage = File(picked.path);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al capturar la imagen: $e')),
        );
      }
    }
  }

  void _showImageSourceSheet(bool isFront) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.black87),
                title: const Text('Tomar foto con la cámara',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(isFront, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.black87),
                title: const Text('Elegir de la galería',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(isFront, ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitVerification() async {
    if (_frontImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, toma la foto frontal de tu DNI')),
      );
      return;
    }

    if (_backImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, toma la foto posterior de tu DNI')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_dniError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_dniError!)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw Exception('Usuario no autenticado.');
      }

      final dni = _dniController.text.trim();
      final name = _nameController.text.trim();

      // Verificar si el DNI ya fue tomado
      final taken = await FirestoreService.instance.isDniTaken(dni);
      if (taken) {
        setState(() {
          _isLoading = false;
          _dniError = 'Este DNI ya está registrado en otra cuenta.';
        });
        return;
      }

      // Subir fotos a Storage
      final frontUrl = await DocumentService.instance.uploadPassengerDniPhoto(
        uid: uid,
        side: 'front',
        imageFile: _frontImage!,
      );

      final backUrl = await DocumentService.instance.uploadPassengerDniPhoto(
        uid: uid,
        side: 'back',
        imageFile: _backImage!,
      );

      // Guardar en Firestore users/{uid}
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final batch = FirebaseFirestore.instance.batch();

      batch.update(userRef, {
        'dni': dni,
        'name': name,
        'dniFrontUrl': frontUrl,
        'dniBackUrl': backUrl,
        'dniStatus': 'completado',
        'documents.dniFront': frontUrl,
        'documents.dniBack': backUrl,
        'documents.dniStatus': 'completado',
        'dniVerifiedAt': FieldValue.serverTimestamp(),
      });

      // Registrar en índice de DNI
      final dniIndexRef =
          FirebaseFirestore.instance.collection('dni_index').doc(dni);
      batch.set(dniIndexRef, {
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // Actualizar usuario en sesión
      final auth = AuthService.instance;
      if (auth.currentUser != null) {
        auth.currentUser = auth.currentUser!.copyWith(
          dni: dni,
          name: name,
        );
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Documento guardado con éxito! Bienvenido a Mijano Drive.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar documento: $e')),
      );
    }
  }

  void _skipForNow() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Omitir por ahora?'),
        content: const Text(
          'Puedes continuar a la app ahora y completar la verificación de tu DNI más adelante desde tu perfil.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Completar ahora', style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF9D408),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
            },
            child: const Text('Continuar al Inicio',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9D408),
        elevation: 0,
        title: const Text(
          'Verificación de Identidad',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _skipForNow,
            child: const Text(
              'Omitir',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Banner de Bienvenida ---
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9C4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF9D408), width: 1.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF9D408),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.badge_outlined,
                          color: Colors.black, size: 28),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¡Bienvenido a Mijano Drive!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Para brindarte viajes seguros y confiables, completa tu información tomando una foto clara a tu DNI por ambos lados.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // --- Sección Fotos DNI ---
              const Text(
                'Fotos de tu DNI',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Asegúrate de que la foto sea legible y sin reflejos de luz.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildDocCard(
                      title: 'Lado Frontal (Anverso)',
                      imageFile: _frontImage,
                      onTap: () => _showImageSourceSheet(true),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildDocCard(
                      title: 'Lado Posterior (Reverso)',
                      imageFile: _backImage,
                      onTap: () => _showImageSourceSheet(false),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // --- Sección Reconocimiento / Datos del DNI ---
              const Text(
                'Confirma tus Datos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Verifica que el número y nombre coincidan con tu documento.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _dniController,
                keyboardType: TextInputType.number,
                maxLength: 8,
                onChanged: _onDniChanged,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                validator: (v) {
                  if (v == null || v.trim().length != 8) {
                    return 'Ingresa exactamente 8 dígitos del DNI';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Número de DNI',
                  hintText: '12345678',
                  prefixIcon: const Icon(Icons.pin_outlined),
                  counterText: '',
                  errorText: _dniError,
                  suffixIcon: _isCheckingDni
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Ingresa tus nombres y apellidos';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Nombres y Apellidos completos',
                  hintText: 'Como figura en tu DNI',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // --- Botón Guardar ---
              ElevatedButton(
                onPressed: _isLoading ? null : _submitVerification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF9D408),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        'Guardar y Empezar a Viajar',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: _isLoading ? null : _skipForNow,
                child: const Text(
                  'Completar más tarde',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocCard({
    required String title,
    required File? imageFile,
    required VoidCallback onTap,
  }) {
    final hasImage = imageFile != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: hasImage ? Colors.black87 : const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasImage ? const Color(0xFFF9D408) : Colors.grey.shade300,
            width: hasImage ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage)
                Image.file(
                  imageFile,
                  fit: BoxFit.cover,
                )
              else
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 34,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Toca para subir',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              if (hasImage)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF9D408),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.black,
                    ),
                  ),
                ),
              if (hasImage)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.6),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
