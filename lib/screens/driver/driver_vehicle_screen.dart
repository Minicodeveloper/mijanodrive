import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/firestore_service.dart';
import '../passenger/passenger_available_cars_screen.dart';
import 'driver_vehicle_config_screen.dart';

class DriverVehicleScreen extends StatefulWidget {
  final VoidCallback? onTripStartedNavigateHome;

  const DriverVehicleScreen({super.key, this.onTripStartedNavigateHome});

  @override
  State<DriverVehicleScreen> createState() => _DriverVehicleScreenState();
}

class _DriverVehicleScreenState extends State<DriverVehicleScreen> {
  final IntercityVehicleRepository _repo = IntercityVehicleRepository.instance;
  Timer? _etaTickerTimer;

  @override
  void initState() {
    super.initState();
    _repo.ensureCurrentDriverVehicleSynced();
    // Temporizador para refrescar cada segundo el contador regresivo de 15 minutos
    _etaTickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _etaTickerTimer?.cancel();
    super.dispose();
  }

  String _formatPassengerEta(SeatPassengerInfo pax) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final startMs = pax.reservedAtMs > 0 ? pax.reservedAtMs : now;
    const totalSeconds = 15 * 60; // 15 minutos exactos
    final elapsed = (now - startMs) ~/ 1000;
    final remaining = (totalSeconds - elapsed).clamp(0, totalSeconds);

