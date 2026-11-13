import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../passenger/passenger_edit_profile_screen.dart';
import '../driver/driver_vehicle_config_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _showEditEmergencyPhoneDialog(BuildContext context, User user) async {
    final controller = TextEditingController(text: user.emergencyPhone ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.contact_phone, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Número de Emergencia', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ingresa el número de celular de un familiar o contacto de confianza. Si presionas S.O.S., la central de control lo llamará inmediatamente.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.phone,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Número de celular',
                  hintText: 'Ej: 987654321',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Ingresa un número de teléfono';
                  }
                  if (val.trim().length < 6) {
                    return 'Ingresa un número válido';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final phone = controller.text.trim();
              Navigator.pop(ctx);

              final updated = user.copyWith(emergencyPhone: phone);
              await FirestoreService.instance.saveUser(updated);
              AuthService.instance.currentUser = updated;

              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('¡Número de emergencia guardado correctamente!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF9D408),
              foregroundColor: Colors.black,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService.instance;
    final firestoreService = FirestoreService.instance;
    final currentUid = authService.currentUser?.uid;

    if (currentUid == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFFF9D408),
          title: const Text('Mi Perfil', style: TextStyle(color: Colors.black)),
        ),
        body: const Center(child: Text('No hay una sesión activa')),
      );
    }

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
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: FutureBuilder<User?>(
        future: firestoreService.getUser(currentUid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || snapshot.data == null) {
            return const Center(child: Text('Error al cargar los datos del perfil'));
          }

          final User user = snapshot.data!;
          final String roleName = user.role == UserRole.driver ? 'Conductor' : 'Pasajero';

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile header
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: user.photoUrl != null && user.photoUrl!.isNotEmpty
                            ? NetworkImage(user.photoUrl!)
                            : null,
                        child: user.photoUrl == null || user.photoUrl!.isEmpty
                            ? const Icon(Icons.person, size: 50, color: Colors.black54)
                            : null,
                      ),
                      const SizedBox(height: 15),
                      Text(
                        user.name ?? 'Usuario Mijano',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        roleName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatItem('4.8', 'Calificación'),
                          _buildStatItem('127', 'Viajes'),
                          _buildStatItem('98%', 'Completados'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Contact info
                Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.phone),
                        title: const Text('Teléfono'),
                        subtitle: Text(user.phone),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.email),
                        title: const Text('Correo'),
                        subtitle: Text(user.email ?? 'No registrado'),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.card_giftcard),
                        title: const Text('DNI'),
                        subtitle: Text(user.dni ?? 'No registrado'),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.location_on),
                        title: const Text('Ciudad'),
                        subtitle: Text(user.city ?? 'Tarapoto'),
                      ),
                      if (user.role == UserRole.passenger) ...[
                        const Divider(),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.contact_phone, color: Colors.redAccent, size: 20),
                          ),
                          title: Row(
                            children: [
                              const Text('Número de emergencia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'S.O.S.',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            (user.emergencyPhone != null && user.emergencyPhone!.trim().isNotEmpty)
                                ? user.emergencyPhone!
                                : 'No configurado · Toca para colocar número',
                            style: TextStyle(
                              color: (user.emergencyPhone != null && user.emergencyPhone!.trim().isNotEmpty)
                                  ? Colors.black87
                                  : Colors.orange[800],
                              fontWeight: (user.emergencyPhone != null && user.emergencyPhone!.trim().isNotEmpty)
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _showEditEmergencyPhoneDialog(context, user),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF9D408),
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(
                              (user.emergencyPhone != null && user.emergencyPhone!.trim().isNotEmpty)
                                  ? 'Cambiar'
                                  : 'Colocar',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Settings
                Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.edit),
                        title: const Text('Editar perfil'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PassengerEditProfileScreen(),
                            ),
                          );
                          if (result == true && mounted) {
                            setState(() {});
                          }
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.tune, color: Color(0xFFB26A00)),
                        title: const Text(
                          'Configura tu auto',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text('Asientos y capacidad de tu vehículo'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DriverVehicleConfigScreen(),
                            ),
                          );
                          if (result == true && mounted) {
                            setState(() {});
                          }
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.security),
                        title: const Text('Seguridad'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // TODO: Navigate to security settings
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.notifications),
                        title: const Text('Notificaciones'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // TODO: Navigate to notification settings
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.info),
                        title: const Text('Acerca de'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // TODO: Show about dialog
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Logout button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Cerrar sesión'),
                          content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(dialogContext);
                                await authService.signOut();
                                if (context.mounted) {
                                  Navigator.of(context).pushNamedAndRemoveUntil(
                                    '/login',
                                    (route) => false,
                                  );
                                }
                              },
                              child: const Text('Cerrar sesión'),
                            ),
                          ],
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text(
                      'Cerrar sesión',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

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
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}