import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import 'passenger_edit_profile_screen.dart';

/// Pantalla completa de Perfil del Pasajero.
/// Recepta la jerarquía visual de "Mi Perfil" (capturas de referencia):
/// Cabecera con avatar y 3 métricas, bloque de datos personales,
/// opciones de ajustes y botón inferior de cierre de sesión.
class PassengerProfileScreen extends StatefulWidget {
  const PassengerProfileScreen({super.key});

  @override
  State<PassengerProfileScreen> createState() => _PassengerProfileScreenState();
}

class _PassengerProfileScreenState extends State<PassengerProfileScreen> {
  User? _user;
  int _tripCount = 0;
  int _completedCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final currentAuthUser = fb.FirebaseAuth.instance.currentUser;
    if (currentAuthUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final cachedUser = AuthService.instance.currentUser;
    if (mounted && cachedUser != null) {
      setState(() => _user = cachedUser);
    }

    try {
      // 1. Precargar usuario desde la colección 'users' de Firestore
      final freshUser = await FirestoreService.instance.getUser(currentAuthUser.uid);
      if (freshUser != null && mounted) {
        setState(() {
          _user = freshUser;
          AuthService.instance.currentUser = freshUser;
        });
      }

      // 2. Precargar métricas de viajes del pasajero
      final tripsSnapshot = await FirebaseFirestore.instance
          .collection('trips')
          .where('passengerId', isEqualTo: currentAuthUser.uid)
          .get();

      final trips = tripsSnapshot.docs;
      final total = trips.length;
      final completed = trips.where((doc) {
        final status = doc.data()['status'];
        return status == 'completed' || status == 'finalized';
      }).length;

      if (mounted) {
        setState(() {
          _tripCount = total;
          _completedCount = completed;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 85,
    );

    if (pickedFile == null || _user == null) return;

    try {
      final downloadUrl = await AuthService.instance.uploadProfileImage(
        _user!.uid,
        File(pickedFile.path),
      );

      if (downloadUrl != null) {
        final updatedUser = _user!.copyWith(photoUrl: downloadUrl);
        await FirestoreService.instance.saveUser(updatedUser);
        AuthService.instance.currentUser = updatedUser;
        if (mounted) {
          setState(() => _user = updatedUser);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: MijanoTheme.ink,
              content: Text(
                'Foto de perfil actualizada correctamente',
                style: TextStyle(color: MijanoTheme.sol, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: MijanoTheme.signal,
            content: Text('Error al actualizar la foto: $e'),
          ),
        );
      }
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Wrap(
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: MijanoTheme.cream,
                    child: Icon(Icons.photo_library, color: MijanoTheme.ink),
                  ),
                  title: const Text(
                    'Galería de fotos',
                    style: TextStyle(fontWeight: FontWeight.bold, color: MijanoTheme.ink),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: MijanoTheme.cream,
                    child: Icon(Icons.photo_camera, color: MijanoTheme.ink),
                  ),
                  title: const Text(
                    'Tomar foto con la cámara',
                    style: TextStyle(fontWeight: FontWeight.bold, color: MijanoTheme.ink),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatPhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return 'No registrado';
    final clean = phone.trim();
    if (clean.startsWith('+')) return clean;
    return '+51 $clean';
  }

  String get _completionRate {
    if (_tripCount == 0) return '100%';
    final pct = ((_completedCount / _tripCount) * 100).round();
    return '$pct%';
  }

  @override
  Widget build(BuildContext context) {
    final user = _user ?? AuthService.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9D408),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Mi Perfil',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: _isLoading && user == null
          ? const Center(child: CircularProgressIndicator(color: MijanoTheme.ink))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. CABECERA Y RESUMEN SUPERIOR (Captura 1)
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Column(
                      children: [
                        // Avatar circular con selector de cámara integrado
                        Center(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 52,
                                backgroundColor: Colors.grey[300],
                                backgroundImage: user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                                    ? NetworkImage(user.photoUrl!)
                                    : null,
                                child: (user?.photoUrl == null || user!.photoUrl!.isEmpty)
                                    ? const Icon(Icons.person, size: 52, color: Colors.black54)
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: InkWell(
                                  onTap: _showImagePickerOptions,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9D408),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.black, width: 1.5),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      color: Colors.black,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Nombre del pasajero
                        Text(
                          user?.name != null && user!.name!.isNotEmpty
                              ? user.name!
                              : 'Usuario',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Rol adaptado
                        Text(
                          'Pasajero',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Fila horizontal de 3 métricas destacadas
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatItem('$_tripCount', 'Viajes'),
                            _buildStatItem('Activo', 'Estado'),
                            _buildStatItem(_completionRate, 'Completados'),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 2. BLOQUE DE DATOS PERSONALES (Capturas 1 y 2)
                  Container(
                    color: Colors.white,
                    child: Column(
                      children: [
                        _buildDataTile(
                          icon: Icons.phone,
                          title: 'Teléfono',
                          value: _formatPhone(user?.phone),
                        ),
                        const Divider(height: 1, indent: 64, thickness: 0.8),
                        _buildDataTile(
                          icon: Icons.email_outlined,
                          title: 'Correo',
                          value: user?.email != null && user!.email!.isNotEmpty
                              ? user.email!
                              : 'No registrado',
                        ),
                        const Divider(height: 1, indent: 64, thickness: 0.8),
                        _buildDataTile(
                          icon: Icons.badge_outlined,
                          title: 'DNI',
                          value: user?.dni != null && user!.dni!.isNotEmpty
                              ? user.dni!
                              : 'No registrado',
                        ),
                        const Divider(height: 1, indent: 64, thickness: 0.8),
                        _buildDataTile(
                          icon: Icons.location_on_outlined,
                          title: 'Ciudad',
                          value: user?.city != null && user!.city!.isNotEmpty
                              ? user.city!
                              : 'Lima',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 3. OPCIONES DE NAVEGACIÓN Y AJUSTES (Captura 2)
                  Container(
                    color: Colors.white,
                    child: Column(
                      children: [
                        _buildNavTile(
                          icon: Icons.edit,
                          title: 'Editar perfil',
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PassengerEditProfileScreen(),
                              ),
                            );
                            if (result == true) {
                              _loadUserData();
                            }
                          },
                        ),
                        const Divider(height: 1, indent: 64, thickness: 0.8),
                        _buildNavTile(
                          icon: Icons.security,
                          title: 'Seguridad',
                          onTap: _showSecurityDialog,
                        ),
                        const Divider(height: 1, indent: 64, thickness: 0.8),
                        _buildNavTile(
                          icon: Icons.notifications,
                          title: 'Notificaciones',
                          onTap: _showNotificationsDialog,
                        ),
                        const Divider(height: 1, indent: 64, thickness: 0.8),
                        _buildNavTile(
                          icon: Icons.info,
                          title: 'Acerca de',
                          onTap: _showAboutDialog,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 4. CIERRE DE SESIÓN (Captura 2)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5733),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _showLogoutConfirmation,
                      child: const Text(
                        'Cerrar sesión',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  /// Métrica destacada en dorado (#F9D408) con etiqueta en gris
  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF9D408),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Fila de datos personales
  Widget _buildDataTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF333333), size: 24),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
      subtitle: Text(
        value,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  /// Opción de navegación con chevron derecho
  Widget _buildNavTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF333333), size: 24),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        size: 22,
        color: Colors.black45,
      ),
      onTap: onTap,
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Cerrar sesión',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5733),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await fb.FirebaseAuth.instance.signOut();
              await AuthService.instance.signOut();
              if (!mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            },
            child: const Text('Cerrar sesión', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSecurityDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Seguridad de la Cuenta', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Opciones de autenticación y protección de tu perfil:'),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.fingerprint, color: MijanoTheme.ink),
              title: const Text('Autenticación biométrica'),
              subtitle: Text(
                _user?.biometricEnabled == true ? 'Habilitada' : 'Deshabilitada',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Switch(
                value: _user?.biometricEnabled ?? false,
                activeThumbColor: MijanoTheme.sol,
                onChanged: (val) async {
                  if (_user == null) return;
                  final updated = _user!.copyWith(biometricEnabled: val);
                  await FirestoreService.instance.saveUser(updated);
                  AuthService.instance.currentUser = updated;
                  if (!mounted) return;
                  setState(() => _user = updated);
                  if (dialogCtx.mounted) {
                    Navigator.pop(dialogCtx);
                  }
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cerrar', style: TextStyle(color: MijanoTheme.ink, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Notificaciones', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Recibirás alertas en tiempo real sobre la asignación de tu conductor, llegada del motokar y recibos de viaje.',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MijanoTheme.ink,
              foregroundColor: MijanoTheme.sol,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Aceptar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Acerca de Mijano Drive', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mijano Drive v1.0.1',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'La plataforma formal de motokar y transporte rápido y seguro para la región San Martín, Perú.',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Entendido', style: TextStyle(color: MijanoTheme.ink, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
