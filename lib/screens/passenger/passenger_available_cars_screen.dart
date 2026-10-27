import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class SeatPassengerInfo {
  final int seatNumber;
  final String passengerId;
  final String passengerName;
  final String shortName;
  final String phone;
  final String etaText;

  const SeatPassengerInfo({
    required this.seatNumber,
    required this.passengerId,
    required this.passengerName,
    required this.shortName,
    required this.phone,
    required this.etaText,
  });

  Map<String, dynamic> toMap() => {
    'seatNumber': seatNumber,
    'passengerId': passengerId,
    'passengerName': passengerName,
    'shortName': shortName,
    'phone': phone,
    'etaText': etaText,
  };

  factory SeatPassengerInfo.fromMap(Map<String, dynamic> map, int fallbackSeat) {
    final fullName = (map['passengerName'] ?? 'Pasajero').toString();
    return SeatPassengerInfo(
      seatNumber: (map['seatNumber'] as num?)?.toInt() ?? fallbackSeat,
      passengerId: (map['passengerId'] ?? 'guest').toString(),
      passengerName: fullName,
      shortName: (map['shortName'] ?? _formatShortName(fullName)).toString(),
      phone: (map['phone'] ?? '+51987654321').toString(),
      etaText: (map['etaText'] ?? 'ETA: 12 min a 15 min').toString(),
    );
  }

  static String _formatShortName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'Pasajero';
    if (parts.length == 1) return parts.first;
    final lastInitial = parts[1].isNotEmpty ? '${parts[1][0].toUpperCase()}.' : '';
    return '${parts.first} $lastInitial'.trim();
  }
}

class PendingSeatRequest {
  final String requestId;
  final String carId;
  final int seatNumber;
  final String passengerId;
  final String passengerName;
  final String passengerPhone;
  final double price;
  final String originCity;
  final String destinationCity;

  const PendingSeatRequest({
    required this.requestId,
    required this.carId,
    required this.seatNumber,
    required this.passengerId,
    required this.passengerName,
    required this.passengerPhone,
    required this.price,
    required this.originCity,
    required this.destinationCity,
  });

  String get seatPositionDescription {
    switch (seatNumber) {
      case 1:
        return 'Copiloto Delantero';
      case 2:
        return 'Atrás Izquierda';
      case 3:
        return 'Atrás Centro';
      case 4:
        return 'Atrás Derecha';
      default:
        return 'Asiento $seatNumber';
    }
  }

  Map<String, dynamic> toMap() => {
    'requestId': requestId,
    'carId': carId,
    'seatNumber': seatNumber,
    'passengerId': passengerId,
    'passengerName': passengerName,
    'passengerPhone': passengerPhone,
    'price': price,
    'originCity': originCity,
    'destinationCity': destinationCity,
  };

  factory PendingSeatRequest.fromMap(Map<String, dynamic> map) {
    return PendingSeatRequest(
      requestId: (map['requestId'] ?? '').toString(),
      carId: (map['carId'] ?? 'car_1').toString(),
      seatNumber: (map['seatNumber'] as num?)?.toInt() ?? 2,
      passengerId: (map['passengerId'] ?? 'guest').toString(),
      passengerName: (map['passengerName'] ?? 'María Torres').toString(),
      passengerPhone: (map['passengerPhone'] ?? '+51984112233').toString(),
      price: (map['price'] as num?)?.toDouble() ?? 45.0,
      originCity: (map['originCity'] ?? 'Tarapoto').toString(),
      destinationCity: (map['destinationCity'] ?? 'Yurimaguas').toString(),
    );
  }
}

class AvailableCarItem {
  final String id;
  final String driverName;
  final String vehicleModel;
  final String vehiclePlate;
  final String departureLabel;
  final double pricePerSeat;
  final String avatarUrl;
  final String originCity;
  final String destinationCity;
  final Map<int, String> seatStates; // 1..4 -> 'available' | 'occupied'
  final Map<int, SeatPassengerInfo> seatPassengers;
  final List<PendingSeatRequest> pendingRequests;

  const AvailableCarItem({
    required this.id,
    required this.driverName,
    required this.vehicleModel,
    required this.vehiclePlate,
    required this.departureLabel,
    required this.pricePerSeat,
    required this.avatarUrl,
    this.originCity = 'Tarapoto',
    this.destinationCity = 'Yurimaguas',
    required this.seatStates,
    this.seatPassengers = const {},
    this.pendingRequests = const [],
  });

  int get availableSeatsCount =>
      seatStates.values.where((s) => s == 'available').length;

  int get occupiedSeatsCount =>
      seatStates.values.where((s) => s == 'occupied').length;

  bool get isFull => availableSeatsCount == 0;

