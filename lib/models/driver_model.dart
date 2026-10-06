import 'package:cloud_firestore/cloud_firestore.dart';

class Driver {
  final String uid;
  final String name; 
  final String email; 
  final String phone; // <--- Añadido aquí
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
  final String status; 
  final String city;
  final DateTime createdAt;
  bool isAvailable;
  final double? currentLatitude;
  final double? currentLongitude;
  final DateTime? locationUpdatedAt;

  Driver({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone, // <--- Añadido al constructor
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
    this.status = 'pending',
    required this.city,
    required this.createdAt,
    this.isAvailable = true,
    this.currentLatitude,
    this.currentLongitude,
    this.locationUpdatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone, // <--- Añadido a toMap
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
      'status': status,
      'city': city,
      'createdAt': createdAt,
      'isAvailable': isAvailable,
      'currentLatitude': currentLatitude,
      'currentLongitude': currentLongitude,
    };
  }

  factory Driver.fromMap(Map<String, dynamic> map, String uid) {
    // 1. Manejo seguro de 'documents' que puede ser List o Map
    Map<String, dynamic> parsedDocs = {};
    
    void addDoc(String key, dynamic value) {
      if (value is Map) {
        parsedDocs[key] = value['url'];
        parsedDocs['${key}Status'] = value['status'];
      } else if (value is String) {
        parsedDocs[key] = value;
      }
    }

    if (map['documents'] is Map) {
      final docsMap = map['documents'] as Map;
      for (final entry in docsMap.entries) {
        if (!entry.key.toString().endsWith('Status')) {
           addDoc(entry.key.toString(), entry.value);
        } else {
           parsedDocs[entry.key.toString()] = entry.value;
        }
      }
    } else if (map['documents'] is List) {
      final list = map['documents'] as List;
      for (var item in list) {
        if (item is Map) {
          final id = item['id'];
          if (id == 'dni') {
            parsedDocs['docFront'] = item['url'];
            parsedDocs['docFrontStatus'] = item['status'];
          } else if (id == 'license') {
            parsedDocs['licensedDocument'] = item['url'];
            parsedDocs['licensedDocumentStatus'] = item['status'];
          } else if (id == 'soat') {
            parsedDocs['soatPhoto'] = item['url'];
            parsedDocs['soatPhotoStatus'] = item['status'];
          } else {
            parsedDocs[id.toString()] = item['url'];
            parsedDocs['${id}Status'] = item['status'];
          }
        }
      }
    }

    // 2. Manejo seguro de 'createdAt' (Timestamp, String o int)
    DateTime parsedDate = DateTime.now();
    final cAt = map['createdAt'];
    if (cAt is Timestamp) {
      parsedDate = cAt.toDate();
    } else if (cAt is String) {
      parsedDate = DateTime.tryParse(cAt) ?? DateTime.now();
    } else if (cAt is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(cAt);
    }

    // 3. Manejo seguro de locationUpdatedAt
    DateTime? locUpdatedAt;
    final lAt = map['locationUpdatedAt'];
    if (lAt is Timestamp) {
      locUpdatedAt = lAt.toDate();
    } else if (lAt is String) {
      locUpdatedAt = DateTime.tryParse(lAt);
    } else if (lAt is int) {
      locUpdatedAt = DateTime.fromMillisecondsSinceEpoch(lAt);
    }

    return Driver(
      uid: uid,
      name: map['name'] ?? map['fullName'] ?? 'Sin nombre',
      email: map['email'] ?? 'Sin correo',
      phone: map['phone'] ?? '', // <--- Mapeado desde Firestore
      licenseNumber: map['licenseNumber'] ?? '',
      plate: map['plate'] ?? map['vehiclePlate'] ?? '',
      vehicleBrand: map['vehicleBrand'] ?? '',
      vehicleModel: map['vehicleModel'] ?? map['vehicle'] ?? 'N/A',
      photoUrl: map['photoUrl'],
      soatPhotoUrl: map['soatPhotoUrl'],
      licensePhotoUrl: map['licensePhotoUrl'],
      documents: parsedDocs, 
      isApproved: map['isApproved'] ?? false,
      isBlocked: map['isBlocked'] ?? false,
      status: map['status'] ?? 'pending',
      city: map['city'] ?? '',
      createdAt: parsedDate,
      isAvailable: map['isAvailable'] ?? false,
      currentLatitude: (map['currentLatitude'] as num?)?.toDouble(),
      currentLongitude: (map['currentLongitude'] as num?)?.toDouble(),
      locationUpdatedAt: locUpdatedAt,
    );
  }

  factory Driver.fromFirestore(DocumentSnapshot doc) {
    return Driver.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Driver copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone, // <--- Añadido a copyWith
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
    String? status,
    String? city,
    DateTime? createdAt,
    bool? isAvailable,
    double? currentLatitude,
    double? currentLongitude,
    DateTime? locationUpdatedAt,
  }) {
    return Driver(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone, // <--- Añadido aquí
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
      status: status ?? this.status,
      city: city ?? this.city,
      createdAt: createdAt ?? this.createdAt,
      isAvailable: isAvailable ?? this.isAvailable,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      locationUpdatedAt: locationUpdatedAt ?? this.locationUpdatedAt,
    );
  }
}