import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth_service.dart';
import '../../theme.dart';

class DriverPlanPaymentScreen extends StatefulWidget {
  const DriverPlanPaymentScreen({super.key});

  @override
  State<DriverPlanPaymentScreen> createState() =>
      _DriverPlanPaymentScreenState();
}

class _DriverPlan {
  const _DriverPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.durationDays,
  });

  final String id;
  final String name;
  final double price;
  final int durationDays;
}

class _DriverPlanPaymentScreenState extends State<DriverPlanPaymentScreen> {
  static const _plans = [
    _DriverPlan(
      id: 'daily',
      name: 'Plan diario',
      price: 2.50,
      durationDays: 1,
    ),
    _DriverPlan(
      id: 'weekly',
      name: 'Plan semanal',
      price: 15,
      durationDays: 7,
    ),
    _DriverPlan(
      id: 'monthly',
      name: 'Plan mensual',
      price: 50,
      durationDays: 30,
    ),
  ];

  static const _paymentNumber = '987 654 321';
  final _picker = ImagePicker();
  final _notesController = TextEditingController();
  _DriverPlan _selectedPlan = _plans.first;
  File? _receipt;
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
    if (image == null || !mounted) return;
    setState(() => _receipt = File(image.path));
  }

  Future<void> _copyPaymentNumber() async {
    await Clipboard.setData(const ClipboardData(text: _paymentNumber));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Número copiado')),
    );
  }

  Future<void> _submitPayment() async {
    final receipt = _receipt;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (receipt == null) {
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
    final paymentRef =
        FirebaseFirestore.instance.collection('driver_plan_payments').doc();
    final fileExtension =
        receipt.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('drivers')
        .child(uid)
        .child('plan-payment-${paymentRef.id}.$fileExtension');

    try {
      await storageRef.putFile(
        receipt,
        SettableMetadata(
          contentType: fileExtension == 'png' ? 'image/png' : 'image/jpeg',
        ),
      );
      final receiptUrl = await storageRef.getDownloadURL();
      final batch = FirebaseFirestore.instance.batch();
      batch.set(paymentRef, {
        'driverId': uid,
        'driverName': AuthService.instance.currentUser?.name ?? 'Conductor',
        'vehiclePlate': AuthService.instance.currentUser?.vehiclePlate ?? '',
        'planId': _selectedPlan.id,
        'planName': _selectedPlan.name,
        'amount': _selectedPlan.price,
        'durationDays': _selectedPlan.durationDays,
        'receiptUrl': receiptUrl,
        'notes': _notesController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(
        FirebaseFirestore.instance.collection('drivers').doc(uid),
        {
          'isAvailable': false,
          'planPaymentStatus': 'pending',
          'pendingPlanId': _selectedPlan.id,
        },
        SetOptions(merge: true),
      );
      await batch.commit();

      if (!mounted) return;
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
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      appBar: AppBar(
        title: const Text('Activa tus viajes'),
        backgroundColor: const Color(0xFFFAF8FF),
        foregroundColor: MijanoTheme.ink,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              for (final plan in _plans) ...[
                _PlanOption(
                  plan: plan,
                  isSelected: _selectedPlan.id == plan.id,
                  onTap: () => setState(() => _selectedPlan = plan),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 10),
              _SectionLabel(
                number: '1',
                title: 'Paga S/ ${_selectedPlan.price.toStringAsFixed(2)}',
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/images/driver_payment_qr.jpeg',
                        width: 224,
                        height: 224,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Paga aquí con Plin',
                      style: TextStyle(
                        color: MijanoTheme.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF8FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Número para Yape / Plin',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  _paymentNumber,
                                  style: TextStyle(
                                    color: MijanoTheme.ink,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Copiar número',
                            onPressed: _copyPaymentNumber,
                            icon: const Icon(
                              Icons.copy_rounded,
                              color: MijanoTheme.solDeep,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SectionLabel(
                number: '2',
                title: 'Adjunta tu comprobante',
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _isSubmitting ? null : _pickReceipt,
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
                              'JPG o PNG',
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
                                    style: TextStyle(color: Colors.white),
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
                maxLines: 3,
                maxLength: 240,
                decoration: InputDecoration(
                  hintText: 'Ej.: pago realizado desde una cuenta de terceros',
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
                  onPressed: _isSubmitting ? null : _submitPayment,
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
                      : const Text(
                          'Enviar comprobante',
                          style: TextStyle(fontWeight: FontWeight.w700),
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

  final _DriverPlan plan;
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
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected ? MijanoTheme.solDeep : Colors.black38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  plan.name,
                  style: const TextStyle(
                    color: MijanoTheme.ink,
                    fontWeight: FontWeight.w700,
                  ),
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
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.number, required this.title});

  final String number;
  final String title;

  @override
  Widget build(BuildContext context) {
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
