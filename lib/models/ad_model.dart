import 'package:cloud_firestore/cloud_firestore.dart';

class AdModel {
  final String id;
  final String companyName;
  final String description;
  final String phone;
  final String imageUrl;
  final String type; // 'banner' | 'imagen'
  final bool isActive;
  final DateTime createdAt;
  final String createdBy;

  AdModel({
    required this.id,
    required this.companyName,
    required this.description,
    required this.phone,
    required this.imageUrl,
    required this.type,
    required this.isActive,
    required this.createdAt,
    required this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'companyName': companyName,
      'description': description,
      'phone': phone,
      'imageUrl': imageUrl,
      'type': type,
      'isActive': isActive,
      'createdAt': createdAt,
      'createdBy': createdBy,
    };
  }

  factory AdModel.fromMap(Map<String, dynamic> map, String id) {
    return AdModel(
      id: id,
      companyName: map['companyName'] ?? '',
      description: map['description'] ?? '',
      phone: map['phone'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      type: map['type'] ?? 'banner',
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'] ?? '',
    );
  }

  factory AdModel.fromFirestore(DocumentSnapshot doc) {
    return AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }
}