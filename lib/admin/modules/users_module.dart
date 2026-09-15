import 'package:flutter/material.dart';
import '../../theme.dart';
import 'shared_admin_widgets.dart';

class UsersModule extends StatefulWidget {
  const UsersModule({super.key});

  @override
  State<UsersModule> createState() => _UsersModuleState();
}

class _UsersModuleState extends State<UsersModule> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  // TODO(Equipo): Reemplazar por stream real de FirestoreService para collection('users')
  List<Map<String, dynamic>> _fetchMockUsers() {
    return [
      {
        'uid': 'usr_1',
        'phone': '+51 999888777',
        'email': 'pasajero1@test.com',
        'name': 'Juan Pérez',
        'dni': '70001111',
        'role': 'passenger',
        'city': 'Lima',
        'isReported': false,
        'tripsCount': 12,
      },
      {
        'uid': 'usr_2',
        'phone': '+51 987654321',
        'email': 'maria@test.com',
        'name': 'Maria Gomez',
        'dni': '70002222',
        'role': 'passenger',
        'city': 'Trujillo',
        'isReported': true,
        'tripsCount': 3,
      }
    ];
  }

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
                // TODO(Equipo): Conectar actualización real
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teléfono actualizado (Mock)')));
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
    final allUsers = _fetchMockUsers();
    final users = _query.isEmpty
        ? allUsers
        : allUsers.where((u) => u['name'].toString().toLowerCase().contains(_query.toLowerCase()) || u['phone'].toString().contains(_query)).toList();

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
                if (users.isEmpty)
                  const Text('No se encontraron usuarios.')
                else
                  ListView.builder(
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
                            Text(u['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            if (u['isReported'] == true)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                                child: const Text('Reportado', style: TextStyle(fontSize: 10, color: Colors.red)),
                              ),
                          ],
                        ),
                        subtitle: Text('${u['phone']} · Viajes: ${u['tripsCount']} · ${u['city']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.phone_android), tooltip: 'Editar teléfono', onPressed: () => _editPhone(u)),
                            IconButton(
                              icon: const Icon(Icons.warning_amber),
                              color: Colors.orange,
                              tooltip: 'Marcar como reportado',
                              onPressed: () {
                                // TODO(Equipo): Escribir en base de datos
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marcado como reportado (Mock)')));
                              },
                            )
                          ],
                        ),
                      );
                    },
                  )
              ],
            ),
          )
        ],
      ),
    );
  }
}
