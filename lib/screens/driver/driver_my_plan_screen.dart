import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/plan_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import 'driver_plan_payment_screen.dart';

class DriverPlanHelper {
  static String formatPlanTitle(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return 'Plan Activo';
    if (trimmed.toLowerCase().startsWith('plan ')) {
      return trimmed;
    }
    return 'Plan $trimmed';
  }

  static String resolvePlanName({
    Map<String, dynamic>? driverData,
    Map<String, dynamic>? driverPlanData,
    List<PlanModel> plans = const [],
  }) {
    // 1. Nombre directo en driver_plans o drivers
    final directName =
        (driverPlanData?['planName'] ?? driverData?['planName'])
            ?.toString()
            .trim();
    if (directName != null &&
        directName.isNotEmpty &&
        directName.toLowerCase() != 'plan activo') {
      return formatPlanTitle(directName);
    }

    // 2. Por ID del plan
    final activePlanId =
        (driverData?['activePlanId'] ?? driverPlanData?['planId'])
            ?.toString()
            .trim();
    if (activePlanId != null && activePlanId.isNotEmpty) {
      for (final p in plans) {
        if (p.id == activePlanId && p.name.trim().isNotEmpty) {
          return formatPlanTitle(p.name);
        }
      }
      final lowerId = activePlanId.toLowerCase();
      if (lowerId.contains('mensual')) return 'Plan Mensual';
      if (lowerId.contains('semanal')) return 'Plan Semanal';
      if (lowerId.contains('diario')) return 'Plan Diario';
    }

    // 3. Por tier explícito
    final tier = (driverData?['planTier'] ?? driverPlanData?['tier'])
        ?.toString()
        .toLowerCase()
        .trim();
    if (tier != null && tier.isNotEmpty) {
      if (tier.contains('mensual')) return 'Plan Mensual';
      if (tier.contains('semanal')) return 'Plan Semanal';
      if (tier.contains('diario')) return 'Plan Diario';
    }

    // 4. Inferencia por duración o tiempo restante
    final expiresAt =
        (driverData?['planExpiresAt'] as Timestamp?)?.toDate() ??
        (driverPlanData?['expiresAt'] as Timestamp?)?.toDate();
    final startsAt = (driverPlanData?['startsAt'] as Timestamp?)?.toDate();

    if (expiresAt != null) {
      final totalDays = startsAt != null
          ? expiresAt.difference(startsAt).inDays
          : expiresAt.difference(DateTime.now()).inDays;
      if (totalDays > 8) return 'Plan Mensual';
      if (totalDays > 1) return 'Plan Semanal';
      return 'Plan Diario';
    }

    return 'Plan Activo';
  }

  static bool isPlanCurrent({
    required PlanModel plan,
    required bool hasActivePlan,
    Map<String, dynamic>? driverData,
    Map<String, dynamic>? driverPlanData,
    required String resolvedCurrentPlanName,
  }) {
    if (!hasActivePlan) return false;

    final activePlanId =
        (driverData?['activePlanId'] ?? driverPlanData?['planId'])
            ?.toString()
            .trim();
    if (activePlanId != null && activePlanId.isNotEmpty) {
      if (plan.id == activePlanId) return true;
    }

    final formattedOption = formatPlanTitle(plan.name).toLowerCase();
    if (formattedOption == resolvedCurrentPlanName.toLowerCase()) {
      return true;
    }

    final tier = (driverData?['planTier'] ?? driverPlanData?['tier'])
        ?.toString()
        .toLowerCase()
        .trim();
    if (tier != null &&
        tier.isNotEmpty &&
        plan.tier.toLowerCase() == tier) {
      return true;
    }

    return false;
  }

  static String formatRemainingTime(DateTime? expiresAt) {
    if (expiresAt == null) return '';
    final diff = expiresAt.difference(DateTime.now());
    if (diff.isNegative) return 'Plan expirado';
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    if (days > 0) {
      return '$days d $hours h restantes';
    }
    if (hours > 0) {
      return '$hours h $minutes min restantes';
    }
    return '${minutes.clamp(1, 59)} min restantes';
  }
}

class DriverMyPlanScreen extends StatelessWidget {
  const DriverMyPlanScreen({super.key});

  String get _uid =>
      FirebaseAuth.instance.currentUser?.uid ??
      AuthService.instance.currentUser?.uid ??
      'demo-driver';

