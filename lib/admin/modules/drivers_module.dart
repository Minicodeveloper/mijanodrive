import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../models/driver_model.dart';
import '../../services/firestore_service.dart';
import 'shared_admin_widgets.dart';

class DriversModule extends StatefulWidget {
  final Future<void> Function(BuildContext, Driver, String, String, StateSetter)? onUpdateStatus;

  const DriversModule({super.key, this.onUpdateStatus});

  @override
  State<DriversModule> createState() => _DriversModuleState();
}

class _DriversModuleState extends State<DriversModule> {
  int _currentTab = 0; // 0: Todos, 1: Pendientes, 2: Activos, 3: Inactivos
  final fs = FirestoreService.instance;
  final _searchCtrl = TextEditingController();
  String _query = '';

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
        child: StreamBuilder<List<Driver>>(
          stream: fs.allDrivers(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final drivers = snap.data ?? [];
            final pendientes = drivers.where((d) => d.status == 'pending').toList();
            final activos = drivers.where((d) => d.status == 'approved').toList();
            final inactivos = drivers.where((d) => d.status == 'rejected' || d.isBlocked).toList();

            List<Driver> filtered = drivers;
            if (_currentTab == 1) filtered = pendientes;
            if (_currentTab == 2) filtered = activos;
            if (_currentTab == 3) filtered = inactivos;

            if (_query.isNotEmpty) {
              final q = _query.toLowerCase();
              filtered = filtered
                  .where((d) =>
              d.name.toLowerCase().contains(q) ||
                  d.email.toLowerCase().contains(q) ||
                  d.plate.toLowerCase().contains(q) ||
                  d.licenseNumber.toLowerCase().contains(q))
                  .toList();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AdminHeader('Gestión de Conductores', 'Supervisión y control de conductores registrados'),
                AdminStatsGrid(items: [
                  AdminStat('Total', '${drivers.length}', Icons.people, Colors.blueGrey),
                  AdminStat('Pendientes', '${pendientes.length}', Icons.access_time, Colors.orange),
                  AdminStat('Activos', '${activos.length}', Icons.check_circle, Colors.green),
                  AdminStat('Inactivos', '${inactivos.length}', Icons.cancel, Colors.red),
                ]),
                const SizedBox(height: 24),
                AdminFilterBar(
                  tabs: [
                    'Todos (${drivers.length})',
                    'Pendientes (${pendientes.length})',
                    'Activos (${activos.length})',
                    'Inactivos (${inactivos.length})',
                  ],
                  selected: _currentTab,
                  onSelected: (i) => setState(() => _currentTab = i),
                  searchCtrl: _searchCtrl,
                  searchHint: 'Buscar conductor...',
                  onSearch: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 16),
                adminCard(
                  padding: EdgeInsets.all(compact ? 12 : 20),
                  child: filtered.isEmpty
                      ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No hay conductores para mostrar.')),
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

  // ---------- Vista ancha: tabla que ocupa todo el ancho ----------
  Widget _wideTable(List<Driver> list) {
    const head = TextStyle(fontWeight: FontWeight.bold);
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Expanded(flex: 3, child: Text('Conductor', style: head)),
            Expanded(flex: 2, child: Text('Vehículo', style: head)),
            Expanded(flex: 3, child: Text('Contacto', style: head)),
            Expanded(flex: 2, child: Text('Estado', style: head)),
            SizedBox(width: 56, child: Text('Acciones', style: head)),
          ]),
        ),
        const Divider(height: 1),
        for (final d in list) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Expanded(flex: 3, child: _identity(d)),
              Expanded(flex: 2, child: _vehicle(d)),
              Expanded(
                flex: 3,
                child: Text(d.email.isNotEmpty ? d.email : 'Sin correo',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _buildStatusBadge(d.status))),
              SizedBox(width: 56, child: _actions(d)),
            ]),
          ),
          const Divider(height: 1),
        ],
      ],
    );
  }

  // ---------- Vista angosta: tarjetas ----------
  Widget _compactList(List<Driver> list) {
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
                  _buildStatusBadge(list[i].status),
                  _actions(list[i]),
                ]),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${list[i].vehicleModel.isNotEmpty ? list[i].vehicleModel : 'N/A'} · Placa: ${list[i].plate}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        list[i].email.isNotEmpty ? list[i].email : 'Sin correo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
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

  Widget _identity(Driver d) {
    final hasPhoto = d.photoUrl != null && d.photoUrl!.isNotEmpty;
    return Row(children: [
      CircleAvatar(
        radius: 16,
        backgroundColor: MijanoTheme.sol,
        backgroundImage: hasPhoto ? NetworkImage(d.photoUrl!) : null,
        child: hasPhoto
            ? null
            : Text(d.name.isNotEmpty ? d.name[0].toUpperCase() : '?',
            style: const TextStyle(color: MijanoTheme.ink)),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(d.name.isNotEmpty ? d.name : 'Sin nombre',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(d.createdAt.toLocal().toString().split(' ')[0],
                style: const TextStyle(fontSize: 10, color: Colors.black54)),
          ],
        ),
      ),
    ]);
  }

  Widget _vehicle(Driver d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(d.vehicleModel.isNotEmpty ? d.vehicleModel : 'N/A',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        Text('Placa: ${d.plate}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Colors.black54)),
      ],
    );
  }

  Widget _actions(Driver d) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      onSelected: (value) async {
        if (value == 'approve') {
          await fs.approveDriver(d.uid, true);
        } else if (value == 'reject') {
          await fs.approveDriver(d.uid, false);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'approve', child: Text('Aprobar')),
        PopupMenuItem(value: 'reject', child: Text('Rechazar / Desactivar')),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    switch (status.toLowerCase()) {
      case 'approved':
        color = Colors.green;
        text = 'Activo';
        break;
      case 'rejected':
        color = Colors.red;
        text = 'Rechazado';
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