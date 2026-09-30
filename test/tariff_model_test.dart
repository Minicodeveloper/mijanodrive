import 'package:flutter_test/flutter_test.dart';
import 'package:mijano_drive_app/models/tariff_model.dart';

void main() {
  final settings = PricingSettings.fromMap(null);

  test('viaje diurno en mototaxi', () {
    final quote = settings.quote(
      category: VehicleCategory.moto,
      distanceKm: 5.2,
      durationMin: 15,
      hour: 14,
    );
    expect(quote.isNight, isFalse);
    expect(quote.minFareApplied, isFalse);
    expect(quote.total, 13.80);
  });

  test('viaje nocturno en mototaxi', () {
    final quote = settings.quote(
      category: VehicleCategory.moto,
      distanceKm: 2.0,
      durationMin: 8,
      hour: 23,
    );
    expect(quote.isNight, isTrue);
    expect(quote.total, 9.10);
  });

  test('la tarifa mínima eleva el subtotal de un viaje ultracorto', () {
    final quote = settings.quote(
      category: VehicleCategory.moto,
      distanceKm: 0.3,
      durationMin: 2,
      hour: 10,
    );
    expect(quote.minFareApplied, isTrue);
    expect(quote.total, 4.00);
  });

  test('franja nocturna que cruza medianoche', () {
    expect(settings.isNightHour(22), isTrue);
    expect(settings.isNightHour(5), isTrue);
    expect(settings.isNightHour(6), isFalse);
    expect(settings.isNightHour(21), isFalse);
  });

  test('toMap y fromMap conservan los valores y las claves del documento', () {
    final map = settings.toMap();
    expect(map.containsKey('moto_baseFare'), isTrue);
    expect(map['nightStartHour'], 22);
    expect(map['max_offer_radius_km'], 5.0);

    final restored = PricingSettings.fromMap(map);
    expect(
      restored.tariffFor(VehicleCategory.moto).perKm,
      settings.tariffFor(VehicleCategory.moto).perKm,
    );
  });
}