import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../models/ad_model.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import 'shared_admin_widgets.dart';

class AdsModule extends StatefulWidget {
  const AdsModule({super.key});

  @override
  State<AdsModule> createState() => _AdsModuleState();
}

class _AdsModuleState extends State<AdsModule> {
  final fs = FirestoreService.instance;

  // --- FORMULARIO 1: Banners ---
  final _formKey = GlobalKey<FormState>();
  final _companyCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _adType = 'banner';
  Uint8List? _imageBytes;
  bool _isLoading = false;

  // --- FORMULARIO 2: Pop-ups Programados y Segmentados ---
  final _popupFormKey = GlobalKey<FormState>();
  final _popupCompanyCtrl = TextEditingController();
  final _popupDescCtrl = TextEditingController();
  final _popupPhoneCtrl = TextEditingController();
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 20, minute: 0);
  bool _enableSound = true;
  String _targetAudience = 'Todos los usuarios'; // Nuevo campo de segmentación
  Uint8List? _popupImageBytes;
  bool _isPopupLoading = false;

  @override
  void dispose() {
    _companyCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    _popupCompanyCtrl.dispose();
    _popupDescCtrl.dispose();
    _popupPhoneCtrl.dispose();
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

  Future<void> _pickPopupImage() async {
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
        _popupImageBytes = bytes;
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
      final ref = FirebaseStorage.instance.ref().child('ads/$newAdId.jpg');
      final uploadTask = ref.putData(_imageBytes!);
      final snapshot = await uploadTask;
      final imageUrl = await snapshot.ref.getDownloadURL();

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
          const SnackBar(content: Text('Publicidad subida correctamente a la carpeta ads/.'), backgroundColor: Colors.green),
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

  // Guardar Pop-up Programado con Audiencia Seleccionada
  Future<void> _submitPopupAd() async {
    if (!_popupFormKey.currentState!.validate()) return;
    if (_popupImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes seleccionar una imagen para el Pop-up.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isPopupLoading = true);

    try {
      final newAdId = FirebaseFirestore.instance.collection('ads').doc().id;
      final ref = FirebaseStorage.instance.ref().child('ads/$newAdId.jpg');
      final uploadTask = ref.putData(_popupImageBytes!);
      final snapshot = await uploadTask;
      final imageUrl = await snapshot.ref.getDownloadURL();

      await fs.createAd({
        'companyName': _popupCompanyCtrl.text.trim(),
        'description': _popupDescCtrl.text.trim(),
        'phone': _popupPhoneCtrl.text.trim(),
        'type': 'popup',
        'imageUrl': imageUrl,
        'isActive': true,
        'startTime': '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
        'endTime': '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
        'enableSound': _enableSound,
        'targetAudience': _targetAudience, // Guardamos la audiencia seleccionada
        'createdBy': 'Admin',
      });

      _popupFormKey.currentState!.reset();
      _popupCompanyCtrl.clear();
      _popupDescCtrl.clear();
      _popupPhoneCtrl.clear();
      setState(() {
        _popupImageBytes = null;
        _targetAudience = 'Todos los usuarios';
        _isPopupLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pop-up programado correctamente.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _isPopupLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear pop-up: $e'), backgroundColor: Colors.red),
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
      try {
        final uri = Uri.parse(ad.imageUrl);
        final pathSegments = uri.pathSegments;
        String filePath = pathSegments.skipWhile((val) => val != 'ads').join('/');
        if (filePath.isNotEmpty) {
          await FirebaseStorage.instance.ref().child(filePath).delete();
        }
      } catch (_) {}

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

  // Formulario de Pop-ups con selector de Audiencia
  Widget _buildPopupForm() {
    return Form(
      key: _popupFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _pickPopupImage,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: MijanoTheme.cream,
                    border: Border.all(color: MijanoTheme.ink, width: 2),
                    borderRadius: BorderRadius.circular(12),
                    image: _popupImageBytes != null
                        ? DecorationImage(image: MemoryImage(_popupImageBytes!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _popupImageBytes == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_to_photos, size: 40, color: Colors.black54),
                            SizedBox(height: 8),
                            Text('Imagen Pop-up', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
                          ],
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _popupCompanyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la Empresa / Campaña',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: MijanoTheme.cream,
                      ),
                      validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _popupPhoneCtrl,
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
                        if (!RegExp(r'^9\d{8}$').hasMatch(v)) return 'Ingrese un número válido';
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
            controller: _popupDescCtrl,
            decoration: const InputDecoration(
              labelText: 'Descripción del Pop-up',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: MijanoTheme.cream,
            ),
            maxLength: 120,
            maxLines: 2,
            validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 12),
          // Selector de Audiencia Destino
          DropdownButtonFormField<String>(
            value: _targetAudience,
            decoration: const InputDecoration(
              labelText: 'Dirigido a (Audiencia)',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: MijanoTheme.cream,
            ),
            items: const [
              DropdownMenuItem(value: 'Todos los usuarios', child: Text('Todos los usuarios')),
              DropdownMenuItem(value: 'Recién registrados', child: Text('Recién registrados')),
              DropdownMenuItem(value: 'Usuarios con viajes previos', child: Text('Usuarios con viajes previos')),
            ],
            onChanged: (v) => setState(() => _targetAudience = v ?? 'Todos los usuarios'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.schedule, color: MijanoTheme.ink),
              const SizedBox(width: 8),
              const Text('Horario:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showTimePicker(context: context, initialTime: _startTime);
                  if (picked != null) setState(() => _startTime = picked);
                },
                icon: const Icon(Icons.access_time, size: 16),
                label: Text('Desde: ${_startTime.format(context)}'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showTimePicker(context: context, initialTime: _endTime);
                  if (picked != null) setState(() => _endTime = picked);
                },
                icon: const Icon(Icons.access_time_filled, size: 16),
                label: Text('Hasta: ${_endTime.format(context)}'),
              ),
              const SizedBox(width: 15),
              Row(
                children: [
                  Checkbox(
                    value: _enableSound,
                    onChanged: (v) => setState(() => _enableSound = v ?? true),
                    activeColor: MijanoTheme.ink,
                  ),
                  const Text('Con Sonido'),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _isPopupLoading ? null : _submitPopupAd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MijanoTheme.ink,
                  foregroundColor: MijanoTheme.sol,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                icon: _isPopupLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: MijanoTheme.sol, strokeWidth: 2)) : const Icon(Icons.campaign),
                label: Text(_isPopupLoading ? 'Guardando...' : 'Programar Pop-up'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdGrid(List<Map<String, dynamic>> rawAds, {required bool isPopupGroup}) {
    final filteredRaw = rawAds.where((e) {
      final type = e['type'] ?? 'banner';
      return isPopupGroup ? type == 'popup' : type != 'popup';
    }).toList();

    if (filteredRaw.isEmpty) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        child: Text(
          isPopupGroup ? 'No hay Pop-ups programados' : 'No hay anuncios registrados',
          style: const TextStyle(color: Colors.black45, fontWeight: FontWeight.bold),
        ),
      );
    }

    final ads = filteredRaw.map((e) => AdModel.fromMap(e, e['id'])).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 380,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        mainAxisExtent: 150,
      ),
      itemCount: ads.length,
      itemBuilder: (context, i) {
        final ad = ads[i];
        final rawMap = filteredRaw[i];
        final String? startTime = rawMap['startTime'];
        final String? endTime = rawMap['endTime'];
        final String? audience = rawMap['targetAudience'];

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
                      if (isPopupGroup && audience != null)
                        Text(
                          '👥 $audience',
                          style: const TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold),
                        ),
                      if (isPopupGroup && startTime != null && endTime != null)
                        Text(
                          '⏰ $startTime - $endTime',
                          style: const TextStyle(fontSize: 10, color: Colors.blueAccent, fontWeight: FontWeight.bold),
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
          adminCard(child: _buildForm()),
          const SizedBox(height: 16),
          const Text('Anuncios Activos', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: MijanoTheme.ink)),
          const SizedBox(height: 8),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: fs.streamAds(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              return _buildAdGrid(snapshot.data ?? [], isPopupGroup: false);
            },
          ),

          const SizedBox(height: 40),
          const Divider(thickness: 2),
          const SizedBox(height: 10),

          const Text('Pop-ups Programados', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: MijanoTheme.ink)),
          const SizedBox(height: 4),
          const Text('Gestión de anuncios emergentes automáticos con horarios, alertas y segmentación', style: TextStyle(color: Colors.black54, fontSize: 13)),
          const SizedBox(height: 12),
          adminCard(child: _buildPopupForm()),
          const SizedBox(height: 16),
          const Text('Pop-ups Activos', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: MijanoTheme.ink)),
          const SizedBox(height: 8),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: fs.streamAds(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              return _buildAdGrid(snapshot.data ?? [], isPopupGroup: true);
            },
          ),
        ],
      ),
    );
  }
}
