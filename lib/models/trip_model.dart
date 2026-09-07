import 'package:cloud_firestore/cloud_firestore.dart';

enum TripStatus { pending, accepted, active, completed, cancelled }

enum PaymentMethod { cash, wallet, card }

class Trip {
  final String id;
  final String passengerId;
  final String? driverId;
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
  final String city;
  final double distanceKm;

  Trip({
    required this.id,
    required this.passengerId,
    this.driverId,
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
    required this.city,
    required this.distanceKm,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'passengerId': passengerId,
      'driverId': driverId,
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
      'city': city,
      'distanceKm': distanceKm,
    };
  }

  factory Trip.fromMap(Map<String, dynamic> map, String id) {
    return Trip(
      id: id,
      passengerId: map['passengerId'] ?? '',
      driverId: map['driverId'],
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
      city: map['city'] ?? '',
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
    String? driverId,
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
    String? city,
    double? distanceKm,
  }) {
    return Trip(
      id: id ?? this.id,
      passengerId: passengerId ?? this.passengerId,
      driverId: driverId ?? this.driverId,
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
      city: city ?? this.city,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }
}
