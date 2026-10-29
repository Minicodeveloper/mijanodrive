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

  test('la tarifa mínima eleva el subtotal de un viaje ultracorto en mototaxi', () {
    final quote = settings.quote(
      category: VehicleCategory.moto,
      distanceKm: 0.3,
      durationMin: 2,
      hour: 10,
    );
    expect(quote.minFareApplied, isTrue);
    expect(quote.total, 4.00);
  });

  test('viaje diurno en auto / coche', () {
    final quote = settings.quote(
      category: VehicleCategory.car,
      distanceKm: 5.2,
      durationMin: 15,
      hour: 14,
    );
    expect(quote.isNight, isFalse);
    expect(quote.minFareApplied, isFalse);
    expect(quote.total, 25.50);
  });

  test('viaje nocturno en auto / coche con recargo nocturno', () {
    final quote = settings.quote(
      category: VehicleCategory.car,
      distanceKm: 2.0,
      durationMin: 8,
      hour: 23,
    );
    expect(quote.isNight, isTrue);
    expect(quote.nightSurcharge, 3.0);
    expect(quote.total, 18.40);
  });

  test('la tarifa mínima eleva el subtotal de un viaje ultracorto en auto / coche', () {
    final quote = settings.quote(
      category: VehicleCategory.car,
      distanceKm: 0.3,
      durationMin: 2,
      hour: 10,
    );
    expect(quote.minFareApplied, isTrue);
    expect(quote.total, 15.00);
  });

  test('franja nocturna que cruza medianoche', () {
    expect(settings.isNightHour(22), isTrue);
    expect(settings.isNightHour(5), isTrue);
    expect(settings.isNightHour(6), isFalse);
    expect(settings.isNightHour(21), isFalse);
  });

  test('fromMap sin claves car_* utiliza valores por defecto (retrocompatibilidad)', () {
    final legacyMap = {'moto_baseFare': 3.5, 'nightStartHour': 22};
    final legacySettings = PricingSettings.fromMap(legacyMap);

    expect(legacySettings.tariffFor(VehicleCategory.car).baseFare, 8.0);
    expect(legacySettings.tariffFor(VehicleCategory.car).perKm, 2.5);
    expect(legacySettings.carPricePerSeat, 45.0);
  });

  test('toMap y fromMap conservan los valores y las claves de ambas categorías', () {
    final map = settings.toMap();
    expect(map.containsKey('moto_baseFare'), isTrue);
    expect(map.containsKey('car_baseFare'), isTrue);
    expect(map.containsKey('car_pricePerSeat'), isTrue);
    expect(map['nightStartHour'], 22);
    expect(map['max_offer_radius_km'], 5.0);
    expect(map['car_pricePerSeat'], 45.0);

    final restored = PricingSettings.fromMap(map);
    expect(
      restored.tariffFor(VehicleCategory.moto).perKm,
      settings.tariffFor(VehicleCategory.moto).perKm,
    );
    expect(
      restored.tariffFor(VehicleCategory.car).perKm,
      settings.tariffFor(VehicleCategory.car).perKm,
    );
    expect(restored.carPricePerSeat, 45.0);
  });
}
