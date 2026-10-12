import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/plan_model.dart';
import '../../services/document_service.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';

class DriverPlanPaymentScreen extends StatefulWidget {
  const DriverPlanPaymentScreen({super.key});

  @override
  State<DriverPlanPaymentScreen> createState() =>
      _DriverPlanPaymentScreenState();
}

class _DriverPlanPaymentScreenState extends State<DriverPlanPaymentScreen> {
  final _picker = ImagePicker();
  final _notesController = TextEditingController();
  PlanModel? _selectedPlan;
  File? _receipt;
  Uint8List? _receiptBytes;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La imagen supera los 5 MB'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _receipt = File(image.path);
      _receiptBytes = bytes;
    });
  }

  Future<void> _submitPayment() async {
    final bytes = _receiptBytes;
    final selectedPlan = _selectedPlan;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (selectedPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un plan')),
      );
      return;
    }
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adjunta el comprobante de pago')),
      );
      return;
    }
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesión para enviar el pago')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Verificación de solicitud pendiente para evitar duplicados
      final pendingSnap = await FirebaseFirestore.instance
          .collection('plan_requests')
          .where('driverId', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .get();

      if (pendingSnap.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ya tienes una solicitud de plan pendiente de revisión.'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      // Subir comprobante a Storage plan_receipts/{uid}/{timestamp}.jpg
      final receiptUrl =
          await DocumentService.instance.uploadReceipt(uid, bytes);

      // Crear solicitud en plan_requests
      await FirestoreService.instance.createPlanRequest({
        'driverId': uid,
        'planId': selectedPlan.id,
        'planName': selectedPlan.name,
        'amount': selectedPlan.price,
        'days': selectedPlan.durationDays,
        'priority': selectedPlan.priority,
        'receiptUrl': receiptUrl,
        if (_notesController.text.trim().isNotEmpty)
          'notes': _notesController.text.trim(),
      });

      // Actualizar estado en la colección drivers
      await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
        'isAvailable': false,
        'planPaymentStatus': 'pending',
        'pendingPlanId': selectedPlan.id,
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comprobante enviado correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar el comprobante: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      appBar: AppBar(
        title: const Text('Activa tus viajes'),
        backgroundColor: const Color(0xFFFAF8FF),
        foregroundColor: MijanoTheme.ink,
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: FirestoreService.instance.streamPlans(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: MijanoTheme.sol),
              );
            }

            if (snapshot.hasError) {
              return const Center(
                child: Text('Error al cargar los planes disponibles.'),
              );
            }

            final rawPlans = snapshot.data ?? [];
            final plans = rawPlans
                .map((e) => PlanModel.fromMap(e, e['id']))
                .where((p) => p.isActive)
                .toList()
              ..sort((a, b) => a.priority.compareTo(b.priority));

            if (plans.isEmpty) {
              return const Center(
                child: Text('No hay planes disponibles por el momento.'),
              );
            }

            // Seleccionar el primer plan disponible por defecto si no hay selección
            if (_selectedPlan == null ||
                !plans.any((p) => p.id == _selectedPlan!.id)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && plans.isNotEmpty) {
                  setState(() => _selectedPlan = plans.first);
                }
              });
            }

            final activePlan = _selectedPlan ?? plans.first;

            return StreamBuilder<QuerySnapshot>(
              stream: uid != null
                  ? FirebaseFirestore.instance
                      .collection('plan_requests')
                      .where('driverId', isEqualTo: uid)
                      .snapshots()
                  : null,
              builder: (context, requestsSnap) {
                final docs = requestsSnap.data?.docs ?? [];
                final pendingDocs = docs.where((d) => d['status'] == 'pending').toList();
                final hasPending = pendingDocs.isNotEmpty;

                String? rejectReason;
                if (!hasPending) {
                  final rejectedDocs = docs.where((d) => d['status'] == 'rejected').toList();
                  if (rejectedDocs.isNotEmpty) {
                    rejectedDocs.sort((a, b) {
                      final aTime = (a.data() as Map)['createdAt'] as Timestamp?;
                      final bTime = (b.data() as Map)['createdAt'] as Timestamp?;
                      if (aTime == null || bTime == null) return 0;
                      return bTime.compareTo(aTime);
                    });
                    final lastDoc = rejectedDocs.first.data() as Map<String, dynamic>;
                    rejectReason = lastDoc['rejectReason']?.toString();
                  }
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (hasPending) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.shade700),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.hourglass_top, color: Colors.amber),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Tienes una solicitud de plan en revisión por el administrador.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ] else if (rejectReason != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.error_outline, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text(
                                    'Tu solicitud anterior fue rechazada',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              if (rejectReason.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Motivo: $rejectReason',
                                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                                ),
                              ],
                              const SizedBox(height: 8),
                              const Text(
                                'Selecciona un plan y vuelve a enviar tu comprobante:',
                                style: TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      const Text(
                        'Elige tu plan',
                        style: TextStyle(
                          color: MijanoTheme.ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Paga con Plin y adjunta el comprobante para validar tu cuenta.',
                        style: TextStyle(color: Colors.black54, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      for (final plan in plans) ...[
                        _PlanOption(
                          plan: plan,
                          isSelected: activePlan.id == plan.id,
                          onTap: hasPending
                              ? () {}
                              : () => setState(() => _selectedPlan = plan),
                        ),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 10),
                      _SectionLabel(
                        number: '1',
                        title: 'Paga S/ ${activePlan.price.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFECE8F4)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0D24203A),
                              blurRadius: 18,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            StreamBuilder<Map<String, dynamic>?>(
                              stream: FirestoreService.instance.streamPaymentQr(),
                              builder: (context, qrSnap) {
                                final qrData = qrSnap.data;
                                final qrUrl = qrData?['url'] as String?;

                                Widget qrWidget;
                                if (qrSnap.connectionState == ConnectionState.waiting) {
                                  qrWidget = const SizedBox(
                                    width: 224,
                                    height: 224,
                                    child: Center(
                                      child: CircularProgressIndicator(color: MijanoTheme.sol),
                                    ),
                                  );
                                } else if (qrUrl != null && qrUrl.isNotEmpty) {
                                  qrWidget = CachedNetworkImage(
                                    imageUrl: qrUrl,
                                    width: 224,
                                    height: 224,
                                    fit: BoxFit.contain,
                                    placeholder: (_, __) => const SizedBox(
                                      width: 224,
                                      height: 224,
                                      child: Center(
                                        child: CircularProgressIndicator(color: MijanoTheme.sol),
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) => Image.asset(
                                      'assets/images/driver_payment_qr.jpeg',
                                      width: 224,
                                      height: 224,
                                      fit: BoxFit.contain,
                                    ),
                                  );
                                } else {
                                  qrWidget = Image.asset(
                                    'assets/images/driver_payment_qr.jpeg',
                                    width: 224,
                                    height: 224,
                                    fit: BoxFit.contain,
                                  );
                                }

                                return GestureDetector(
                                  onTap: () {
                                    if (qrUrl != null && qrUrl.isNotEmpty) {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => Dialog(
                                          child: InteractiveViewer(
                                            child: CachedNetworkImage(
                                              imageUrl: qrUrl,
                                              fit: BoxFit.contain,
                                              errorWidget: (_, __, ___) => Image.asset(
                                                'assets/images/driver_payment_qr.jpeg',
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    } else {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => Dialog(
                                          child: InteractiveViewer(
                                            child: Image.asset(
                                              'assets/images/driver_payment_qr.jpeg',
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: qrWidget,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Paga aquí con Plin',
                              style: TextStyle(
                                color: MijanoTheme.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _SectionLabel(
                          number: '2', title: 'Adjunta tu comprobante'),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: (hasPending || _isSubmitting)
                            ? null
                            : _pickReceipt,
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          height: 156,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2EFFF),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: _receipt == null
                                  ? const Color(0xFFDCD5F1)
                                  : MijanoTheme.solDeep,
                            ),
                          ),
                          child: _receipt == null
                              ? const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 38,
                                      color: MijanoTheme.solDeep,
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      'Toca para adjuntar una imagen',
                                      style: TextStyle(
                                        color: MijanoTheme.ink,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'JPG o PNG (máx. 5 MB)',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(21),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.file(_receipt!, fit: BoxFit.cover),
                                      Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Container(
                                          width: double.infinity,
                                          color: Colors.black54,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          child: const Text(
                                            'Toca para cambiar la imagen',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Notas adicionales (opcional)',
                        style: TextStyle(
                          color: MijanoTheme.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesController,
                        enabled: !hasPending && !_isSubmitting,
                        maxLines: 3,
                        maxLength: 240,
                        decoration: InputDecoration(
                          hintText:
                              'Ej.: pago realizado desde una cuenta de terceros',
                          filled: true,
                          fillColor: const Color(0xFFF2EFFF),
                          border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: (hasPending || _isSubmitting)
                              ? null
                              : _submitPayment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MijanoTheme.ink,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  hasPending
                                      ? 'Solicitud en revisión'
                                      : 'Enviar comprobante',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Tu disponibilidad se activará cuando el administrador valide el pago.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _PlanOption extends StatelessWidget {
  const _PlanOption({
    required this.plan,
    required this.isSelected,
    required this.onTap,
  });

  final PlanModel plan;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? const Color(0xFFFFF8E1) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? MijanoTheme.solDeep : const Color(0xFFECE8F4),
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: isSelected ? MijanoTheme.solDeep : Colors.black38,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          style: const TextStyle(
                            color: MijanoTheme.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${plan.durationDays} ${plan.durationDays == 1 ? "día" : "días"}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'S/ ${plan.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: MijanoTheme.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (plan.benefits.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Text(
                    plan.benefits.join(' · '),
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black87),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.number, required this.title});

  final String number;
  final String title;

  @override  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: MijanoTheme.sol,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: MijanoTheme.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: MijanoTheme.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
