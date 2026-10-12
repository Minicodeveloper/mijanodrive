import 'package:flutter/material.dart';
import '../../models/plan_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import '../modules/shared_admin_widgets.dart';

class EditPlanDialog extends StatefulWidget {
  final PlanModel plan;

  const EditPlanDialog({super.key, required this.plan});

  static Future<bool?> show(BuildContext context, PlanModel plan) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => EditPlanDialog(plan: plan),
    );
  }

  @override
  State<EditPlanDialog> createState() => _EditPlanDialogState();
}

class _EditPlanDialogState extends State<EditPlanDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _daysController;
  final _newBenefitController = TextEditingController();

  late bool _isActive;
  late int _priority;
  late List<String> _benefits;

  bool _isSaving = false;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.plan.name);
    _priceController = TextEditingController(text: widget.plan.price.toString());
    _daysController = TextEditingController(text: widget.plan.durationDays.toString());
    _isActive = widget.plan.isActive;
    _priority = widget.plan.priority;
    _benefits = List<String>.from(widget.plan.benefits);

    _nameController.addListener(_markDirty);
    _priceController.addListener(_markDirty);
    _daysController.addListener(_markDirty);
  }

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _daysController.dispose();
    _newBenefitController.dispose();
    super.dispose();
  }

  void _addBenefit() {
    final text = _newBenefitController.text.trim();
    if (text.isEmpty) return;
    if (_benefits.length >= 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Máximo 8 beneficios por plan')),
      );
      return;
    }
    if (text.length > 60) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El beneficio no puede superar los 60 caracteres')),
      );
      return;
    }
    setState(() {
      _benefits.add(text);
      _newBenefitController.clear();
      _isDirty = true;
    });
  }

  void _removeBenefit(int index) {
    setState(() {
      _benefits.removeAt(index);
      _isDirty = true;
    });
  }

  void _editBenefit(int index) {
    final controller = TextEditingController(text: _benefits[index]);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar beneficio'),
        content: TextField(
          controller: controller,
          maxLength: 60,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: MijanoTheme.sol, foregroundColor: MijanoTheme.ink),
            onPressed: () {
              final newText = controller.text.trim();
              if (newText.isNotEmpty && newText.length <= 60) {
                setState(() {
                  _benefits[index] = newText;
                  _isDirty = true;
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_benefits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes agregar al menos 1 beneficio')),
      );
      return;
    }

    final priceNum = double.parse(_priceController.text.trim().replaceAll(',', '.'));
    final daysNum = int.parse(_daysController.text.trim());

    final updatedPlan = PlanModel(
      id: widget.plan.id,
      name: _nameController.text.trim(),
      price: priceNum,
      durationDays: daysNum,
      priority: _priority,
      benefits: _benefits,
      isActive: _isActive,
    );

    setState(() => _isSaving = true);

    try {
      final adminName = AuthService.instance.currentUser?.name ?? 'SuperAdmin';
      await FirestoreService.instance.updatePlan(updatedPlan, adminName);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plan actualizado correctamente'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar el plan: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _closeDialog() async {
    if (!_isDirty || _isSaving) {
      Navigator.pop(context, false);
      return;
    }
    final leave = await adminConfirm(
      context,
      title: 'Cambios sin guardar',
      body: '¿Deseas salir sin guardar los cambios en el plan?',
      action: 'Salir sin guardar',
      danger: true,
    );
    if (leave && mounted) {
      Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return PopScope(
      canPop: !_isDirty && !_isSaving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isDirty && !_isSaving) {
          _closeDialog();
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: maxHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Editar Plan: ${widget.plan.name}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: MijanoTheme.ink,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _closeDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Nota de negocio
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Los cambios aplican a nuevas solicitudes; las pendientes conservan el precio con el que se enviaron.',
                            style: TextStyle(fontSize: 11, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Nombre del Plan',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa un nombre' : null,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _priceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Precio (S/)',
                                    border: OutlineInputBorder(),
                                    prefixText: 'S/ ',
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Requerido';
                                    final clean = v.trim().replaceAll(',', '.');
                                    final val = double.tryParse(clean);
                                    if (val == null || val <= 0) return 'Precio inválido (> 0)';
                                    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(clean)) {
                                      return 'Máx. 2 decimales';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _daysController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Duración (días)',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Requerido';
                                    final val = int.tryParse(v.trim());
                                    if (val == null || val <= 0) return 'Días inválidos (> 0)';
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Plan Activo', style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: const Text('Los conductores solo pueden solicitar planes activos'),
                            value: _isActive,
                            activeColor: Colors.green,
                            onChanged: (val) {
                              setState(() {
                                _isActive = val;
                                _isDirty = true;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Beneficios:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Text('${_benefits.length}/8', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _newBenefitController,
                                  maxLength: 60,
                                  decoration: const InputDecoration(
                                    hintText: 'Añadir nuevo beneficio...',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    counterText: '',
                                  ),
                                  onSubmitted: (_) => _addBenefit(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: MijanoTheme.ink,
                                  foregroundColor: MijanoTheme.sol,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                                onPressed: _benefits.length < 8 ? _addBenefit : null,
                                child: const Text('Agregar'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_benefits.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('Sin beneficios registrados.', style: TextStyle(color: Colors.red, fontSize: 12)),
                            )
                          else
                            ReorderableListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _benefits.length,
                              onReorder: (oldIndex, newIndex) {
                                setState(() {
                                  if (newIndex > oldIndex) newIndex -= 1;
                                  final item = _benefits.removeAt(oldIndex);
                                  _benefits.insert(newIndex, item);
                                  _isDirty = true;
                                });
                              },
                              itemBuilder: (context, index) {
                                final b = _benefits[index];
                                return Card(
                                  key: ValueKey('benefit_$index\_$b'),
                                  margin: const EdgeInsets.only(bottom: 6),
                                  child: ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.drag_handle, color: Colors.black38),
                                    title: Text(b, style: const TextStyle(fontSize: 13)),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                          onPressed: () => _editBenefit(index),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                          onPressed: () => _removeBenefit(index),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _isSaving ? null : _closeDialog,
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MijanoTheme.sol,
                          foregroundColor: MijanoTheme.ink,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: MijanoTheme.ink))
                            : const Icon(Icons.save, size: 18),
                        label: const Text('Guardar Cambios'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
