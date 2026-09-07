import 'package:cloud_firestore/cloud_firestore.dart';

class Wallet {
  final String uid;
  double balance;
  final String currency;
  final DateTime lastUpdated;

  Wallet({
    required this.uid,
    required this.balance,
    this.currency = 'PEN',
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'balance': balance,
      'currency': currency,
      'lastUpdated': lastUpdated,
    };
  }

  factory Wallet.fromMap(Map<String, dynamic> map, String uid) {
    return Wallet(
      uid: uid,
      balance: (map['balance'] ?? 0).toDouble(),
      currency: map['currency'] ?? 'PEN',
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory Wallet.fromFirestore(DocumentSnapshot doc) {
    return Wallet.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Wallet copyWith({
    String? uid,
    double? balance,
    String? currency,
    DateTime? lastUpdated,
  }) {
    return Wallet(
      uid: uid ?? this.uid,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
