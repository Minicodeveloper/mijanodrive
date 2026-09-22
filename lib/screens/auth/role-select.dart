import 'package:flutter/material.dart';
import '../../theme.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  void _navigateToLogin(BuildContext context, String role) {
    
    Navigator.of(context).pushNamed(
      '/login', 
      arguments: {'role': role},
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: MijanoTheme.sol, 
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
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pushNamed(
                    '/admin',
                    arguments: const {'createFirstAdmin': true},
                  ),
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
              ),

              const Spacer(),

              // ==========================================
              // OPCIÓN: COMO PASAJERO -> Lleva al Login con rol pasajero
              // ==========================================
              _buildRoleCard(
                context: context,
                title: 'Como Pasajero',
                onTap: () => _navigateToLogin(context, 'passenger'),
              ),

              const SizedBox(height: 32),

              // ==========================================
              // OPCIÓN: COMO CONDUCTOR -> Lleva al Login con rol conductor
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
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 15,
                spreadRadius: 1,
                offset: const Offset(0, 8), 
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(-2, -2), 
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
