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
  int _currentTab = 0; // 0: Todos
  final _searchCtrl = TextEditingController();
  String _query = '';
  final fs = FirestoreService.instance;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final compact = c.maxWidth < 720;
      return SingleChildScrollView(
        padding: EdgeInsets.all(compact ? 14 : 28),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: fs.allUsers(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final allUsers = snap.data ?? [];
            List<Map<String, dynamic>> filtered = allUsers;

            if (_query.isNotEmpty) {
              final q = _query.toLowerCase();
              filtered = filtered
                  .where((u) =>
              (u['name']?.toString().toLowerCase() ?? '').contains(q) ||
                  (u['phone']?.toString() ?? '').contains(_query))
                  .toList();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AdminHeader('Gestión de Clientes', 'Supervisión y control de usuarios pasajeros'),
                AdminStatsGrid(items: [
                  AdminStat('Total Clientes', '${allUsers.length}', Icons.people, Colors.blueGrey),
                  const AdminStat('Pendientes', '0', Icons.access_time, Colors.orange),
                  const AdminStat('Con Viajes', '0', Icons.location_on, Colors.green),
                ]),
                const SizedBox(height: 24),
                AdminFilterBar(
                  tabs: ['Todos (${allUsers.length})'],
                  selected: _currentTab,
                  onSelected: (i) => setState(() => _currentTab = i),
                  searchCtrl: _searchCtrl,
                  searchHint: 'Buscar por nombre o teléfono...',
                  onSearch: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 16),
                adminCard(
                  padding: EdgeInsets.all(compact ? 12 : 20),
                  child: filtered.isEmpty
                      ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No hay clientes para mostrar.')),
                  )
                      : (compact ? _compactList(filtered) : _wideTable(filtered)),
                ),
              ],
            );
          },
        ),
      );
    });
  }

  String _name(Map<String, dynamic> u) {
    final n = (u['name'] ?? '').toString();
    return n.isEmpty ? 'Sin nombre' : n;
  }

  String _phone(Map<String, dynamic> u) {
    final p = (u['phone'] ?? '').toString();
    return p.isEmpty ? 'Sin teléfono' : p;
  }

  String _status(Map<String, dynamic> u) => u['isBlocked'] == true ? 'Bloqueado' : 'Activo';

  // ---------- Vista ancha ----------
  Widget _wideTable(List<Map<String, dynamic>> list) {
    const head = TextStyle(fontWeight: FontWeight.bold);
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Expanded(flex: 4, child: Text('Cliente', style: head)),
            Expanded(flex: 2, child: Text('Teléfono', style: head)),
            Expanded(flex: 2, child: Text('Viajes', style: head)),
            Expanded(flex: 2, child: Text('Estado', style: head)),
            Expanded(flex: 2, child: Text('Registro', style: head)),
            SizedBox(width: 56, child: Text('Acciones', style: head)),
          ]),
        ),
        const Divider(height: 1),
        for (final u in list) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Expanded(flex: 4, child: _identity(u)),
              Expanded(flex: 2, child: Text(_phone(u), maxLines: 1, overflow: TextOverflow.ellipsis)),
              const Expanded(flex: 2, child: Text('0 viajes')),
              Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _buildStatusBadge(_status(u)))),
              const Expanded(flex: 2, child: Text('Reciente')),
              SizedBox(
                width: 56,
                child: IconButton(icon: const Icon(Icons.more_horiz), onPressed: () {}),
              ),
            ]),
          ),
          const Divider(height: 1),
        ],
      ],
    );
  }

  // ---------- Vista angosta ----------
  Widget _compactList(List<Map<String, dynamic>> list) {
    return Column(
      children: [
        for (int i = 0; i < list.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: _identity(list[i])),
                  _buildStatusBadge(_status(list[i])),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.more_horiz),
                    onPressed: () {},
                  ),
                ]),
                Padding(
                  padding: const EdgeInsets.only(left: 40),
                  child: Text(
                    '${_phone(list[i])} · 0 viajes · Reciente',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          if (i < list.length - 1) const Divider(height: 1),
        ],
      ],
    );
  }

  Widget _identity(Map<String, dynamic> u) {
    final name = _name(u);
    return Row(children: [
      CircleAvatar(
        radius: 16,
        backgroundColor: MijanoTheme.sol,
        child: Text(name[0].toUpperCase(), style: const TextStyle(color: MijanoTheme.ink)),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(u['email'] ?? 'Sin correo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: Colors.black54)),
          ],
        ),
      ),
    ]);
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    switch (status.toLowerCase()) {
      case 'activo':
        color = Colors.green;
        text = 'Activo';
        break;
      case 'bloqueado':
        color = Colors.red;
        text = 'Bloqueado';
        break;
      default:
        color = Colors.orange;
        text = 'Pendiente';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}