import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { passenger, driver, admin, operator }

class User {
  final String uid;
  final String phone;
  final String? email;
  final String? name;
  final String? dni;
  final String? photoUrl;
  final UserRole role;
  final DateTime createdAt;
  bool biometricEnabled;
  final String? city;
  final String status;

  // Campos específicos para conductores y sus vehículos
  final String? vehiclePlate;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehicleColor;
  final String? vehicleYear;
  final String? vehicleType;
  final String? licenseNumber;
  final Map<String, dynamic> documents;

  User({
    required this.uid,
    required this.phone,
    this.email,
    this.name,
    this.dni,
    this.photoUrl,
    required this.role,
    required this.createdAt,
    this.biometricEnabled = false,
    this.city,
    this.status = 'approved',
    this.vehiclePlate,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleColor,
    this.vehicleYear,
    this.vehicleType,
    this.licenseNumber,
    this.documents = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'phone': phone,
      'email': email,
      'name': name,
      'dni': dni,
      'photoUrl': photoUrl,
      'role': role.toString().split('.').last,
      'createdAt': createdAt,
      'biometricEnabled': biometricEnabled,
      'city': city,
      'status': status,
      'vehiclePlate': vehiclePlate,
      'vehicleBrand': vehicleBrand,
      'vehicleModel': vehicleModel,
      'vehicleColor': vehicleColor,
      'vehicleYear': vehicleYear,
      'vehicleType': vehicleType,
      'licenseNumber': licenseNumber,
      'documents': documents,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    UserRole parsedRole = UserRole.passenger;
    final r = map['role'];
    if (r == 'driver') parsedRole = UserRole.driver;
    else if (r == 'admin' || r == 'superAdmin') parsedRole = UserRole.admin;
    else if (r == 'operator') parsedRole = UserRole.operator;

    return User(
      uid: map['uid'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'],
      name: map['name'],
      dni: map['dni'],
      photoUrl: map['photoUrl'],
      role: parsedRole,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      biometricEnabled: map['biometricEnabled'] ?? false,
      city: map['city'],
      status: map['status'] ?? 'approved',
      vehiclePlate: map['vehiclePlate'],
      vehicleBrand: map['vehicleBrand'],
      vehicleModel: map['vehicleModel'],
      vehicleColor: map['vehicleColor'],
      vehicleYear: map['vehicleYear'],
      vehicleType: map['vehicleType'],
      licenseNumber: map['licenseNumber'],
      documents: Map<String, dynamic>.from(map['documents'] ?? {}),
    );
  }

  factory User.fromFirestore(DocumentSnapshot doc) {
    return User.fromMap(doc.data() as Map<String, dynamic>);
  }

  User copyWith({
    String? uid,
    String? phone,
    String? email,
    String? name,
    String? dni,
    String? photoUrl,
    UserRole? role,
    DateTime? createdAt,
    bool? biometricEnabled,
    String? city,
    String? status,
    String? vehiclePlate,
    String? vehicleBrand,
    String? vehicleModel,
    String? vehicleColor,
    String? vehicleYear,
    String? vehicleType,
    String? licenseNumber,
    Map<String, dynamic>? documents,
  }) {
    return User(
      uid: uid ?? this.uid,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      name: name ?? this.name,
      dni: dni ?? this.dni,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      city: city ?? this.city,
      status: status ?? this.status,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      vehicleBrand: vehicleBrand ?? this.vehicleBrand,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      vehicleYear: vehicleYear ?? this.vehicleYear,
      vehicleType: vehicleType ?? this.vehicleType,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      documents: documents ?? this.documents,
    );
  }
}