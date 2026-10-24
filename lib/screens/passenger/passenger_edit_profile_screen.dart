import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_config.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';

/// Pantalla de edición de perfil para Pasajeros.
/// Adapta el formulario de datos a la identidad gráfica de MijanoDrive
/// (paleta sol/ink/cream, bordes redondeados y tipografía consistente).
class PassengerEditProfileScreen extends StatefulWidget {
  const PassengerEditProfileScreen({super.key});

  @override
  State<PassengerEditProfileScreen> createState() => _PassengerEditProfileScreenState();
}

class _PassengerEditProfileScreenState extends State<PassengerEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String _selectedCity = AppConfig.cities.first;

  File? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = AuthService.instance.currentUser;
    _nameController.text = user?.name ?? '';
    _phoneController.text = user?.phone ?? '';
    final savedCity = user?.city;
    _selectedCity = AppConfig.cities.firstWhere(
      (city) => city.toLowerCase() == savedCity?.toLowerCase(),
      orElse: () => AppConfig.cities.first,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No hay sesión de usuario activa.');
      }

      String? photoUrl = currentUser.photoUrl;
      if (_selectedImage != null) {
        photoUrl = await AuthService.instance.uploadProfileImage(
          currentUser.uid,
          _selectedImage!,
        );
      }

      final updatedUser = currentUser.copyWith(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        city: _selectedCity,
        photoUrl: photoUrl ?? currentUser.photoUrl,
      );

      await FirestoreService.instance.saveUser(updatedUser);
      AuthService.instance.currentUser = updatedUser;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: MijanoTheme.ink,
          content: Text(
            '¡Perfil actualizado correctamente!',
            style: TextStyle(color: MijanoTheme.sol, fontWeight: FontWeight.bold),
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: MijanoTheme.signal,
          content: Text('Error al actualizar el perfil: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Editar Perfil',
          style: TextStyle(fontWeight: FontWeight.w900, color: MijanoTheme.ink),
        ),
        backgroundColor: MijanoTheme.sol,
        elevation: 0,
        iconTheme: const IconThemeData(color: MijanoTheme.ink),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: MijanoTheme.ink),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),

                    // Avatar con insignia interactiva para cambiar foto
                    Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: MijanoTheme.ink, width: 3),
                            ),
                            child: CircleAvatar(
                              radius: 55,
                              backgroundColor: MijanoTheme.cream,
                              backgroundImage: _selectedImage != null
                                  ? FileImage(_selectedImage!)
                                  : (user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                                      ? NetworkImage(user.photoUrl!)
                                      : null) as ImageProvider?,
                              child: (_selectedImage == null &&
                                      (user?.photoUrl == null || user!.photoUrl!.isEmpty))
                                  ? const Icon(Icons.person, size: 60, color: MijanoTheme.ink)
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: InkWell(
                              onTap: () => _pickImage(ImageSource.camera),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: MijanoTheme.sol,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: MijanoTheme.ink, width: 2),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: MijanoTheme.ink,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        'Toca el icono para cambiar tu foto',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Campo Nombre Completo
                    _buildLabel('Nombre completo'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: MijanoTheme.ink),
                      decoration: InputDecoration(
                        hintText: 'Ingresa tu nombre y apellido',
                        prefixIcon: const Icon(Icons.person_outline, color: MijanoTheme.ink),
                        fillColor: MijanoTheme.cream,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: MijanoTheme.ink, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: MijanoTheme.ink.withValues(alpha: 0.3), width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: MijanoTheme.ink, width: 2.5),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor ingresa tu nombre completo';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // Campo Teléfono
                    _buildLabel('Número de teléfono'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: MijanoTheme.ink),
                      decoration: InputDecoration(
                        hintText: '+51 987 654 321',
                        prefixIcon: const Icon(Icons.phone_outlined, color: MijanoTheme.ink),
                        fillColor: MijanoTheme.cream,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: MijanoTheme.ink, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: MijanoTheme.ink.withValues(alpha: 0.3), width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: MijanoTheme.ink, width: 2.5),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor ingresa un número de teléfono';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // Campo Ciudad
                    _buildLabel('Ciudad'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCity,
                      validator: (value) => value == null ? 'Selecciona una ciudad' : null,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: MijanoTheme.ink),
                      decoration: InputDecoration(
                        labelText: 'Ciudad',
                        prefixIcon: const Icon(Icons.location_city_outlined, color: MijanoTheme.ink),
                        fillColor: MijanoTheme.cream,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: MijanoTheme.ink, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: MijanoTheme.ink.withValues(alpha: 0.3), width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: MijanoTheme.ink, width: 2.5),
                        ),
                      ),
                      items: AppConfig.cities
                          .map((city) => DropdownMenuItem(value: city, child: Text(city)))
                          .toList(),
                      onChanged: (city) {
                        if (city != null) setState(() => _selectedCity = city);
                      },
                    ),
                    const SizedBox(height: 32),

                    // Botón Guardar Cambios
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MijanoTheme.ink,
                        foregroundColor: MijanoTheme.sol,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      onPressed: _saveProfile,
                      child: const Text(
                        'Guardar Cambios',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: MijanoTheme.ink,
      ),
    );
  }
}
