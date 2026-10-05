import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../services/firestore_service.dart';
import 'profile_dialogs.dart';
import 'shared_admin_widgets.dart';

class UsersModule extends StatefulWidget {
  final bool canSeeMoney;
  const UsersModule({super.key, required this.canSeeMoney});

  @override
  State<UsersModule> createState() => _UsersModuleState();
}

class _UsersModuleState extends State<UsersModule> {
  int _currentTab = 0; // 0: Todos, 1: Activos, 2: Bloqueados
  final _searchCtrl = TextEditingController();
  String _query = '';
  final fs = FirestoreService.instance;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// `users` también guarda conductores y cuentas del panel: aquí solo pasajeros.
  bool _isPassenger(Map<String, dynamic> u) {
    final r = (u['role'] ?? 'passenger').toString().toLowerCase();
    return r == 'passenger' || r == 'pasajero';
  }

  bool _isBlocked(Map<String, dynamic> u) => u['isBlocked'] == true;

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
            if (snap.hasError) {
              return Text('No se pudo cargar la lista: ${snap.error}',
                  style: TextStyle(color: Colors.red.shade700));
            }

            final allUsers = (snap.data ?? []).where(_isPassenger).toList();
            final activos = allUsers.where((u) => !_isBlocked(u)).toList();
            final bloqueados = allUsers.where(_isBlocked).toList();

            List<Map<String, dynamic>> filtered = allUsers;
            if (_currentTab == 1) filtered = activos;
            if (_currentTab == 2) filtered = bloqueados;

            if (_query.isNotEmpty) {
              final q = _query.toLowerCase();
              filtered = filtered
                  .where((u) =>
                      (u['name']?.toString().toLowerCase() ?? '').contains(q) ||
                      (u['email']?.toString().toLowerCase() ?? '').contains(q) ||
                      (u['phone']?.toString() ?? '').contains(_query))
                  .toList();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AdminHeader('Gestión de Clientes', 'Supervisión y control de usuarios pasajeros'),
                AdminStatsGrid(items: [
                  AdminStat('Total Clientes', '${allUsers.length}', Icons.people, Colors.blueGrey),
                  AdminStat('Activos', '${activos.length}', Icons.check_circle, Colors.green),
                  AdminStat('Bloqueados', '${bloqueados.length}', Icons.block, Colors.red),
                ]),
                const SizedBox(height: 24),
                AdminFilterBar(
                  tabs: [
                    'Todos (${allUsers.length})',
                    'Activos (${activos.length})',
                    'Bloqueados (${bloqueados.length})',
                  ],
                  selected: _currentTab,
                  onSelected: (i) => setState(() => _currentTab = i),
                  searchCtrl: _searchCtrl,
                  searchHint: 'Buscar por nombre, correo o teléfono...',
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

  String _city(Map<String, dynamic> u) {
    final c = (u['city'] ?? '').toString();
    return c.isEmpty ? '—' : c;
  }

  String _status(Map<String, dynamic> u) => _isBlocked(u) ? 'Bloqueado' : 'Activo';

  void _openProfile(Map<String, dynamic> u) =>
      PassengerProfileDialog.show(context, u['uid'].toString(), canSeeMoney: widget.canSeeMoney);

  Future<void> _onAction(String action, Map<String, dynamic> u) async {
    final uid = u['uid'].toString();
    final name = _name(u);
    final messenger = ScaffoldMessenger.of(context);

    Future<void> run(Future<void> Function() fn, String ok) async {
      try {
        await fn();
        messenger.showSnackBar(SnackBar(content: Text(ok)));
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('No se pudo completar la acción: $e')));
      }
    }

    switch (action) {
      case 'profile':
        _openProfile(u);
        break;
      case 'block':
        final ok = await adminConfirm(context,
            title: 'Bloquear pasajero',
            body: '$name no podrá iniciar sesión mientras esté bloqueado.',
            action: 'Bloquear',
            danger: true);
        if (!ok) return;
        await run(() => fs.setAccountBlocked(uid, true), '$name bloqueado');
        break;
      case 'unblock':
        await run(() => fs.setAccountBlocked(uid, false), '$name desbloqueado');
        break;
    }
  }

  Widget _actions(Map<String, dynamic> u) {
    final blocked = _isBlocked(u);
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      onSelected: (v) => _onAction(v, u),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'profile', child: Text('Ver perfil')),
        PopupMenuItem(
          value: blocked ? 'unblock' : 'block',
          child: Text(blocked ? 'Desbloquear' : 'Bloquear'),
        ),
      ],
    );
  }

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
            Expanded(flex: 2, child: Text('Ciudad', style: head)),
            Expanded(flex: 2, child: Text('Estado', style: head)),
            Expanded(flex: 2, child: Text('Registro', style: head)),
            SizedBox(width: 56, child: Text('Acciones', style: head)),
          ]),
        ),
        const Divider(height: 1),
        for (final u in list) ...[
          InkWell(
            onTap: () => _openProfile(u),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Expanded(flex: 4, child: _identity(u)),
                Expanded(flex: 2, child: Text(_phone(u), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Expanded(flex: 2, child: Text(_city(u), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _buildStatusBadge(_status(u)))),
                Expanded(flex: 2, child: Text(formatAdminDate(u['createdAt']))),
                SizedBox(width: 56, child: _actions(u)),
              ]),
            ),
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
          InkWell(
            onTap: () => _openProfile(list[i]),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: _identity(list[i])),
                    _buildStatusBadge(_status(list[i])),
                    _actions(list[i]),
                  ]),
                  Padding(
                    padding: const EdgeInsets.only(left: 40),
                    child: Text(
                      '${_phone(list[i])} · ${_city(list[i])} · ${formatAdminDate(list[i]['createdAt'])}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ],
              ),
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
            Text((u['email'] ?? 'Sin correo').toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: Colors.black54)),
          ],
        ),
      ),
    ]);
  }

  Widget _buildStatusBadge(String status) {
    switch (status.toLowerCase()) {
      case 'activo':
        return const AdminBadge('Activo', Colors.green);
      case 'bloqueado':
        return AdminBadge('Bloqueado', Colors.red.shade800);
      default:
        return const AdminBadge('Pendiente', Colors.orange);
    }
  }
}
