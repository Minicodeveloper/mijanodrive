import 'package:cloud_firestore/cloud_firestore.dart';

class PlanModel {
  final String id;
  final String name; // Diario/Semanal/Mensual
  final num price;
  final int durationDays; // 1/7/30
  final int priority; // 1/2/3
  final List<String> benefits;
  final bool isActive;

  PlanModel({
    required this.id,
    required this.name,
    required this.price,
    required this.durationDays,
    required this.priority,
    required this.benefits,
    required this.isActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'durationDays': durationDays,
      'priority': priority,
      'benefits': benefits,
      'isActive': isActive,
    };
  }

  factory PlanModel.fromMap(Map<String, dynamic> map, String id) {
    return PlanModel(
      id: id,
      name: map['name'] ?? '',
      price: map['price'] ?? 0,
      durationDays: map['durationDays'] ?? 1,
      priority: map['priority'] ?? 1,
      benefits: List<String>.from(map['benefits'] ?? []),
      isActive: map['isActive'] ?? true,
    );
  }

  factory PlanModel.fromFirestore(DocumentSnapshot doc) {
    return PlanModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }
}