// ============================================================================
// CONTRATO DE DATOS: PLANES Y SOLICITUDES
// plan_requests: driverId, driverName, driverPhone, planId, planName, amount,
//                days, priority, receiptUrl, notes, status ('pending'|'approved'|'rejected'),
//                rejectReason, lastWarning, lastWarningAt, lastWarningBy,
//                createdAt, reviewedBy, reviewedAt.
// driver_plans:  planId, planName, priority, startsAt, expiresAt, status ('active'|'expired'),
//                activatedBy, updatedAt. (ID del documento = driverId)
// drivers:       planPaymentStatus ('pending'|'active'|'rejected'), activePlanId, planExpiresAt
// ============================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import '../../models/driver_plan_model.dart';
import '../../models/plan_model.dart';
import '../widgets/document_viewer_dialog.dart';
import '../widgets/edit_plan_dialog.dart';
import '../utils/plan_reject_reasons.dart';
import 'shared_admin_widgets.dart';

class PlansModule extends StatefulWidget {
  final bool canEdit;
  const PlansModule({super.key, required this.canEdit});

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
                  final reviewedAt = (req['reviewedAt'] as Timestamp?)?.toDate();
                  final status = req['status'] ?? 'pending';
                  final receiptUrl = req['receiptUrl']?.toString() ?? '';
                  final driverName = req['driverName']?.toString() ?? 'Sin nombre';