  @override
  Widget build(BuildContext context) {
    final uid = _uid;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      appBar: AppBar(
        backgroundColor: MijanoTheme.sol,
        foregroundColor: MijanoTheme.ink,
        elevation: 0,
        title: const Text(
          'Mi Plan y Planes Disponibles',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: MijanoTheme.ink,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('drivers')
            .doc(uid)
            .snapshots(),
        builder: (context, driverSnap) {
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('driver_plans')
                .doc(uid)
                .snapshots(),
            builder: (context, driverPlanSnap) {
              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: FirestoreService.instance.streamPlans(),
                builder: (context, plansSnap) {
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('plan_requests')
                        .where('driverId', isEqualTo: uid)
                        .snapshots(),
                    builder: (context, requestsSnap) {
                      final driverData = driverSnap.data?.data();
                      final driverPlanData = driverPlanSnap.data?.data();

                      final rawPlans = plansSnap.data ?? [];
                      final plans = rawPlans
                          .map((e) => PlanModel.fromMap(e, e['id']))
                          .where((p) => p.isActive)
                          .toList()
                        ..sort((a, b) => a.priority.compareTo(b.priority));

                      final expiresAt =
                          (driverData?['planExpiresAt'] as Timestamp?)
                              ?.toDate() ??
                          (driverPlanData?['expiresAt'] as Timestamp?)
                              ?.toDate();
                      final startsAt =
                          (driverPlanData?['startsAt'] as Timestamp?)?.toDate();

                      final hasNotExpired =
                          expiresAt != null &&
                          expiresAt.isAfter(DateTime.now());
                      final hasActivePlan =
                          (driverData?['planPaymentStatus'] == 'active' ||
                              driverPlanData?['status'] == 'active') &&
                          hasNotExpired;

                      final currentPlanName =
                          DriverPlanHelper.resolvePlanName(
                            driverData: driverData,
                            driverPlanData: driverPlanData,
                            plans: plans,
                          );

                      final remainingText =
                          DriverPlanHelper.formatRemainingTime(expiresAt);

                      // Verificar si hay solicitud de migración/activación pendiente
                      final reqDocs = requestsSnap.data?.docs ?? [];
                      final pendingDocs = reqDocs
                          .where((d) => d.data()['status'] == 'pending')
                          .toList();
                      final hasPendingRequest = pendingDocs.isNotEmpty;
                      final pendingPlanName = hasPendingRequest
                          ? (pendingDocs.first.data()['planName']?.toString() ??
                                'Nuevo plan')
                          : null;

                      // Encontrar el modelo del plan actual si coincide con la lista
                      PlanModel? currentPlanModel;
                      for (final p in plans) {
                        if (DriverPlanHelper.isPlanCurrent(
                          plan: p,
                          hasActivePlan: hasActivePlan,
                          driverData: driverData,
                          driverPlanData: driverPlanData,
                          resolvedCurrentPlanName: currentPlanName,
                        )) {
                          currentPlanModel = p;
                          break;
                        }
                      }

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ==========================================
                            // SECCIÓN 1: TU PLAN ACTUAL
                            // ==========================================
                            const Text(
                              'Tu Plan Actual',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: MijanoTheme.ink,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildCurrentPlanCard(
                              context: context,
                              hasActivePlan: hasActivePlan,
                              currentPlanName: currentPlanName,
                              remainingText: remainingText,
                              startsAt: startsAt,
                              expiresAt: expiresAt,
                              currentPlanModel: currentPlanModel,
                              hasPendingRequest: hasPendingRequest,
                              pendingPlanName: pendingPlanName,
                            ),

                            if (hasPendingRequest) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.amber.shade700,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.hourglass_top_rounded,
                                      color: Colors.amber.shade900,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Solicitud en revisión: ${DriverPlanHelper.formatPlanTitle(pendingPlanName ?? '')}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                              color: Colors.amber.shade900,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          const Text(
                                            'Tu comprobante fue enviado. El administrador validará tu cambio de plan en breve.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 26),

                            // ==========================================
                            // SECCIÓN 2: TODOS LOS PLANES Y MIGRACIÓN
                            // ==========================================
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Todos los Planes Disponibles',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: MijanoTheme.ink,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Compara beneficios y migra a otro plan cuando quieras',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            if (plansSnap.connectionState ==
                                    ConnectionState.waiting &&
                                plans.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(32),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: MijanoTheme.sol,
                                  ),
                                ),
                              )
                            else if (plans.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.black12),
                                ),
                                child: const Center(
                                  child: Text(
                                    'No hay planes disponibles en este momento.',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ),
                              )
                            else
                              for (final plan in plans) ...[
                                _buildPlanCard(
                                  context: context,
                                  plan: plan,
                                  isCurrent: DriverPlanHelper.isPlanCurrent(
                                    plan: plan,
                                    hasActivePlan: hasActivePlan,
                                    driverData: driverData,
                                    driverPlanData: driverPlanData,
                                    resolvedCurrentPlanName: currentPlanName,
                                  ),
                                  hasActivePlan: hasActivePlan,
                                  hasPendingRequest: hasPendingRequest,
                                ),
                                const SizedBox(height: 14),
                              ],
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCurrentPlanCard({
    required BuildContext context,
    required bool hasActivePlan,
    required String currentPlanName,
    required String remainingText,
    required DateTime? startsAt,
    required DateTime? expiresAt,
    required PlanModel? currentPlanModel,
    required bool hasPendingRequest,
    required String? pendingPlanName,
  }) {
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    if (!hasActivePlan) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MijanoTheme.sol, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_outlined,
                    color: MijanoTheme.sol,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasPendingRequest
                            ? 'Solicitud en validación'
                            : 'Sin plan activo actualmente',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasPendingRequest
                            ? 'Esperando aprobación para ${DriverPlanHelper.formatPlanTitle(pendingPlanName ?? '')}'
                            : 'Elige uno de los planes de abajo para activarte y recibir viajes.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MijanoTheme.sol, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 14),
                    SizedBox(width: 5),
                    Text(
                      'EN USO ACTUALMENTE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              if (currentPlanModel != null)
                Text(
                  'S/ ${currentPlanModel.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: MijanoTheme.sol,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: MijanoTheme.sol,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.card_membership,
                  color: MijanoTheme.ink,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentPlanName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      remainingText,
                      style: const TextStyle(
                        color: MijanoTheme.sol,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (expiresAt != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_available,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      startsAt != null
                          ? 'Inicio: ${dateFmt.format(startsAt.toLocal())}  •  Vence: ${dateFmt.format(expiresAt.toLocal())}'
                          : 'Vence el: ${dateFmt.format(expiresAt.toLocal())}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (currentPlanModel != null &&
              currentPlanModel.benefits.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: currentPlanModel.benefits.map((b) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check,
                        size: 13,
                        color: MijanoTheme.sol,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        b,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required BuildContext context,
    required PlanModel plan,
    required bool isCurrent,
    required bool hasActivePlan,
    required bool hasPendingRequest,
  }) {
    final planTitle = DriverPlanHelper.formatPlanTitle(plan.name);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isCurrent ? const Color(0xFFFFFBEA) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrent ? MijanoTheme.ink : Colors.black12,
          width: isCurrent ? 2 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            planTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: MijanoTheme.ink,
                            ),
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade700,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Plan Actual',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Duración: ${plan.durationDays} ${plan.durationDays == 1 ? "día" : "días"}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'S/ ${plan.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: MijanoTheme.ink,
                ),
              ),
            ],
          ),
          if (plan.benefits.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            for (final benefit in plan.benefits)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: isCurrent
                          ? Colors.green.shade700
                          : MijanoTheme.solDeep,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        benefit,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: isCurrent
                ? OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MijanoTheme.ink,
                      side: const BorderSide(color: MijanoTheme.ink, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: hasPendingRequest
                        ? null
                        : () => _openMigrationOrPayment(
                            context,
                            plan: plan,
                            isMigration: false,
                          ),
                    icon: const Icon(Icons.autorenew, size: 18),
                    label: const Text(
                      'Renovar / Extender mi plan actual',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  )
                : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MijanoTheme.sol,
                      foregroundColor: MijanoTheme.ink,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: hasPendingRequest
                        ? null
                        : () => _openMigrationOrPayment(
                            context,
                            plan: plan,
                            isMigration: hasActivePlan,
                          ),
                    icon: Icon(
                      hasActivePlan ? Icons.swap_horiz_rounded : Icons.bolt,
                      size: 20,
                    ),
                    label: Text(
                      hasActivePlan
                          ? 'Migrar a $planTitle'
                          : 'Activar $planTitle',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMigrationOrPayment(
    BuildContext context, {
    required PlanModel plan,
    required bool isMigration,
  }) async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => DriverPlanPaymentScreen(
          initialPlanId: plan.id,
          isMigration: isMigration,
        ),
      ),
    );

    if (submitted == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Text(
            isMigration
                ? 'Solicitud de migración a ${DriverPlanHelper.formatPlanTitle(plan.name)} enviada.'
                : 'Comprobante enviado correctamente.',
          ),
        ),
      );
    }
  }
}
