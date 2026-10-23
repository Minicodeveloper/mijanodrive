import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_config.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/validators.dart';
import '../../theme.dart';
import '../../widgets/mijano_icon.dart';

/// Configuración obligatoria del perfil (primera vez):
/// DNI + RENIEC autollenado, selfie en vivo, ciudad detectada, rol.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _dniController = TextEditingController();
  final _nameController = TextEditingController();
  String _city = AppConfig.cities.first;
  UserRole _role = UserRole.passenger;
  String? _selfiePath;
  bool _saving = false;

  final _auth = AuthService.instance;

  @override
  void dispose() {
    _dniController.dispose();
    _nameController.dispose();
    super.dispose();
  }



  Future<void> _takeSelfie() async {
    try {
      final picker = ImagePicker();
      final img = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 800,
      );
      if (img != null) setState(() => _selfiePath = img.path);
    } catch (_) {
      _snack('No se pudo abrir la cámara');
    }
  }

  Future<void> _save() async {
    final dniVal = Validators.validateDni(_dniController.text);
    if (dniVal != null) {
      _snack(dniVal);
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      _snack('Completa tu nombre');
      return;
    }

    setState(() => _saving = true);
    
    final isTaken = await FirestoreService.instance.isDniTaken(_dniController.text.trim());
    if (isTaken) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Este DNI ya está registrado en otra cuenta.');
      return;
    }

    try {
      await _auth.completeProfile(
        name: _nameController.text.trim(),
        dni: _dniController.text.trim(),
        city: _city,
        role: _role,
        photoUrl: _selfiePath,
      );
      if (_role == UserRole.driver && _auth.currentUser != null) {
        await FirestoreService.instance.setDriverAvailability(_auth.currentUser!.uid, false);
      }
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pushNamedAndRemoveUntil(
        _role == UserRole.driver ? '/driver' : '/home',
        (r) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Completa tu perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            // Selfie
            Center(
              child: GestureDetector(
                onTap: _takeSelfie,
                child: CircleAvatar(
                  radius: 56,
                  backgroundColor: MijanoTheme.cream,
                  backgroundImage: _selfiePath != null
                      ? FileImage(File(_selfiePath!))
                      : null,
                  child: _selfiePath == null
                      ? const Icon(Icons.add_a_photo,
                          size: 34, color: MijanoTheme.ink)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text('Tómate una selfie en vivo',
                  style: TextStyle(color: Colors.black54)),
            ),
            const SizedBox(height: 24),
            // DNI
            TextField(
              controller: _dniController,
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: const InputDecoration(
                labelText: 'Número de DNI',
                prefixIcon: Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombres y apellidos',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            // Ciudad
            DropdownButtonFormField<String>(
              initialValue: _city,
              decoration: const InputDecoration(
                labelText: 'Ciudad',
                prefixIcon: Icon(Icons.location_city),
              ),
              items: AppConfig.cities
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _city = v ?? _city),
            ),
            const SizedBox(height: 16),
            // Rol
            const Text('¿Cómo usarás Mijano Drive?',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: _roleTile(
                      UserRole.passenger, Icons.person, 'Pasajero')),
              const SizedBox(width: 10),
              Expanded(
                  child: _roleTile(
                      UserRole.driver, Icons.two_wheeler, 'Conductor')),
            ]),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: MijanoTheme.sol))
                  : const Text('Guardar y continuar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleTile(UserRole role, IconData icon, String label) {
    final selected = _role == role;
    return GestureDetector(
      onTap: () => setState(() => _role = role),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected ? MijanoTheme.sol : MijanoTheme.cream,
          border: Border.all(color: MijanoTheme.ink, width: 2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: [
          MijanoIcon(icon, size: 34, color: MijanoTheme.ink),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: MijanoTheme.ink)),
        ]),
      ),
    );
  }
}
