import 'package:cloud_firestore/cloud_firestore.dart';

enum VehicleCategory {
  moto(
    'moto_',
    'Mototaxi',
    VehicleTariff(
      baseFare: 3.0,
      perKm: 1.5,
      perMinute: 0.2,
      minFare: 4.0,
      nightSurcharge: 1.5,
    ),
  ),
  car(
    'car_',
    'Auto / Coche',
    VehicleTariff(
      baseFare: 8.0,
      perKm: 2.5,
      perMinute: 0.3,
      minFare: 15.0,
      nightSurcharge: 3.0,
    ),
  );

  final String prefix;
  final String label;
  final VehicleTariff defaults;
  const VehicleCategory(this.prefix, this.label, this.defaults);
}

class VehicleTariff {
  final double baseFare;
  final double perKm;
  final double perMinute;
  final double minFare;
  final double nightSurcharge;

  const VehicleTariff({
    required this.baseFare,
    required this.perKm,
    required this.perMinute,
    required this.minFare,
    required this.nightSurcharge,
  });

  factory VehicleTariff.fromMap(
    Map<String, dynamic> map,
    VehicleCategory category,
  ) {
    final defaults = category.defaults;
    double read(String key, double fallback) =>
        (map['${category.prefix}$key'] as num?)?.toDouble() ?? fallback;

    return VehicleTariff(
      baseFare: read('baseFare', defaults.baseFare),
      perKm: read('perKm', defaults.perKm),
      perMinute: read('perMinute', defaults.perMinute),
      minFare: read('minFare', defaults.minFare),
      nightSurcharge: read('nightSurcharge', defaults.nightSurcharge),
    );
  }

  Map<String, dynamic> toMap(VehicleCategory category) {
    final prefix = category.prefix;
    return {
      '${prefix}baseFare': baseFare,
      '${prefix}perKm': perKm,
      '${prefix}perMinute': perMinute,
      '${prefix}minFare': minFare,
      '${prefix}nightSurcharge': nightSurcharge,
    };
  }
}

class FareQuote {
  final double baseFare;
  final double distanceCost;
  final double timeCost;
  final double nightSurcharge;
  final double subtotal;
  final double total;
  final bool isNight;
  final bool minFareApplied;

  const FareQuote({
    required this.baseFare,
    required this.distanceCost,
    required this.timeCost,
    required this.nightSurcharge,
    required this.subtotal,
    required this.total,
    required this.isNight,
    required this.minFareApplied,
  });
}

class PricingSettings {
  static const int defaultNightStartHour = 22;
  static const int defaultNightEndHour = 6;
  static const double defaultMaxOfferRadiusKm = 5.0;
  static const double defaultCarPricePerSeat = 45.0;

  final Map<VehicleCategory, VehicleTariff> tariffs;
  final int nightStartHour;
  final int nightEndHour;
  final double maxOfferRadiusKm;
  final double carPricePerSeat;
  final DateTime? updatedAt;

  const PricingSettings({
    required this.tariffs,
    required this.nightStartHour,
    required this.nightEndHour,
    required this.maxOfferRadiusKm,
    required this.carPricePerSeat,
    this.updatedAt,
  });

  factory PricingSettings.fromMap(Map<String, dynamic>? map) {
    final data = map ?? const <String, dynamic>{};
    return PricingSettings(
      tariffs: {
        for (final category in VehicleCategory.values)
          category: VehicleTariff.fromMap(data, category),
      },
      nightStartHour:
          (data['nightStartHour'] as num?)?.toInt() ?? defaultNightStartHour,
      nightEndHour:
          (data['nightEndHour'] as num?)?.toInt() ?? defaultNightEndHour,
      maxOfferRadiusKm: (data['max_offer_radius_km'] as num?)?.toDouble() ??
          defaultMaxOfferRadiusKm,
      carPricePerSeat: (data['car_pricePerSeat'] as num?)?.toDouble() ??
          defaultCarPricePerSeat,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      for (final entry in tariffs.entries) ...entry.value.toMap(entry.key),
      'nightStartHour': nightStartHour,
      'nightEndHour': nightEndHour,
      'max_offer_radius_km': maxOfferRadiusKm,
      'car_pricePerSeat': carPricePerSeat,
    };
  }

  PricingSettings copyWith({
    Map<VehicleCategory, VehicleTariff>? tariffs,
    int? nightStartHour,
    int? nightEndHour,
    double? maxOfferRadiusKm,
    double? carPricePerSeat,
    DateTime? updatedAt,
  }) {
    return PricingSettings(
      tariffs: tariffs ?? this.tariffs,
      nightStartHour: nightStartHour ?? this.nightStartHour,
      nightEndHour: nightEndHour ?? this.nightEndHour,
      maxOfferRadiusKm: maxOfferRadiusKm ?? this.maxOfferRadiusKm,
      carPricePerSeat: carPricePerSeat ?? this.carPricePerSeat,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  VehicleTariff tariffFor(VehicleCategory category) =>
      tariffs[category] ?? category.defaults;

  bool isNightHour(int hour) {
    if (nightStartHour == nightEndHour) return false;
    if (nightStartHour > nightEndHour) {
      return hour >= nightStartHour || hour < nightEndHour;
    }
    return hour >= nightStartHour && hour < nightEndHour;
  }

  FareQuote quote({
    required VehicleCategory category,
    required double distanceKm,
    required double durationMin,
    int? hour,
  }) {
    final tariff = tariffFor(category);
    final isNight = isNightHour(hour ?? DateTime.now().hour);

    final distanceCost = distanceKm * tariff.perKm;
    final timeCost = durationMin * tariff.perMinute;
    final nightSurcharge = isNight ? tariff.nightSurcharge : 0.0;
    final subtotal =
        tariff.baseFare + distanceCost + timeCost + nightSurcharge;
    final minFareApplied = subtotal < tariff.minFare;

    return FareQuote(
      baseFare: tariff.baseFare,
      distanceCost: distanceCost,
      timeCost: timeCost,
      nightSurcharge: nightSurcharge,
      subtotal: subtotal,
      total: _round2(minFareApplied ? tariff.minFare : subtotal),
      isNight: isNight,
      minFareApplied: minFareApplied,
    );
  }
}

double _round2(double value) => (value * 100).round() / 100;
