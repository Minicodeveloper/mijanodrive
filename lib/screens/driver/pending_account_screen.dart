import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import 'driver_documents_screen.dart';

class PendingAccountScreen extends StatelessWidget {
  const PendingAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), 
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF9D408).withOpacity(0.3)),
                  ),
                  child: const Icon(
                    Icons.hourglass_bottom_rounded,
                    size: 50,
                    color: Color(0xFFF9D408),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Cuenta Pendiente',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF9D408),
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Tu cuenta de conductor está siendo revisada por un administrador. Te notificaremos cuando sea aprobada.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: FirestoreService.instance.userNotifications(AuthService.instance.currentUser?.uid ?? ''),
                builder: (context, snapshot) {
                  final notifs = snapshot.data ?? [];
                  final unread = notifs.where((n) => n['isRead'] == false).toList();
                  if (unread.isEmpty) return const SizedBox.shrink();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.red),
                            SizedBox(width: 8),
                            Expanded(child: Text('Atención Requerida', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...unread.map((n) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ', style: TextStyle(color: Colors.white)),
                                Expanded(child: Text(n['body'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13))),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                                  onPressed: () => FirestoreService.instance.markNotificationRead(n['id']),
                                )
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
              ElevatedButton(
                onPressed: () {
                  
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DriverDocumentsScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF9D408),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_shared, color: Colors.black),
                    SizedBox(width: 8),
                    Text(
                      'Revisar Mis Documentos',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              OutlinedButton(
                onPressed: () async {
                  await AuthService.instance.signOut(); 
                  if (!context.mounted) return;
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.grey),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  'Cerrar Sesión',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}