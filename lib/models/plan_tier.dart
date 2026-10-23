enum PlanTier {
  diario(1),
  semanal(2),
  mensual(3);

  final int rank;
  const PlanTier(this.rank);

  String get key {
    switch (this) {
      case PlanTier.mensual:
        return 'mensual';
      case PlanTier.semanal:
        return 'semanal';
      case PlanTier.diario:
        return 'diario';
    }
  }

  static PlanTier resolve(Map<String, dynamic>? data) {
    if (data == null) return PlanTier.diario;

    // 1. Explicit tier
    final explicit = (data['tier'] ?? data['planTier'])?.toString().toLowerCase().trim();
    if (explicit != null) {
      if (explicit.contains('mensual')) return PlanTier.mensual;
      if (explicit.contains('semanal')) return PlanTier.semanal;
      if (explicit.contains('diario')) return PlanTier.diario;
    }

    // 2. Duration based
    final durationUnit = data['durationUnit']?.toString().toLowerCase().trim();
    final durationValue = (data['durationValue'] as num?)?.toInt() 
        ?? (data['durationDays'] as num?)?.toInt() 
        ?? (data['days'] as num?)?.toInt();

    if (durationUnit == 'hours') {
      return PlanTier.diario;
    }

    if (durationValue != null) {
      if (durationValue >= 28) return PlanTier.mensual;
      if (durationValue >= 7) return PlanTier.semanal;
      return PlanTier.diario;
    }

    // 3. Name based
    final name = (data['planName'] ?? data['name'])?.toString().toLowerCase().trim();
    if (name != null) {
      if (name.contains('mensual')) return PlanTier.mensual;
      if (name.contains('semanal')) return PlanTier.semanal;
    }

    // 4. Default
    return PlanTier.diario;
  }
}

class DispatchCandidate {
  final String id;
  final double distanceKm;
  final PlanTier tier;

  const DispatchCandidate({
    required this.id,
    required this.distanceKm,
    required this.tier,
  });
}

List<String> buildDispatchOrder(List<DispatchCandidate> candidates) {
  final list = List<DispatchCandidate>.from(candidates);
  list.sort((a, b) {
    // tier.rank DESC
    int cmp = b.tier.rank.compareTo(a.tier.rank);
    if (cmp != 0) return cmp;

    // distanceKm ASC
    cmp = a.distanceKm.compareTo(b.distanceKm);
    if (cmp != 0) return cmp;

    // id ASC as deterministic tie-breaker
    return a.id.compareTo(b.id);
  });
  return list.map((c) => c.id).toList();
}