                  Color badgeColor = Colors.orange;
                  String badgeText = 'Pendiente';
                  if (status == 'approved') {
                    badgeColor = Colors.green;
                    badgeText = 'Aprobada';
                  } else if (status == 'rejected') {
                    badgeColor = Colors.red;
                    badgeText = 'Rechazada';
                  }

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () => DocumentViewerDialog.show(
                                  context,
                                  url: receiptUrl,
                                  title: 'Comprobante - $driverName',
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    receiptUrl,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 60,
                                      height: 60,
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.receipt_long, color: Colors.grey),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            driverName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        AdminBadge(badgeText, badgeColor),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Plan ${req['planName']} · S/ ${req['amount']} · ${req['driverPhone'] ?? ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _timeAgo(createdAt),
                                      style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                                    ),
                                    if (status != 'pending' && req['reviewedBy'] != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        reviewedAt != null
                                            ? 'Por: ${req['reviewedBy']} el ${_formatDate(reviewedAt)}'
                                            : 'Por: ${req['reviewedBy']}',
                                        style: const TextStyle(fontSize: 11, color: Colors.black45),
                                      ),
                                    ],
                                    if (req['lastWarning'] != null && (req['lastWarning'] as String).isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Aviso enviado ${_timeAgo((req['lastWarningAt'] as Timestamp?)?.toDate() ?? createdAt)}: ${req['lastWarning']}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                    if (status == 'rejected' && req['rejectReason'] != null && (req['rejectReason'] as String).isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Motivo: ${req['rejectReason']}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: MijanoTheme.ink,
                                  side: const BorderSide(color: Colors.black26),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                icon: const Icon(Icons.visibility, size: 18),
                                label: const Text('Ver Doc'),
                                onPressed: () => DocumentViewerDialog.show(
                                  context,
                                  url: receiptUrl,
                                  title: 'Comprobante - $driverName',
                                ),
                              ),
                              if (status == 'pending')
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: MijanoTheme.sol,
                                    foregroundColor: MijanoTheme.ink,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  icon: const Icon(Icons.rate_review, size: 18),
                                  label: const Text('Revisar Solicitud'),
                                  onPressed: () => _showReceiptDialog(req),
                                ),
                            ],
                          ),
                        ],
                      ),
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
    final detailCtrl = TextEditingController();
    String? selectedReason = PlanRejectReasons.reasons.first;
    bool isProcessing = false;
    final receiptUrl = req['receiptUrl']?.toString() ?? '';

    String getEffectiveReason() {
      final detail = detailCtrl.text.trim();
      if (selectedReason == PlanRejectReasons.other) {
        return detail;
      }
      if (detail.isNotEmpty) {
        return '$selectedReason ($detail)';
      }
      return selectedReason ?? '';
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final lastWarningAt = (req['lastWarningAt'] as Timestamp?)?.toDate();

          return AlertDialog(
            title: Text('Revisar Solicitud: ${req['driverName']}'),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 550,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plan: ${req['planName']} - S/ ${req['amount']} (${req['days']} días)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    if (req['driverPhone'] != null) ...[
                      const SizedBox(height: 4),
                      Text('Teléfono: ${req['driverPhone']}', style: const TextStyle(color: Colors.black87)),
                    ],
                    if (req['notes'] != null && (req['notes'] as String).trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Nota: ${req['notes']}', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black54)),
                    ],
                    if (req['lastWarning'] != null && (req['lastWarning'] as String).isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Aviso enviado hace ${_timeAgo(lastWarningAt ?? DateTime.now())} por ${req['lastWarningBy'] ?? 'Admin'}:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber.shade900),
                            ),
                            const SizedBox(height: 2),
                            Text(req['lastWarning'].toString(), style: const TextStyle(fontSize: 13, color: Colors.black87)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => DocumentViewerDialog.show(
                        context,
                        url: receiptUrl,
                        title: 'Comprobante - ${req['driverName']}',
                      ),
                      child: Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                receiptUrl,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                      SizedBox(height: 8),
                                      Text('No se pudo cargar la imagen', style: TextStyle(color: Colors.black54)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.zoom_in, color: Colors.white, size: 16),
                                    SizedBox(width: 4),
                                    Text('Toca para ampliar', style: TextStyle(color: Colors.white, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (req['status'] == 'pending') ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedReason,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Motivo / Indicación',
                          border: OutlineInputBorder(),
                        ),
                        items: PlanRejectReasons.reasons
                            .map((r) => DropdownMenuItem(
                                  value: r,
                                  child: Text(r, overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (v) => setStateDialog(() => selectedReason = v),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: detailCtrl,
                        maxLines: selectedReason == PlanRejectReasons.other ? 3 : 1,
                        decoration: InputDecoration(
                          labelText: selectedReason == PlanRejectReasons.other
                              ? 'Escribe el motivo detallado'
                              : 'Detalle adicional (opcional)',
                          border: const OutlineInputBorder(),
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
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: isProcessing ? null : () => Navigator.pop(dialogCtx),
                    child: const Text('Cerrar', style: TextStyle(color: Colors.black54)),
                  ),
                  if (req['status'] == 'pending') ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.amber.shade900,
                        side: BorderSide(color: Colors.amber.shade700),
                      ),
                      onPressed: isProcessing ? null : () async {
                        final reason = getEffectiveReason();
                        if (reason.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Debes seleccionar o escribir un motivo/indicación')),
                          );
                          return;
                        }
                        setStateDialog(() => isProcessing = true);
                        try {
                          await fs.notifyPlanRequestIssue(req, reason, 'Admin');
                          if (context.mounted) {
                            Navigator.pop(dialogCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Aviso enviado al conductor'), backgroundColor: Colors.amber),
                            );
                          }
                        } catch (e) {
                          setStateDialog(() => isProcessing = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        }
                      },
                      icon: const Icon(Icons.warning_amber, size: 16),
                      label: const Text('Avisar al conductor'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      onPressed: isProcessing ? null : () async {
                        final reason = getEffectiveReason();
                        if (reason.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Debes seleccionar o escribir un motivo para rechazar')),
                          );
                          return;
                        }

                        final confirm = await adminConfirm(
                          context,
                          title: 'Rechazar solicitud',
                          body: '¿Estás seguro de rechazar la solicitud de ${req['driverName']}?',
                          danger: true,
                          action: 'Rechazar',
                        );
                        if (!confirm) return;

                        setStateDialog(() => isProcessing = true);
                        try {
                          await fs.rejectPlanRequest(req, reason, 'Admin');
                          if (context.mounted) {
                            Navigator.pop(dialogCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Solicitud rechazada'), backgroundColor: Colors.red),
                            );
                          }
                        } catch (e) {
                          setStateDialog(() => isProcessing = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        }
                      },
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Rechazar'),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MijanoTheme.sol,
                        foregroundColor: MijanoTheme.ink,
                      ),
                      onPressed: isProcessing ? null : () async {
                        setStateDialog(() => isProcessing = true);
                        try {
                          await fs.approvePlanRequest(req, 'Admin');
                          if (context.mounted) {
                            Navigator.pop(dialogCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Plan activado correctamente'), backgroundColor: Colors.green),
                            );
                          }
                        } catch (e) {
                          setStateDialog(() => isProcessing = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        }
                      },
                      icon: isProcessing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: MijanoTheme.ink))
                          : const Icon(Icons.check, size: 16),
                      label: const Text('Aprobar y activar plan'),
                    ),
                  ],
                ],
              ),
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
        final rawPlans = snap.data ?? [];

        if (rawPlans.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('No hay planes configurados en la base de datos.'),
                if (widget.canEdit) ...[
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      await fs.seedDefaultPlans();
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Planes por defecto creados')));
                    },
                    child: const Text('Cargar planes por defecto'),
                  ),
                ],
              ],
            ),
          );
        }

        final plans = rawPlans.map((p) => PlanModel.fromMap(p, p['id'])).toList();

        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 380,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            mainAxisExtent: 290,
          ),
          itemCount: plans.length,
          itemBuilder: (context, i) {
            final plan = plans[i];

            return adminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(plan.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: MijanoTheme.ink)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (plan.isActive)
                            const AdminBadge('Activo', Colors.green)
                          else
                            const AdminBadge('Inactivo', Colors.red),
                          if (widget.canEdit) ...[
                            const SizedBox(width: 8),
                            Switch(
                              value: plan.isActive,
                              activeColor: Colors.green,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              onChanged: (val) async {
                                if (!val) {
                                  final confirm = await adminConfirm(
                                    context,
                                    title: 'Desactivar plan',
                                    body: '¿Desactivar el plan ${plan.name}? Los conductores ya no podrán seleccionar este plan.',
                                    danger: true,
                                    action: 'Desactivar',
                                  );
                                  if (!confirm) return;
                                }
                                await fs.togglePlanActive(plan.id, val, 'SuperAdmin');
                              },
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('S/ ${plan.price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: MijanoTheme.sol)),
                  Text('Duración: ${plan.durationDays} ${plan.durationDays == 1 ? "día" : "días"}', style: const TextStyle(color: Colors.black54)),
                  const Divider(height: 20),
                  const Text('Beneficios:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ListView.builder(
                      itemCount: plan.benefits.length,
                      itemBuilder: (ctx, j) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check, size: 16, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(child: Text(plan.benefits[j], style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (widget.canEdit) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MijanoTheme.ink,
                          side: const BorderSide(color: Colors.black26),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Editar'),
                        onPressed: () => EditPlanDialog.show(context, plan),
                      ),
                    ),
                  ],
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
