import 'package:cloud_firestore/cloud_firestore.dart';

class Driver {
  final String uid;
  final String licenseNumber;
  final String plate;
  final String? soatPhotoUrl;
  final String? licensePhotoUrl;
  bool isApproved;
  final String city;
  final DateTime createdAt;
  bool isAvailable;
  final double? currentLatitude;
  final double? currentLongitude;

  Driver({
    required this.uid,
    required this.licenseNumber,
    required this.plate,
    this.soatPhotoUrl,
    this.licensePhotoUrl,
    this.isApproved = false,
    required this.city,
    required this.createdAt,
    this.isAvailable = true,
    this.currentLatitude,
    this.currentLongitude,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'licenseNumber': licenseNumber,
      'plate': plate,
      'soatPhotoUrl': soatPhotoUrl,
      'licensePhotoUrl': licensePhotoUrl,
      'isApproved': isApproved,
      'city': city,
      'createdAt': createdAt,
      'isAvailable': isAvailable,
      'currentLatitude': currentLatitude,
      'currentLongitude': currentLongitude,
    };
  }

  factory Driver.fromMap(Map<String, dynamic> map, String uid) {
    return Driver(
      uid: uid,
      licenseNumber: map['licenseNumber'] ?? '',
      plate: map['plate'] ?? '',
      soatPhotoUrl: map['soatPhotoUrl'],
      licensePhotoUrl: map['licensePhotoUrl'],
      isApproved: map['isApproved'] ?? false,
      city: map['city'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isAvailable: map['isAvailable'] ?? true,
      currentLatitude: (map['currentLatitude'] as num?)?.toDouble(),
      currentLongitude: (map['currentLongitude'] as num?)?.toDouble(),
    );
  }

  factory Driver.fromFirestore(DocumentSnapshot doc) {
    return Driver.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Driver copyWith({
    String? uid,
    String? licenseNumber,
    String? plate,
    String? soatPhotoUrl,
    String? licensePhotoUrl,
    bool? isApproved,
    String? city,
    DateTime? createdAt,
    bool? isAvailable,
    double? currentLatitude,
    double? currentLongitude,
  }) {
    return Driver(
      uid: uid ?? this.uid,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      plate: plate ?? this.plate,
      soatPhotoUrl: soatPhotoUrl ?? this.soatPhotoUrl,
      licensePhotoUrl: licensePhotoUrl ?? this.licensePhotoUrl,
      isApproved: isApproved ?? this.isApproved,
      city: city ?? this.city,
      createdAt: createdAt ?? this.createdAt,
      isAvailable: isAvailable ?? this.isAvailable,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
    );
  }
}
