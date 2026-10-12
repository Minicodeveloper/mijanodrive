import 'package:cloud_firestore/cloud_firestore.dart';

class DriverPlanModel {
  final String driverId; // Document ID = driverId
  final String planId;
  final String planName;
  final int priority;
  final DateTime startsAt;
  final DateTime expiresAt;
  final String status; // 'active' | 'expired'
  final String activatedBy;
  final DateTime updatedAt;

  DriverPlanModel({
    required this.driverId,
    required this.planId,
    required this.planName,
    required this.priority,
    required this.startsAt,
    required this.expiresAt,
    required this.status,
    required this.activatedBy,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'planId': planId,
      'planName': planName,
      'priority': priority,
      'startsAt': startsAt,
      'expiresAt': expiresAt,
      'status': status,
      'activatedBy': activatedBy,
      'updatedAt': updatedAt,
    };
  }

  factory DriverPlanModel.fromMap(Map<String, dynamic> map, String driverId) {
    return DriverPlanModel(
      driverId: driverId,
      planId: map['planId'] ?? '',
      planName: map['planName'] ?? '',
      priority: map['priority'] ?? 1,
      startsAt: (map['startsAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'active',
      activatedBy: map['activatedBy'] ?? '',
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory DriverPlanModel.fromFirestore(DocumentSnapshot doc) {
    return DriverPlanModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }
}