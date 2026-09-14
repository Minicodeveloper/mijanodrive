import 'package:flutter/material.dart';
import '../../theme.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({Key? key}) : super(key: key);

  void _navigateToLogin(BuildContext context, String role) {
    // Redirige a la pantalla de login pasando el rol como argumento por si lo necesitas luego
    Navigator.of(context).pushNamed('/login-screen', arguments: {'role': role});
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: MijanoTheme.sol, // Mantiene el fondo amarillo corporativo
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // ==========================================
              // LOGO SUPERIOR (logo.png)
              // ==========================================
              Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  width: size.width * 0.55,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Text(
                    'MIJANO DRIVE',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: MijanoTheme.ink,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // ==========================================
              // OPCIÓN: COMO PASAJERO
              // ==========================================
              _buildRoleCard(
                context: context,
                title: 'Como Pasajero',
                onTap: () => _navigateToLogin(context, 'passenger'),
              ),

              const SizedBox(height: 32),

              // ==========================================
              // OPCIÓN: COMO CONDUCTOR
              // ==========================================
              _buildRoleCard(
                context: context,
                title: 'Como Conductor',
                onTap: () => _navigateToLogin(context, 'driver'),
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  // Tarjeta personalizada con la sombra y bordes redondeados de la imagen
  Widget _buildRoleCard({
    required BuildContext context,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          height: 140,
          decoration: BoxDecoration(
            color: MijanoTheme.sol, // Mismo color del fondo
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 15,
                spreadRadius: 1,
                offset: const Offset(0, 8), // Sombra inferior para dar efecto elevado
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(-2, -2), // Brillo superior ligero
              ),
            ],
          ),
          child: Center(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: MijanoTheme.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}