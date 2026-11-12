import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/frequent_place_model.dart';
import '../screens/passenger/location_picker_map_screen.dart';
import '../services/frequent_places_service.dart';
import '../theme.dart';

class FrequentPlacesSheet extends StatefulWidget {
  final void Function(String address, LatLng? coords) onPlaceSelected;

  const FrequentPlacesSheet({super.key, required this.onPlaceSelected});

  @override
  State<FrequentPlacesSheet> createState() => _FrequentPlacesSheetState();
}

class _FrequentPlacesSheetState extends State<FrequentPlacesSheet> {
  final _service = FrequentPlacesService.instance;

  static const List<Map<String, dynamic>> _defaultTemplates = [
    {'id': 'casa', 'name': 'Casa', 'iconKey': 'home', 'icon': Icons.home_rounded},
    {'id': 'trabajo', 'name': 'Trabajo', 'iconKey': 'work', 'icon': Icons.work_rounded},
    {'id': 'supermercado', 'name': 'Supermercado', 'iconKey': 'shopping_cart', 'icon': Icons.shopping_cart_rounded},
    {'id': 'hospital', 'name': 'Hospital', 'iconKey': 'local_hospital', 'icon': Icons.local_hospital_rounded},
  ];

  Future<void> _openMapPicker({
    String? initialName,
    String? initialIconKey,
    String? placeId,
    LatLng? initialPoint,
  }) async {
    final result = await Navigator.push<FrequentPlace>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerMapScreen(
          initialName: initialName,
          initialIconKey: initialIconKey,
          placeId: placeId,
          initialPoint: initialPoint,
        ),
      ),
    );

    if (result != null && mounted) {
      // Al guardar, seleccionamos automáticamente el lugar para el destino
      widget.onPlaceSelected(
        result.address,
        LatLng(result.latitude, result.longitude),
      );
    }
  }

  void _showPlaceOptions(FrequentPlace place) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(place.icon, color: MijanoTheme.solDeep),
                title: Text(place.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(place.address, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.edit_location_alt_rounded),
                title: const Text('Cambiar ubicación en el mapa'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openMapPicker(
                    initialName: place.name,
                    initialIconKey: place.iconKey,
                    placeId: place.id,
                    initialPoint: LatLng(place.latitude, place.longitude),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Eliminar de frecuentes', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _service.deletePlace(place.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('"${place.name}" eliminado de frecuentes.')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    if (keyboardHeight > 0) {
      return const SizedBox.shrink();
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.10,
      minChildSize: 0.08,
      maxChildSize: 0.65,
      snap: true,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: StreamBuilder<List<FrequentPlace>>(
            stream: _service.streamPlaces(),
            builder: (context, snapshot) {
              final savedList = snapshot.data ?? _service.cachedPlaces;

              // Separar predeterminados guardados vs personalizados
              final Map<String, FrequentPlace> savedById = {
                for (var p in savedList) p.id: p,
              };

              final customPlaces = savedList
                  .where((p) => !_defaultTemplates.any((t) => t['id'] == p.id))
                  .toList();

              return CustomScrollView(
                controller: scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Lugares frecuentes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: MijanoTheme.ink,
                                ),
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.add, size: 16, color: Colors.black87),
                                label: const Text(
                                  'Agregar',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                onPressed: () => _openMapPicker(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),

                  // Grid de Plantillas (Casa, Trabajo, Supermercado, Hospital)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 2.3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final template = _defaultTemplates[index];
                          final id = template['id'] as String;
                          final saved = savedById[id];

                          if (saved != null) {
                            return _buildSavedCard(saved);
                          } else {
                            return _buildUnsetCard(
                              name: template['name'] as String,
                              icon: template['icon'] as IconData,
                              onTap: () => _openMapPicker(
                                initialName: template['name'] as String,
                                initialIconKey: template['iconKey'] as String,
                                placeId: id,
                              ),
                            );
                          }
                        },
                        childCount: _defaultTemplates.length,
                      ),
                    ),
                  ),

                  // Lista de lugares personalizados agregados
                  if (customPlaces.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Otros lugares guardados (${customPlaces.length})',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final place = customPlaces[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFFF9C4),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(place.icon, color: MijanoTheme.solDeep, size: 20),
                                ),
                                title: Text(
                                  place.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                                subtitle: Text(
                                  place.address,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                                  onPressed: () => _showPlaceOptions(place),
                                ),
                                onTap: () => widget.onPlaceSelected(
                                  place.address,
                                  LatLng(place.latitude, place.longitude),
                                ),
                              ),
                            );
                          },
                          childCount: customPlaces.length,
                        ),
                      ),
                    ),
                  ],

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 20),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // Tarjeta cuando el lugar ya tiene ubicación guardada
  Widget _buildSavedCard(FrequentPlace place) {
    return InkWell(
      onTap: () => widget.onPlaceSelected(
        place.address,
        LatLng(place.latitude, place.longitude),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDE7),
          border: Border.all(color: const Color(0xFFF9D408), width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFF9D408),
                shape: BoxShape.circle,
              ),
              child: Icon(place.icon, color: Colors.black87, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    place.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.edit_location_alt_outlined, size: 16, color: Colors.black54),
              onPressed: () => _showPlaceOptions(place),
            ),
          ],
        ),
      ),
    );
  }

  // Tarjeta cuando el lugar aún no tiene ubicación fijada
  Widget _buildUnsetCard({
    required String name,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300, width: 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.grey.shade600, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Row(
                    children: [
                      Icon(Icons.add, size: 11, color: Color(0xFF8A5300)),
                      SizedBox(width: 2),
                      Text(
                        'Fijar mapa',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF8A5300),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
