import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { passenger, driver }

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
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      uid: map['uid'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'],
      name: map['name'],
      dni: map['dni'],
      photoUrl: map['photoUrl'],
      role: (map['role'] ?? 'passenger') == 'driver' ? UserRole.driver : UserRole.passenger,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      biometricEnabled: map['biometricEnabled'] ?? false,
      city: map['city'],
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
    );
  }
}
