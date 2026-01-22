/// Age calculation and banding for sleep analysis
///
/// Maps a baby's birthDate to an age band with associated sleep expectations.
/// Bands are defined based on developmental stages (0-28d, 1-2m, 2-4m, etc.)
library;

/// Represents age bands for sleep expectations
///
/// Each band corresponds to a developmental stage with distinct sleep patterns.
enum SleepAgeBand {
  /// Newborn: 0-28 days
  newborn0to28d,

  /// 1-2 months (29 days to ~8 weeks)
  months1to2,

  /// 2-4 months
  months2to4,

  /// 4-6 months
  months4to6,

  /// 6-9 months
  months6to9,

  /// 9-12 months
  months9to12,

  /// 12-18 months (1-1.5 years)
  months12to18,

  /// 18-24 months (1.5-2 years)
  months18to24,

  /// 2-3 years
  years2to3,

  /// 3+ years (fallback for older toddlers)
  years3plus,

  /// Unknown age (birthDate not available)
  unknown,
}

/// Extension methods for SleepAgeBand
extension SleepAgeBandExtension on SleepAgeBand {
  /// Human-readable label in Portuguese
  String get labelPt {
    switch (this) {
      case SleepAgeBand.newborn0to28d:
        return 'Recém-nascido (0-4 semanas)';
      case SleepAgeBand.months1to2:
        return '1-2 meses';
      case SleepAgeBand.months2to4:
        return '2-4 meses';
      case SleepAgeBand.months4to6:
        return '4-6 meses';
      case SleepAgeBand.months6to9:
        return '6-9 meses';
      case SleepAgeBand.months9to12:
        return '9-12 meses';
      case SleepAgeBand.months12to18:
        return '12-18 meses';
      case SleepAgeBand.months18to24:
        return '18-24 meses';
      case SleepAgeBand.years2to3:
        return '2-3 anos';
      case SleepAgeBand.years3plus:
        return '3+ anos';
      case SleepAgeBand.unknown:
        return 'Idade desconhecida';
    }
  }

  /// Short label for compact UI
  String get shortLabelPt {
    switch (this) {
      case SleepAgeBand.newborn0to28d:
        return '0-4 sem';
      case SleepAgeBand.months1to2:
        return '1-2m';
      case SleepAgeBand.months2to4:
        return '2-4m';
      case SleepAgeBand.months4to6:
        return '4-6m';
      case SleepAgeBand.months6to9:
        return '6-9m';
      case SleepAgeBand.months9to12:
        return '9-12m';
      case SleepAgeBand.months12to18:
        return '12-18m';
      case SleepAgeBand.months18to24:
        return '18-24m';
      case SleepAgeBand.years2to3:
        return '2-3a';
      case SleepAgeBand.years3plus:
        return '3+a';
      case SleepAgeBand.unknown:
        return '?';
    }
  }

  /// Whether this band has known expectations
  bool get hasExpectations => this != SleepAgeBand.unknown;
}

/// Utility class for age calculations
class AgeCalculator {
  const AgeCalculator._();

  /// Calculates age in days from birthDate to reference date
  ///
  /// Returns null if birthDate is null or in the future.
  static int? ageInDays(DateTime? birthDate, {DateTime? referenceDate}) {
    if (birthDate == null) return null;

    final reference = referenceDate ?? DateTime.now();
    if (birthDate.isAfter(reference)) return null;

    return reference.difference(birthDate).inDays;
  }

  /// Calculates age in months (approximate, 30.44 days/month)
  static double? ageInMonths(DateTime? birthDate, {DateTime? referenceDate}) {
    final days = ageInDays(birthDate, referenceDate: referenceDate);
    if (days == null) return null;
    return days / 30.44;
  }

  /// Determines the sleep age band for a given birthDate
  ///
  /// Returns [SleepAgeBand.unknown] if birthDate is null or invalid.
  static SleepAgeBand ageBand(DateTime? birthDate, {DateTime? referenceDate}) {
    final days = ageInDays(birthDate, referenceDate: referenceDate);
    if (days == null || days < 0) return SleepAgeBand.unknown;

    // Band boundaries in days
    // 0-28 days: newborn
    if (days <= 28) return SleepAgeBand.newborn0to28d;

    // ~1-2 months (29-60 days)
    if (days <= 60) return SleepAgeBand.months1to2;

    // ~2-4 months (61-120 days)
    if (days <= 120) return SleepAgeBand.months2to4;

    // ~4-6 months (121-180 days)
    if (days <= 180) return SleepAgeBand.months4to6;

    // ~6-9 months (181-270 days)
    if (days <= 270) return SleepAgeBand.months6to9;

    // ~9-12 months (271-365 days)
    if (days <= 365) return SleepAgeBand.months9to12;

    // ~12-18 months (366-545 days)
    if (days <= 545) return SleepAgeBand.months12to18;

    // ~18-24 months (546-730 days)
    if (days <= 730) return SleepAgeBand.months18to24;

    // ~2-3 years (731-1095 days)
    if (days <= 1095) return SleepAgeBand.years2to3;

    // 3+ years
    return SleepAgeBand.years3plus;
  }
}
