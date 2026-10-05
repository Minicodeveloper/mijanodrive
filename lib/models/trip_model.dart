import 'package:cloud_firestore/cloud_firestore.dart';

enum TripStatus { pending, accepted, active, completed, cancelled }

enum PaymentMethod { cash, wallet, card }

class Trip {
  final String id;
  final String passengerId;
  final String? passengerName; 
  final String? driverId;
  final String? driverName;
  final String? driverPlate;
  final String? driverVehicleModel;
  final String? driverVehicleBrand;
  final String? driverVehicleColor;
  final GeoPoint origin;
  final GeoPoint destination;
  final String? originAddress;
  final String? destinationAddress;
  final TripStatus status;
  final double fareAmount;
  final PaymentMethod paymentMethod;
  final DateTime createdAt;
  DateTime? completedAt;
  double? rating;
  String? feedback;
  final double distanceKm;

  Trip({
    required this.id,
    required this.passengerId,
    this.passengerName, 
    this.driverId,
    this.driverName,
    this.driverPlate,
    this.driverVehicleModel,
    this.driverVehicleBrand,
    this.driverVehicleColor,
    required this.origin,
    required this.destination,
    this.originAddress,
    this.destinationAddress,
    required this.status,
    required this.fareAmount,
    required this.paymentMethod,
    required this.createdAt,
    this.completedAt,
    this.rating,
    this.feedback,
    required this.distanceKm,
  });

  Map<String, dynamic> toMap() {
    return {
      'passengerId': passengerId,
      'passengerName': passengerName, 
      'driverId': driverId,
      if (driverName != null) 'driverName': driverName,
      if (driverPlate != null) 'driverPlate': driverPlate,
      if (driverVehicleModel != null) 'driverVehicleModel': driverVehicleModel,
      if (driverVehicleBrand != null) 'driverVehicleBrand': driverVehicleBrand,
      if (driverVehicleColor != null) 'driverVehicleColor': driverVehicleColor,
      'origin': origin,
      'destination': destination,
      'originAddress': originAddress,
      'destinationAddress': destinationAddress,
      'status': status.toString().split('.').last,
      'fareAmount': fareAmount,
      'paymentMethod': paymentMethod.toString().split('.').last,
      'createdAt': createdAt,
      'completedAt': completedAt,
      'rating': rating,
      'feedback': feedback,
      'distanceKm': distanceKm,
    };
  }

  factory Trip.fromMap(Map<String, dynamic> map, String id) {
    return Trip(
      id: id,
      passengerId: map['passengerId'] ?? '',
      passengerName: map['passengerName'], 
      driverId: map['driverId'],
      driverName: map['driverName'],
      driverPlate: map['driverPlate'],
      driverVehicleModel: map['driverVehicleModel'],
      driverVehicleBrand: map['driverVehicleBrand'],
      driverVehicleColor: map['driverVehicleColor'],
      origin: map['origin'] ?? GeoPoint(0, 0),
      destination: map['destination'] ?? GeoPoint(0, 0),
      originAddress: map['originAddress'],
      destinationAddress: map['destinationAddress'],
      status: _parseStatus(map['status'] ?? 'pending'),
      fareAmount: (map['fareAmount'] ?? 0).toDouble(),
      paymentMethod: _parsePaymentMethod(map['paymentMethod'] ?? 'cash'),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
      rating: (map['rating'] ?? 0).toDouble(),
      feedback: map['feedback'],
      distanceKm: (map['distanceKm'] ?? 0).toDouble(),
    );
  }

  factory Trip.fromFirestore(DocumentSnapshot doc) {
    return Trip.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  static TripStatus _parseStatus(String status) {
    switch (status) {
      case 'accepted':
        return TripStatus.accepted;
      case 'active':
        return TripStatus.active;
      case 'completed':
        return TripStatus.completed;
      case 'cancelled':
        return TripStatus.cancelled;
      default:
        return TripStatus.pending;
    }
  }

  static PaymentMethod _parsePaymentMethod(String method) {
    switch (method) {
      case 'wallet':
        return PaymentMethod.wallet;
      case 'card':
        return PaymentMethod.card;
      default:
        return PaymentMethod.cash;
    }
  }

  Trip copyWith({
    String? id,
    String? passengerId,
    String? passengerName, 
    String? driverId,
    String? driverName,
    String? driverPlate,
    String? driverVehicleModel,
    String? driverVehicleBrand,
    String? driverVehicleColor,
    GeoPoint? origin,
    GeoPoint? destination,
    String? originAddress,
    String? destinationAddress,
    TripStatus? status,
    double? fareAmount,
    PaymentMethod? paymentMethod,
    DateTime? createdAt,
    DateTime? completedAt,
    double? rating,
    String? feedback,
    double? distanceKm,
  }) {
    return Trip(
      id: id ?? this.id,
      passengerId: passengerId ?? this.passengerId,
      passengerName: passengerName ?? this.passengerName, 
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPlate: driverPlate ?? this.driverPlate,
      driverVehicleModel: driverVehicleModel ?? this.driverVehicleModel,
      driverVehicleBrand: driverVehicleBrand ?? this.driverVehicleBrand,
      driverVehicleColor: driverVehicleColor ?? this.driverVehicleColor,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      originAddress: originAddress ?? this.originAddress,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      status: status ?? this.status,
      fareAmount: fareAmount ?? this.fareAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      rating: rating ?? this.rating,
      feedback: feedback ?? this.feedback,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }
}