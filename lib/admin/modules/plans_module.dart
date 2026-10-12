// ============================================================================
// CONTRATO DE DATOS: PLANES
// plan_requests: driverId, driverName, driverPhone, planId, planName, amount,
//                days, receiptUrl, status ('pending'|'approved'|'rejected'),
//                rejectReason, createdAt, reviewedBy, reviewedAt.
// driver_plans:  planId, planName, priority, startsAt, expiresAt, status,
//                activatedBy, updatedAt. (ID del documento = driverId)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import '../../models/driver_plan_model.dart';
import 'shared_admin_widgets.dart';

class PlansModule extends StatefulWidget {
  const PlansModule({super.key});

  @override
  State<PlansModule> createState() => _PlansModuleState();
}

class _PlansModuleState extends State<PlansModule> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final fs = FirestoreService.instance;
  String _requestsFilter = 'pending'; // 'pending', 'approved', 'rejected'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) {
    return DateFormat('dd/MM/yy HH:mm').format(d.toLocal());
  }

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays > 0) return 'hace ${diff.inDays} d';
    if (diff.inHours > 0) return 'hace ${diff.inHours} h';
    if (diff.inMinutes > 0) return 'hace ${diff.inMinutes} min';
    return 'hace instantes';
  }

  // ==============================================
  // 1. SOLICITUDES
  // ==============================================
  Widget _buildRequestsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Filtrar por: ', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _requestsFilter,
              items: const [
                DropdownMenuItem(value: 'pending', child: Text('Pendientes')),
                DropdownMenuItem(value: 'approved', child: Text('Aprobadas')),
                DropdownMenuItem(value: 'rejected', child: Text('Rechazadas')),
              ],
              onChanged: (v) => setState(() => _requestsFilter = v!),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: fs.streamAllPlanRequests(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final allReqs = snap.data ?? [];
              final reqs = allReqs.where((r) => r['status'] == _requestsFilter).toList();

              if (reqs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('No hay solicitudes en esta categoría', style: TextStyle(color: Colors.black54)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: reqs.length,
                itemBuilder: (context, index) {
                  final req = reqs[index];
                  final createdAt = (req['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: GestureDetector(
                        onTap: () => _showReceiptDialog(req),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            req['receiptUrl'] ?? '',
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 60, height: 60, color: Colors.grey.shade200,
                              child: const Icon(Icons.receipt_long, color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                      title: Text(req['driverName'] ?? 'Sin nombre', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Plan ${req['planName']} (S/ ${req['amount']}) · ${req['driverPhone']}'),
                          Text(_timeAgo(createdAt), style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                          if (req['status'] != 'pending')
                            Text('Por: ${req['reviewedBy']} el ${_formatDate((req['reviewedAt'] as Timestamp?)?.toDate() ?? DateTime.now())}', style: const TextStyle(fontSize: 11, color: Colors.black45)),
                        ],
                      ),
                      trailing: req['status'] == 'pending' ? IconButton(
                        icon: const Icon(Icons.open_in_new, color: MijanoTheme.sol),
                        onPressed: () => _showReceiptDialog(req),
                      ) : null,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showReceiptDialog(Map<String, dynamic> req) {
    final reasonCtrl = TextEditingController();
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('Solicitud: ${req['driverName']}'),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Plan: ${req['planName']} - S/ ${req['amount']} (${req['days']} días)', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 400,
                      width: double.infinity,
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Image.network(
                          req['receiptUrl'] ?? '',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, size: 64, color: Colors.grey),
                                SizedBox(height: 12),
                                Text('No se pudo cargar la imagen', style: TextStyle(color: Colors.black54)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (req['status'] == 'pending') ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: reasonCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Motivo de rechazo (solo si vas a rechazar)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ] else if (req['status'] == 'rejected') ...[
                      const SizedBox(height: 16),
                      Text('Motivo de rechazo: ${req['rejectReason']}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ]
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cerrar', style: TextStyle(color: Colors.black54)),
              ),
              if (req['status'] == 'pending') ...[
                TextButton(
                  onPressed: isProcessing ? null : () async {
                    if (reasonCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escribe un motivo para rechazar')));
                      return;
                    }
                    setStateDialog(() => isProcessing = true);
                    try {
                      await fs.rejectPlanRequest(req, reasonCtrl.text.trim(), 'Admin');
                      if (context.mounted) {
                         Navigator.pop(dialogCtx);
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitud rechazada')));
                      }
                    } catch (e) {
                      setStateDialog(() => isProcessing = false);
                      if (context.mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Rechazar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: MijanoTheme.sol, foregroundColor: MijanoTheme.ink),
                  onPressed: isProcessing ? null : () async {
                    setStateDialog(() => isProcessing = true);
                    try {
                      await fs.approvePlanRequest(req, 'Admin');
                      if (context.mounted) {
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plan activado correctamente')));
                      }
                    } catch (e) {
                      setStateDialog(() => isProcessing = false);
                      if (context.mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  child: isProcessing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Aprobar y activar plan'),
                ),
              ]
            ],
          );
        },
      ),
    );
  }

  // ==============================================
  // 2. CONDUCTORES CON PLAN
  // ==============================================
  Widget _buildDriverPlansTab() {
    return StreamBuilder<List<DriverPlanModel>>(
      stream: fs.streamDriverPlans(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final plans = snap.data ?? [];
        final now = DateTime.now();

        int activos = 0;
        int porVencer = 0;
        int vencidos = 0;

        for (var p in plans) {
          final diff = p.expiresAt.difference(now);
          if (diff.isNegative || p.status == 'expired') {
            vencidos++;
          } else if (diff.inDays <= 2) {
            porVencer++;
            activos++;
          } else {
            activos++;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminStatsGrid(items: [
              AdminStat('Planes Activos', '$activos', Icons.check_circle, Colors.green),
              AdminStat('Por vencer (≤2d)', '$porVencer', Icons.warning_amber, Colors.orange),
              AdminStat('Vencidos', '$vencidos', Icons.error_outline, Colors.red),
            ]),
            const SizedBox(height: 20),
            Expanded(
              child: adminCard(
                child: plans.isEmpty
                    ? const Center(child: Text('No hay planes registrados'))
                    : ListView.separated(
                        itemCount: plans.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, i) {
                          final p = plans[i];
                          final diff = p.expiresAt.difference(now);
                          
                          String statusText;
                          Color statusColor;
                          if (diff.isNegative || p.status == 'expired') {
                            statusText = 'Vencido';
                            statusColor = Colors.red;
                          } else if (diff.inDays <= 2) {
                            statusText = 'Por vencer (${diff.inDays} d)';
                            statusColor = Colors.orange;
                          } else {
                            statusText = 'Activo (${diff.inDays} d)';
                            statusColor = Colors.green;
                          }

                          return ListTile(
                            leading: const CircleAvatar(backgroundColor: MijanoTheme.cream, child: Icon(Icons.two_wheeler, color: MijanoTheme.ink)),
                            title: Text('Conductor ID: ${p.driverId}'), // Ideally resolve name
                            subtitle: Text('Plan: ${p.planName} · Vence: ${_formatDate(p.expiresAt)}'),
                            trailing: AdminBadge(statusText, statusColor),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ==============================================
  // 3. PLANES Y PRECIOS
  // ==============================================
  Widget _buildPlansTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: fs.streamPlans(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final plans = snap.data ?? [];

        if (plans.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('No hay planes configurados en la base de datos.'),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    await fs.seedDefaultPlans();
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Planes por defecto creados')));
                  },
                  child: const Text('Cargar planes por defecto'),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 350,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.8,
          ),
          itemCount: plans.length,
          itemBuilder: (context, i) {
            final p = plans[i];
            final benefits = List<String>.from(p['benefits'] ?? []);

            return adminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(p['name'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: MijanoTheme.ink)),
                      if (p['isActive'] == true) const AdminBadge('Activo', Colors.green) else const AdminBadge('Inactivo', Colors.red),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('S/ ${p['price']}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: MijanoTheme.sol)),
                  Text('Duración: ${p['durationDays']} días', style: const TextStyle(color: Colors.black54)),
                  const Divider(height: 24),
                  const Text('Beneficios:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: benefits.length,
                      itemBuilder: (ctx, j) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check, size: 16, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(child: Text(benefits[j], style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Solo lectura por ahora
                  const SizedBox(height: 8),
                  const Text('Solo SuperAdmin puede editar precios (desde Firestore).', style: TextStyle(fontSize: 10, color: Colors.black38)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminHeader('Planes de Conductores', 'Gestión de suscripciones y aprobaciones'),
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black12)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: MijanoTheme.ink,
              unselectedLabelColor: Colors.black54,
              indicatorColor: MijanoTheme.sol,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'Solicitudes'),
                Tab(text: 'Conductores con plan'),
                Tab(text: 'Planes y precios'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRequestsTab(),
                _buildDriverPlansTab(),
                _buildPlansTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
