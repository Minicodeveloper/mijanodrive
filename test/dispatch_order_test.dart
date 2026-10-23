import 'package:flutter_test/flutter_test.dart';
import 'package:mijano_drive_app/models/plan_tier.dart';

void main() {
  group('Step 6 Verification Tests for PlanTier.resolve & buildDispatchOrder', () {
    test('Un conductor sin planTier ni duración pero con planName "Mensual" cae en mensual', () {
      final data = {'planName': 'Plan Mensual Especial VIP'};
      expect(PlanTier.resolve(data), PlanTier.mensual);
    });

    test('Un plan personalizado sin "tier" y con duración en horas cae en diario', () {
      final data = {'planName': 'Promoción Flash', 'durationUnit': 'hours', 'durationValue': 12};
      expect(PlanTier.resolve(data), PlanTier.diario);
    });

    test('Un plan personalizado con nombre libre y "tier" explícito se resuelve bien', () {
      final data = {'name': 'Super Promo', 'tier': 'mensual'};
      expect(PlanTier.resolve(data), PlanTier.mensual);
    });

    test('Un mensual lejano va antes que un semanal y un diario cercanos', () {
      final candidates = [
        DispatchCandidate(id: 'd_close', distanceKm: 1.0, tier: PlanTier.diario),
        DispatchCandidate(id: 's_mid', distanceKm: 3.0, tier: PlanTier.semanal),
        DispatchCandidate(id: 'm_far', distanceKm: 45.0, tier: PlanTier.mensual),
      ];

      final order = buildDispatchOrder(candidates);
      expect(order, ['m_far', 's_mid', 'd_close']);
    });

    test('Dentro del mismo tier gana el más cercano', () {
      final candidates = [
        DispatchCandidate(id: 'm_far', distanceKm: 25.0, tier: PlanTier.mensual),
        DispatchCandidate(id: 'm_close', distanceKm: 2.5, tier: PlanTier.mensual),
      ];

      final order = buildDispatchOrder(candidates);
      expect(order, ['m_close', 'm_far']);
    });

    test('Empates exactos de distancia se resuelven de forma determinista por ID ASC', () {
      final candidates = [
        DispatchCandidate(id: 'driver_zeta', distanceKm: 10.0, tier: PlanTier.diario),
        DispatchCandidate(id: 'driver_alpha', distanceKm: 10.0, tier: PlanTier.diario),
      ];

      final order = buildDispatchOrder(candidates);
      expect(order, ['driver_alpha', 'driver_zeta']);
    });
  });
}
