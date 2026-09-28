import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import 'passenger_profile_screen.dart';
import 'passenger_support_chat_screen.dart';

/// Pantalla principal de cuenta y perfil del Pasajero.
/// Replica con fidelidad visual la arquitectura y diseño de la pantalla de cuenta
/// del conductor (tarjeta superior en cream, badge de ciudad, opciones de ajustes,
/// diálogo modal de Términos y Condiciones y botón de cerrar sesión en signal).
class PassengerAccountScreen extends StatefulWidget {
  const PassengerAccountScreen({super.key});

  @override
  State<PassengerAccountScreen> createState() => _PassengerAccountScreenState();
}

class _PassengerAccountScreenState extends State<PassengerAccountScreen> {
  User? _user;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final cachedUser = AuthService.instance.currentUser;
    if (mounted) {
      setState(() {
        _user = cachedUser;
      });
    }

    final currentAuthUser = fb.FirebaseAuth.instance.currentUser;
    if (currentAuthUser != null) {
      final freshUser = await FirestoreService.instance.getUser(currentAuthUser.uid);
      if (freshUser != null && mounted) {
        setState(() {
          _user = freshUser;
          AuthService.instance.currentUser = freshUser;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user ?? AuthService.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Mi Cuenta',
          style: TextStyle(
            color: MijanoTheme.ink,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: MijanoTheme.sol,
        elevation: 0,
        iconTheme: const IconThemeData(color: MijanoTheme.ink),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        children: [
          // Tarjeta superior del perfil (Fiel a la captura de referencia)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MijanoTheme.cream,
              border: Border.all(color: MijanoTheme.ink, width: 1.5),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: MijanoTheme.sol,
                  backgroundImage: user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                      ? NetworkImage(user.photoUrl!)
                      : null,
                  child: (user?.photoUrl == null || user!.photoUrl!.isEmpty)
                      ? const Icon(Icons.person, size: 44, color: MijanoTheme.ink)
                      : null,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Usuario',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: MijanoTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.phone != null && user!.phone.isNotEmpty
                            ? user.phone
                            : 'Sin teléfono registrado',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF555555),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: MijanoTheme.sol,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Ciudad: ${user?.city ?? 'Lima'}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
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

          // Título de la sección
          const Text(
            'Configuración y Ajustes',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: MijanoTheme.ink,
            ),
          ),
          const SizedBox(height: 12),

          // Opción 1: Editar Perfil / Mi Perfil Completo
          _buildOptionTile(
            icon: Icons.person_outline,
            title: 'Editar Perfil',
            subtitle: 'Actualiza tus datos personales',
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PassengerProfileScreen(),
                ),
              );
              if (result == true) {
                _loadUserData();
              }
            },
          ),
          const SizedBox(height: 10),

          // Opción 2: Soporte
          _buildOptionTile(
            icon: Icons.headset_mic_outlined,
            title: 'Soporte',
            subtitle: 'Chatea en tiempo real con la administración',
            onTap: () {
              final currentUid = fb.FirebaseAuth.instance.currentUser?.uid ?? user?.uid;
              final currentName = user?.name ?? 'Pasajero';

              if (currentUid != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PassengerSupportChatScreen(
                      passengerUid: currentUid,
                      passengerName: currentName,
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error: No se encontró la sesión del usuario'),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 10),

          // Opción 3: Términos y Condiciones
          _buildOptionTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Términos y Condiciones',
            subtitle: 'Políticas de uso de Mijano Drive',
            onTap: () {
              _showTermsDialog(context);
            },
          ),

          const SizedBox(height: 28),

          // Botón inferior: Cerrar Sesión con contorno rojo y llamada a signOut
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: MijanoTheme.signal,
              side: const BorderSide(color: MijanoTheme.signal, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.logout, color: MijanoTheme.signal),
            label: const Text(
              'Cerrar Sesión',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: MijanoTheme.signal,
              ),
            ),
            onPressed: () async {
              await fb.FirebaseAuth.instance.signOut();
              await AuthService.instance.signOut();
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
        border: Border.all(color: Colors.black12, width: 1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Icon(icon, color: MijanoTheme.ink, size: 26),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: MijanoTheme.ink,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black54,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          size: 24,
          color: Colors.black45,
        ),
        onTap: onTap,
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: MijanoTheme.cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: const Text(
          'Términos y Condiciones',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: MijanoTheme.ink,
          ),
        ),
        content: const Text(
          'Mijano Drive conecta pasajeros y conductores de motokar de manera rápida y segura. Al usar la app aceptas cumplir con las normativas locales de tránsito y respeto.',
          style: TextStyle(
            fontSize: 15,
            color: Colors.black87,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cerrar',
              style: TextStyle(
                color: MijanoTheme.solDeep,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
