import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/ad_model.dart';
import '../../services/firestore_service.dart';
import '../../services/document_service.dart';
import '../../theme.dart';
import 'shared_admin_widgets.dart';

class AdsModule extends StatefulWidget {
  const AdsModule({super.key});

  @override
  State<AdsModule> createState() => _AdsModuleState();
}

class _AdsModuleState extends State<AdsModule> {
  final fs = FirestoreService.instance;
  final _formKey = GlobalKey<FormState>();

  final _companyCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _adType = 'banner';
  Uint8List? _imageBytes;
  bool _isLoading = false;

  @override
  void dispose() {
    _companyCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) {
      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('La imagen supera los 5 MB'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      setState(() {
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _submitAd() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes seleccionar una imagen para publicar.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newAdId = FirebaseFirestore.instance.collection('ads').doc().id;
      final imageUrl = await DocumentService.instance.uploadAdImage(newAdId, _imageBytes!.toList());

      await fs.createAd({
        'companyName': _companyCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'type': _adType,
        'imageUrl': imageUrl,
        'isActive': true,
        'createdBy': 'Admin',
      });

      _formKey.currentState!.reset();
      _companyCtrl.clear();
      _descCtrl.clear();
      _phoneCtrl.clear();
      setState(() {
        _imageBytes = null;
        _adType = 'banner';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Publicidad subida correctamente.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear publicidad: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteAd(AdModel ad) async {
    final confirm = await adminConfirm(
      context,
      title: 'Eliminar publicidad',
      body: '¿Estás seguro de eliminar el anuncio de ${ad.companyName}?',
      danger: true,
      action: 'Eliminar',
    );
    if (!confirm) return;

    try {
      await fs.deleteAd(ad.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Publicidad eliminada'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openWhatsApp(String phone) {
    if (phone.isEmpty) return;
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/51$cleanPhone');
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: MijanoTheme.cream,
                    border: Border.all(color: MijanoTheme.ink, width: 2),
                    borderRadius: BorderRadius.circular(12),
                    image: _imageBytes != null
                        ? DecorationImage(image: MemoryImage(_imageBytes!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _imageBytes == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate, size: 40, color: Colors.black54),
                            SizedBox(height: 8),
                            Text('Añadir Imagen', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
                          ],
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 20),
              // Form Fields
              Expanded(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _companyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la Empresa',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: MijanoTheme.cream,
                      ),
                      validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono (WhatsApp)',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: MijanoTheme.cream,
                        prefixText: '+51 ',
                      ),
                      keyboardType: TextInputType.phone,
                      maxLength: 9,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Requerido';
                        if (!RegExp(r'^9\d{8}$').hasMatch(v)) return 'Ingrese un número válido de 9 dígitos';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Descripción corta',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: MijanoTheme.cream,
            ),
            maxLength: 120,
            maxLines: 2,
            validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Tipo:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              Radio<String>(
                value: 'banner',
                groupValue: _adType,
                onChanged: (v) => setState(() => _adType = v!),
                activeColor: MijanoTheme.ink,
              ),
              const Text('Banner Superior'),
              const SizedBox(width: 20),
              Radio<String>(
                value: 'imagen',
                groupValue: _adType,
                onChanged: (v) => setState(() => _adType = v!),
                activeColor: MijanoTheme.ink,
              ),
              const Text('Imagen Cuadrada'),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _submitAd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MijanoTheme.ink,
                  foregroundColor: MijanoTheme.sol,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: MijanoTheme.sol, strokeWidth: 2)) : const Icon(Icons.publish),
                label: Text(_isLoading ? 'Publicando...' : 'Publicar Anuncio'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdGrid(List<Map<String, dynamic>> rawAds) {
    if (rawAds.isEmpty) {
      return Container(
        height: 250,
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.campaign_outlined, size: 64, color: Colors.black26),
            SizedBox(height: 12),
            Text('No hay anuncios registrados', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    final ads = rawAds.map((e) => AdModel.fromMap(e, e['id'])).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 380,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        mainAxisExtent: 140, // height
      ),
      itemCount: ads.length,
      itemBuilder: (context, i) {
        final ad = ads[i];
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                child: Image.network(
                  ad.imageUrl,
                  width: 120,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              ad.companyName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w900, color: MijanoTheme.ink, fontSize: 14),
                            ),
                          ),
                          Switch(
                            value: ad.isActive,
                            onChanged: (v) => fs.toggleAd(ad.id, v),
                            activeColor: Colors.green,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Expanded(
                        child: Text(
                          ad.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: () => _openWhatsApp(ad.phone),
                            child: Row(
                              children: [
                                const Icon(Icons.phone, size: 14, color: Colors.green),
                                const SizedBox(width: 4),
                                Text(ad.phone, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                              ],
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteAd(ad),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminHeader('Publicidad', 'Banners e imágenes de empresas asociadas'),
          adminCard(
            child: _buildForm(),
          ),
          const SizedBox(height: 24),
          const Text('Anuncios Activos', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: MijanoTheme.ink)),
          const SizedBox(height: 12),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: fs.streamAds(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              return _buildAdGrid(snapshot.data ?? []);
            },
          ),
        ],
      ),
    );
  }
}
