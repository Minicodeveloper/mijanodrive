import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../services/firestore_service.dart';
import 'shared_admin_widgets.dart';

class UsersModule extends StatefulWidget {
  const UsersModule({super.key});

  @override
  State<UsersModule> createState() => _UsersModuleState();
}

class _UsersModuleState extends State<UsersModule> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  final fs = FirestoreService.instance;

  void _editPhone(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: user['phone']);
        return AlertDialog(
          title: Text('Editar teléfono - ${user['name']}'),
          content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Nuevo teléfono')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                // TODO: Conectar actualización real a Firestore
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edición de teléfono (Pendiente de Auth)')));
                Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminHeader('Usuarios / Pasajeros', 'Gestión de clientes y recuperación de acceso'),
          adminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Buscar por nombre o teléfono...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (val) => setState(() => _query = val),
                ),
                const SizedBox(height: 20),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: fs.allUsers(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    final allUsers = snap.data ?? [];
                    final users = _query.isEmpty
                        ? allUsers
                        : allUsers.where((u) => 
                            (u['name']?.toString().toLowerCase() ?? '').contains(_query.toLowerCase()) || 
                            (u['phone']?.toString() ?? '').contains(_query)
                          ).toList();

                    if (users.isEmpty) return const Text('No se encontraron usuarios.');

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: users.length,
                      itemBuilder: (ctx, i) {
                        final u = users[i];
                        return ListTile(
                          leading: CircleAvatar(
                              backgroundColor: MijanoTheme.sol,
                              child: const Icon(Icons.person, color: MijanoTheme.ink)),
                          title: Row(
                            children: [
                              Text(u['name'] ?? 'Sin nombre', style: const TextStyle(fontWeight: FontWeight.bold)),
                              if (u['isReported'] == true)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                                  child: const Text('Reportado', style: TextStyle(fontSize: 10, color: Colors.red)),
                                ),
                            ],
                          ),
                          subtitle: Text('${u['phone'] ?? '-'} · Viajes: ${u['tripsCount'] ?? 0} · ${u['city'] ?? '-'}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.phone_android), tooltip: 'Editar teléfono', onPressed: () => _editPhone(u)),
                              IconButton(
                                icon: const Icon(Icons.warning_amber),
                                color: Colors.orange,
                                tooltip: u['isReported'] == true ? 'Quitar reporte' : 'Marcar como reportado',
                                onPressed: () {
                                  fs.updateUserStatus(u['uid'], isReported: !(u['isReported'] == true));
                                },
                              )
                            ],
                          ),
                        );
                      },
                    );
                  }
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
