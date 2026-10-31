import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/tariff_model.dart';
import '../../services/auth_service.dart';

class SeatPassengerInfo {
  final int seatNumber;
  final String passengerId;
  final String passengerName;
  final String shortName;
  final String phone;
  final String etaText;
  final String dni;
  final String email;
  final int? age;
  final String city;
  final String photoUrl;
  final int reservedAtMs;
  final String tripId;

  const SeatPassengerInfo({
    required this.seatNumber,
    required this.passengerId,
    required this.passengerName,
    required this.shortName,
    required this.phone,
    required this.etaText,
    this.dni = '',
    this.email = '',
    this.age,
    this.city = '',
    this.photoUrl = '',
    this.reservedAtMs = 0,
    this.tripId = '',
  });

  SeatPassengerInfo copyWith({
    int? seatNumber,
    String? passengerId,
    String? passengerName,
    String? shortName,
    String? phone,
    String? etaText,
    String? dni,
    String? email,
    int? age,
    String? city,
    String? photoUrl,
    int? reservedAtMs,
    String? tripId,
  }) {
    return SeatPassengerInfo(
      seatNumber: seatNumber ?? this.seatNumber,
      passengerId: passengerId ?? this.passengerId,
      passengerName: passengerName ?? this.passengerName,
      shortName: shortName ?? this.shortName,
      phone: phone ?? this.phone,
      etaText: etaText ?? this.etaText,
      dni: dni ?? this.dni,
      email: email ?? this.email,
      age: age ?? this.age,
      city: city ?? this.city,
      photoUrl: photoUrl ?? this.photoUrl,
      reservedAtMs: reservedAtMs ?? this.reservedAtMs,
      tripId: tripId ?? this.tripId,
    );
  }

  Map<String, dynamic> toMap() => {
    'seatNumber': seatNumber,
    'passengerId': passengerId,
    'passengerName': passengerName,
    'shortName': shortName,
    'phone': phone,
    'etaText': etaText,
    'dni': dni,
    'email': email,
    'age': age,
    'city': city,
    'photoUrl': photoUrl,
    'reservedAtMs': reservedAtMs,
    'tripId': tripId,
  };

  factory SeatPassengerInfo.fromMap(
    Map<String, dynamic> map,
    int fallbackSeat,
  ) {
    final fullName = (map['passengerName'] ?? 'Pasajero').toString();
    return SeatPassengerInfo(
      seatNumber: (map['seatNumber'] as num?)?.toInt() ?? fallbackSeat,
      passengerId: (map['passengerId'] ?? 'guest').toString(),
      passengerName: fullName,
      shortName: (map['shortName'] ?? formatShortName(fullName)).toString(),
      phone: (map['phone'] ?? '+51987654321').toString(),
      etaText: (map['etaText'] ?? 'ETA: 12 min a 15 min').toString(),
      dni: (map['dni'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      age: (map['age'] as num?)?.toInt(),
      city: (map['city'] ?? '').toString(),
      photoUrl: (map['photoUrl'] ?? '').toString(),
      reservedAtMs: (map['reservedAtMs'] as num?)?.toInt() ?? 0,
      tripId: (map['tripId'] ?? '').toString(),
    );
  }

  static String formatShortName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'Pasajero';
    if (parts.length == 1) return parts.first;
    final lastInitial = parts[1].isNotEmpty
        ? '${parts[1][0].toUpperCase()}.'
        : '';
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
  final String passengerDni;
  final String passengerEmail;
  final int? passengerAge;
  final String passengerCity;
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
    this.passengerDni = '',
    this.passengerEmail = '',
    this.passengerAge,
    this.passengerCity = '',
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
    'passengerDni': passengerDni,
    'passengerEmail': passengerEmail,
    'passengerAge': passengerAge,
    'passengerCity': passengerCity,
    'price': price,
    'originCity': originCity,
    'destinationCity': destinationCity,
  };

  factory PendingSeatRequest.fromMap(Map<String, dynamic> map) {
    return PendingSeatRequest(
      requestId: (map['requestId'] ?? '').toString(),
      carId: (map['carId'] ?? '').toString(),
      seatNumber: (map['seatNumber'] as num?)?.toInt() ?? 2,
      passengerId: (map['passengerId'] ?? 'guest').toString(),
      passengerName: (map['passengerName'] ?? 'Pasajero').toString(),
      passengerPhone: (map['passengerPhone'] ?? '+51987654321').toString(),
      passengerDni: (map['passengerDni'] ?? '').toString(),
      passengerEmail: (map['passengerEmail'] ?? '').toString(),
      passengerAge: (map['passengerAge'] as num?)?.toInt(),
      passengerCity: (map['passengerCity'] ?? '').toString(),
      price: (map['price'] as num?)?.toDouble() ?? 45.0,
      originCity: (map['originCity'] ?? 'Tarapoto').toString(),
      destinationCity: (map['destinationCity'] ?? 'Yurimaguas').toString(),
    );
  }
}

class AvailableCarItem {
  final String id;
  final String driverId;
  final String driverName;
  final String driverPhone;
  final String vehicleBrand;
  final String vehicleModel;
  final String vehiclePlate;
  final String agencyName;
  final String departureLabel;
  final double pricePerSeat;
  final String avatarUrl;
  final String originCity;
  final String destinationCity;
  final Map<int, String> seatStates; // 1..4 -> 'available' | 'occupied'
  final Map<int, SeatPassengerInfo> seatPassengers;
  final List<PendingSeatRequest> pendingRequests;
  final List<Map<String, dynamic>> chatMessages;
  final bool tripStarted;

  const AvailableCarItem({
    required this.id,
    this.driverId = '',
    required this.driverName,
    this.driverPhone = '',
    this.vehicleBrand = '',
    required this.vehicleModel,
    required this.vehiclePlate,
    this.agencyName = '',
    required this.departureLabel,
    required this.pricePerSeat,
    required this.avatarUrl,
    this.originCity = 'Tarapoto',
    this.destinationCity = 'Yurimaguas',
    required this.seatStates,
    this.seatPassengers = const {},
    this.pendingRequests = const [],
    this.chatMessages = const [],
    this.tripStarted = false,
  });

  int get availableSeatsCount =>
      seatStates.values.where((s) => s == 'available').length;

  int get occupiedSeatsCount =>
      seatStates.values.where((s) => s == 'occupied').length;

  int get totalSeatsCount => seatStates.isNotEmpty ? seatStates.length : 4;

