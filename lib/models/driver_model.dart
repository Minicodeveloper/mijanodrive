import 'package:cloud_firestore/cloud_firestore.dart';

class Driver {
  final String uid;
  final String name; 
  final String email; 
  final String licenseNumber;
  final String plate;
  final String vehicleBrand; 
  final String vehicleModel; 
  final String? photoUrl;
  final String? soatPhotoUrl;
  final String? licensePhotoUrl;
  final Map<String, dynamic> documents; 
  bool isApproved;
  bool isBlocked; 
  final String city;
  final DateTime createdAt;
  bool isAvailable;
  final double? currentLatitude;
  final double? currentLongitude;

  Driver({
    required this.uid,
    required this.name,
    required this.email,
    required this.licenseNumber,
    required this.plate,
    required this.vehicleBrand,
    required this.vehicleModel,
    this.photoUrl,
    this.soatPhotoUrl,
    this.licensePhotoUrl,
    this.documents = const {}, 
    this.isApproved = false,
    this.isBlocked = false,
    required this.city,
    required this.createdAt,
    this.isAvailable = true,
    this.currentLatitude,
    this.currentLongitude,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'licenseNumber': licenseNumber,
      'plate': plate,
      'vehicleBrand': vehicleBrand,
      'vehicleModel': vehicleModel,
      'photoUrl': photoUrl,
      'soatPhotoUrl': soatPhotoUrl,
      'licensePhotoUrl': licensePhotoUrl,
      'documents': documents, 
      'isApproved': isApproved,
      'isBlocked': isBlocked,
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
      name: map['name'] ?? map['fullName'] ?? 'Sin nombre',
      email: map['email'] ?? 'Sin correo',
      licenseNumber: map['licenseNumber'] ?? '',
      plate: map['plate'] ?? map['vehiclePlate'] ?? '',
      vehicleBrand: map['vehicleBrand'] ?? '',
      vehicleModel: map['vehicleModel'] ?? map['vehicle'] ?? 'N/A',
      photoUrl: map['photoUrl'],
      soatPhotoUrl: map['soatPhotoUrl'],
      licensePhotoUrl: map['licensePhotoUrl'],
      documents: Map<String, dynamic>.from(map['documents'] ?? {}), 
      isApproved: map['isApproved'] ?? false,
      isBlocked: map['isBlocked'] ?? false,
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
    String? name,
    String? email,
    String? licenseNumber,
    String? plate,
    String? vehicleBrand,
    String? vehicleModel,
    String? photoUrl,
    String? soatPhotoUrl,
    String? licensePhotoUrl,
    Map<String, dynamic>? documents, 
    bool? isApproved,
    bool? isBlocked,
    String? city,
    DateTime? createdAt,
    bool? isAvailable,
    double? currentLatitude,
    double? currentLongitude,
  }) {
    return Driver(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      plate: plate ?? this.plate,
      vehicleBrand: vehicleBrand ?? this.vehicleBrand,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      photoUrl: photoUrl ?? this.photoUrl,
      soatPhotoUrl: soatPhotoUrl ?? this.soatPhotoUrl,
      licensePhotoUrl: licensePhotoUrl ?? this.licensePhotoUrl,
      documents: documents ?? this.documents, 
      isApproved: isApproved ?? this.isApproved,
      isBlocked: isBlocked ?? this.isBlocked,
      city: city ?? this.city,
      createdAt: createdAt ?? this.createdAt,
      isAvailable: isAvailable ?? this.isAvailable,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
    );
  }
}