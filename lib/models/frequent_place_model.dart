import 'package:flutter/material.dart';

class FrequentPlace {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String iconKey;

  const FrequentPlace({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.iconKey = 'place',
  });

  IconData get icon {
    switch (iconKey.toLowerCase()) {
      case 'home':
      case 'casa':
        return Icons.home_rounded;
      case 'work':
      case 'trabajo':
        return Icons.work_rounded;
      case 'shopping_cart':
      case 'supermercado':
      case 'compras':
        return Icons.shopping_cart_rounded;
      case 'local_hospital':
      case 'hospital':
      case 'salud':
        return Icons.local_hospital_rounded;
      case 'school':
      case 'universidad':
      case 'colegio':
        return Icons.school_rounded;
      case 'fitness_center':
      case 'gym':
      case 'gimnasio':
        return Icons.fitness_center_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'iconKey': iconKey,
    };
  }

  factory FrequentPlace.fromMap(Map<String, dynamic> map) {
    return FrequentPlace(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      iconKey: map['iconKey']?.toString() ?? 'place',
    );
  }
}
