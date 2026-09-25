import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import 'driver_support_chat_screen.dart'; 

class DriverAccountScreen extends StatelessWidget {
  const DriverAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Tarjeta de perfil del conductor
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MijanoTheme.cream,
              border: Border.all(color: MijanoTheme.ink, width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 35,
                  backgroundColor: MijanoTheme.sol,
                  child: Icon(Icons.person, size: 40, color: MijanoTheme.ink),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Conductor Mijano',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: MijanoTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.phone ?? 'Sin teléfono registrado',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: MijanoTheme.sol,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Ciudad: ${user?.city ?? 'Tarapoto'}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: MijanoTheme.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Configuración y Ajustes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: MijanoTheme.ink,
            ),
          ),
          const SizedBox(height: 12),

          // Opciones de la cuenta
          _buildOptionTile(
            icon: Icons.person_outline,
            title: 'Editar Perfil',
            subtitle: 'Actualiza tus datos personales',
            onTap: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
          const SizedBox(height: 8),
          
          // --- SOPORTE CENTRALIZADO ---
          _buildOptionTile(
            icon: Icons.support_agent_outlined,
            title: 'Soporte',
            subtitle: 'Chatea en tiempo real con la administración',
            onTap: () {
              final currentUid = FirebaseAuth.instance.currentUser?.uid;
              final currentName = user?.name ?? 'Conductor Mijano'; 
              
              if (currentUid != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SupportChatScreen(
                      driverUid: currentUid,
                      driverName: currentName, 
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error: No se encontró la sesión del usuario')),
                );
              }
            },
          ),
          

          const SizedBox(height: 8),
          _buildOptionTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Términos y Condiciones',
            subtitle: 'Políticas de uso de Mijano Drive',
            onTap: () {
              _showInfoDialog(
                context,
                'Términos y Condiciones',
                'Mijano Drive conecta pasajeros y conductores de motokar de manera rápida y segura. Al usar la app aceptas cumplir con las normativas locales de tránsito y respeto.',
              );
            },
          ),

          const SizedBox(height: 32),

          // Botón de Cerrar Sesión
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: MijanoTheme.signal,
              side: const BorderSide(color: MijanoTheme.signal, width: 2),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.logout),
            label: const Text(
              'Cerrar Sesión',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onPressed: () async {
              await auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: MijanoTheme.ink),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black45),
        onTap: onTap,
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}