  AvailableCarItem copyWith({
    String? id,
    String? driverName,
    String? vehicleModel,
    String? vehiclePlate,
    String? departureLabel,
    double? pricePerSeat,
    String? avatarUrl,
    String? originCity,
    String? destinationCity,
    Map<int, String>? seatStates,
    Map<int, SeatPassengerInfo>? seatPassengers,
    List<PendingSeatRequest>? pendingRequests,
  }) {
    return AvailableCarItem(
      id: id ?? this.id,
      driverName: driverName ?? this.driverName,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      departureLabel: departureLabel ?? this.departureLabel,
      pricePerSeat: pricePerSeat ?? this.pricePerSeat,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      originCity: originCity ?? this.originCity,
      destinationCity: destinationCity ?? this.destinationCity,
      seatStates: seatStates ?? Map<int, String>.from(this.seatStates),
      seatPassengers:
          seatPassengers ??
          Map<int, SeatPassengerInfo>.from(this.seatPassengers),
      pendingRequests:
          pendingRequests ?? List<PendingSeatRequest>.from(this.pendingRequests),
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    final seatsMap = <String, String>{};
    for (final entry in seatStates.entries) {
      seatsMap[entry.key.toString()] = entry.value;
    }
    final passengersMap = <String, dynamic>{};
    for (final entry in seatPassengers.entries) {
      passengersMap[entry.key.toString()] = entry.value.toMap();
    }
    return {
      'id': id,
      'driverName': driverName,
      'vehicleModel': vehicleModel,
      'vehiclePlate': vehiclePlate,
      'departureLabel': departureLabel,
      'pricePerSeat': pricePerSeat,
      'avatarUrl': avatarUrl,
      'originCity': originCity,
      'destinationCity': destinationCity,
      'seatStates': seatsMap,
      'seatPassengers': passengersMap,
      'pendingRequests': pendingRequests.map((r) => r.toMap()).toList(),
      'availableSeats': availableSeatsCount,
      'occupiedSeats': occupiedSeatsCount,
      'isPubliclyVisible': availableSeatsCount > 0,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory AvailableCarItem.fromFirestoreMap(
    String docId,
    Map<String, dynamic> data,
    AvailableCarItem fallback,
  ) {
    final rawSeats = data['seatStates'];
    final parsedSeats = <int, String>{
      1: 'available',
      2: 'available',
      3: 'occupied',
      4: 'available',
    };
    if (rawSeats is Map) {
      for (final seatNum in [1, 2, 3, 4]) {
        final val = rawSeats[seatNum.toString()] ?? rawSeats[seatNum];
        if (val != null) {
          parsedSeats[seatNum] = val.toString();
        }
      }
    } else {
      parsedSeats.addAll(fallback.seatStates);
    }

    final rawPassengers = data['seatPassengers'];
    final parsedPassengers = <int, SeatPassengerInfo>{};
    if (rawPassengers is Map) {
      for (final entry in rawPassengers.entries) {
        final seatNum = int.tryParse(entry.key.toString());
        if (seatNum != null && entry.value is Map) {
          parsedPassengers[seatNum] = SeatPassengerInfo.fromMap(
            Map<String, dynamic>.from(entry.value as Map),
            seatNum,
          );
        }
      }
    } else {
      parsedPassengers.addAll(fallback.seatPassengers);
    }

    final rawRequests = data['pendingRequests'];
    final parsedRequests = <PendingSeatRequest>[];
    if (rawRequests is List) {
      for (final item in rawRequests) {
        if (item is Map) {
          parsedRequests.add(
            PendingSeatRequest.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    } else {
      parsedRequests.addAll(fallback.pendingRequests);
    }

    return AvailableCarItem(
      id: docId,
      driverName: (data['driverName'] ?? fallback.driverName).toString(),
      vehicleModel: (data['vehicleModel'] ?? fallback.vehicleModel).toString(),
      vehiclePlate: (data['vehiclePlate'] ?? fallback.vehiclePlate).toString(),
      departureLabel:
          (data['departureLabel'] ?? fallback.departureLabel).toString(),
      pricePerSeat:
          (data['pricePerSeat'] as num?)?.toDouble() ?? fallback.pricePerSeat,
      avatarUrl: (data['avatarUrl'] ?? fallback.avatarUrl).toString(),
      originCity: (data['originCity'] ?? fallback.originCity).toString(),
      destinationCity:
          (data['destinationCity'] ?? fallback.destinationCity).toString(),
      seatStates: parsedSeats,
      seatPassengers: parsedPassengers,
      pendingRequests: parsedRequests,
    );
  }
}

/// Repositorio en tiempo real (Firestore + estado reactivo local) para la
/// automatización de disponibilidad de asientos y ocultamiento/reapertura.
class IntercityVehicleRepository extends ChangeNotifier {
  IntercityVehicleRepository._internal() {
    _initFirestoreSync();
  }

  static final IntercityVehicleRepository instance =
      IntercityVehicleRepository._internal();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  final List<AvailableCarItem> _cars = [
    AvailableCarItem(
      id: 'car_1',
      driverName: 'Juan Pérez',
      vehicleModel: 'Toyota Yaris',
      vehiclePlate: 'ABC-123',
      departureLabel: 'Hoy, 14:30',
      pricePerSeat: 45.00,
      avatarUrl:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=240&auto=format&fit=crop&q=80',
      originCity: 'Tarapoto',
      destinationCity: 'Yurimaguas',
      seatStates: const {
        1: 'occupied',
        2: 'available',
        3: 'occupied',
        4: 'available',
      },
      seatPassengers: const {
        1: SeatPassengerInfo(
          seatNumber: 1,
          passengerId: 'pax_juan_d',
          passengerName: 'Juan Díaz',
          shortName: 'Juan D.',
          phone: '+51987654321',
          etaText: 'ETA: 12 min a 15 min',
        ),
        3: SeatPassengerInfo(
          seatNumber: 3,
          passengerId: 'pax_carlos_r',
          passengerName: 'Carlos Ramírez',
          shortName: 'Carlos R.',
          phone: '+51912345678',
          etaText: 'ETA: 12 min a 15 min',
        ),
      },
      pendingRequests: const [
        PendingSeatRequest(
          requestId: 'req_maria_seat2',
          carId: 'car_1',
          seatNumber: 2,
          passengerId: 'pax_maria_t',
          passengerName: 'María Torres',
          passengerPhone: '+51945678123',
          price: 45.00,
          originCity: 'Tarapoto',
          destinationCity: 'Yurimaguas',
        ),
      ],
    ),
    AvailableCarItem(
      id: 'car_2',
      driverName: 'Juan Pérez',
      vehicleModel: 'Toyota Yaris',
      vehiclePlate: 'ABC-123',
      departureLabel: 'Hoy, 14:30',
      pricePerSeat: 45.00,
      avatarUrl:
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=240&auto=format&fit=crop&q=80',
      originCity: 'Yurimaguas',
      destinationCity: 'Tarapoto',
      seatStates: const {
        1: 'occupied',
        2: 'available',
        3: 'occupied',
        4: 'occupied',
      },
      seatPassengers: const {
        1: SeatPassengerInfo(
          seatNumber: 1,
          passengerId: 'pax_1',
          passengerName: 'Luis Gómez',
          shortName: 'Luis G.',
          phone: '+51987111222',
          etaText: 'ETA: 10 min a 12 min',
        ),
        3: SeatPassengerInfo(
          seatNumber: 3,
          passengerId: 'pax_3',
          passengerName: 'Ana Vargas',
          shortName: 'Ana V.',
          phone: '+51987333444',
          etaText: 'ETA: 12 min a 15 min',
        ),
        4: SeatPassengerInfo(
          seatNumber: 4,
          passengerId: 'pax_4',
          passengerName: 'Pedro Salas',
          shortName: 'Pedro S.',
          phone: '+51987555666',
          etaText: 'ETA: 8 min a 10 min',
        ),
      },
    ),
    AvailableCarItem(
      id: 'car_3',
      driverName: 'Juan Pérez',
      vehicleModel: 'Toyota Yaris',
      vehiclePlate: 'ABC-123',
      departureLabel: 'Hoy, 14:30',
      pricePerSeat: 45.00,
      avatarUrl:
          'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=240&auto=format&fit=crop&q=80',
      originCity: 'Yurimaguas',
      destinationCity: 'Tarapoto',
      seatStates: const {
        1: 'occupied',
        2: 'available',
        3: 'occupied',
        4: 'occupied',
      },
    ),
    AvailableCarItem(
      id: 'car_4',
      driverName: 'Juan Pérez',
      vehicleModel: 'Toyota Yaris',
      vehiclePlate: 'ABC-123',
      departureLabel: 'Hoy, 14:30',
      pricePerSeat: 45.00,
      avatarUrl:
          'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=240&auto=format&fit=crop&q=80',
      originCity: 'Yurimaguas',
      destinationCity: 'Tarapoto',
      seatStates: const {
        1: 'occupied',
        2: 'available',
        3: 'occupied',
        4: 'occupied',
      },
    ),
  ];

  List<AvailableCarItem> get allCars => List.unmodifiable(_cars);

  /// Ocultamiento Automático por Ocupación Total:
  /// Cuando los 4 asientos de un vehículo alcanzan el estado de ocupados
  /// (availableSeatsCount == 0), se retira automáticamente de la lista pública.
  List<AvailableCarItem> get publicAvailableCars =>
      _cars.where((c) => c.availableSeatsCount > 0).toList();

  /// Vehículo activo del conductor actual (por defecto car_1).
  AvailableCarItem get driverPrimaryVehicle => _cars.first;

  AvailableCarItem getCarById(String carId) {
    return _cars.firstWhere(
      (c) => c.id == carId,
      orElse: () => _cars.first,
    );
  }

  void _initFirestoreSync() {
    try {
      final col = FirebaseFirestore.instance.collection('intercity_vehicles');
      _subscription = col.snapshots().listen(
        (snapshot) {
          if (snapshot.docs.isEmpty) {
            // Sembrar los vehículos iniciales en Firestore
            for (final car in _cars) {
              col.doc(car.id).set(car.toFirestoreMap()).catchError((_) {});
            }
            return;
          }
          bool changed = false;
          for (final doc in snapshot.docs) {
            final idx = _cars.indexWhere((c) => c.id == doc.id);
            if (idx != -1) {
              _cars[idx] = AvailableCarItem.fromFirestoreMap(
                doc.id,
                doc.data(),
                _cars[idx],
              );
              changed = true;
            }
          }
          if (changed) {
            notifyListeners();
          }
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  Future<void> _persistCar(AvailableCarItem car) async {
    try {
      await FirebaseFirestore.instance
          .collection('intercity_vehicles')
          .doc(car.id)
          .set(car.toFirestoreMap(), SetOptions(merge: true));
    } catch (_) {}
  }

  /// Reserva u ocupa un asiento en tiempo real. Si con este asiento se llenan
  /// los 4 asientos, availableSeats pasa a 0 y el vehículo se oculta de la
  /// lista pública de pasajeros automáticamente.
  Future<void> occupySeat({
    required String carId,
    required int seatNumber,
    required String passengerId,
    required String passengerName,
    required String passengerPhone,
    String etaText = 'ETA: 12 min a 15 min',
    String? removeRequestId,
  }) async {
    final idx = _cars.indexWhere((c) => c.id == carId);
    if (idx == -1) return;

    final current = _cars[idx];
    final updatedSeats = Map<int, String>.from(current.seatStates);
    updatedSeats[seatNumber] = 'occupied';

    final updatedPassengers = Map<int, SeatPassengerInfo>.from(
      current.seatPassengers,
    );
    updatedPassengers[seatNumber] = SeatPassengerInfo(
      seatNumber: seatNumber,
      passengerId: passengerId,
      passengerName: passengerName,
      shortName: SeatPassengerInfo._formatShortName(passengerName),
      phone: passengerPhone.isNotEmpty ? passengerPhone : '+51987654321',
      etaText: etaText,
    );

    final updatedRequests = List<PendingSeatRequest>.from(
      current.pendingRequests,
    )..removeWhere(
      (r) =>
          (removeRequestId != null && r.requestId == removeRequestId) ||
          r.seatNumber == seatNumber,
    );

    final updatedCar = current.copyWith(
      seatStates: updatedSeats,
      seatPassengers: updatedPassengers,
      pendingRequests: updatedRequests,
    );

    _cars[idx] = updatedCar;
    notifyListeners();
    await _persistCar(updatedCar);
  }

  /// Reapertura Automática por Cancelación:
  /// Si un pasajero cancela su reserva con anticipación (o el conductor libera
  /// el asiento), el sistema libera el asiento correspondiente, actualiza su
  /// estado a 'available' y el vehículo reaparece instantáneamente en la lista
  /// pública reflejando el número real de plazas libres (ej. 1/4 Disponibles).
  Future<void> cancelSeatReservation({
    required String carId,
    required int seatNumber,
  }) async {
    final idx = _cars.indexWhere((c) => c.id == carId);
    if (idx == -1) return;

    final current = _cars[idx];
    final updatedSeats = Map<int, String>.from(current.seatStates);
    updatedSeats[seatNumber] = 'available';

    final updatedPassengers = Map<int, SeatPassengerInfo>.from(
      current.seatPassengers,
    )..remove(seatNumber);

    final updatedCar = current.copyWith(
      seatStates: updatedSeats,
      seatPassengers: updatedPassengers,
    );

    _cars[idx] = updatedCar;
    notifyListeners();
    await _persistCar(updatedCar);
  }

  /// Rechaza una solicitud pendiente sin ocupar el asiento.
  Future<void> rejectPendingRequest({
    required String carId,
    required String requestId,
  }) async {
    final idx = _cars.indexWhere((c) => c.id == carId);
    if (idx == -1) return;

    final current = _cars[idx];
    final updatedRequests = List<PendingSeatRequest>.from(
      current.pendingRequests,
    )..removeWhere((r) => r.requestId == requestId);

    final updatedCar = current.copyWith(pendingRequests: updatedRequests);
    _cars[idx] = updatedCar;
    notifyListeners();
    await _persistCar(updatedCar);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

class AvailableCarsScreen extends StatefulWidget {
  final String originCity;
  final String destinationCity;

  const AvailableCarsScreen({
    super.key,
    required this.originCity,
    required this.destinationCity,
  });

  @override
  State<AvailableCarsScreen> createState() => _AvailableCarsScreenState();
}

class _AvailableCarsScreenState extends State<AvailableCarsScreen> {
  int _selectedCardIndex = 1;
  final IntercityVehicleRepository _repo = IntercityVehicleRepository.instance;

  void _openSeatSelection(AvailableCarItem car, int index) {
    setState(() => _selectedCardIndex = index);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CarSeatSelectionScreen(
          car: car,
          originCity: widget.originCity,
          destinationCity: widget.destinationCity,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _repo,
      builder: (context, _) {
        final visibleCars = _repo.publicAvailableCars;
        final fullHiddenCars = _repo.allCars.where((c) => c.isFull).toList();

        return Scaffold(
          backgroundColor: const Color(0xFFF8F8F8),
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Autos Disponibles',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          body: Column(
            children: [
              // Si el usuario tiene una reserva en un vehículo (incluso si el
              // vehículo ya se llenó 4/4 y se ocultó de la lista pública),
              // permite cancelar anticipadamente para disparar la Reapertura Automática.
              if (fullHiddenCars.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF9D408)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${fullHiddenCars.length} vehículo(s) con 4/4 asientos ocupados se ocultaron automáticamente.',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () async {
                          final fullCar = fullHiddenCars.first;
                          // Liberar el último asiento ocupado para demostrar
                          // la reapertura instantánea (1/4 Disponibles)
                          final occupiedEntry = fullCar.seatStates.entries
                              .firstWhere(
                                (e) => e.value == 'occupied',
                                orElse: () => const MapEntry(4, 'occupied'),
                              );
                          await _repo.cancelSeatReservation(
                            carId: fullCar.id,
                            seatNumber: occupiedEntry.key,
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Reserva cancelada en Asiento ${occupiedEntry.key}. '
                                'El vehículo ${fullCar.vehiclePlate} reapareció (1/4 Disponibles).',
                              ),
                              backgroundColor: Colors.green.shade700,
                            ),
                          );
                        },
                        child: const Text(
                          'Cancelar mi reserva',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: visibleCars.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.directions_car_filled_outlined,
                                size: 54,
                                color: Colors.black38,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Todos los vehículos están llenos (4/4 ocupados)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Si un pasajero cancela su reserva con anticipación, el vehículo reaparecerá automáticamente aquí.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: visibleCars.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final car = visibleCars[index];
                          final isSelected = _selectedCardIndex == index;
                          final showSeatNumbers = index == 2;
                          final freeSeats = car.availableSeatsCount;

                          return GestureDetector(
                            onTap: () => _openSeatSelection(car, index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                14,
                                14,
                                14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.black87
                                      : Colors.grey.shade200,
                                  width: isSelected ? 1.8 : 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          car.avatarUrl,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Container(
                                            width: 60,
                                            height: 60,
                                            color: Colors.grey.shade300,
                                            child: const Icon(
                                              Icons.person,
                                              color: Colors.black54,
                                              size: 32,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              car.driverName,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              '${car.vehicleModel} - ${car.vehiclePlate}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              car.departureLabel,
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const SizedBox(width: 74),
                                      Text(
                                        'S/ ${car.pricePerSeat.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const Spacer(),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          _MiniSeatGridIndicator(
                                            showNumbers: showSeatNumbers,
                                            seatStates: car.seatStates,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '$freeSeats/4 Disponibles',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.black87,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniSeatGridIndicator extends StatelessWidget {
  final bool showNumbers;
  final Map<int, String> seatStates;

  const _MiniSeatGridIndicator({
    this.showNumbers = false,
    required this.seatStates,
  });

  Color _colorForSeat(int seat, {bool highlightFirstAvailable = false}) {
    final isOccupied = seatStates[seat] == 'occupied';
    if (isOccupied) return const Color(0xFF555555);
    if (highlightFirstAvailable) return const Color(0xFFF9D408);
    return const Color(0xFF9E9E9E);
  }

  @override
  Widget build(BuildContext context) {
    final seat2Available = seatStates[2] != 'occupied';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _MiniSeatIcon(color: Color(0xFFBDBDBD)),
            const SizedBox(width: 3),
            const _MiniSeatIcon(color: Color(0xFFBDBDBD)),
            const SizedBox(width: 3),
            _MiniSeatIcon(color: _colorForSeat(1)),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MiniSeatIcon(
              color: _colorForSeat(2, highlightFirstAvailable: seat2Available),
              label: showNumbers ? '2' : null,
              labelColor: seat2Available ? Colors.black : Colors.white,
            ),
            const SizedBox(width: 3),
            _MiniSeatIcon(
              color: _colorForSeat(3),
              label: showNumbers ? '3' : null,
              labelColor: Colors.white,
            ),
            const SizedBox(width: 3),
            _MiniSeatIcon(color: _colorForSeat(4)),
          ],
        ),
      ],
    );
  }
}

class _MiniSeatIcon extends StatelessWidget {
  final Color color;
  final String? label;
  final Color labelColor;

  const _MiniSeatIcon({
    required this.color,
    this.label,
    this.labelColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
          ),
        ),
        const SizedBox(height: 1),
        Container(
          width: 14,
          height: 13,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
          child: label != null
              ? Text(
                  label!,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: labelColor,
                    height: 1,
                  ),
                )
              : null,
        ),
      ],
    );
  }
}

class CarSeatSelectionScreen extends StatefulWidget {
  final AvailableCarItem car;
  final String originCity;
  final String destinationCity;

  const CarSeatSelectionScreen({
    super.key,
    required this.car,
    required this.originCity,
    required this.destinationCity,
  });

  @override
  State<CarSeatSelectionScreen> createState() => _CarSeatSelectionScreenState();
}

class _CarSeatSelectionScreenState extends State<CarSeatSelectionScreen> {
  final IntercityVehicleRepository _repo = IntercityVehicleRepository.instance;
  late int _selectedSeat;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final liveCar = _repo.getCarById(widget.car.id);
    _selectedSeat = _firstAvailableSeat(liveCar);
  }

  int _firstAvailableSeat(AvailableCarItem car) {
    for (final s in [2, 1, 4, 3]) {
      if (car.seatStates[s] != 'occupied') return s;
    }
    return 2;
  }

  Future<void> _confirmSeatBooking(AvailableCarItem liveCar) async {
    if (liveCar.seatStates[_selectedSeat] == 'occupied') return;
    setState(() => _isSubmitting = true);

    final user = AuthService.instance.currentUser;
    final passengerId = user?.uid ?? 'guest';
    final rawName = user?.name?.trim() ?? '';
    final passengerName = rawName.isNotEmpty ? rawName : 'Pasajero Mijano';
    final rawPhone = user?.phone.trim() ?? '';
    final passengerPhone = rawPhone.isNotEmpty ? rawPhone : '+51987654321';

    // Actualizar ocupación en tiempo real (si llega a 4/4 ocupados, el
    // contador pasa a 0 y se oculta automáticamente de la lista pública).
    await _repo.occupySeat(
      carId: liveCar.id,
      seatNumber: _selectedSeat,
      passengerId: passengerId,
      passengerName: passengerName,
      passengerPhone: passengerPhone,
      etaText: 'ETA: 12 min a 15 min',
    );

    try {
      await FirebaseFirestore.instance.collection('trips').add({
        'passengerId': passengerId,
        'passengerName': passengerName,
        'passengerPhone': passengerPhone,
        'originAddress': widget.originCity,
        'destinationAddress': widget.destinationCity,
        'fareAmount': liveCar.pricePerSeat,
        'serviceType': 'Auto Interprovincial',
        'vehicleType': 'Auto',
        'carId': liveCar.id,
        'driverName': liveCar.driverName,
        'driverVehicleModel': liveCar.vehicleModel,
        'driverVehiclePlate': liveCar.vehiclePlate,
        'seatNumber': _selectedSeat,
        'departureLabel': liveCar.departureLabel,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    final updatedCar = _repo.getCarById(liveCar.id);
    final isNowFull = updatedCar.availableSeatsCount == 0;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Asiento Reservado',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          'Has seleccionado el Asiento $_selectedSeat para la ruta '
          '${widget.originCity} → ${widget.destinationCity} '
          'con ${liveCar.driverName} (${liveCar.vehicleModel} - ${liveCar.vehiclePlate}).\n\n'
          'Total: S/ ${liveCar.pricePerSeat.toStringAsFixed(2)}'
          '${isNowFull ? '\n\n¡Vehículo completo (4/4)! Se ha retirado automáticamente de la lista pública.' : ''}',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF9D408),
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text(
              'Aceptar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _repo,
      builder: (context, _) {
        final liveCar = _repo.getCarById(widget.car.id);
        if (liveCar.seatStates[_selectedSeat] == 'occupied' &&
            liveCar.availableSeatsCount > 0) {
          _selectedSeat = _firstAvailableSeat(liveCar);
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Seleccionar Asiento → ${widget.destinationCity}',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Ruta: ${widget.originCity} → ${widget.destinationCity}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '(${liveCar.departureLabel})',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Diagrama interactivo del Auto
                      SizedBox(
                        width: 280,
                        height: 330,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: CarTopDownOutlinePainter(),
                              ),
                            ),
                            // Asiento 1 (Copiloto - Delantero derecho)
                            Positioned(
                              top: 86,
                              right: 42,
                              child: _SeatBoxWidget(
                                seatNumber: 1,
                                status: _seatStatus(liveCar, 1),
                                onTap: () => _onSelectSeat(liveCar, 1),
                              ),
                            ),
                            // Fila trasera: Asientos 2, 3 y 4
                            Positioned(
                              bottom: 62,
                              left: 34,
                              right: 34,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _SeatBoxWidget(
                                    seatNumber: 2,
                                    status: _seatStatus(liveCar, 2),
                                    onTap: () => _onSelectSeat(liveCar, 2),
                                  ),
                                  _SeatBoxWidget(
                                    seatNumber: 3,
                                    status: _seatStatus(liveCar, 3),
                                    onTap: () => _onSelectSeat(liveCar, 3),
                                  ),
                                  _SeatBoxWidget(
                                    seatNumber: 4,
                                    status: _seatStatus(liveCar, 4),
                                    onTap: () => _onSelectSeat(liveCar, 4),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Leyenda de estados
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          _SeatLegendItem(
                            color: Color(0xFFE5E5E5),
                            borderColor: Color(0xFFBDBDBD),
                            label: 'Disponible',
                          ),
                          SizedBox(width: 16),
                          _SeatLegendItem(
                            color: Color(0xFFF9D408),
                            borderColor: Color(0xFFD4B200),
                            label: 'Seleccionado',
                          ),
                          SizedBox(width: 16),
                          _SeatLegendItem(
                            color: Color(0xFF555555),
                            borderColor: Color(0xFF444444),
                            label: 'Ocupado',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Barra inferior de confirmación
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ruta: ${widget.originCity} → ${widget.destinationCity}',
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF9D408),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed:
                            (_isSubmitting || liveCar.availableSeatsCount == 0)
                            ? null
                            : () => _confirmSeatBooking(liveCar),
                        child: Text(
                          _isSubmitting
                              ? 'Confirmando...'
                              : 'Confirmar Asiento $_selectedSeat',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _seatStatus(AvailableCarItem car, int seatNumber) {
    final baseState = car.seatStates[seatNumber] ?? 'available';
    if (baseState == 'occupied') return 'occupied';
    if (_selectedSeat == seatNumber) return 'selected';
    return 'available';
  }

  void _onSelectSeat(AvailableCarItem car, int seatNumber) {
    final baseState = car.seatStates[seatNumber] ?? 'available';
    if (baseState == 'occupied') return;
    setState(() => _selectedSeat = seatNumber);
  }
}

class _SeatBoxWidget extends StatelessWidget {
  final int seatNumber;
  final String status; // 'available' | 'selected' | 'occupied'
  final VoidCallback onTap;

  const _SeatBoxWidget({
    required this.seatNumber,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = status == 'selected';
    final bool isOccupied = status == 'occupied';

    final Color bgColor = isSelected
        ? const Color(0xFFF9D408)
        : isOccupied
        ? const Color(0xFF5A5A5A)
        : const Color(0xFFE6E6E6);

    final Color borderColor = isSelected
        ? Colors.black87
        : isOccupied
        ? const Color(0xFF424242)
        : const Color(0xFF9E9E9E);

    final Color textColor = isOccupied ? Colors.white : Colors.black;

    final String statusText = isSelected
        ? 'Seleccionado'
        : isOccupied
        ? 'Ocupado'
        : 'Disponible';

    return GestureDetector(
      onTap: isOccupied ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 64,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: borderColor,
                width: isSelected ? 1.8 : 1.2,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isOccupied)
                  CustomPaint(
                    size: const Size(44, 44),
                    painter: OccupiedCrossPainter(),
                  ),
                Text(
                  '$seatNumber',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            statusText,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class OccupiedCrossPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const OccupiedCrossPainter({
    this.color = const Color(0x38FFFFFF),
    this.strokeWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      const Offset(8, 8),
      Offset(size.width - 8, size.height - 8),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - 8, 8),
      Offset(8, size.height - 8),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SeatLegendItem extends StatelessWidget {
  final Color color;
  final Color borderColor;
  final String label;

  const _SeatLegendItem({
    required this.color,
    required this.borderColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: borderColor, width: 1),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class CarTopDownOutlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bodyFill = Paint()
      ..color = const Color(0xFFF3F3F3)
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = const Color(0xFF333333)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final detailPaint = Paint()
      ..color = const Color(0xFF555555)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;

    // Contorno principal del auto (vista superior)
    final carPath = Path()
      ..moveTo(w * 0.22, h * 0.08)
      ..quadraticBezierTo(w * 0.50, h * 0.01, w * 0.78, h * 0.08)
      ..quadraticBezierTo(w * 0.90, h * 0.16, w * 0.90, h * 0.34)
      ..lineTo(w * 0.91, h * 0.82)
      ..quadraticBezierTo(w * 0.90, h * 0.95, w * 0.76, h * 0.97)
      ..quadraticBezierTo(w * 0.50, h * 0.99, w * 0.24, h * 0.97)
      ..quadraticBezierTo(w * 0.10, h * 0.95, w * 0.09, h * 0.82)
      ..lineTo(w * 0.10, h * 0.34)
      ..quadraticBezierTo(w * 0.10, h * 0.16, w * 0.22, h * 0.08)
      ..close();

    canvas.drawPath(carPath, bodyFill);
    canvas.drawPath(carPath, outlinePaint);

    // Espejos laterales
    final leftMirror = Path()
      ..moveTo(w * 0.10, h * 0.25)
      ..lineTo(w * 0.02, h * 0.22)
      ..quadraticBezierTo(w * 0.01, h * 0.26, w * 0.04, h * 0.28)
      ..lineTo(w * 0.10, h * 0.29);
    final rightMirror = Path()
      ..moveTo(w * 0.90, h * 0.25)
      ..lineTo(w * 0.98, h * 0.22)
      ..quadraticBezierTo(w * 0.99, h * 0.26, w * 0.96, h * 0.28)
      ..lineTo(w * 0.90, h * 0.29);
    canvas.drawPath(leftMirror, bodyFill);
    canvas.drawPath(leftMirror, outlinePaint);
    canvas.drawPath(rightMirror, bodyFill);
    canvas.drawPath(rightMirror, outlinePaint);

    // Parabrisas delantero y tablero
    final windshieldPath = Path()
      ..moveTo(w * 0.16, h * 0.22)
      ..quadraticBezierTo(w * 0.50, h * 0.14, w * 0.84, h * 0.22)
      ..lineTo(w * 0.82, h * 0.27)
      ..quadraticBezierTo(w * 0.50, h * 0.23, w * 0.18, h * 0.27)
      ..close();
    canvas.drawPath(windshieldPath, detailPaint);

    // Líneas del capó
    canvas.drawLine(
      Offset(w * 0.26, h * 0.09),
      Offset(w * 0.22, h * 0.20),
      detailPaint,
    );
    canvas.drawLine(
      Offset(w * 0.74, h * 0.09),
      Offset(w * 0.78, h * 0.20),
      detailPaint,
    );

    // Volante (lado del conductor - delantero izquierdo)
    final wheelCenter = Offset(w * 0.29, h * 0.28);
    canvas.drawCircle(wheelCenter, 15, outlinePaint);
    canvas.drawCircle(wheelCenter, 11, detailPaint);
    canvas.drawCircle(wheelCenter, 3, outlinePaint);
    canvas.drawLine(
      Offset(wheelCenter.dx - 11, wheelCenter.dy),
      Offset(wheelCenter.dx + 11, wheelCenter.dy),
      detailPaint,
    );
    canvas.drawLine(
      Offset(wheelCenter.dx, wheelCenter.dy),
      Offset(wheelCenter.dx, wheelCenter.dy + 11),
      detailPaint,
    );

    // Asiento del conductor (delantero izquierdo)
    final driverSeatRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.17, h * 0.33, 52, 46),
      const Radius.circular(8),
    );
    final driverBackrest = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.19, h * 0.45, 42, 12),
      const Radius.circular(5),
    );
    canvas.drawRRect(
      driverSeatRect,
      Paint()
        ..color = const Color(0xFFDADADA)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(driverSeatRect, detailPaint);
    canvas.drawRRect(driverBackrest, detailPaint);

    // Consola central / palanca de cambios
    final consoleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.45, h * 0.30, 22, 48),
      const Radius.circular(5),
    );
    canvas.drawRRect(consoleRect, detailPaint);
    canvas.drawCircle(Offset(w * 0.49, h * 0.37), 4, outlinePaint);

    // Línea inferior de maletera
    final trunkPath = Path()
      ..moveTo(w * 0.15, h * 0.87)
      ..quadraticBezierTo(w * 0.50, h * 0.91, w * 0.85, h * 0.87);
    canvas.drawPath(trunkPath, detailPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
