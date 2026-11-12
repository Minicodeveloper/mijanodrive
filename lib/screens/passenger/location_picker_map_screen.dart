import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../models/frequent_place_model.dart';
import '../../services/frequent_places_service.dart';
import '../../services/location_service.dart';

class LocationPickerMapScreen extends StatefulWidget {
  final String? initialName;
  final String? initialIconKey;
  final String? placeId;
  final LatLng? initialPoint;

  const LocationPickerMapScreen({
    super.key,
    this.initialName,
    this.initialIconKey,
    this.placeId,
    this.initialPoint,
  });

  @override
  State<LocationPickerMapScreen> createState() => _LocationPickerMapScreenState();
}

class _LocationPickerMapScreenState extends State<LocationPickerMapScreen> {
  GoogleMapController? _mapController;
  late LatLng _cameraPosition;
  bool _isMoving = false;
  bool _isGeocoding = false;
  String _currentAddress = 'Obteniendo dirección...';
  Timer? _geocodeDebounce;

  late TextEditingController _nameController;
  late String _selectedIconKey;
  bool _isCustomName = false;
  bool _isSaving = false;

  // Ubicación por defecto en Yurimaguas si aún no hay GPS
  static const LatLng _defaultLocation = LatLng(-5.8973, -76.1086);

  static const List<Map<String, dynamic>> _quickPresets = [
    {'name': 'Casa', 'iconKey': 'home', 'icon': Icons.home_rounded},
    {'name': 'Trabajo', 'iconKey': 'work', 'icon': Icons.work_rounded},
    {'name': 'Supermercado', 'iconKey': 'shopping_cart', 'icon': Icons.shopping_cart_rounded},
    {'name': 'Hospital', 'iconKey': 'local_hospital', 'icon': Icons.local_hospital_rounded},
    {'name': 'Gym', 'iconKey': 'fitness_center', 'icon': Icons.fitness_center_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _cameraPosition = widget.initialPoint ?? _defaultLocation;
    _nameController = TextEditingController(text: widget.initialName ?? 'Casa');
    _selectedIconKey = widget.initialIconKey ?? 'home';

    // Determinar si el nombre inicial es personalizado
    final matchesPreset = _quickPresets.any((p) => p['name'] == _nameController.text);
    _isCustomName = !matchesPreset && _nameController.text.isNotEmpty;

    _initCurrentLocation();
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    _nameController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initCurrentLocation() async {
    if (widget.initialPoint != null) {
      _fetchAddressForPosition(_cameraPosition);
      return;
    }

    try {
      final pos = await LocationService.instance.current();
      final currentLatLng = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _cameraPosition = currentLatLng;
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(currentLatLng, 16.5),
        );
        _fetchAddressForPosition(currentLatLng);
      }
    } catch (_) {
      _fetchAddressForPosition(_cameraPosition);
    }
  }

  void _onCameraMove(CameraPosition position) {
    _cameraPosition = position.target;
    if (!_isMoving) {
      setState(() => _isMoving = true);
    }
  }

  void _onCameraIdle() {
    setState(() => _isMoving = false);
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(const Duration(milliseconds: 350), () {
      _fetchAddressForPosition(_cameraPosition);
    });
  }