  bool get isFull => availableSeatsCount == 0;

  AvailableCarItem copyWith({
    String? id,
    String? driverId,
    String? driverName,
    String? driverPhone,
    String? vehicleBrand,
    String? vehicleModel,
    String? vehiclePlate,
    String? agencyName,
    String? departureLabel,
    double? pricePerSeat,
    String? avatarUrl,
    String? originCity,
    String? destinationCity,
    Map<int, String>? seatStates,
    Map<int, SeatPassengerInfo>? seatPassengers,
    List<PendingSeatRequest>? pendingRequests,
    List<Map<String, dynamic>>? chatMessages,
    bool? tripStarted,
  }) {
    return AvailableCarItem(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      vehicleBrand: vehicleBrand ?? this.vehicleBrand,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      agencyName: agencyName ?? this.agencyName,
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
      chatMessages:
          chatMessages ?? List<Map<String, dynamic>>.from(this.chatMessages),
      tripStarted: tripStarted ?? this.tripStarted,
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
      'driverId': driverId.isNotEmpty ? driverId : id,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'vehicleBrand': vehicleBrand,
      'vehicleModel': vehicleModel,
      'vehiclePlate': vehiclePlate,
      'vehicleType': 'Carro',
      'agencyName': agencyName,
      'departureLabel': departureLabel,
      'pricePerSeat': pricePerSeat,
      'avatarUrl': avatarUrl,
      'originCity': originCity,
      'destinationCity': destinationCity,
      'seatStates': seatsMap,
      'seatPassengers': passengersMap,
      'pendingRequests': pendingRequests.map((r) => r.toMap()).toList(),
      'chatMessages': chatMessages,
      'tripStarted': tripStarted,
      'availableSeats': availableSeatsCount,
      'occupiedSeats': occupiedSeatsCount,
      'isPubliclyVisible': availableSeatsCount > 0 && !tripStarted,
      'isIntercityCar': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory AvailableCarItem.fromFirestoreMap(
    String rawDocId,
    Map<String, dynamic> data, {
    AvailableCarItem? fallback,
  }) {
    final cleanId = rawDocId.startsWith('CAR_VEHICLE_')
        ? rawDocId.substring('CAR_VEHICLE_'.length)
        : (data['driverId'] ?? data['id'] ?? rawDocId).toString();

    final rawSeats = data['seatStates'];
    final parsedSeats = <int, String>{};
    if (fallback != null && fallback.seatStates.isNotEmpty) {
      parsedSeats.addAll(fallback.seatStates);
    } else {
      parsedSeats.addAll({
        1: 'available',
        2: 'available',
        3: 'available',
        4: 'available',
      });
    }
    if (rawSeats is Map && rawSeats.isNotEmpty) {
      parsedSeats.clear();
      for (final entry in rawSeats.entries) {
        final seatNum = int.tryParse(entry.key.toString());
        if (seatNum != null && seatNum > 0) {
          parsedSeats[seatNum] = entry.value.toString();
        }
      }
    }

    final rawPassengers = data['seatPassengers'];
    final parsedPassengers = <int, SeatPassengerInfo>{};
    if (rawPassengers is Map) {
      for (final entry in rawPassengers.entries) {
        final seatNum = int.tryParse(entry.key.toString());
        if (seatNum != null && entry.value is Map) {
          final parsed = SeatPassengerInfo.fromMap(
            Map<String, dynamic>.from(entry.value as Map),
            seatNum,
          );
          final prev = fallback?.seatPassengers[seatNum];
          parsedPassengers[seatNum] = prev != null
              ? parsed.copyWith(
                  dni: parsed.dni.isNotEmpty ? parsed.dni : prev.dni,
                  email: parsed.email.isNotEmpty ? parsed.email : prev.email,
                  age: parsed.age ?? prev.age,
                  city: parsed.city.isNotEmpty ? parsed.city : prev.city,
                  photoUrl: parsed.photoUrl.isNotEmpty
                      ? parsed.photoUrl
                      : prev.photoUrl,
                )
              : parsed;
        }
      }
    } else if (fallback != null) {
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
    } else if (fallback != null) {
      parsedRequests.addAll(fallback.pendingRequests);
    }

    final rawChat = data['chatMessages'];
    final parsedChat = <Map<String, dynamic>>[];
    if (rawChat is List) {
      for (final item in rawChat) {
        if (item is Map) {
          parsedChat.add(Map<String, dynamic>.from(item));
        }
      }
    } else if (fallback != null) {
      parsedChat.addAll(fallback.chatMessages);
    }

    final brand =
        (data['vehicleBrand'] ?? fallback?.vehicleBrand ?? '').toString().trim();
    final rawModel =
        (data['vehicleModel'] ?? fallback?.vehicleModel ?? '').toString().trim();
    String displayModel = rawModel;
    if (brand.isNotEmpty &&
        !rawModel.toLowerCase().startsWith(brand.toLowerCase())) {
      displayModel = '$brand $rawModel'.trim();
    }
    if (displayModel.isEmpty) {
      displayModel = 'Toyota Yaris';
    }

    final rawPlate =
        (data['vehiclePlate'] ?? data['plate'] ?? fallback?.vehiclePlate ?? '')
            .toString()
            .trim()
            .toUpperCase();

    return AvailableCarItem(
      id: cleanId,
      driverId: cleanId,
      driverName:
          (data['driverName'] ??
                  data['name'] ??
                  fallback?.driverName ??
                  'Conductor Mijano')
              .toString(),
      driverPhone:
          (data['driverPhone'] ?? data['phone'] ?? fallback?.driverPhone ?? '')
              .toString(),
      vehicleBrand: brand,
      vehicleModel: displayModel,
      vehiclePlate: rawPlate.isNotEmpty ? rawPlate : 'ABC-123',
      agencyName:
          (data['agencyName'] ?? fallback?.agencyName ?? '').toString(),
      departureLabel:
          (data['departureLabel'] ?? fallback?.departureLabel ?? 'Hoy, 14:30')
              .toString(),
      pricePerSeat:
          (data['pricePerSeat'] as num?)?.toDouble() ??
          fallback?.pricePerSeat ??
          PricingSettings.defaultCarPricePerSeat,
      avatarUrl:
          (data['avatarUrl'] ?? data['photoUrl'] ?? fallback?.avatarUrl ?? '')
              .toString(),
      originCity:
          (data['originCity'] ?? data['city'] ?? fallback?.originCity ?? 'Tarapoto')
              .toString(),
      destinationCity:
          (data['destinationCity'] ?? fallback?.destinationCity ?? 'Yurimaguas')
              .toString(),
      seatStates: parsedSeats,
      seatPassengers: parsedPassengers,
      pendingRequests: parsedRequests,
      chatMessages: parsedChat,
      tripStarted: data['tripStarted'] is bool
          ? data['tripStarted'] as bool
          : (fallback?.tripStarted ?? false),
    );
  }
}

/// Repositorio en tiempo real que conecta las cuentas reales de conductores
/// registrados con "Carro / Auto" con la búsqueda de "Autos Disponibles" del
/// pasajero y la pestaña "Vehículo" del conductor.
class IntercityVehicleRepository extends ChangeNotifier {
  IntercityVehicleRepository._internal() {
    _initFirestoreStreams();
  }

  static final IntercityVehicleRepository instance =
      IntercityVehicleRepository._internal();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _plateIndexSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _intercitySub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _usersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _driversSub;

  /// Mapa de autos reales registrados en Firebase (key = uid del conductor).
  final Map<String, AvailableCarItem> _realCarsByUid = {};

  static const Set<String> _legacyDemoIds = {
    'car_1',
    'car_2',
    'car_3',
    'car_4',
  };

  bool _isCarVehicleMap(Map<String, dynamic> data) {
    final rawType =
        (data['vehicleType'] ??
                data['tipoVehiculo'] ??
                (data['vehicle'] is Map
                    ? (data['vehicle'] as Map)['type']
                    : null) ??
                '')
            .toString()
            .trim()
            .toLowerCase();
    if (rawType.contains('moto')) return false;
    final agency = (data['agencyName'] ?? '').toString().trim();
    return rawType == 'carro' ||
        rawType == 'auto' ||
        rawType.contains('carro') ||
        rawType.contains('auto') ||
        agency.isNotEmpty ||
        data['isIntercityCar'] == true;
  }

  /// Todos los vehículos reales registrados con cuenta de Auto / Carro.
  List<AvailableCarItem> get allCars =>
      List.unmodifiable(_realCarsByUid.values.toList());

  /// Ocultamiento Automático por Ocupación Total o Viaje en Curso:
  /// Cuando los 4 asientos de un vehículo alcanzan el estado de ocupados
  /// (availableSeatsCount == 0) o el viaje ya inició, se retira de la lista pública.
  List<AvailableCarItem> get publicAvailableCars {
    final currentUid = AuthService.instance.currentUser?.uid ??
        fb.FirebaseAuth.instance.currentUser?.uid ??
        '';
    return allCars.where((c) {
      // 1. Un pasajero jamás debe ver un auto a su propio nombre o UID
      if (currentUid.isNotEmpty &&
          (c.id == currentUid || c.driverId == currentUid)) {
        return false;
      }
      // 2. Si la placa es un marcador genérico de prueba y no tiene agencia real, descartar
      if (c.vehiclePlate == 'ABC-123' && c.agencyName.trim().isEmpty) {
        return false;
      }
      return c.availableSeatsCount > 0 && !c.tripStarted;
    }).toList();
  }

  /// Obtiene el vehículo correspondiente al conductor autenticado actual
  /// (sin datos por defecto ni pasajeros ficticios).
  AvailableCarItem get driverPrimaryVehicle {
    final user = AuthService.instance.currentUser;
    final uid = user?.uid ?? fb.FirebaseAuth.instance.currentUser?.uid ?? '';
    final rawType = (user?.vehicleType ?? '').trim().toLowerCase();
    final isMoto = rawType.contains('moto');

    // Solo devolver el vehículo de _realCarsByUid si pertenece a este conductor y NO es mototaxi
    if (uid.isNotEmpty && _realCarsByUid.containsKey(uid) && !isMoto) {
      return _realCarsByUid[uid]!;
    }

    // Aislamiento estricto: NUNCA hacer fallback a `_realCarsByUid.values.first`,
    // para evitar que mototaxistas u otros conductores vean viajes o destinos ajenos.
    final brand = (user?.vehicleBrand ?? '').trim();
    final model = (user?.vehicleModel ?? '').trim();
    final fullModel = '$brand $model'.trim();
    return AvailableCarItem(
      id: uid.isNotEmpty ? uid : 'driver_car',
      driverId: uid,
      driverName: (user?.name != null && user!.name!.trim().isNotEmpty)
          ? user.name!.trim()
          : 'Conductor',
      driverPhone: user?.phone ?? '',
      vehicleBrand: brand,
      vehicleModel: fullModel.isNotEmpty ? fullModel : 'Auto',
      vehiclePlate: (user?.vehiclePlate ?? '').trim().toUpperCase(),
      agencyName: user?.agencyName ?? '',
      departureLabel: 'Hoy, 14:30',
      pricePerSeat: PricingSettings.defaultCarPricePerSeat,
      avatarUrl: user?.photoUrl ?? '',
      originCity: user?.city ?? 'Tarapoto',
      destinationCity: 'Yurimaguas',
      tripStarted: false,
      seatStates: const {
        1: 'available',
        2: 'available',
        3: 'available',
        4: 'available',
      },
    );
  }

  AvailableCarItem getCarById(String carId) {
    if (_realCarsByUid.containsKey(carId)) {
      return _realCarsByUid[carId]!;
    }
    for (final c in allCars) {
      if (c.id == carId) return c;
    }
    return driverPrimaryVehicle;
  }

  void _initFirestoreStreams() {
    final db = FirebaseFirestore.instance;

    // 1. Escuchar `plate_index` (colección pública con lectura/escritura abierta
    // para usuarios autenticados en las reglas desplegadas).
    try {
      _plateIndexSub = db.collection('plate_index').snapshots().listen(
        (snapshot) {
          bool changed = false;
          for (final doc in snapshot.docs) {
            final data = doc.data();
            if (doc.id.startsWith('CAR_VEHICLE_') ||
                data['isIntercityCar'] == true) {
              final cleanId = doc.id.startsWith('CAR_VEHICLE_')
                  ? doc.id.substring('CAR_VEHICLE_'.length)
                  : (data['driverId'] ?? data['id'] ?? doc.id).toString();
              if (_legacyDemoIds.contains(cleanId)) continue;

              final existing = _realCarsByUid[cleanId];
              _realCarsByUid[cleanId] = AvailableCarItem.fromFirestoreMap(
                cleanId,
                data,
                fallback: existing,
              );
              changed = true;
            }
          }
          if (changed) notifyListeners();
        },
        onError: (_) {},
      );
    } catch (_) {}

    // 2. Escuchar `intercity_vehicles`
    try {
      _intercitySub = db.collection('intercity_vehicles').snapshots().listen(
        (snapshot) {
          bool changed = false;
          for (final doc in snapshot.docs) {
            if (_legacyDemoIds.contains(doc.id)) continue;
            final data = doc.data();
            final existing = _realCarsByUid[doc.id];
            _realCarsByUid[doc.id] = AvailableCarItem.fromFirestoreMap(
              doc.id,
              data,
              fallback: existing,
            );
            changed = true;
          }
          if (changed) notifyListeners();
        },
        onError: (_) {},
      );
    } catch (_) {}

    // 3. Escuchar conductores de Auto en `users`
    try {
      _usersSub = db
          .collection('users')
          .where('role', isEqualTo: 'driver')
          .snapshots()
          .listen(
            (snapshot) {
              bool changed = false;
              for (final doc in snapshot.docs) {
                final data = doc.data();
                if (_isCarVehicleMap(data)) {
                  _mergeProfileFromUserDoc(doc.id, data, publishIfMissing: true);
                  changed = true;
                }
              }
              if (changed) notifyListeners();
            },
            onError: (_) {},
          );
    } catch (_) {}

    // 4. Escuchar conductores de Auto en `drivers`
    try {
      _driversSub = db.collection('drivers').snapshots().listen(
        (snapshot) {
          bool changed = false;
          for (final doc in snapshot.docs) {
            final data = doc.data();
            if (_isCarVehicleMap(data)) {
              _mergeProfileFromUserDoc(doc.id, data, publishIfMissing: false);
              changed = true;
            }
          }
          if (changed) notifyListeners();
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  void _mergeProfileFromUserDoc(
    String uid,
    Map<String, dynamic> userMap, {
    bool publishIfMissing = false,
  }) {
    if (uid.isEmpty || _legacyDemoIds.contains(uid)) return;

    final existing = _realCarsByUid[uid];
    final brand =
        (userMap['vehicleBrand'] ?? existing?.vehicleBrand ?? '')
            .toString()
            .trim();
    final rawModel =
        (userMap['vehicleModel'] ?? existing?.vehicleModel ?? '')
            .toString()
            .trim();
    String fullModel = rawModel;
    if (brand.isNotEmpty &&
        !rawModel.toLowerCase().startsWith(brand.toLowerCase())) {
      fullModel = '$brand $rawModel'.trim();
    }
    if (fullModel.isEmpty) {
      fullModel = existing?.vehicleModel ?? 'Auto Interprovincial';
    }

    final plate =
        (userMap['vehiclePlate'] ??
                userMap['plate'] ??
                existing?.vehiclePlate ??
                '')
            .toString()
            .trim()
            .toUpperCase();

    final merged = AvailableCarItem(
      id: uid,
      driverId: uid,
      driverName:
          (userMap['name'] ??
                  userMap['driverName'] ??
                  existing?.driverName ??
                  'Conductor Mijano')
              .toString(),
      driverPhone:
          (userMap['phone'] ??
                  userMap['driverPhone'] ??
                  existing?.driverPhone ??
                  '')
              .toString(),
      vehicleBrand: brand,
      vehicleModel: fullModel,
      vehiclePlate: plate.isNotEmpty ? plate : 'SIN-PLACA',
      agencyName:
          (userMap['agencyName'] ?? existing?.agencyName ?? '').toString(),
      departureLabel:
          (userMap['departureLabel'] ?? existing?.departureLabel ?? 'Hoy, 14:30')
              .toString(),
      pricePerSeat:
          (userMap['pricePerSeat'] as num?)?.toDouble() ??
          existing?.pricePerSeat ??
          PricingSettings.defaultCarPricePerSeat,
      avatarUrl:
          (userMap['photoUrl'] ??
                  userMap['avatarUrl'] ??
                  existing?.avatarUrl ??
                  '')
              .toString(),
      originCity:
          (userMap['originCity'] ??
                  userMap['city'] ??
                  existing?.originCity ??
                  'Tarapoto')
              .toString(),
      destinationCity:
          (userMap['destinationCity'] ??
                  existing?.destinationCity ??
                  'Yurimaguas')
              .toString(),
      seatStates:
          existing?.seatStates ??
          const {
            1: 'available',
            2: 'available',
            3: 'available',
            4: 'available',
          },
      seatPassengers: existing?.seatPassengers ?? const {},
      pendingRequests: existing?.pendingRequests ?? const [],
      chatMessages: existing?.chatMessages ?? const [],
      tripStarted: existing?.tripStarted ?? false,
    );

    _realCarsByUid[uid] = merged;

    if (publishIfMissing && existing == null) {
      unawaited(_persistCar(merged));
    }
  }

  final Set<String> _enrichingPassengerIds = {};

  /// Completa automáticamente los datos personales de los pasajeros (DNI, correo,
  /// edad, ciudad, teléfono) consultando `users/{passengerId}` en Firestore.
  Future<void> enrichPassengersFromFirestore(String carId) async {
    final current = getCarById(carId);
    if (current.seatPassengers.isEmpty) return;

    bool anyUpdated = false;
    final updatedPassengers = Map<int, SeatPassengerInfo>.from(
      current.seatPassengers,
    );

    for (final entry in current.seatPassengers.entries) {
      final seatNum = entry.key;
      final pax = entry.value;
      final pid = pax.passengerId.trim();
      if (pid.isEmpty ||
          pid == 'guest' ||
          pid.startsWith('pax_manual_') ||
          _enrichingPassengerIds.contains(pid)) {
        continue;
      }
      if (pax.dni.trim().isNotEmpty && pax.email.trim().isNotEmpty) {
        continue;
      }

      _enrichingPassengerIds.add(pid);
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(pid)
            .get();
        if (doc.exists && doc.data() != null) {
          final d = doc.data()!;
          final fullName = (d['name'] ?? pax.passengerName).toString().trim();
          final phone = (d['phone'] ?? pax.phone).toString().trim();
          final dni = (d['dni'] ?? pax.dni).toString().trim();
          final email = (d['email'] ?? pax.email).toString().trim();
          final age = (d['age'] as num?)?.toInt() ?? pax.age;
          final city = (d['city'] ?? pax.city).toString().trim();
          final photoUrl = (d['photoUrl'] ?? pax.photoUrl).toString().trim();

          updatedPassengers[seatNum] = pax.copyWith(
            passengerName: fullName.isNotEmpty ? fullName : pax.passengerName,
            shortName: SeatPassengerInfo.formatShortName(
              fullName.isNotEmpty ? fullName : pax.passengerName,
            ),
            phone: phone.isNotEmpty ? phone : pax.phone,
            dni: dni,
            email: email,
            age: age,
            city: city,
            photoUrl: photoUrl,
          );
          anyUpdated = true;
        }
      } catch (_) {
      } finally {
        _enrichingPassengerIds.remove(pid);
      }
    }

    if (anyUpdated) {
      final latest = getCarById(carId);
      final mergedPassengers = Map<int, SeatPassengerInfo>.from(
        latest.seatPassengers,
      );
      for (final entry in updatedPassengers.entries) {
        if (mergedPassengers.containsKey(entry.key)) {
          mergedPassengers[entry.key] = entry.value;
        }
      }
      final updatedCar = latest.copyWith(seatPassengers: mergedPassengers);
      _updateLocalCar(updatedCar);
      await _persistCar(updatedCar);
    }
  }

  /// Asegura que la cuenta actual de conductor de Auto esté sincronizada y
  /// publicada en Firestore para que aparezca en "Autos Disponibles".
  Future<void> syncFromUserMap(String uid, Map<String, dynamic> data) async {
    if (uid.isEmpty || !_isCarVehicleMap(data)) return;
    _mergeProfileFromUserDoc(uid, data, publishIfMissing: false);
    notifyListeners();
    final current = _realCarsByUid[uid];
    if (current != null) {
      await _persistCar(current);
    }
  }

  Future<void> ensureCurrentDriverVehicleSynced() async {
    final currentUser = AuthService.instance.currentUser;
    final uid =
        currentUser?.uid ?? fb.FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    if (currentUser != null && currentUser.role == UserRole.driver) {
      await syncFromUserMap(uid, currentUser.toMap());
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists && doc.data() != null) {
        await syncFromUserMap(uid, doc.data()!);
      }
    } catch (_) {}
  }

  Future<void> _persistCar(AvailableCarItem car) async {
    final payload = car.toFirestoreMap();
    final db = FirebaseFirestore.instance;

    try {
      await db
          .collection('plate_index')
          .doc('CAR_VEHICLE_${car.id}')
          .set(payload, SetOptions(merge: true));
    } catch (_) {}

    try {
      await db
          .collection('intercity_vehicles')
          .doc(car.id)
          .set(payload, SetOptions(merge: true));
    } catch (_) {}
  }

  void _updateLocalCar(AvailableCarItem updatedCar) {
    _realCarsByUid[updatedCar.id] = updatedCar;
    notifyListeners();
  }

  /// Actualiza la ruta, horario o precio por asiento del vehículo del conductor.
  Future<void> updateVehicleRouteAndSchedule({
    required String carId,
    required String originCity,
    required String destinationCity,
    required String departureLabel,
    required double pricePerSeat,
  }) async {
    final current = getCarById(carId);
    final updated = current.copyWith(
      originCity: originCity,
      destinationCity: destinationCity,
      departureLabel: departureLabel,
      pricePerSeat: pricePerSeat,
    );
    _updateLocalCar(updated);
    await _persistCar(updated);
  }

  /// Actualiza la capacidad total de asientos del vehículo (ej. 4, 6, 7, 8, etc.)
  /// y reubica la disponibilidad manteniendo los datos de pasajeros previamente asignados.
  Future<void> updateVehicleSeatCapacity({
    required String carId,
    required int totalSeats,
  }) async {
    final current = getCarById(carId);
    final updatedSeats = <int, String>{};
    final updatedPassengers = <int, SeatPassengerInfo>{};

    for (int s = 1; s <= totalSeats; s++) {
      updatedSeats[s] = current.seatStates[s] ?? 'available';
      if (current.seatPassengers.containsKey(s) &&
          updatedSeats[s] == 'occupied') {
        updatedPassengers[s] = current.seatPassengers[s]!;
      }
    }

    final updatedCar = current.copyWith(
      seatStates: updatedSeats,
      seatPassengers: updatedPassengers,
    );

    _updateLocalCar(updatedCar);
    await _persistCar(updatedCar);

    try {
      final user = AuthService.instance.currentUser;
      final uid = user?.uid ?? fb.FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
          'totalSeats': totalSeats,
          'vehicleCapacity': totalSeats,
        }, SetOptions(merge: true));
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'totalSeats': totalSeats,
          'vehicleCapacity': totalSeats,
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  /// Cuando un pasajero confirma un asiento desde "Seleccionar Asiento":
  /// 1. El asiento pasa a 'occupied' con los datos reales del pasajero.
  /// 2. Se agrega una `PendingSeatRequest` para que al conductor le salga el
  ///    banner de "Nueva Solicitud (Pendiente)" con "Aceptar Viaje" y "Rechazar".
  /// 3. Si los 4 asientos quedan ocupados (availableSeats == 0), el vehículo se
  ///    oculta automáticamente de la lista pública de pasajeros.
  Future<void> occupySeat({
    required String carId,
    required int seatNumber,
    required String passengerId,
    required String passengerName,
    required String passengerPhone,
    String passengerDni = '',
    String passengerEmail = '',
    int? passengerAge,
    String passengerCity = '',
    String passengerPhotoUrl = '',
    String etaText = 'ETA: 12 min a 15 min',
    String tripId = '',
    int? reservedAtMs,
    String? removeRequestId,
    bool createPendingBannerForDriver = false,
    String? originCity,
    String? destinationCity,
  }) async {
    final current = getCarById(carId);
    final existingPax = current.seatPassengers[seatNumber];
    final updatedSeats = Map<int, String>.from(current.seatStates);
    updatedSeats[seatNumber] = 'occupied';

    final updatedPassengers = Map<int, SeatPassengerInfo>.from(
      current.seatPassengers,
    );
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    updatedPassengers[seatNumber] = SeatPassengerInfo(
      seatNumber: seatNumber,
      passengerId: passengerId,
      passengerName: passengerName,
      shortName: SeatPassengerInfo.formatShortName(passengerName),
      phone: passengerPhone.isNotEmpty ? passengerPhone : '+51987654321',
      etaText: etaText,
      dni: passengerDni.isNotEmpty ? passengerDni : (existingPax?.dni ?? ''),
      email: passengerEmail.isNotEmpty
          ? passengerEmail
          : (existingPax?.email ?? ''),
      age: passengerAge ?? existingPax?.age,
      city: passengerCity.isNotEmpty
          ? passengerCity
          : (existingPax?.city ?? ''),
      photoUrl: passengerPhotoUrl.isNotEmpty
          ? passengerPhotoUrl
          : (existingPax?.photoUrl ?? ''),
      reservedAtMs: reservedAtMs ?? (existingPax?.reservedAtMs != null && existingPax!.reservedAtMs > 0 ? existingPax.reservedAtMs : nowMs),
      tripId: tripId.isNotEmpty ? tripId : (existingPax?.tripId ?? ''),
    );

    final updatedRequests = List<PendingSeatRequest>.from(
      current.pendingRequests,
    )..removeWhere(
      (r) =>
          (removeRequestId != null && r.requestId == removeRequestId) ||
          r.seatNumber == seatNumber,
    );

    if (createPendingBannerForDriver) {
      updatedRequests.add(
        PendingSeatRequest(
          requestId:
              'req_${DateTime.now().millisecondsSinceEpoch}_s$seatNumber',
          carId: current.id,
          seatNumber: seatNumber,
          passengerId: passengerId,
          passengerName: passengerName,
          passengerPhone: passengerPhone,
          passengerDni: passengerDni,
          passengerEmail: passengerEmail,
          passengerAge: passengerAge,
          passengerCity: passengerCity,
          price: current.pricePerSeat,
          originCity: originCity ?? current.originCity,
          destinationCity: destinationCity ?? current.destinationCity,
        ),
      );
    }

    final updatedCar = current.copyWith(
      seatStates: updatedSeats,
      seatPassengers: updatedPassengers,
      pendingRequests: updatedRequests,
    );

    _updateLocalCar(updatedCar);
    await _persistCar(updatedCar);
    unawaited(enrichPassengersFromFirestore(carId));
  }

  /// El conductor acepta la solicitud pendiente en su pestaña "Vehículo":
  /// mantiene el asiento ocupado y limpia el aviso pendiente.
  Future<void> acceptPendingRequest({
    required String carId,
    required PendingSeatRequest request,
  }) async {
    await occupySeat(
      carId: carId,
      seatNumber: request.seatNumber,
      passengerId: request.passengerId,
      passengerName: request.passengerName,
      passengerPhone: request.passengerPhone,
      passengerDni: request.passengerDni,
      passengerEmail: request.passengerEmail,
      passengerAge: request.passengerAge,
      passengerCity: request.passengerCity,
      etaText: 'ETA: 12 min a 15 min',
      removeRequestId: request.requestId,
      createPendingBannerForDriver: false,
    );
  }

  /// Inicia el viaje interprovincial cuando el vehículo está lleno (4/4) y el
  /// conductor confirma "¿Estás seguro de iniciar el viaje?".
  Future<void> startIntercityTrip(String carId) async {
    final current = getCarById(carId);
    final updatedPassengers = Map<int, SeatPassengerInfo>.from(
      current.seatPassengers,
    );
    for (final entry in updatedPassengers.entries) {
      updatedPassengers[entry.key] = entry.value.copyWith(
        etaText: 'A bordo • En viaje hacia ${current.destinationCity}',
      );
    }
    final updatedCar = current.copyWith(
      tripStarted: true,
      pendingRequests: const [],
      seatPassengers: updatedPassengers,
    );
    _updateLocalCar(updatedCar);
    await _persistCar(updatedCar);
    await enrichPassengersFromFirestore(carId);
  }

  /// Finaliza el viaje interprovincial y deja los 4 asientos disponibles
  /// para una nueva ruta.
  Future<void> finishIntercityTrip(String carId) async {
    final current = getCarById(carId);
    final updatedCar = current.copyWith(
      tripStarted: false,
      seatStates: const {
        1: 'available',
        2: 'available',
        3: 'available',
        4: 'available',
      },
      seatPassengers: const {},
      pendingRequests: const [],
      chatMessages: const [],
    );
    _updateLocalCar(updatedCar);
    await _persistCar(updatedCar);
  }

  /// Reapertura Automática por Cancelación:
  /// Si un pasajero cancela su reserva con anticipación (o el conductor libera
  /// o rechaza el asiento), el sistema libera el asiento correspondiente,
  /// actualiza su estado a 'available' y el vehículo reaparece instantáneamente
  /// en la lista pública reflejando el número real de plazas libres.
  Future<void> cancelSeatReservation({
    required String carId,
    required int seatNumber,
  }) async {
    final current = getCarById(carId);
    final updatedSeats = Map<int, String>.from(current.seatStates);
    updatedSeats[seatNumber] = 'available';

    final updatedPassengers = Map<int, SeatPassengerInfo>.from(
      current.seatPassengers,
    )..remove(seatNumber);

    final updatedRequests = List<PendingSeatRequest>.from(
      current.pendingRequests,
    )..removeWhere((r) => r.seatNumber == seatNumber);

    final updatedCar = current.copyWith(
      seatStates: updatedSeats,
      seatPassengers: updatedPassengers,
      pendingRequests: updatedRequests,
    );

    _updateLocalCar(updatedCar);
    await _persistCar(updatedCar);
  }

  /// El conductor rechaza una solicitud pendiente y libera el asiento.
  Future<void> rejectPendingRequest({
    required String carId,
    required PendingSeatRequest request,
  }) async {
    await cancelSeatReservation(
      carId: carId,
      seatNumber: request.seatNumber,
    );
  }

  /// Envía un mensaje en tiempo real en el chat directo entre conductor y pasajero.
  Future<void> sendDirectChatMessage({
    required String carId,
    required int seatNumber,
    required String senderRole, // 'driver' | 'passenger'
    required String senderName,
    required String text,
  }) async {
    final current = getCarById(carId);
    final updatedChat = List<Map<String, dynamic>>.from(current.chatMessages)
      ..add({
        'seatNumber': seatNumber,
        'sender': senderRole,
        'senderName': senderName,
        'text': text,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    final updatedCar = current.copyWith(chatMessages: updatedChat);
    _updateLocalCar(updatedCar);
    await _persistCar(updatedCar);
  }

  @override
  void dispose() {
    _plateIndexSub?.cancel();
    _intercitySub?.cancel();
    _usersSub?.cancel();
    _driversSub?.cancel();
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
  int _selectedCardIndex = 0;
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
        final currentPassengerUid =
            AuthService.instance.currentUser?.uid ??
            fb.FirebaseAuth.instance.currentUser?.uid ??
            'guest';

        // Buscar asientos reservados por el pasajero actual (incluso en autos llenos)
        final myReservedSeats = <({AvailableCarItem car, int seatNumber})>[];
        for (final car in _repo.allCars) {
          for (final entry in car.seatPassengers.entries) {
            if (entry.value.passengerId == currentPassengerUid) {
              myReservedSeats.add((car: car, seatNumber: entry.key));
            }
          }
        }

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
              // Tarjeta de reservas activas del pasajero con opción de cancelar
              // anticipadamente (dispara la Reapertura Automática en tiempo real).
              if (myReservedSeats.isNotEmpty)
                ...myReservedSeats.map(
                  (res) => Container(
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
                          Icons.event_seat,
                          size: 20,
                          color: Colors.black87,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tu reserva: Asiento ${res.seatNumber} • ${res.car.driverName} (${res.car.vehicleModel} - ${res.car.vehiclePlate})',
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
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                title: const Text('¿Cancelar reserva?'),
                                content: Text(
                                  'Se liberará tu Asiento ${res.seatNumber} en el vehículo de ${res.car.driverName}.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Volver'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Sí, cancelar'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true) return;

                            // 1. Cancelar en repositorio local
                            await _repo.cancelSeatReservation(
                              carId: res.car.id,
                              seatNumber: res.seatNumber,
                            );

                            // 2. Cancelar en Firestore trips
                            try {
                              final tripsQuery = await FirebaseFirestore.instance
                                  .collection('trips')
                                  .where('passengerId', isEqualTo: currentPassengerUid)
                                  .where('seatNumber', isEqualTo: res.seatNumber)
                                  .where('status', whereIn: ['pending', 'accepted', 'active'])
                                  .get();
                              for (final doc in tripsQuery.docs) {
                                await doc.reference.update({
                                  'status': 'cancelled',
                                  'cancelledBy': 'passenger',
                                  'cancelledAt': FieldValue.serverTimestamp(),
                                });
                              }
                            } catch (_) {}

                            if (!context.mounted) return;
                            final updated = _repo.getCarById(res.car.id);
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Reserva del Asiento ${res.seatNumber} cancelada. '
                                  'Vehículo ${res.car.vehiclePlate} (${updated.availableSeatsCount}/4 Disponibles).',
                                ),
                                backgroundColor: Colors.red.shade700,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: const Text(
                            'Cancelar reserva',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (fullHiddenCars.isNotEmpty)
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
                                        child: car.avatarUrl.trim().isNotEmpty
                                            ? Image.network(
                                                car.avatarUrl,
                                                width: 60,
                                                height: 60,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) =>
                                                    _buildAvatarPlaceholder(),
                                              )
                                            : _buildAvatarPlaceholder(),
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
                                            if (car.agencyName
                                                .trim()
                                                .isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                car.agencyName,
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                            ],
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
                                            '$freeSeats/${car.seatStates.length} Disponibles',
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

  Widget _buildAvatarPlaceholder() {
    return Container(
      width: 60,
      height: 60,
      color: const Color(0xFFFFF3B0),
      child: const Icon(
        Icons.person,
        color: Colors.black87,
        size: 32,
      ),
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
  int _passengerCount = 1;
  final Set<int> _selectedSeats = <int>{};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final liveCar = _repo.getCarById(widget.car.id);
    final first = _firstAvailableSeat(liveCar);
    _selectedSeats.add(first);
  }

  int _firstAvailableSeat(AvailableCarItem car) {
    for (final s in [2, 1, 4, 3]) {
      if (car.seatStates[s] != 'occupied') return s;
    }
    return 2;
  }

  Future<void> _confirmSeatBooking(AvailableCarItem liveCar) async {
    if (_selectedSeats.isEmpty) return;
    for (final s in _selectedSeats) {
      if (liveCar.seatStates[s] == 'occupied') return;
    }

    setState(() => _isSubmitting = true);

    final user = AuthService.instance.currentUser;
    final passengerId =
        user?.uid ?? fb.FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final rawName = user?.name?.trim() ?? '';
    final passengerName = rawName.isNotEmpty ? rawName : 'Pasajero Mijano';
    final rawPhone = user?.phone.trim() ?? '';
    final passengerPhone = rawPhone.isNotEmpty ? rawPhone : '+51987654321';

    final rawDni = user?.dni ?? '';
    final rawEmail = user?.email ?? '';
    final rawAge = user?.age;
    final rawCity = user?.city ?? '';
    final rawPhoto = user?.photoUrl ?? '';
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final sortedSeats = _selectedSeats.toList()..sort();

    // 1. Registrar cada asiento en `trips` y ocupar en el repositorio
    for (final seatNum in sortedSeats) {
      String createdTripId = '';
      try {
        final tripRef =
            await FirebaseFirestore.instance.collection('trips').add({
          'passengerId': passengerId,
          'passengerName': passengerName,
          'passengerPhone': passengerPhone,
          'passengerDni': rawDni,
          'passengerEmail': rawEmail,
          'originAddress': widget.originCity,
          'destinationAddress': widget.destinationCity,
          'fareAmount': liveCar.pricePerSeat,
          'serviceType': 'Auto Interprovincial',
          'vehicleType': 'Auto',
          'isIntercityCar': true,
          'carId': liveCar.id,
          'driverId': liveCar.driverId.isNotEmpty ? liveCar.driverId : liveCar.id,
          'driverName': liveCar.driverName,
          'driverPhone': liveCar.driverPhone,
          'driverVehicleModel': liveCar.vehicleModel,
          'driverVehiclePlate': liveCar.vehiclePlate,
          'agencyName': liveCar.agencyName,
          'seatNumber': seatNum,
          'departureLabel': liveCar.departureLabel,
          'status': 'pending',
          'createdAtMs': nowMs,
          'createdAt': FieldValue.serverTimestamp(),
        });
        createdTripId = tripRef.id;
      } catch (_) {}

      await _repo.occupySeat(
        carId: liveCar.id,
        seatNumber: seatNum,
        passengerId: passengerId,
        passengerName: passengerName,
        passengerPhone: passengerPhone,
        passengerDni: rawDni,
        passengerEmail: rawEmail,
        passengerAge: rawAge,
        passengerCity: rawCity,
        passengerPhotoUrl: rawPhoto,
        etaText: 'ETA: 15 min',
        tripId: createdTripId,
        reservedAtMs: nowMs,
        createPendingBannerForDriver: true,
        originCity: widget.originCity,
        destinationCity: widget.destinationCity,
      );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    final updatedCar = _repo.getCarById(liveCar.id);
    final isNowFull = updatedCar.availableSeatsCount == 0;
    final totalFare = liveCar.pricePerSeat * sortedSeats.length;
    final seatsText = sortedSeats.join(', ');

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
                'Reserva Confirmada',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          'Has reservado ${sortedSeats.length == 1 ? 'el Asiento $seatsText' : 'los Asientos $seatsText'} '
          'para la ruta ${widget.originCity} → ${widget.destinationCity} '
          'con ${liveCar.driverName} (${liveCar.vehicleModel} - ${liveCar.vehiclePlate}).\n\n'
          'Total: S/ ${totalFare.toStringAsFixed(2)} '
          '(${sortedSeats.length} ${sortedSeats.length == 1 ? 'persona' : 'personas'})'
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

        // Limpiar asientos que se hayan ocupado externamente
        _selectedSeats.removeWhere((s) => liveCar.seatStates[s] == 'occupied');
        if (_selectedSeats.isEmpty && liveCar.availableSeatsCount > 0) {
          _selectedSeats.add(_firstAvailableSeat(liveCar));
        }

        final sortedSeats = _selectedSeats.toList()..sort();
        final seatsLabel = sortedSeats.join(', ');
        final totalFare = liveCar.pricePerSeat * _selectedSeats.length;
        final isCompleteSelection = _selectedSeats.length == _passengerCount;

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
                        '${liveCar.driverName} • ${liveCar.vehicleModel} (${liveCar.vehiclePlate}) • ${liveCar.departureLabel}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // SECCIÓN: Selector de cantidad de personas que viajan
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBFBFB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: const [
                                    Icon(
                                      Icons.people_alt,
                                      size: 18,
                                      color: Colors.black87,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      '¿Cuántas personas viajan?',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCompleteSelection
                                        ? const Color(0xFFE8F5E9)
                                        : const Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${_selectedSeats.length}/$_passengerCount asientos',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: isCompleteSelection
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFFE65100),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [1, 2, 3, 4].map((paxCount) {
                                final isSelected = _passengerCount == paxCount;
                                final isAllowed =
                                    paxCount <= liveCar.availableSeatsCount;

                                return Expanded(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 3),
                                    child: InkWell(
                                      onTap: isAllowed
                                          ? () {
                                              setState(() {
                                                _passengerCount = paxCount;
                                                // Recortar si sobran asientos
                                                while (_selectedSeats.length >
                                                    _passengerCount) {
                                                  _selectedSeats.remove(
                                                    _selectedSeats.last,
                                                  );
                                                }
                                                // Autocompletar si faltan asientos y hay disponibles
                                                for (final s in [2, 1, 4, 3]) {
                                                  if (_selectedSeats.length >=
                                                      _passengerCount) {
                                                    break;
                                                  }
                                                  if (liveCar.seatStates[s] !=
                                                          'occupied' &&
                                                      !_selectedSeats
                                                          .contains(s)) {
                                                    _selectedSeats.add(s);
                                                  }
                                                }
                                              });
                                            }
                                          : null,
                                      borderRadius: BorderRadius.circular(10),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 180),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 7,
                                        ),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFFF9D408)
                                              : (isAllowed
                                                  ? Colors.white
                                                  : Colors.grey.shade100),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isSelected
                                                ? Colors.black87
                                                : (isAllowed
                                                    ? Colors.grey.shade300
                                                    : Colors.grey.shade200),
                                            width: isSelected ? 1.6 : 1.0,
                                          ),
                                        ),
                                        child: Text(
                                          paxCount == 1
                                              ? '1 persona'
                                              : '$paxCount personas',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                            color: isAllowed
                                                ? Colors.black87
                                                : Colors.grey.shade400,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Diagrama interactivo del Auto o Van según modelo activo (Sedán, Van 8 o Van 16)
                      _buildPassengerChassisDiagram(liveCar),
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
                            (_isSubmitting ||
                                liveCar.availableSeatsCount == 0 ||
                                !isCompleteSelection)
                            ? null
                            : () => _confirmSeatBooking(liveCar),
                        child: Text(
                          _isSubmitting
                              ? 'Confirmando...'
                              : (isCompleteSelection
                                  ? 'Confirmar Asiento${sortedSeats.length > 1 ? 's' : ''} $seatsLabel • S/ ${totalFare.toStringAsFixed(2)}'
                                  : 'Selecciona $_passengerCount asiento${_passengerCount > 1 ? 's' : ''} (${_selectedSeats.length}/$_passengerCount)'),
                          style: const TextStyle(
                            fontSize: 15.5,
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

  Widget _buildPassengerChassisDiagram(AvailableCarItem liveCar) {
    final total = liveCar.seatStates.length;
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
                child: _SeatBoxWidget(
                  seatNumber: i + 1,
                  status: _seatStatus(liveCar, i + 1),
                  onTap: () => _onSelectSeat(liveCar, i + 1),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _seatStatus(AvailableCarItem car, int seatNumber) {
    final baseState = car.seatStates[seatNumber] ?? 'available';
    if (baseState == 'occupied') return 'occupied';
    if (_selectedSeats.contains(seatNumber)) return 'selected';
    return 'available';
  }

  void _onSelectSeat(AvailableCarItem car, int seatNumber) {
    final baseState = car.seatStates[seatNumber] ?? 'available';
    if (baseState == 'occupied') return;

    setState(() {
      if (_selectedSeats.contains(seatNumber)) {
        if (_selectedSeats.length > 1) {
          _selectedSeats.remove(seatNumber);
        }
      } else {
        if (_selectedSeats.length < _passengerCount) {
          _selectedSeats.add(seatNumber);
        } else if (_passengerCount == 1) {
          _selectedSeats.clear();
          _selectedSeats.add(seatNumber);
        } else {
          _selectedSeats.remove(_selectedSeats.first);
          _selectedSeats.add(seatNumber);
        }
      }
    });
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
                  const CustomPaint(
                    size: Size(44, 44),
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
