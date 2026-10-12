import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/document_service.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import '../modules/shared_admin_widgets.dart';

class EditQrDialog extends StatefulWidget {
  const EditQrDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const EditQrDialog(),
    );
  }

  @override
  State<EditQrDialog> createState() => _EditQrDialogState();
}

class _EditQrDialogState extends State<EditQrDialog> {
  final _picker = ImagePicker();
  Uint8List? _selectedBytes;
  String? _selectedExt;
  bool _isSaving = false;

  Future<void> _pickImage() async {
    try {
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
              content: Text('La imagen supera el límite de 5 MB'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final ext = image.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';

      setState(() {
        _selectedBytes = bytes;
        _selectedExt = ext;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')),
        );
      }
    }
  }

  Future<void> _save(String? oldStoragePath) async {
    if (_selectedBytes == null || _selectedExt == null) return;

    setState(() => _isSaving = true);

    try {
      final adminName = AuthService.instance.currentUser?.name ?? 'SuperAdmin';
      final uploadRes = await DocumentService.instance.uploadPaymentQr(
        _selectedBytes!,
        _selectedExt!,
      );

      final url = uploadRes['url']!;
      final storagePath = uploadRes['storagePath']!;

      await FirestoreService.instance.savePaymentQr(
        url: url,
        storagePath: storagePath,
        oldStoragePath: oldStoragePath,
        adminName: adminName,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR de pago actualizado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar el QR: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _restoreDefault(String? oldStoragePath) async {
    final confirm = await adminConfirm(
      context,
      title: 'Restaurar QR por defecto',
      body: '¿Deseas restaurar la imagen del QR al archivo por defecto de la aplicación?',
      danger: true,
      action: 'Restaurar',
    );
    if (!confirm || !mounted) return;

    setState(() => _isSaving = true);

    try {
      await FirestoreService.instance.restoreDefaultPaymentQr(
        oldStoragePath: oldStoragePath,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR restaurado al valor por defecto'),
            backgroundColor: Colors.amber,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al restaurar el QR: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: maxHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: StreamBuilder<Map<String, dynamic>?>(
            stream: FirestoreService.instance.streamPaymentQr(),
            builder: (context, snapshot) {
              final qrData = snapshot.data;
              final currentUrl = qrData?['url'] as String?;
              final oldStoragePath = qrData?['storagePath'] as String?;

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Editar QR de Pago',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: MijanoTheme.ink,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _isSaving ? null : () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Los conductores verán este QR en la pantalla de pago de suscripción.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    // Vista previa
                    Center(
                      child: Container(
                        width: 224,
                        height: 224,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFECE8F4)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0D24203A),
                              blurRadius: 18,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: _selectedBytes != null
                              ? Image.memory(
                                  _selectedBytes!,
                                  fit: BoxFit.contain,
                                )
                              : (currentUrl != null && currentUrl.isNotEmpty)
                                  ? Image.network(
                                      currentUrl,
                                      fit: BoxFit.contain,
                                      loadingBuilder: (_, child, prog) {
                                        if (prog == null) return child;
                                        return const Center(
                                          child: CircularProgressIndicator(
                                            color: MijanoTheme.sol,
                                          ),
                                        );
                                      },
                                      errorBuilder: (_, __, ___) => Image.asset(
                                        'assets/images/driver_payment_qr.jpeg',
                                        fit: BoxFit.contain,
                                      ),
                                    )
                                  : Image.asset(
                                      'assets/images/driver_payment_qr.jpeg',
                                      fit: BoxFit.contain,
                                    ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MijanoTheme.ink,
                        side: const BorderSide(color: Colors.black26),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _isSaving ? null : _pickImage,
                      icon: const Icon(Icons.photo_library),
                      label: Text(
                        _selectedBytes == null
                            ? 'Seleccionar nueva imagen'
                            : 'Cambiar imagen elegida',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          onPressed: _isSaving ? null : () => Navigator.pop(context),
                          child: const Text('Cancelar', style: TextStyle(color: Colors.black54)),
                        ),
                        if (qrData != null)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                            onPressed: _isSaving ? null : () => _restoreDefault(oldStoragePath),
                            icon: const Icon(Icons.restore, size: 16),
                            label: const Text('Restaurar defecto'),
                          ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MijanoTheme.sol,
                            foregroundColor: MijanoTheme.ink,
                          ),
                          onPressed: (_selectedBytes == null || _isSaving)
                              ? null
                              : () => _save(oldStoragePath),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: MijanoTheme.ink,
                                  ),
                                )
                              : const Icon(Icons.save, size: 16),
                          label: const Text('Guardar'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
