import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
                        onTap: () {
                          // TODO: Navigate to edit profile
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