  Future<void> _fetchAddressForPosition(LatLng position) async {
    if (!mounted) return;
    setState(() => _isGeocoding = true);

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=${position.latitude},${position.longitude}'
        '&key=${AppConfig.googleMapsKey}'
        '&language=es',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && (data['results'] as List).isNotEmpty) {
          final formatted = data['results'][0]['formatted_address'].toString();
          if (mounted) {
            setState(() {
              _currentAddress = formatted;
              _isGeocoding = false;
            });
            return;
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _currentAddress =
            'Ubicación (${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)})';
        _isGeocoding = false;
      });
    }
  }

  Future<void> _goToMyLocation() async {
    try {
      final pos = await LocationService.instance.current();
      final currentLatLng = LatLng(pos.latitude, pos.longitude);
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(currentLatLng, 17.0),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo obtener la ubicación actual.')),
        );
      }
    }
  }

  Future<void> _saveLocation() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa un nombre para el lugar.')),
      );
      return;
    }

    if (_isGeocoding || _currentAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Espera un segundo mientras se obtiene la dirección.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Si no se proporcionó id, generar uno normalizado a partir del nombre o timestamp
      String placeId = widget.placeId ?? '';
      if (placeId.isEmpty) {
        final normalized = name.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
        if (['casa', 'trabajo', 'supermercado', 'hospital', 'gym'].contains(normalized)) {
          placeId = normalized;
        } else {
          placeId = 'place_${DateTime.now().millisecondsSinceEpoch}';
        }
      }

      final place = FrequentPlace(
        id: placeId,
        name: name,
        address: _currentAddress,
        latitude: _cameraPosition.latitude,
        longitude: _cameraPosition.longitude,
        iconKey: _selectedIconKey,
      );

      await FrequentPlacesService.instance.savePlace(place);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡"${place.name}" guardado en lugares frecuentes!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, place);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar lugar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9D408),
        elevation: 0,
        title: Text(
          'Marcar ${_nameController.text.isNotEmpty ? _nameController.text : "lugar"} en el mapa',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // 1. Mapa de Google
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _cameraPosition,
              zoom: 16.5,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // 2. Pin flotante en el centro del mapa
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                transform: Matrix4.translationValues(0, _isMoving ? -14 : 0, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Text(
                        _nameController.text.isNotEmpty ? _nameController.text : 'Mueve el mapa',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(
                      Icons.location_pin,
                      size: 48,
                      color: Color(0xFFE53935),
                    ),
                    // Sombra bajo el pin
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: _isMoving ? 8 : 14,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: _isMoving ? 0.2 : 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Botón flotante para centrar en mi ubicación
          Positioned(
            right: 16,
            bottom: 220,
            child: FloatingActionButton.small(
              heroTag: 'myLocationBtn',
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 4,
              onPressed: _goToMyLocation,
              child: const Icon(Icons.my_location),
            ),
          ),

          // 4. Selector superior de tipos de lugares
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final p in _quickPresets)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        avatar: Icon(
                          p['icon'] as IconData,
                          size: 16,
                          color: (_nameController.text == p['name'] && !_isCustomName)
                              ? Colors.black
                              : Colors.black54,
                        ),
                        label: Text(p['name'] as String),
                        selected: _nameController.text == p['name'] && !_isCustomName,
                        selectedColor: const Color(0xFFF9D408),
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: Colors.black87,
                          fontWeight: (_nameController.text == p['name'] && !_isCustomName)
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 12.5,
                        ),
                        elevation: 2,
                        pressElevation: 3,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _nameController.text = p['name'] as String;
                              _selectedIconKey = p['iconKey'] as String;
                              _isCustomName = false;
                            });
                          }
                        },
                      ),
                    ),
                  ChoiceChip(
                    avatar: Icon(
                      Icons.edit_location_alt_rounded,
                      size: 16,
                      color: _isCustomName ? Colors.black : Colors.black54,
                    ),
                    label: const Text('Otro...'),
                    selected: _isCustomName,
                    selectedColor: const Color(0xFFF9D408),
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: Colors.black87,
                      fontWeight: _isCustomName ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12.5,
                    ),
                    elevation: 2,
                    pressElevation: 3,
                    onSelected: (selected) {
                      setState(() {
                        _isCustomName = true;
                        _selectedIconKey = 'place';
                        if (_quickPresets.any((p) => p['name'] == _nameController.text)) {
                          _nameController.text = '';
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // 5. Tarjeta inferior con dirección y botón de guardar
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isCustomName) ...[
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Nombre del lugar',
                        hintText: 'Ej. Universidad, Casa de mamá...',
                        prefixIcon: const Icon(Icons.bookmark_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Dirección detectada
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF9C4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Color(0xFF8A5300),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dirección seleccionada:',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (_isGeocoding)
                              const Row(
                                children: [
                                  SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  SizedBox(width: 6),
                                  Text('Detectando dirección...', style: TextStyle(fontSize: 13)),
                                ],
                              )
                            else
                              Text(
                                _currentAddress,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Botón Guardar
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF9D408),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.check_circle_outline, size: 20),
                    label: Text(
                      _isSaving ? 'Guardando...' : 'Guardar ubicación',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
