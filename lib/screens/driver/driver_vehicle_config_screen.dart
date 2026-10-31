import 'package:flutter/material.dart';
import '../passenger/passenger_available_cars_screen.dart';

class DriverVehicleConfigScreen extends StatefulWidget {
  const DriverVehicleConfigScreen({super.key});

  @override
  State<DriverVehicleConfigScreen> createState() =>
      _DriverVehicleConfigScreenState();
}

class _DriverVehicleConfigScreenState extends State<DriverVehicleConfigScreen> {
  final IntercityVehicleRepository _repo = IntercityVehicleRepository.instance;
  late int _seatCount;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final car = _repo.driverPrimaryVehicle;
    final existingCount = car.seatStates.length;
    _seatCount = existingCount > 0 ? existingCount : 4;
  }

  void _setSeatCount(int count) {
    if (count < 1 || count > 16) return;
    setState(() {
      _seatCount = count;
    });
  }

  int get _vehicleModelIndex {
    if (_seatCount <= 4) return 1;
    if (_seatCount <= 8) return 2;
    return 3;
  }

  String get _vehicleModelName {
    switch (_vehicleModelIndex) {
      case 1:
        return 'Auto Sedán (Hasta 4 pax)';
      case 2:
        return 'Van Mediana (Hasta 8 pax)';
      case 3:
      default:
        return 'Van Grande / Combi (Hasta 16 pax)';
    }
  }

  String get _chassisAsset {
    switch (_vehicleModelIndex) {
      case 1:
        return 'assets/images/chassis_car_4.jpg';
      case 2:
        return 'assets/images/chassis_van_8.jpg';
      case 3:
      default:
        return 'assets/images/chassis_van_16.jpg';
    }
  }

  double get _diagramWidth => _vehicleModelIndex == 1 ? 290 : 270;
  double get _diagramHeight => _vehicleModelIndex == 1 ? 390 : 560;

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);
    final car = _repo.driverPrimaryVehicle;

    try {
      await _repo.updateVehicleSeatCapacity(
        carId: car.id,
        totalSeats: _seatCount,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '¡Configuración guardada! Vehículo configurado con $_seatCount asientos ($_vehicleModelName).',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade800,
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar configuración: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Calcula las posiciones de cada asiento según el modelo de auto activo:
  /// - Modelo 1 (1..4 asientos): Auto Sedán
  /// - Modelo 2 (5..8 asientos): Van Mediana
  /// - Modelo 3 (9..16 asientos): Van Grande / Minibús
  List<Offset> _getSeatOffsets(int total) {
    final model = _vehicleModelIndex;

    // --- MODELO 1: AUTO SEDÁN (1 a 4 asientos) ---
    if (model == 1) {
      final List<Offset> positions = [];
      const copilotOffset = Offset(168, 136);

      if (total >= 1) positions.add(copilotOffset); // Asiento 1: Copiloto

      if (total == 2) {
        positions.add(const Offset(119, 234)); // Trasero central
      } else if (total == 3) {
        positions.add(const Offset(72, 234)); // Trasero izq
        positions.add(const Offset(164, 234)); // Trasero der
      } else if (total == 4) {
        positions.add(const Offset(64, 234)); // Trasero izq
        positions.add(const Offset(119, 234)); // Trasero centro
        positions.add(const Offset(174, 234)); // Trasero der
      }
      return positions;
    }

    // --- MODELO 2: VAN MEDIANA (5 a 8 asientos) ---
    if (model == 2) {
      // 8 posiciones exactas correspondientes a los asientos dibujados en chassis_van_8.jpg
      const van8Slots = [
        Offset(54, 123), // 1. Frontal Izq
        Offset(108, 123), // 2. Frontal Centro-Izq
        Offset(57, 230), // 3. Fila 2 Izq
        Offset(111, 230), // 4. Fila 2 Centro
        Offset(165, 230), // 5. Fila 2 Der
        Offset(57, 347), // 6. Fila 3 Izq
        Offset(111, 347), // 7. Fila 3 Centro
        Offset(165, 347), // 8. Fila 3 Der
      ];

      if (total == 8) return van8Slots;
      if (total == 7) {
        return [
          van8Slots[0], // Delantero
          van8Slots[2],
          van8Slots[3],
          van8Slots[4], // Fila 2 completa
          van8Slots[5],
          van8Slots[6],
          van8Slots[7], // Fila 3 completa
        ];
      }
      if (total == 6) {
        return [
          van8Slots[2],
          van8Slots[3],
          van8Slots[4], // Fila 2 completa (3 pax)
          van8Slots[5],
          van8Slots[6],
          van8Slots[7], // Fila 3 completa (3 pax)
        ];
      }
      // total == 5
      return [
        van8Slots[0],
        van8Slots[1], // Fila 1 (2 pax)
        van8Slots[2],
        van8Slots[3],
        van8Slots[4], // Fila 2 (3 pax)
      ];
    }

    // --- MODELO 3: VAN GRANDE / MINIBÚS (9 a 16 asientos) ---
    final List<Offset> positions = [];
    const copilot = Offset(60, 125);
    positions.add(copilot); // Asiento 1: Copiloto delantero izq

    final remaining = total - 1;
    final rowYs = [190.0, 255.0, 320.0, 385.0, 450.0];
    final colXs = [54.0, 114.0, 174.0];

    int placed = 0;
    for (int r = 0; r < rowYs.length && placed < remaining; r++) {
      final y = rowYs[r];
      final toPlaceInRow = (remaining - placed).clamp(1, 3);
      if (toPlaceInRow == 1) {
        positions.add(Offset(colXs[1], y));
        placed++;
      } else if (toPlaceInRow == 2) {
        positions.add(Offset(colXs[0], y));
        positions.add(Offset(colXs[2], y));
        placed += 2;
      } else {
        positions.add(Offset(colXs[0], y));
        positions.add(Offset(colXs[1], y));
        positions.add(Offset(colXs[2], y));
        placed += 3;
      }
    }

    return positions;
  }

  @override
  Widget build(BuildContext context) {
    final seatPositions = _getSeatOffsets(_seatCount);
    final width = _diagramWidth;
    final height = _diagramHeight;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9D408),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Configura tu auto',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Tarjeta de configuración superior
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF9C4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.airline_seat_recline_normal,
                          color: Color(0xFF8A5300),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Capacidad del Vehículo',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _vehicleModelName,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF8A5300),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Chips de selección rápida
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPresetChip(4, '4 Asientos (Sedán)'),
                      _buildPresetChip(6, '6 Asientos (Van)'),
                      _buildPresetChip(8, '8 Asientos (Van)'),
                      _buildPresetChip(12, '12 Asientos (Combi)'),
                      _buildPresetChip(16, '16 Asientos (Minibús)'),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Stepper interactivo [-]  N  [+]
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7F7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Capacidad total:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _seatCount > 1
                                  ? () => _setSeatCount(_seatCount - 1)
                                  : null,
                              icon: const Icon(Icons.remove_circle_outline),
                              color: _seatCount > 1
                                  ? const Color(0xFF8A5300)
                                  : Colors.grey.shade400,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9D408),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$_seatCount asientos',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _seatCount < 16
                                  ? () => _setSeatCount(_seatCount + 1)
                                  : null,
                              icon: const Icon(Icons.add_circle_outline),
                              color: _seatCount < 16
                                  ? const Color(0xFF8A5300)
                                  : Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Título de la vista previa con modelo dinámico
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDE7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF9D408)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.directions_car_filled,
                    size: 16,
                    color: Color(0xFF8A5300),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '$_vehicleModelName • $_seatCount ubicados',
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8A5300),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Diagrama con el modelo de auto activo (Model 1, Model 2 o Model 3)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: width,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    // Imagen base del chasis activo
                    Positioned.fill(
                      child: Image.asset(
                        _chassisAsset,
                        fit: BoxFit.fill,
                      ),
                    ),

                    // Asientos generados dinámicamente y perfectamente alineados
                    for (int i = 0; i < seatPositions.length; i++) ...[
                      Positioned(
                        left: seatPositions[i].dx,
                        top: seatPositions[i].dy,
                        child: _ConfigSeatBox(
                          seatNumber: i + 1,
                          size: _vehicleModelIndex == 3 ? 42 : 48,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Leyenda de referencia
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1EE61E),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Colors.black87, width: 1),
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Asiento Disponible / Configurado',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Botón Guardar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF9D408),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isSaving ? null : _saveConfig,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 22),
                label: Text(
                  _isSaving
                      ? 'Guardando...'
                      : 'Guardar Configuración ($_seatCount Asientos)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(int count, String label) {
    final isSelected = _seatCount == count;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFFF9D408),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? Colors.black87 : Colors.grey.shade300,
        width: isSelected ? 1.5 : 1.0,
      ),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: Colors.black87,
      ),
      onSelected: (_) => _setSeatCount(count),
    );
  }
}

class _ConfigSeatBox extends StatelessWidget {
  final int seatNumber;
  final double size;

  const _ConfigSeatBox({
    required this.seatNumber,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF1EE61E),
            borderRadius: BorderRadius.circular(size * 0.2),
            border: Border.all(
              color: Colors.black87,
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 3,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '$seatNumber',
              style: TextStyle(
                fontSize: size * 0.4,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'Asiento $seatNumber',
            style: TextStyle(
              fontSize: size * 0.2,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
