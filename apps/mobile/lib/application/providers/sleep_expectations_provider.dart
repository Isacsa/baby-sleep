import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/active_baby_provider.dart';
import 'package:temp_flutter/data/datasources/local/curated_sleep_expectations_loader.dart';
import 'package:temp_flutter/domain/analysis/age_band.dart';
import 'package:temp_flutter/domain/analysis/sleep_expectations.dart';

/// Provider for the curated sleep expectations loader
///
/// Loads expectations from bundled JSON asset on first access.
/// Caches in memory for subsequent reads.
final sleepExpectationsLoaderProvider =
    FutureProvider<CuratedSleepExpectationsLoader>((ref) async {
  final loader = CuratedSleepExpectationsLoader.instance;
  await loader.load();
  return loader;
});

/// Provider for all sleep expectations by age band
///
/// Returns null while loading.
final allSleepExpectationsProvider =
    Provider<AsyncValue<Map<SleepAgeBand, SleepExpectations>>>((ref) {
  final loaderAsync = ref.watch(sleepExpectationsLoaderProvider);

  return loaderAsync.when(
    data: (loader) {
      final expectations = loader.allExpectations;
      if (expectations == null) {
        return const AsyncValue.loading();
      }
      return AsyncValue.data(expectations);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// Provider for sleep expectations for the active baby
///
/// Returns the expectations based on the baby's birthDate and current age.
/// Returns null if:
/// - No active baby
/// - Baby has no birthDate
/// - Expectations not yet loaded
final activeBabySleepExpectationsProvider =
    Provider<AsyncValue<BabySleepExpectationsData?>>((ref) {
  final activeBaby = ref.watch(activeBabyProvider);
  final loaderAsync = ref.watch(sleepExpectationsLoaderProvider);

  if (activeBaby == null) {
    return const AsyncValue.data(null);
  }

  return loaderAsync.when(
    data: (loader) {
      final birthDate = activeBaby.birthDate;
      if (birthDate == null) {
        return AsyncValue.data(BabySleepExpectationsData.noBirthDate(
          babyName: activeBaby.name,
        ));
      }

      final now = DateTime.now();
      final ageInDays = AgeCalculator.ageInDays(birthDate, referenceDate: now);
      final ageBand = AgeCalculator.ageBand(birthDate, referenceDate: now);
      final expectations = loader.getForBand(ageBand);

      return AsyncValue.data(BabySleepExpectationsData(
        babyName: activeBaby.name,
        birthDate: birthDate,
        ageInDays: ageInDays ?? 0,
        ageBand: ageBand,
        expectations: expectations,
      ));
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// Provider for just the age band of the active baby
final activeBabyAgeBandProvider = Provider<SleepAgeBand>((ref) {
  final activeBaby = ref.watch(activeBabyProvider);
  if (activeBaby == null || activeBaby.birthDate == null) {
    return SleepAgeBand.unknown;
  }
  return AgeCalculator.ageBand(activeBaby.birthDate);
});

/// Data class combining baby info with sleep expectations
class BabySleepExpectationsData {
  final String babyName;
  final DateTime? birthDate;
  final int ageInDays;
  final SleepAgeBand ageBand;
  final SleepExpectations? expectations;
  final bool hasBirthDate;

  const BabySleepExpectationsData({
    required this.babyName,
    required this.birthDate,
    required this.ageInDays,
    required this.ageBand,
    required this.expectations,
  }) : hasBirthDate = birthDate != null;

  /// Creates instance for baby without birthDate
  factory BabySleepExpectationsData.noBirthDate({required String babyName}) {
    return BabySleepExpectationsData(
      babyName: babyName,
      birthDate: null,
      ageInDays: 0,
      ageBand: SleepAgeBand.unknown,
      expectations: null,
    );
  }

  /// Whether we have valid expectations for this baby
  bool get hasExpectations => expectations != null;

  /// Age in months (approximate)
  double get ageInMonths => ageInDays / 30.44;

  /// Formatted age string in Portuguese
  String get ageFormattedPt {
    if (!hasBirthDate) return 'Idade desconhecida';

    if (ageInDays <= 28) {
      final weeks = ageInDays ~/ 7;
      return '$weeks semana${weeks != 1 ? 's' : ''}';
    }

    final months = ageInMonths.floor();
    if (months < 12) {
      return '$months ${months == 1 ? 'mês' : 'meses'}';
    }

    final years = months ~/ 12;
    final remainingMonths = months % 12;
    if (remainingMonths == 0) {
      return '$years ano${years != 1 ? 's' : ''}';
    }
    return '$years ano${years != 1 ? 's' : ''} e $remainingMonths ${remainingMonths == 1 ? 'mês' : 'meses'}';
  }

  @override
  String toString() =>
      'BabySleepExpectationsData(name: $babyName, age: $ageInDays days, band: $ageBand)';
}
