import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import 'shared_admin_widgets.dart';
// theme import removed

class WalletModule extends StatefulWidget {
  const WalletModule({super.key});

  @override
  State<WalletModule> createState() => _WalletModuleState();
}

class _WalletModuleState extends State<WalletModule> {
  final fs = FirestoreService.instance;
  final TextEditingController _userSearchCtrl = TextEditingController();
  String _selectedUid = '';

  Future<void> _manualAdjust(BuildContext context) async {
    if (_selectedUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona un usuario primero')));
      return;
    }

    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajuste Manual'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Monto (S/) - Usa negativo para restar'), keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true)),
            const SizedBox(height: 16),
            TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Motivo / Referencia')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(amountCtrl.text);
              if (amt != null && reasonCtrl.text.isNotEmpty) {
                await fs.addManualTransaction(_selectedUid, amt, reasonCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Aplicar'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminHeader('Billetera y recargas', 'Gestión de saldos y transacciones (Culqi/Niubiz + manual)'),
          
          adminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _userSearchCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Ingresa UID del conductor/pasajero',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onSubmitted: (val) => setState(() => _selectedUid = val.trim()),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _selectedUid = _userSearchCtrl.text.trim()),
                      icon: const Icon(Icons.filter_list),
                      label: const Text('Filtrar'),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: () => _manualAdjust(context),
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Ajuste Manual'),
                    ),
                  ],
                ),
                if (_selectedUid.isNotEmpty) ...[
                  const Divider(height: 32),
                  Text('Transacciones para UID: $_selectedUid', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: fs.transactions(_selectedUid),
                    builder: (context, snap) {
                      if (!snap.hasData) return const CircularProgressIndicator();
                      final txs = snap.data!;
                      if (txs.isEmpty) return const Text('No hay transacciones');
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: txs.length,
                        itemBuilder: (ctx, i) {
                          final t = txs[i];
                          final amt = (t['amount'] as num?)?.toDouble() ?? 0.0;
                          return ListTile(
                            leading: Icon(amt >= 0 ? Icons.arrow_downward : Icons.arrow_upward, color: amt >= 0 ? Colors.green : Colors.red),
                            title: Text(t['type'] ?? 'Desconocido'),
                            subtitle: Text(t['createdAt']?.toDate().toString() ?? ''),
                            trailing: Text('S/ ${amt.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: amt >= 0 ? Colors.green : Colors.red)),
                          );
                        },
                      );
                    },
                  )
                ]
              ],
            ),
          )
        ],
      ),
    );
  }
}
