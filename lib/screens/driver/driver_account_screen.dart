import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/plan_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import 'driver_my_plan_screen.dart';
import 'driver_support_chat_screen.dart'; 
import 'driver_vehicle_config_screen.dart'; 

class DriverAccountScreen extends StatelessWidget {
  const DriverAccountScreen({super.key});

  bool _isCarDriver(dynamic user, Map<String, dynamic>? userData) {
    final rawType = (userData?['vehicleType'] ?? user?.vehicleType ?? '').toString().trim().toLowerCase();
    if (rawType.contains('moto')) return false;
    final hasAgency = (userData?['agencyName'] ?? user?.agencyName ?? '').toString().trim().isNotEmpty;
    final isCar = rawType == 'carro' ||
        rawType == 'auto' ||
        rawType.contains('carro') ||
        rawType.contains('auto') ||
        hasAgency ||
        (userData?['isIntercityCar'] == true);
    return isCar;
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    final user = auth.currentUser;
    final uid =
        FirebaseAuth.instance.currentUser?.uid ?? user?.uid ?? 'demo-driver';

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, userSnap) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('driver_plans')
              .doc(uid)
              .snapshots(),
          builder: (context, driverPlanSnap) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: FirestoreService.instance.streamPlans(),
              builder: (context, plansSnap) {
                final userData = userSnap.data?.data();
                final driverPlanData = driverPlanSnap.data?.data();
                final rawPlans = plansSnap.data ?? [];
                final plans = rawPlans
                    .map((e) => PlanModel.fromMap(e, e['id']))
                    .toList();

                final isCarDriver = _isCarDriver(user, userData);

                final expiresAt =
                    (userData?['planExpiresAt'] as Timestamp?)?.toDate() ??
                    (driverPlanData?['expiresAt'] as Timestamp?)?.toDate();
                final hasNotExpired =
                    expiresAt != null && expiresAt.isAfter(DateTime.now());
                final hasActivePlan =
                    (userData?['planPaymentStatus'] == 'active' ||
                        driverPlanData?['status'] == 'active') &&
                    hasNotExpired;

                final currentPlanName = hasActivePlan
                    ? DriverPlanHelper.resolvePlanName(
                        driverData: userData,
                        driverPlanData: driverPlanData,
                        plans: plans,
                      )
                    : 'Sin plan activo';
                final remainingText = hasActivePlan
                    ? DriverPlanHelper.formatRemainingTime(expiresAt)
                    : '';

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
                              child: Icon(
                                Icons.person,
                                size: 40,
                                color: MijanoTheme.ink,
                              ),
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
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: MijanoTheme.sol,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
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
                                      InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const DriverMyPlanScreen(),
                                            ),
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: hasActivePlan
                                                ? Colors.green.shade700
                                                : Colors.black87,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.workspace_premium,
                                                size: 13,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                currentPlanName,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
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

                      // --- APARTADO: VER MI PLAN Y MIGRAR ---
                      _buildOptionTile(
                        icon: Icons.workspace_premium_outlined,
                        title: 'Ver mi plan',
                        subtitle: hasActivePlan
                            ? 'Plan actual: $currentPlanName${remainingText.isNotEmpty ? " ($remainingText)" : ""} · Ver todos o migrar'
                            : 'Consulta todos los planes disponibles y activa o migra tu plan',
                        highlighted: true,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DriverMyPlanScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),

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

                      if (isCarDriver) ...[
                        // Configuración de Asientos del Auto (solo para conductores de Carro / Van)
                        _buildOptionTile(
                          icon: Icons.tune,
                          title: 'Configura tu auto',
                          subtitle: 'Configura los asientos y capacidad de tu auto o van',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DriverVehicleConfigScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                      
                      // --- SOPORTE CENTRALIZADO ---
                      _buildOptionTile(
                        icon: Icons.support_agent_outlined,
                        title: 'Soporte',
                        subtitle: 'Chatea en tiempo real con la administración',
                        onTap: () {
                          final currentUid =
                              FirebaseAuth.instance.currentUser?.uid;
                          final currentName =
                              user?.name ?? 'Conductor Mijano';
                          
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
                              const SnackBar(
                                content: Text(
                                  'Error: No se encontró la sesión del usuario',
                                ),
                              ),
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

                      // Botón de Cerrar Sesión corregido
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MijanoTheme.signal,
                          side: const BorderSide(
                            color: MijanoTheme.signal,
                            width: 2,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.logout),
                        label: const Text(
                          'Cerrar Sesión',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () async {
                          if (context.mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/login',
                              (route) => false,
                            );
                          }

                          await auth.signOut();
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool highlighted = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFFFFBEA) : Colors.white,
        border: Border.all(
          color: highlighted ? MijanoTheme.solDeep : Colors.black12,
          width: highlighted ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: highlighted
                ? MijanoTheme.sol.withValues(alpha: 0.35)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: MijanoTheme.ink),
        ),
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