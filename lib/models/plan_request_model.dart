import 'package:cloud_firestore/cloud_firestore.dart';

class PlanRequestModel {
  final String id;
  final String driverId;
  final String driverName;
  final String driverPhone;
  final String planId;
  final String planName;
  final num amount;
  final int days;
  final String receiptUrl;
  final String status; // 'pending' | 'approved' | 'rejected'
  final String? rejectReason;
  final DateTime createdAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;

  PlanRequestModel({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.driverPhone,
    required this.planId,
    required this.planName,
    required this.amount,
    required this.days,
    required this.receiptUrl,
    required this.status,
    this.rejectReason,
    required this.createdAt,
    this.reviewedBy,
    this.reviewedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'planId': planId,
      'planName': planName,
      'amount': amount,
      'days': days,
      'receiptUrl': receiptUrl,
      'status': status,
      if (rejectReason != null) 'rejectReason': rejectReason,
      'createdAt': createdAt,
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (reviewedAt != null) 'reviewedAt': reviewedAt,
    };
  }

  factory PlanRequestModel.fromMap(Map<String, dynamic> map, String id) {
    return PlanRequestModel(
      id: id,
      driverId: map['driverId'] ?? '',
      driverName: map['driverName'] ?? '',
      driverPhone: map['driverPhone'] ?? '',
      planId: map['planId'] ?? '',
      planName: map['planName'] ?? '',
      amount: map['amount'] ?? 0,
      days: map['days'] ?? 0,
      receiptUrl: map['receiptUrl'] ?? '',
      status: map['status'] ?? 'pending',
      rejectReason: map['rejectReason'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedBy: map['reviewedBy'],
      reviewedAt: (map['reviewedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory PlanRequestModel.fromFirestore(DocumentSnapshot doc) {
    return PlanRequestModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }
}