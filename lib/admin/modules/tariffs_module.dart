import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../services/firestore_service.dart';
import 'shared_admin_widgets.dart';

class TariffsModule extends StatefulWidget {
  const TariffsModule({super.key});

  @override
  State<TariffsModule> createState() => _TariffsModuleState();
}

class _TariffsModuleState extends State<TariffsModule> {
  final _firestore = FirestoreService.instance;

  Future<void> _editTariff(Map<String, dynamic> city) async {
    final baseController = TextEditingController(
      text: city['tariff_base']?.toString() ?? '',
    );
    final perKmController = TextEditingController(
      text: city['tariff_per_km']?.toString() ?? '',
    );
    final commissionController = TextEditingController(
      text: city['commission_percent']?.toString() ?? '',
    );
    final cityName = city['name']?.toString() ?? city['id'].toString();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        bool saving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Editar tarifas - $cityName'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: baseController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Tarifa base (S/)', prefixIcon: Icon(Icons.attach_money)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: perKmController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Precio por km (S/)', prefixIcon: Icon(Icons.route)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: commissionController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Comisión (%)', prefixIcon: Icon(Icons.percent)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final base = double.tryParse(baseController.text.trim());
                          final perKm = double.tryParse(perKmController.text.trim());
                          final commission = double.tryParse(commissionController.text.trim());

                          if (base == null || perKm == null || commission == null || base < 0 || perKm < 0 || commission < 0) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa valores numéricos válidos.')));
                            return;
                          }
                          setDialogState(() => saving = true);
                          try {
                            await _firestore.updateCity(
                              city['id'].toString(),
                              {'tariff_base': base, 'tariff_per_km': perKm, 'commission_percent': commission},
                            );
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext, true);
                            }
                          } catch (e) {
                            setDialogState(() => saving = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: MijanoTheme.sol, foregroundColor: MijanoTheme.ink),
                  child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    baseController.dispose();
    perKmController.dispose();
    commissionController.dispose();

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tarifas de $cityName actualizadas.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminHeader('Tarifas y comisiones', 'Configura precios por ciudad (geofencing)'),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _firestore.allCities(),
            builder: (context, snap) {
              final cities = snap.data ?? [];
              if (cities.isEmpty) {
                return adminCard(child: const Text('No hay ciudades configuradas en Firestore'));
              }
              return Column(
                children: [
                  for (final city in cities)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: adminCard(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_city, color: MijanoTheme.ink),
                                const SizedBox(width: 12),
                                Text(
                                  city['name']?.toString() ?? city['id'].toString(),
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                ),
                              ],
                            ),
                            _pill('Base S/ ${_num(city['tariff_base'])}'),
                            _pill('x Km S/ ${_num(city['tariff_per_km'])}'),
                            _pill('Comisión ${_num(city['commission_percent'])}%'),
                            IconButton(
                              tooltip: 'Editar tarifas',
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editTariff(city),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _num(dynamic value) {
    if (value == null) return '—';
    if (value is num) return value.toStringAsFixed(value == value.toInt() ? 0 : 2);
    return value.toString();
  }

  Widget _pill(String text) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: MijanoTheme.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