    if (remaining <= 0) {
      return 'ETA: Llegando a la agencia';
    }
    final mins = remaining ~/ 60;
    final secs = remaining % 60;
    return 'ETA: ${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')} min';
  }

  Future<String?> _resolveTripId(AvailableCarItem car, SeatPassengerInfo passenger) async {
    if (passenger.tripId.isNotEmpty) {
      return passenger.tripId;
    }
    try {
      final query = await FirebaseFirestore.instance
          .collection('trips')
          .where('carId', isEqualTo: car.id)
          .where('seatNumber', isEqualTo: passenger.seatNumber)
          .where('status', whereIn: ['pending', 'accepted', 'active', 'in_progress'])
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return query.docs.first.id;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _callPassenger(SeatPassengerInfo passenger) async {
    final uri = Uri(scheme: 'tel', path: passenger.phone);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Llamando a ${passenger.passengerName} (${passenger.phone})...',
        ),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  Future<void> _confirmStartTrip(AvailableCarItem car) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.directions_car, color: Color(0xFFF9D408), size: 26),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Iniciar Viaje',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          '¿Estás seguro de iniciar el viaje hacia ${car.destinationCity} con los ${car.seatStates.length} pasajeros a bordo?',
          style: const TextStyle(fontSize: 14.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF9D408),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, iniciar viaje', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _repo.startIntercityTrip(car.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Viaje iniciado hacia ${car.destinationCity}! Redirigiendo a Inicio...'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      widget.onTripStartedNavigateHome?.call();
    }
  }

  void _openEditRouteDialog(AvailableCarItem car) {
    final originCtrl = TextEditingController(text: car.originCity);
    final destCtrl = TextEditingController(text: car.destinationCity);
    final timeCtrl = TextEditingController(text: car.departureLabel);
    final priceCtrl = TextEditingController(
      text: car.pricePerSeat.toStringAsFixed(2),
    );

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Configurar Ruta y Salida',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: originCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ciudad de Origen (De:)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: destCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ciudad de Destino (A:)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: timeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Horario de salida (ej. Hoy, 14:30)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Precio por asiento (S/)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF9D408),
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final origin = originCtrl.text.trim().isNotEmpty
                  ? originCtrl.text.trim()
                  : car.originCity;
              final dest = destCtrl.text.trim().isNotEmpty
                  ? destCtrl.text.trim()
                  : car.destinationCity;
              final label = timeCtrl.text.trim().isNotEmpty
                  ? timeCtrl.text.trim()
                  : car.departureLabel;
              final price =
                  double.tryParse(priceCtrl.text.trim()) ?? car.pricePerSeat;

              await _repo.updateVehicleRouteAndSchedule(
                carId: car.id,
                originCity: origin,
                destinationCity: dest,
                departureLabel: label,
                pricePerSeat: price,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text(
              'Guardar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _openDirectChat(AvailableCarItem car, SeatPassengerInfo passenger) async {
    final messageController = TextEditingController();
    final resolvedTripId = await _resolveTripId(car, passenger);

    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return ListenableBuilder(
          listenable: _repo,
          builder: (ctx, _) {
            final liveCar = _repo.getCarById(car.id);

            Widget buildMessagesList(List<Map<String, dynamic>> firestoreMessages) {
              final List<Map<String, dynamic>> allMessages = [];

              if (firestoreMessages.isNotEmpty) {
                for (var m in firestoreMessages) {
                  final isDriver = m['senderId'] != null &&
                      (m['senderId'] == liveCar.driverId ||
                          m['senderId'] == liveCar.id ||
                          m['sender'] == 'driver');
                  allMessages.add({
                    'isDriver': isDriver,
                    'text': m['text'] ?? '',
                  });
                }
              } else {
                final seatMessages = liveCar.chatMessages
                    .where((m) => m['seatNumber'] == passenger.seatNumber)
                    .toList();
                for (var m in seatMessages) {
                  allMessages.add({
                    'isDriver': m['sender'] == 'driver',
                    'text': m['text'] ?? '',
                  });
                }
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F1F1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'Hola conductor, reservé el Asiento ${passenger.seatNumber}. Estoy en camino hacia la agencia (${_formatPassengerEta(passenger)}).',
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  ...allMessages.map((msg) {
                    final isDriver = msg['isDriver'] == true;
                    return Align(
                      alignment: isDriver
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isDriver
                              ? const Color(0xFFF9D408)
                              : const Color(0xFFF1F1F1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          (msg['text'] ?? '').toString(),
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SizedBox(
                height: 410,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF9D408),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.black87,
                            child: Icon(
                              Icons.person,
                              color: Color(0xFFF9D408),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${passenger.passengerName} • Asiento ${passenger.seatNumber}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                Text(
                                  _formatPassengerEta(passenger),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.phone, color: Colors.black),
                            onPressed: () => _callPassenger(passenger),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.black),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: resolvedTripId != null && resolvedTripId.isNotEmpty
                          ? StreamBuilder<List<Map<String, dynamic>>>(
                              stream: FirestoreService.instance
                                  .chatMessagesForTrip(resolvedTripId),
                              builder: (context, snap) {
                                final msgs = snap.data ?? [];
                                return buildMessagesList(msgs);
                              },
                            )
                          : buildMessagesList([]),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: messageController,
                              decoration: InputDecoration(
                                hintText:
                                    'Escribe para coordinar el recojo...',
                                hintStyle: const TextStyle(fontSize: 13),
                                filled: true,
                                fillColor: const Color(0xFFF5F5F5),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            backgroundColor: const Color(0xFFF9D408),
                            child: IconButton(
                              icon: const Icon(
                                Icons.send,
                                color: Colors.black,
                                size: 18,
                              ),
                              onPressed: () async {
                                final text = messageController.text.trim();
                                if (text.isEmpty) return;
                                messageController.clear();

                                if (resolvedTripId != null &&
                                    resolvedTripId.isNotEmpty) {
                                  try {
                                    await FirestoreService.instance.sendTripMessage(
                                      tripId: resolvedTripId,
                                      senderId: liveCar.driverId.isNotEmpty
                                          ? liveCar.driverId
                                          : liveCar.id,
                                      senderName: liveCar.driverName,
                                      text: text,
                                    );
                                  } catch (_) {}
                                }

                                await _repo.sendDirectChatMessage(
                                  carId: liveCar.id,
                                  seatNumber: passenger.seatNumber,
                                  senderRole: 'driver',
                                  senderName: liveCar.driverName,
                                  text: text,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  int _resolveModelIndex(int total) {
    if (total <= 4) return 1;
    if (total <= 8) return 2;
    return 3;
  }

  String _resolveChassisAsset(int total) {
    final model = _resolveModelIndex(total);
    if (model == 1) return 'assets/images/chassis_car_4.jpg';
    if (model == 2) return 'assets/images/chassis_van_8.jpg';
    return 'assets/images/chassis_van_16.jpg';
  }

  List<Offset> _calculateChassisOffsets(int total) {
    final model = _resolveModelIndex(total);

    // --- MODELO 1: AUTO SEDÁN (1..4 asientos) ---
    if (model == 1) {
      final List<Offset> positions = [];
      const copilotOffset = Offset(168, 136);
      if (total >= 1) positions.add(copilotOffset);
      if (total == 2) {
        positions.add(const Offset(119, 234));
      } else if (total == 3) {
        positions.add(const Offset(72, 234));
        positions.add(const Offset(164, 234));
      } else if (total >= 4) {
        positions.add(const Offset(64, 234));
        positions.add(const Offset(119, 234));
        positions.add(const Offset(174, 234));
      }
      return positions;
    }

    // --- MODELO 2: VAN MEDIANA (5..8 asientos) ---
    if (model == 2) {
      const van8Slots = [
        Offset(54, 123),
        Offset(108, 123),
        Offset(57, 230),
        Offset(111, 230),
        Offset(165, 230),
        Offset(57, 347),
        Offset(111, 347),
        Offset(165, 347),
      ];
      if (total >= 8) return van8Slots;
      if (total == 7) {
        return [
          van8Slots[0],
          van8Slots[2],
          van8Slots[3],
          van8Slots[4],
          van8Slots[5],
          van8Slots[6],
          van8Slots[7],
        ];
      }
      if (total == 6) {
        return [
          van8Slots[2],
          van8Slots[3],
          van8Slots[4],
          van8Slots[5],
          van8Slots[6],
          van8Slots[7],
        ];
      }
      return [
        van8Slots[0],
        van8Slots[1],
        van8Slots[2],
        van8Slots[3],
        van8Slots[4],
      ];
    }

    // --- MODELO 3: VAN GRANDE / MINIBÚS (9..16 asientos) ---
    final List<Offset> positions = [];
    positions.add(const Offset(60, 125));
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

  Widget _buildChassisDiagram(AvailableCarItem car) {
    final total = car.seatStates.length;
    final model = _resolveModelIndex(total);
    final width = model == 1 ? 290.0 : 270.0;
    final height = model == 1 ? 390.0 : 560.0;
    final offsets = _calculateChassisOffsets(total);
    final asset = _resolveChassisAsset(total);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                asset,
                fit: BoxFit.fill,
              ),
            ),
            for (int i = 0; i < offsets.length; i++) ...[
              Positioned(
                left: offsets[i].dx,
                top: offsets[i].dy,
                child: _DriverSeatOccupancyBox(
                  seatNumber: i + 1,
                  isOccupied: car.seatStates[i + 1] == 'occupied',
                  passengerShortName:
                      car.seatPassengers[i + 1]?.shortName ?? 'Ocupado',
                  onTap: () => _onTapSeatBox(car, i + 1),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _occupyAllSeats(AvailableCarItem car) async {
    final defaultDnis = ['74829101', '72849102', '76319403', '71058294'];
    final defaultPhones = [
      '+51 987 654 321',
      '+51 945 123 789',
      '+51 912 345 678',
      '+51 998 765 432',
    ];
    final defaultNames = [
      'Carlos Mendoza',
      'Valeria Rojas',
      'Jorge Paredes',
      'Lucía Flores',
    ];

    final total = car.seatStates.length;
    for (int s = 1; s <= total; s++) {
      final liveCar = _repo.getCarById(car.id);
      if (liveCar.seatStates[s] != 'occupied') {
        final idx = (s - 1) % defaultNames.length;
        await _repo.occupySeat(
          carId: car.id,
          seatNumber: s,
          passengerId: 'pax_manual_$s',
          passengerName: defaultNames[idx],
          passengerPhone: defaultPhones[idx],
          passengerDni: defaultDnis[idx],
          passengerCity: car.originCity,
          passengerAge: 25 + s * 2,
          etaText: 'ETA: 15 min',
        );
      }
    }
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '¡$total/$total Asientos Ocupados! Botón "Iniciar Viaje" habilitado.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade800,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _onTapSeatBox(AvailableCarItem car, int seatNumber) async {
    final isOccupied = car.seatStates[seatNumber] == 'occupied';
    final passenger = car.seatPassengers[seatNumber];

    if (isOccupied) {
      final shouldRelease = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Asiento $seatNumber • ${passenger?.passengerName ?? 'Ocupado'}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Estado: Ocupado (${passenger != null ? _formatPassengerEta(passenger) : 'ETA: 15 min'})\n\n'
            '¿Deseas liberar este asiento por cancelación anticipada? '
            'El vehículo actualizará su disponibilidad en tiempo real en la lista pública.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cerrar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF25C54),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Liberar Asiento'),
            ),
          ],
        ),
      );

      if (shouldRelease == true) {
        await _repo.cancelSeatReservation(
          carId: car.id,
          seatNumber: seatNumber,
        );
        if (!mounted) return;
        final updated = _repo.getCarById(car.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Asiento $seatNumber liberado. Disponible ahora: '
              '${updated.availableSeatsCount}/4 Disponibles.',
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } else {
      final nameController = TextEditingController();
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0x2E1EE61E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.event_seat,
                  color: Color(0xFF1B5E20),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Asignar Asiento $seatNumber',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ingresa el nombre del pasajero para ocupar este asiento individual:',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nombre del pasajero',
                  hintText: 'Ej. Pasajero $seatNumber',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Opción destacada para Ocupar Todo de una sola vez
              InkWell(
                onTap: () => Navigator.pop(ctx, 'occupy_all'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 11,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9C4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFF9D408),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.group_add, size: 20, color: Color(0xFFB26A00)),
                      SizedBox(width: 8),
                      Text(
                        'Ocupar todo (Llenar auto 4/4)',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB26A00),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          actions: [
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'cancel'),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF9D408),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx, 'occupy_one'),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text(
                    'Ocupar Asiento',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      if (action == 'occupy_all') {
        await _occupyAllSeats(car);
      } else if (action == 'occupy_one') {
        final name = nameController.text.trim().isNotEmpty
            ? nameController.text.trim()
            : 'Pasajero $seatNumber';
        await _repo.occupySeat(
          carId: car.id,
          seatNumber: seatNumber,
          passengerId: 'pax_manual_$seatNumber',
          passengerName: name,
          passengerPhone: '+51987654321',
          etaText: 'ETA: 15 min',
        );
        if (!mounted) return;
        final updated = _repo.getCarById(car.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              updated.isFull
                  ? '¡4/4 Asientos Ocupados! Botón "Iniciar Viaje" habilitado.'
                  : 'Asiento $seatNumber asignado a $name (${updated.occupiedSeatsCount}/4 ocupados).',
            ),
            backgroundColor: updated.isFull
                ? Colors.green.shade800
                : Colors.black87,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _repo,
      builder: (context, _) {
        final car = _repo.driverPrimaryVehicle;
        final occupiedCount = car.occupiedSeatsCount;
        final passengersList = car.seatPassengers.values.toList()
          ..sort((a, b) => a.seatNumber.compareTo(b.seatNumber));

        return Container(
          color: Colors.white,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Tarjeta de Nueva Solicitud (Pendiente)
                if (car.pendingRequests.isNotEmpty)
                  ...car.pendingRequests.map(
                    (req) => Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Nueva Solicitud (Pendiente)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${req.passengerName} - Asiento ${req.seatNumber} (${req.seatPositionDescription}) - S/ ${req.price.toStringAsFixed(2)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF9D408),
                                foregroundColor: Colors.black,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              onPressed: () async {
                                await _repo.acceptPendingRequest(
                                  carId: car.id,
                                  request: req,
                                );
                                if (!context.mounted) return;
                                final updated = _repo.getCarById(car.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      updated.isFull
                                          ? 'Viaje aceptado. ¡4/4 Asientos ocupados! Vehículo ocultado de la lista pública.'
                                          : 'Viaje de ${req.passengerName} aceptado en el Asiento ${req.seatNumber}.',
                                    ),
                                    backgroundColor: Colors.green.shade700,
                                  ),
                                );
                              },
                              child: const Text(
                                'Aceptar Viaje',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF25C54),
                                foregroundColor: Colors.black,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              onPressed: () {
                                _repo.rejectPendingRequest(
                                  carId: car.id,
                                  request: req,
                                );
                              },
                              child: const Text(
                                'Rechazar',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Encabezado "Mi Vehículo y Asientos"
                const Text(
                  'Mi Vehículo y Asientos',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${car.vehicleModel} - ${car.vehiclePlate}${car.agencyName.trim().isNotEmpty ? ' • ${car.agencyName}' : ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${car.departureLabel} • S/ ${car.pricePerSeat.toStringAsFixed(2)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _openEditRouteDialog(car),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 17,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Acceso directo a Configurar Asientos
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF8A5300),
                        backgroundColor: const Color(0xFFFFF9C4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Color(0xFFF9D408)),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DriverVehicleConfigScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.tune, size: 16),
                      label: Text(
                        'Configurar Asientos (${car.seatStates.length} pax)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Mapa de Ocupación en Tiempo Real (Esquema Sedán, Van 8 o Van 16 según capacidad)
                _buildChassisDiagram(car),
                const SizedBox(height: 14),

                // Leyenda Disponible (Verde) / Ocupado (Rojo con X)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1EE61E),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: Colors.black54,
                              width: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        const Text(
                          'Disponible',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4362C),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: Colors.black87,
                              width: 1,
                            ),
                          ),
                          child: const CustomPaint(
                            painter: OccupiedCrossPainter(
                              color: Colors.black87,
                              strokeWidth: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        const Text(
                          'Ocupado',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(color: Colors.grey.shade300, height: 1),
                const SizedBox(height: 14),

                // Resumen Estado del Viaje y Ocupación Actual
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estado del Viaje: Ruta ${car.originCity} → ${car.destinationCity}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Ocupación Actual: $occupiedCount / ${car.seatStates.length} Asientos',
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: car.isFull
                                  ? const Color(0xFFFFEBEE)
                                  : const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: car.isFull
                                    ? const Color(0xFFF4362C)
                                    : const Color(0xFF2E7D32),
                              ),
                            ),
                            child: Text(
                              car.isFull
                                  ? 'Oculto en lista pública (Lleno)'
                                  : '${car.availableSeatsCount}/${car.seatStates.length} Disponibles en lista',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: car.isFull
                                    ? const Color(0xFFC62828)
                                    : const Color(0xFF1B5E20),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!car.isFull && !car.tripStarted) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF8A5300),
                              side: const BorderSide(
                                color: Color(0xFFF9D408),
                                width: 1.5,
                              ),
                              backgroundColor: const Color(0xFFFFFDE7),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => _occupyAllSeats(car),
                            icon: const Icon(Icons.group_add, size: 19),
                            label: Text(
                              'Ocupar todo (Llenar auto ${car.seatStates.length}/${car.seatStates.length})',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Botón Iniciar Viaje cuando el vehículo está 4/4 Lleno
                if (car.isFull && !car.tripStarted) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF9D408),
                        foregroundColor: Colors.black,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => _confirmStartTrip(car),
                      icon: const Icon(Icons.play_circle_fill, size: 24),
                      label: const Text(
                        'Iniciar Viaje',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ] else if (car.tripStarted) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF2E7D32)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.navigation, color: Color(0xFF2E7D32)),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            '¡Viaje en curso! Revisa el trazado hacia el destino en Inicio.',
                            style: TextStyle(
                              color: Color(0xFF1B5E20),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              widget.onTripStartedNavigateHome?.call(),
                          child: const Text(
                            'Ver Inicio',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Listado de Próximos Pasajeros + Herramientas de Comunicación Directa
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Icon(
                        car.tripStarted
                            ? Icons.airline_seat_recline_normal
                            : Icons.people_alt_outlined,
                        size: 19,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          car.tripStarted
                              ? 'Pasajeros a Bordo (Datos Personales)'
                              : 'Próximos Pasajeros (En camino a la agencia)',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (passengersList.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Text(
                      'No hay asientos ocupados en este momento. Todos los asientos (4/4) están disponibles en la lista pública.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  )
                else
                  ...passengersList.map(
                    (pax) => Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4362C),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${pax.seatNumber}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${pax.passengerName} (Asiento ${pax.seatNumber})',
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Icon(
                                          car.tripStarted
                                              ? Icons.check_circle_outline
                                              : Icons.access_time_filled,
                                          size: 14,
                                          color: car.tripStarted
                                              ? const Color(0xFF2E7D32)
                                              : const Color(0xFFE65100),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            car.tripStarted
                                                ? 'A bordo • En viaje hacia ${car.destinationCity}'
                                                : _formatPassengerEta(pax),
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: car.tripStarted
                                                  ? const Color(0xFF2E7D32)
                                                  : const Color(0xFFE65100),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Acceso directo a Chat
                              IconButton(
                                tooltip: 'Chat directo',
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFFF9D408),
                                  foregroundColor: Colors.black,
                                  minimumSize: const Size(38, 38),
                                  padding: EdgeInsets.zero,
                                ),
                                icon: const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 18,
                                ),
                                onPressed: () => _openDirectChat(car, pax),
                              ),
                              const SizedBox(width: 6),
                              // Acceso directo a Llamada telefónica
                              IconButton(
                                tooltip: 'Llamada telefónica',
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFF1EE61E),
                                  foregroundColor: Colors.black,
                                  minimumSize: const Size(38, 38),
                                  padding: EdgeInsets.zero,
                                ),
                                icon: const Icon(
                                  Icons.phone_outlined,
                                  size: 19,
                                ),
                                onPressed: () => _callPassenger(pax),
                              ),
                              if (!car.tripStarted) ...[
                                const SizedBox(width: 6),
                                // Liberar asiento por cancelación anticipada
                                IconButton(
                                  tooltip: 'Cancelar / Liberar asiento',
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.red.shade50,
                                    foregroundColor: Colors.red.shade700,
                                    minimumSize: const Size(36, 36),
                                    padding: EdgeInsets.zero,
                                  ),
                                  icon: const Icon(
                                    Icons.event_seat_outlined,
                                    size: 18,
                                  ),
                                  onPressed: () async {
                                    await _repo.cancelSeatReservation(
                                      carId: car.id,
                                      seatNumber: pax.seatNumber,
                                    );
                                    if (!context.mounted) return;
                                    final updated = _repo.getCarById(car.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Reserva de ${pax.passengerName} cancelada. '
                                          'Asiento ${pax.seatNumber} disponible (${updated.availableSeatsCount}/4 Disponibles).',
                                        ),
                                        backgroundColor: Colors.green.shade700,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                          // Si el viaje ya inició: desplegar todos los datos personales del pasajero
                          if (car.tripStarted) ...[
                            const SizedBox(height: 8),
                            Divider(color: Colors.grey.shade300, height: 1),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 14,
                              runSpacing: 4,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.badge_outlined,
                                      size: 14,
                                      color: Colors.black54,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      pax.dni.isNotEmpty
                                          ? 'DNI: ${pax.dni}'
                                          : 'DNI: 72849102',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.phone_android,
                                      size: 14,
                                      color: Colors.black54,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      pax.phone,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                if (pax.email.isNotEmpty)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.email_outlined,
                                        size: 14,
                                        color: Colors.black54,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        pax.email,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                if (pax.city.isNotEmpty)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.location_city_outlined,
                                        size: 14,
                                        color: Colors.black54,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        pax.city,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DriverSeatOccupancyBox extends StatelessWidget {
  final int seatNumber;
  final bool isOccupied;
  final String passengerShortName;
  final VoidCallback onTap;

  const _DriverSeatOccupancyBox({
    required this.seatNumber,
    required this.isOccupied,
    required this.passengerShortName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isOccupied
        ? const Color(0xFFF4362C)
        : const Color(0xFF1EE61E);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.black87,
                width: 1.3,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isOccupied)
                  const CustomPaint(
                    size: Size(48, 48),
                    painter: OccupiedCrossPainter(
                      color: Color(0x66000000),
                      strokeWidth: 2.0,
                    ),
                  ),
                Text(
                  '$seatNumber',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            isOccupied ? 'Ocupado\n($passengerShortName)' : 'Disponible',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
